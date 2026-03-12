// MovementLibraryView.swift
// 养生八段锦 iPad App - 动作库（8个动作的教学说明）

import SwiftUI

/// 动作库主页（列出8式）
struct MovementLibraryView: View {
    @State private var selectedMovement: MovementDefinition?
    private let movements = MovementLibrary.shared.movements

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(movements) { movement in
                        MovementCard(movement: movement)
                            .onTapGesture { selectedMovement = movement }
                    }
                }
                .padding(20)
            }
            .navigationTitle("动作库")
            .sheet(item: $selectedMovement) { movement in
                MovementDetailView(movement: movement)
            }
        }
    }
}

// MARK: - 动作卡片
struct MovementCard: View {
    let movement: MovementDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 序号角标
            HStack {
                Text("第 \(movement.id + 1) 式")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .cornerRadius(10)
                Spacer()
            }

            // 图标
            Image(systemName: movementIcon(for: movement.id))
                .font(.system(size: 40))
                .foregroundColor(.green.opacity(0.8))
                .frame(maxWidth: .infinity)

            // 名称
            Text(movement.name)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)

            // 功效简介
            Text(movement.subtitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(2)

            // 呼吸指导标签
            HStack(spacing: 6) {
                if movement.hasSides {
                    Label("左右", systemImage: "arrow.left.arrow.right")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
                Label(movement.repeatCount, systemImage: "repeat")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .cardStyle()
        .contentShape(Rectangle())
    }

    // 根据动作序号返回对应 SF Symbol
    private func movementIcon(for index: Int) -> String {
        let icons = [
            "hands.and.sparkles.fill",   // 0 双手托天
            "figure.archery",             // 1 开弓似射雕
            "figure.arms.open",           // 2 调理脾胃
            "figure.mind.and.body",       // 3 往后瞧
            "figure.wave",                // 4 摇头摆尾
            "figure.flexibility",         // 5 两手攀足
            "figure.boxing",              // 6 攒拳怒目
            "figure.stand"                // 7 背后七颠
        ]
        return index < icons.count ? icons[index] : "figure.stand"
    }
}

// MARK: - 动作详情页
struct MovementDetailView: View {
    let movement: MovementDefinition
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 头部信息
                    headerSection

                    // 分步骤说明
                    stepsSection

                    // 关键要领
                    keyPointsSection

                    // 常见错误
                    if !movement.commonErrors.isEmpty {
                        errorsSection
                    }

                    // 呼吸配合
                    breathingSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("第 \(movement.id + 1) 式 · \(movement.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    // MARK: - 头部
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(movement.subtitle)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.green)

            Text(movement.description)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .lineSpacing(4)

            HStack(spacing: 16) {
                Label("保持 \(Int(movement.holdDuration)) 秒", systemImage: "timer")
                Label(movement.repeatCount, systemImage: "repeat")
                if movement.hasSides {
                    Label("左右各练", systemImage: "arrow.left.arrow.right")
                }
            }
            .font(.system(size: 14))
            .foregroundColor(.secondary)
        }
        .padding(20)
        .cardStyle()
    }

    // MARK: - 步骤说明
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("动作步骤")
                .font(.system(size: 20, weight: .bold))

            ForEach(movement.steps, id: \.order) { step in
                HStack(alignment: .top, spacing: 14) {
                    // 步骤序号
                    Text("\(step.order)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.green)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.instruction)
                            .font(.system(size: 16))

                        Label(step.bodyFocus, systemImage: "scope")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .cardStyle()
    }

    // MARK: - 关键要领
    private var keyPointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关键要领")
                .font(.system(size: 20, weight: .bold))

            ForEach(movement.keyPoints, id: \.self) { point in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 18))
                    Text(point)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(20)
        .cardStyle()
    }

    // MARK: - 常见错误
    private var errorsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("常见错误")
                .font(.system(size: 20, weight: .bold))

            ForEach(movement.commonErrors, id: \.error) { commonError in
                VStack(alignment: .leading, spacing: 8) {
                    Label(commonError.error, systemImage: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red)

                    Label(commonError.correction, systemImage: "arrow.turn.up.right")
                        .font(.system(size: 15))
                        .foregroundColor(.green)
                        .padding(.leading, 4)
                }
                .padding(12)
                .background(Color.red.opacity(0.05))
                .cornerRadius(10)
            }
        }
        .padding(20)
        .cardStyle()
    }

    // MARK: - 呼吸配合
    private var breathingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("呼吸配合", systemImage: "wind")
                .font(.system(size: 20, weight: .bold))

            Text(movement.breathingGuide)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .cardStyle()
    }
}

#Preview {
    MovementLibraryView()
}
