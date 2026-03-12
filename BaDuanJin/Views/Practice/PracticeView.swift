// PracticeView.swift
// 养生八段锦 iPad App - 练习入口视图

import SwiftUI
import SwiftData

/// 练习模块入口页面（Tab 中的练习选项卡）
struct PracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PracticeViewModel()
    @State private var isShowingPractice = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                // 标题区
                VStack(spacing: 12) {
                    Image(systemName: "figure.mind.and.body")
                        .font(.system(size: 80))
                        .foregroundColor(.green)

                    Text("八段锦练习")
                        .font(.system(size: 36, weight: .bold))

                    Text("通过前置摄像头实时检测动作姿态\n完成八式，获得练习评分")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // 开始练习按钮
                Button(action: { isShowingPractice = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                        Text("开始练习")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .frame(width: 280, height: 60)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(30)
                    .shadow(color: .green.opacity(0.4), radius: 12, x: 0, y: 6)
                }

                // 提示文字
                Text("练习时请确保前置摄像头能看到您的全身")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("练习")
            .fullScreenCover(isPresented: $isShowingPractice) {
                PracticeSessionView(viewModel: viewModel)
                    .onDisappear {
                        // 练习完成后保存记录
                        if case .sessionCompleted = viewModel.sessionState {
                            viewModel.saveSession(to: modelContext)
                        }
                    }
            }
        }
    }
}

/// 练习会话（全屏覆盖）
struct PracticeSessionView: View {
    @ObservedObject var viewModel: PracticeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch viewModel.sessionState {
            case .idle:
                // 启动时自动进入练习
                Color.black
                    .task { await viewModel.startPractice() }

            case .preparingMovement(let index):
                PracticePreparationView(movementIndex: index, viewModel: viewModel)

            case .detectingMovement(let index):
                PracticeDetectionView(movementIndex: index, viewModel: viewModel)

            case .movementCompleted:
                // 短暂显示完成状态，等待跳转
                PracticeDetectionView(movementIndex: 0, viewModel: viewModel)

            case .sessionCompleted:
                if let result = viewModel.practiceResult {
                    PracticeCompletionView(result: result, onDismiss: { dismiss() })
                }

            case .abandonedByUser:
                Color.clear.onAppear { dismiss() }

            case .errorState(let message):
                PracticeErrorView(message: message, onDismiss: { dismiss() })
            }
        }
        .alert("放弃本次练习？", isPresented: $viewModel.showAbandonAlert) {
            Button("继续练习", role: .cancel) { viewModel.cancelAbandon() }
            Button("放弃", role: .destructive) { viewModel.confirmAbandon() }
        } message: {
            Text("本次练习记录不会被保存")
        }
    }
}

/// 错误提示视图
struct PracticeErrorView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("无法开始练习")
                .font(.system(size: 28, weight: .bold))

            Text(message)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("返回") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(40)
    }
}

#Preview {
    PracticeView()
        .modelContainer(for: [PracticeSession.self, MovementResult.self, UserStats.self], inMemory: true)
}
