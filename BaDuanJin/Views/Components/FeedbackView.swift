// FeedbackView.swift
// 养生八段锦 iPad App - 实时纠正提示组件

import SwiftUI

/// 底部纠正提示横幅
struct FeedbackBannerView: View {
    let message: String
    let detectionState: DetectionState

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            stateIcon

            // 提示文字
            Text(displayMessage)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(bannerBackground)
        .animation(.easeInOut(duration: 0.3), value: displayMessage)
    }

    // MARK: - 根据检测状态显示不同图标
    @ViewBuilder
    private var stateIcon: some View {
        switch detectionState {
        case .waitingForPerson, .paused:
            Image(systemName: "person.fill.questionmark")
                .foregroundColor(.yellow)
                .font(.system(size: 22))
        case .poseGood:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 22))
        case .poseNeedsCorrection:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 22))
        default:
            Image(systemName: "figure.mind.and.body")
                .foregroundColor(.white)
                .font(.system(size: 22))
        }
    }

    // MARK: - 根据状态显示提示文字
    private var displayMessage: String {
        if !message.isEmpty { return message }

        switch detectionState {
        case .waitingForPerson:
            return "请站到摄像头前，确保全身在画面内"
        case .personDetected, .positionChecking:
            return "正在检测姿态..."
        case .poseGood:
            return "保持当前姿势，继续保持！"
        case .paused:
            return "未检测到您，请确保全身在画面内"
        default:
            return ""
        }
    }

    // MARK: - 横幅背景颜色
    private var bannerBackground: some View {
        Group {
            switch detectionState {
            case .poseGood:
                Color.black.opacity(0.6)
            case .poseNeedsCorrection:
                Color(hex: "#1A1A1A").opacity(0.85)
            default:
                Color.black.opacity(0.7)
            }
        }
    }
}

/// 动作保持进度条
struct HoldProgressBar: View {
    let progress: Double  // 0.0 - 1.0
    let requiredSeconds: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 8)

                    // 进度填充
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.linear(duration: 0.1), value: progress)
                }
            }
            .frame(height: 8)

            // 进度文字
            Text(progressText)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 20)
    }

    private var progressColor: Color {
        progress >= 1.0 ? Color(hex: "#4CAF50") : Color(hex: "#2196F3")
    }

    private var progressText: String {
        let elapsed = progress * requiredSeconds
        if progress >= 1.0 {
            return "动作完成！"
        } else {
            return String(format: "保持 %.1f秒 / %.0f秒", elapsed, requiredSeconds)
        }
    }
}
