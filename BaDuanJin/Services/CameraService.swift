// CameraService.swift
// 养生八段锦 iPad App - 摄像头管理服务

import AVFoundation
import UIKit

// MARK: - 摄像头服务协议
protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: CameraService, didOutput sampleBuffer: CMSampleBuffer)
    func cameraService(_ service: CameraService, didFailWith error: CameraError)
    func cameraServiceDidChangeRunningState(_ service: CameraService, isRunning: Bool)
}

// MARK: - 摄像头错误类型
enum CameraError: Error, LocalizedError {
    case permissionDenied           // 权限被拒
    case deviceNotAvailable         // 设备不可用
    case sessionInterrupted         // 会话被中断（如设备过热）
    case configurationFailed        // 配置失败

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "摄像头权限被拒绝，请在设置中开启"
        case .deviceNotAvailable:
            return "摄像头被其他应用占用，请关闭后重试"
        case .sessionInterrupted:
            return "设备温度过高，练习已暂停，稍后继续"
        case .configurationFailed:
            return "摄像头配置失败，请重启应用"
        }
    }
}

// MARK: - 摄像头服务
class CameraService: NSObject {
    // MARK: - 属性
    weak var delegate: CameraServiceDelegate?

    // AVFoundation 核心对象
    let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?

    // 后台串行队列（摄像头输出回调线程）
    private let sessionQueue = DispatchQueue(label: "camera-session", qos: .userInteractive)

    // 帧计数器（每3帧处理一次，约10FPS）
    private var frameCount = 0

    // MARK: - 权限检查
    static func checkPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    // MARK: - 配置摄像头
    func configure() async throws {
        // 检查权限
        guard await Self.checkPermission() else {
            throw CameraError.permissionDenied
        }

        // 在会话队列配置
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                do {
                    try self.setupSession()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - 设置 AVCaptureSession
    private func setupSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // 720p 平衡精度和性能
        captureSession.sessionPreset = .hd1280x720

        // 前置摄像头
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video,
                                                    position: .front) else {
            throw CameraError.deviceNotAvailable
        }

        // 添加输入
        let input = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(input) else {
            throw CameraError.configurationFailed
        }
        captureSession.addInput(input)

        // 配置视频输出
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.alwaysDiscardsLateVideoFrames = true  // 丢弃晚帧保持实时性
        output.setSampleBufferDelegate(self, queue: sessionQueue)

        guard captureSession.canAddOutput(output) else {
            throw CameraError.configurationFailed
        }
        captureSession.addOutput(output)
        self.videoOutput = output

        // 镜像设置（前置摄像头镜像，使显示与用户肢体对应）
        if let connection = output.connection(with: .video) {
            connection.isVideoMirrored = true
        }
    }

    // MARK: - 开始/停止会话
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.delegate?.cameraServiceDidChangeRunningState(self, isRunning: true)
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.delegate?.cameraServiceDidChangeRunningState(self, isRunning: false)
            }
        }
    }

    // MARK: - 根据设备方向获取图像方向
    func imageOrientation(for deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch deviceOrientation {
        case .landscapeLeft:  return .up
        case .landscapeRight: return .upMirrored
        default:              return .up
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // 每3帧处理一次（约10FPS）
        frameCount += 1
        guard frameCount % 3 == 0 else { return }

        delegate?.cameraService(self, didOutput: sampleBuffer)
    }
}
