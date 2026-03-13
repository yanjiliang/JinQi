// PracticePreparationView.swift
// 养生八段锦 iPad App - 动作预备页（倒计时）

import SwiftUI

/// 每式开始前的预备页面
struct PracticePreparationView: View {
    let movementIndex: Int
    @ObservedObject var viewModel: PracticeViewModel

    private var movement: MovementDefinition? {
        MovementLibrary.shared.movement(at: movementIndex)
    }

    var body: some View {
        ZStack {
            Color(hex: "#1A1A2E")  // 深色背景
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // 顶部退出按钮
                HStack {
                    Button(action: { viewModel.requestAbandon() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // 动作序号和名称
                VStack(spacing: 16) {
                    Text("第 \(movementIndex + 1) 式")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))

                    Text(movement?.name ?? "")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)

                    if let subtitle = movement?.subtitle {
                        Text(subtitle)
                            .font(.system(size: 18))
                            .foregroundColor(.green.opacity(0.9))
                    }
                }

                // 动作预览动画
                MovementAnimationView(
                    movementIndex: movementIndex,
                    style: .compact,
                    hasSides: movement?.hasSides ?? false
                )
                .padding(.horizontal, 40)

                // 关键要领
                if let keyPoints = movement?.keyPoints, !keyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("关键要领")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))

                        ForEach(keyPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 6)
                                Text(point)
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }

                // 倒计时圆圈
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 6)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: CGFloat(viewModel.preparationCountdown) / 3.0)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: viewModel.preparationCountdown)

                    Text("\(viewModel.preparationCountdown)")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                }

                // 准备好了按钮（跳过倒计时）
                Button(action: { viewModel.userReadyForMovement() }) {
                    Text("准备好了")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 52)
                        .background(Color.green)
                        .cornerRadius(26)
                }

                Spacer()
            }
        }
    }
}
