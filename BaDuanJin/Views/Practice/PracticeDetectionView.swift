// PracticeDetectionView.swift
// 养生八段锦 iPad App - 摄像头检测页（核心练习界面）

import SwiftUI
import Vision

/// 摄像头检测页面（全屏，横屏优先）
struct PracticeDetectionView: View {
    let movementIndex: Int
    @ObservedObject var viewModel: PracticeViewModel

    private var movement: MovementDefinition? {
        MovementLibrary.shared.movement(at: movementIndex)
    }

    // 根据纠正反馈提取需要标红的关节
    private var incorrectJoints: Set<String> {
        if case .poseNeedsCorrection(let feedbacks) = viewModel.detectionState {
            return Set(feedbacks.map { $0.joint })
        }
        return []
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 背景黑色
                Color.black.ignoresSafeArea()

                // 摄像头预览层
                CameraPreviewView(cameraService: viewModel.cameraService)
                    .ignoresSafeArea()

                // 骨骼叠加层
                SkeletonOverlayView(
                    poseFrame: viewModel.currentPoseFrame,
                    viewSize: geometry.size,
                    incorrectJoints: incorrectJoints
                )
                .ignoresSafeArea()

                // 顶部导航栏（半透明）
                VStack {
                    HStack {
                        // 退出按钮
                        Button(action: { viewModel.requestAbandon() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(radius: 4)
                        }

                        Spacer()

                        // 动作名称
                        VStack(spacing: 2) {
                            Text("第 \(movementIndex + 1) 式")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            Text(movement?.name ?? "")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        // 暂停按钮
                        Button(action: {
                            if case .paused = viewModel.detectionState {
                                viewModel.resume()
                            } else {
                                viewModel.pause()
                            }
                        }) {
                            Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(radius: 4)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.6), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Spacer()
                }

                // 底部：纠正提示 + 进度条
                VStack(spacing: 0) {
                    // 纠正提示横幅
                    FeedbackBannerView(
                        message: viewModel.currentFeedback,
                        detectionState: viewModel.detectionState
                    )

                    // 保持进度条
                    HoldProgressBar(
                        progress: viewModel.holdProgress,
                        requiredSeconds: holdDuration
                    )
                    .padding(.bottom, 12)
                    .background(Color.black.opacity(0.7))
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }

    private var isPaused: Bool {
        if case .paused = viewModel.detectionState { return true }
        return false
    }

    private var holdDuration: Double {
        let durations = [3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 2.0, 5.0]
        return movementIndex < durations.count ? durations[movementIndex] : 3.0
    }
}

