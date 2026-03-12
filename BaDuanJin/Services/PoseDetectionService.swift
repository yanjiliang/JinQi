// PoseDetectionService.swift
// 养生八段锦 iPad App - 人体姿态检测服务（Vision 框架）

import Vision
import CoreMedia
import CoreImage

// MARK: - 检测到的关节点
struct RecognizedPoint {
    let normalizedPoint: CGPoint  // Vision 归一化坐标（原点左下角）
    let confidence: Float         // 置信度（0-1）
}

// MARK: - 姿态帧数据
struct PoseFrame {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]  // 归一化坐标
    let overallConfidence: Float   // 整体置信度（核心关节平均值）
    let timestamp: TimeInterval    // 时间戳
}

// MARK: - 检测结果
enum PoseDetectionResult {
    case noPerson              // 未检测到人体
    case detected(PoseFrame)   // 检测到人体
}

// MARK: - 姿态检测服务
class PoseDetectionService {
    // MARK: - 后台处理队列
    private let detectionQueue = DispatchQueue(label: "pose-detection", qos: .userInteractive)

    // MARK: - 结果回调（在 detectionQueue 回调，调用方需自行切换主线程）
    var onDetectionResult: ((PoseDetectionResult) -> Void)?

    // MARK: - 当前设备方向（由外部更新）
    var imageOrientation: CGImagePropertyOrientation = .up

    // MARK: - 处理 CMSampleBuffer
    func process(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self else { return }

            if let error {
                // 忽略单帧错误，不打断流程
                _ = error
                self.onDetectionResult?(.noPerson)
                return
            }

            guard let observations = request.results as? [VNHumanBodyPoseObservation],
                  let observation = observations.first else {
                self.onDetectionResult?(.noPerson)
                return
            }

            let frame = self.buildPoseFrame(from: observation)
            self.onDetectionResult?(.detected(frame))
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: imageOrientation,
                                            options: [:])
        detectionQueue.async {
            try? handler.perform([request])
        }
    }

    // MARK: - 从 VNHumanBodyPoseObservation 提取关节点
    private func buildPoseFrame(from observation: VNHumanBodyPoseObservation) -> PoseFrame {
        // 需要提取的关节点列表
        let targetJoints: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow, .leftWrist, .rightWrist,
            .leftHip, .rightHip, .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle, .neck, .root
        ]

        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        var confidences: [Float] = []

        for jointName in targetJoints {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence > 0.3 else {
                continue  // 低置信度关节点忽略
            }
            joints[jointName] = point.location
            confidences.append(point.confidence)
        }

        // 计算整体置信度（核心关节平均值）
        let overallConfidence: Float = confidences.isEmpty ? 0 :
            confidences.reduce(0, +) / Float(confidences.count)

        return PoseFrame(
            joints: joints,
            overallConfidence: overallConfidence,
            timestamp: Date().timeIntervalSinceReferenceDate
        )
    }

    // MARK: - 坐标转换：Vision 坐标 → 视图坐标
    /// Vision 坐标系原点在左下角，需翻转 Y 轴
    static func convertToViewCoordinates(normalizedPoint: CGPoint, viewSize: CGSize) -> CGPoint {
        return CGPoint(
            x: normalizedPoint.x * viewSize.width,
            y: (1 - normalizedPoint.y) * viewSize.height
        )
    }
}
