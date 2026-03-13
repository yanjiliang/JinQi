// MovementAnimationView.swift
// 锦气 JinQi — 动作动画分解视图

import SwiftUI

// MARK: - 动画骨骼连线定义
private let animationConnections: [(String, String)] = [
    ("nose_joint", "neck_1_joint"),
    ("neck_1_joint", "left_shoulder_1_joint"),
    ("neck_1_joint", "right_shoulder_1_joint"),
    ("left_shoulder_1_joint", "left_forearm_joint"),
    ("left_forearm_joint", "left_hand_joint"),
    ("right_shoulder_1_joint", "right_forearm_joint"),
    ("right_forearm_joint", "right_hand_joint"),
    ("left_shoulder_1_joint", "root"),
    ("right_shoulder_1_joint", "root"),
    ("root", "left_upLeg_joint"),
    ("root", "right_upLeg_joint"),
    ("left_upLeg_joint", "left_leg_joint"),
    ("left_leg_joint", "left_foot_joint"),
    ("right_upLeg_joint", "right_leg_joint"),
    ("right_leg_joint", "right_foot_joint"),
]

// MARK: - 动画样式
enum AnimationStyle {
    case full      // 动作详情页，带控制栏
    case compact   // 练习准备页，自动播放，无控制栏
}

// MARK: - 动画状态管理
@MainActor
class MovementAnimationState: ObservableObject {
    @Published var currentStep = 0
    @Published var animationProgress: CGFloat = 0.0
    @Published var isPlaying = true
    @Published var showMirror = false

    private var timer: Timer?
    var stepCount = 0

