// SkeletonOverlayView.swift
// 养生八段锦 iPad App - 骨骼叠加渲染视图

import SwiftUI
import Vision

// MARK: - 骨骼连线定义
private let skeletonConnections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
    // 头部
    (.nose, .leftEye), (.nose, .rightEye),
    // 肩膀
    (.leftShoulder, .rightShoulder),
    // 左臂
    (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
    // 右臂
    (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
    // 躯干
    (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
    // 腰部
    (.leftHip, .rightHip),
    // 左腿
    (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
    // 右腿
    (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    // 颈部
    (.neck, .leftShoulder), (.neck, .rightShoulder)
]

// MARK: - 骨骼叠加视图
struct SkeletonOverlayView: View {
    /// 用户关节点（Vision 归一化坐标，原点左下角）
    let poseFrame: PoseFrame?
    /// 视图尺寸（用于坐标转换）
    let viewSize: CGSize
    /// 需要标红的关节（纠正中）
    let incorrectJoints: Set<String>

    var body: some View {
        Canvas { context, size in
            guard let frame = poseFrame else { return }

            // 绘制骨骼连线
            for (jointA, jointB) in skeletonConnections {
                guard let pointA = frame.joints[jointA],
                      let pointB = frame.joints[jointB] else { continue }

                let screenA = convertToView(normalizedPoint: pointA, size: size)
                let screenB = convertToView(normalizedPoint: pointB, size: size)

                // 连线颜色：任一端点需要纠正则为红色，否则绿色
                let isIncorrect = incorrectJoints.contains(jointA.rawValue.rawValue) ||
                                  incorrectJoints.contains(jointB.rawValue.rawValue)
                let lineColor: Color = isIncorrect ? Color(hex: "#F44336") : Color(hex: "#4CAF50")

                var path = Path()
                path.move(to: screenA)
                path.addLine(to: screenB)
                context.stroke(path, with: .color(lineColor), lineWidth: 3)
            }

            // 绘制关节点
            for (jointName, normalizedPoint) in frame.joints {
                let screenPoint = convertToView(normalizedPoint: normalizedPoint, size: size)
                let isIncorrect = incorrectJoints.contains(jointName.rawValue.rawValue)
                let dotColor: Color = isIncorrect ? Color(hex: "#F44336") : Color(hex: "#4CAF50")

                let dotRect = CGRect(x: screenPoint.x - 5, y: screenPoint.y - 5, width: 10, height: 10)
                context.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
            }
        }
        .allowsHitTesting(false)  // 不拦截触摸事件
    }

    // MARK: - 坐标转换：Vision 归一化 → 视图坐标
    private func convertToView(normalizedPoint: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(
            x: normalizedPoint.x * size.width,
            y: (1 - normalizedPoint.y) * size.height  // Vision Y 轴向上，视图 Y 轴向下
        )
    }
}