    func start() {
        guard isPlaying, stepCount >= 2 else { return }
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard stepCount >= 2 else { return }
        if animationProgress < 1.0 {
            animationProgress = min(1.0, animationProgress + 0.025)
        } else {
            // 停顿
            stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self else { return }
                self.currentStep = (self.currentStep + 1) % self.stepCount
                self.animationProgress = 0.0
                if self.isPlaying { self.start() }
            }
        }
    }

    func goToStep(_ index: Int) {
        stop()
        currentStep = index
        animationProgress = 0.0
        if isPlaying { start() }
    }

    func nextStep() {
        stop()
        currentStep = (currentStep + 1) % max(1, stepCount)
        animationProgress = 0.0
        if isPlaying { start() }
    }

    func previousStep() {
        stop()
        currentStep = currentStep > 0 ? currentStep - 1 : max(0, stepCount - 1)
        animationProgress = 0.0
        if isPlaying { start() }
    }

    func togglePlay() {
        isPlaying.toggle()
        if isPlaying { start() } else { stop() }
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - 动画视图
struct MovementAnimationView: View {
    let movementIndex: Int
    let style: AnimationStyle
    let hasSides: Bool

    @StateObject private var state = MovementAnimationState()

    private var keyframeSet: MovementKeyframeSet? {
        MovementKeyframeLibrary.shared.keyframes(for: movementIndex)
    }

    private var movement: MovementDefinition? {
        MovementLibrary.shared.movement(at: movementIndex)
    }

    var body: some View {
        Group {
            if let kf = keyframeSet, kf.keyframes.count >= 2 {
                animationContent(keyframeSet: kf)
            } else {
                // 无数据时的占位
                Text("动画数据加载中...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if let kf = keyframeSet {
                state.stepCount = kf.keyframes.count
                state.start()
            }
        }
        .onDisappear {
            state.stop()
        }
    }

    // MARK: - 动画主体内容
    private func animationContent(keyframeSet: MovementKeyframeSet) -> some View {
        VStack(spacing: style == .full ? 16 : 8) {
            // 动画画布
            animationCanvas(keyframeSet: keyframeSet)
                .frame(height: style == .full ? 280 : 160)
                .background(Color(hex: "#1A1A2E").opacity(0.95))
                .cornerRadius(16)

            if style == .full {
                // 步骤指示器
                stepIndicator(count: keyframeSet.keyframes.count)

                // 当前步骤说明
                stepInstruction

                // 控制栏
                controlBar
            }
        }
    }

    // MARK: - 动画画布
    private func animationCanvas(keyframeSet: MovementKeyframeSet) -> some View {
        Canvas { context, size in
            let stepCount = keyframeSet.keyframes.count
            guard stepCount >= 2 else { return }

            let fromIndex = state.currentStep % stepCount
            let toIndex = (state.currentStep + 1) % stepCount
            let fromJoints = keyframeSet.keyframes[fromIndex].joints
            let toJoints = keyframeSet.keyframes[toIndex].joints

            // 应用镜像
            let from = state.showMirror ? MovementKeyframeLibrary.mirrored(fromJoints) : fromJoints
            let to = state.showMirror ? MovementKeyframeLibrary.mirrored(toJoints) : toJoints

            // 插值
            let interpolated = MovementKeyframeLibrary.interpolate(from: from, to: to, progress: state.animationProgress)
            let jointDict = Dictionary(uniqueKeysWithValues: interpolated.map { ($0.jointName, $0) })

            // 当前步骤重点部位
            let bodyFocus = movement?.steps.first { $0.order == state.currentStep + 1 }?.bodyFocus ?? ""

            // 绘制连线
            for (jointA, jointB) in animationConnections {
                guard let posA = jointDict[jointA],
                      let posB = jointDict[jointB] else { continue }

                let screenA = toScreen(posA, size: size)
                let screenB = toScreen(posB, size: size)

                var path = Path()
                path.move(to: screenA)
                path.addLine(to: screenB)

                let isHL = isJointInFocus(jointA, bodyFocus: bodyFocus) ||
                           isJointInFocus(jointB, bodyFocus: bodyFocus)
                let lineColor = isHL
                    ? Color(hex: "#FFD700")
                    : Color(hex: "#4CAF50").opacity(0.8)

                context.stroke(path, with: .color(lineColor), lineWidth: isHL ? 5 : 3.5)
            }

            // 绘制关节点
            for joint in interpolated {
                let screen = toScreen(joint, size: size)
                let isHL = isJointInFocus(joint.jointName, bodyFocus: bodyFocus)
                let radius: CGFloat = isHL ? 8 : 6
                let color = isHL ? Color(hex: "#FFD700") : Color(hex: "#4CAF50")
                let rect = CGRect(x: screen.x - radius, y: screen.y - radius,
                                  width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }

            // 绘制头部圆圈
            if let nose = jointDict["nose_joint"] {
                let screen = toScreen(nose, size: size)
                let headRadius: CGFloat = 16
                let headRect = CGRect(x: screen.x - headRadius, y: screen.y - headRadius,
                                      width: headRadius * 2, height: headRadius * 2)
                context.stroke(Path(ellipseIn: headRect),
                               with: .color(Color(hex: "#4CAF50").opacity(0.6)),
                               lineWidth: 2.5)
            }
        }
    }

    // MARK: - 步骤指示器
    private func stepIndicator(count: Int) -> some View {
        HStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == state.currentStep ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .onTapGesture { state.goToStep(index) }
            }
        }
    }

    // MARK: - 步骤说明
    private var stepInstruction: some View {
        VStack(spacing: 6) {
            if let step = movement?.steps.first(where: { $0.order == state.currentStep + 1 }) {
                Text("第 \(step.order) 步")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Text(step.instruction)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(height: 50)
    }

    // MARK: - 控制栏
    private var controlBar: some View {
        HStack(spacing: 28) {
            Button(action: { state.previousStep() }) {
                Image(systemName: "chevron.backward.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
            }

            Button(action: { state.togglePlay() }) {
                Image(systemName: state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }

            Button(action: { state.nextStep() }) {
                Image(systemName: "chevron.forward.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
            }

            if hasSides {
                Divider().frame(height: 30)
                Button(action: { state.showMirror.toggle() }) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 20))
                        Text(state.showMirror ? "右侧" : "左侧")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(state.showMirror ? .orange : .secondary)
                }
            }
        }
    }

    // MARK: - 坐标转换
    private func toScreen(_ joint: JointPosition, size: CGSize) -> CGPoint {
        let drawArea = min(size.width, size.height * 0.9)
        let offsetX = (size.width - drawArea) / 2
        let offsetY = (size.height - drawArea) / 2

        return CGPoint(
            x: offsetX + joint.x * drawArea,
            y: offsetY + (1 - joint.y) * drawArea
        )
    }

    // MARK: - 判断关节是否在当前步骤重点部位
    private func isJointInFocus(_ jointName: String, bodyFocus: String) -> Bool {
        let focusMapping: [String: [String]] = [
            "双手": ["left_hand_joint", "right_hand_joint"],
            "双臂": ["left_shoulder_1_joint", "right_shoulder_1_joint",
                     "left_forearm_joint", "right_forearm_joint",
                     "left_hand_joint", "right_hand_joint"],
            "上举手": ["left_shoulder_1_joint", "left_forearm_joint", "left_hand_joint"],
            "下按手": ["right_shoulder_1_joint", "right_forearm_joint", "right_hand_joint"],
            "拳手": ["left_forearm_joint", "left_hand_joint"],
            "颈部": ["nose_joint", "neck_1_joint"],
            "下肢": ["left_upLeg_joint", "right_upLeg_joint",
                     "left_leg_joint", "right_leg_joint",
                     "left_foot_joint", "right_foot_joint"],
            "脚部": ["left_foot_joint", "right_foot_joint"],
            "腰部": ["root", "left_upLeg_joint", "right_upLeg_joint"],
            "腰背": ["root", "neck_1_joint"],
            "上身": ["neck_1_joint", "left_shoulder_1_joint", "right_shoulder_1_joint", "root"],
            "臀部": ["root", "left_upLeg_joint", "right_upLeg_joint"],
            "上肢": ["left_shoulder_1_joint", "left_forearm_joint", "left_hand_joint"],
            "脊柱": ["neck_1_joint", "root"],
        ]

        guard let focusJoints = focusMapping[bodyFocus], !focusJoints.isEmpty else {
            return false
        }
        return focusJoints.contains(jointName)
    }
}
