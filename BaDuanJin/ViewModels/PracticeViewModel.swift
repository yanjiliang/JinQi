// PracticeViewModel.swift
// 养生八段锦 iPad App - 练习模式 ViewModel（核心状态管理）

import SwiftUI
import SwiftData
import Vision
import Combine

// MARK: - 练习会话状态
enum PracticeSessionState: Equatable {
    case idle                            // 未开始
    case preparingMovement(index: Int)   // 预备页，倒计时中
    case detectingMovement(index: Int)   // 检测中
    case movementCompleted(index: Int)   // 单动作完成
    case sessionCompleted                // 全部完成
    case abandonedByUser                 // 用户主动放弃
    case errorState(message: String)     // 错误状态

    static func == (lhs: PracticeSessionState, rhs: PracticeSessionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.sessionCompleted, .sessionCompleted), (.abandonedByUser, .abandonedByUser):
            return true
        case (.preparingMovement(let a), .preparingMovement(let b)): return a == b
        case (.detectingMovement(let a), .detectingMovement(let b)): return a == b
        case (.movementCompleted(let a), .movementCompleted(let b)): return a == b
        case (.errorState(let a), .errorState(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - 检测状态
enum DetectionState {
    case waitingForPerson                                      // 未检测到人体
    case personDetected                                        // 检测到人体
    case positionChecking                                      // 正在评估
    case poseGood                                              // 姿态合格，计时中
    case poseNeedsCorrection(feedback: [CorrectionFeedback])  // 需要纠正
    case paused                                                // 暂停
}

// MARK: - 练习 ViewModel
@MainActor
class PracticeViewModel: ObservableObject {
    // MARK: - 发布属性（UI 绑定）
    @Published var sessionState: PracticeSessionState = .idle
    @Published var detectionState: DetectionState = .waitingForPerson
    @Published var holdProgress: Double = 0.0          // 保持进度（0.0-1.0）
    @Published var preparationCountdown: Int = 3        // 预备页倒计时
    @Published var currentFeedback: String = ""         // 当前纠正提示
    @Published var currentPoseFrame: PoseFrame?         // 当前帧数据（骨骼渲染用）
    @Published var movementScores: [Int: Double] = [:]  // 各动作得分
    @Published var movementFeedbacks: [Int: String] = [:] // 各动作主要反馈
    @Published var showAbandonAlert: Bool = false
    @Published var practiceResult: PracticeScoreResult? // 完成后的评分结果

    // MARK: - 内部状态
    let cameraService: CameraService
    private let poseDetectionService: PoseDetectionService
    private let comparisonService: PoseComparisonService
    private let poseAnalyzer: PoseAnalyzer

    private var sessionStartTime: Date?
    private var noPerson_continuousDuration: TimeInterval = 0
    private var lastPersonDetectedTime = Date()
    private var lastFeedbackUpdateTime = Date.distantPast
    private var holdStartTime: Date?
    private var preparationTimer: Timer?
    private var holdTimer: Timer?

    // MARK: - 每个动作的要求保持时长（秒）
    private let holdDurations: [Double] = [3, 3, 3, 3, 3, 3, 2, 5]

    init() {
        cameraService = CameraService()
        poseDetectionService = PoseDetectionService()
        comparisonService = PoseComparisonService()
        poseAnalyzer = PoseAnalyzer(comparisonService: comparisonService)
        setupPoseDetectionCallback()
    }

    // MARK: - 设置姿态检测回调
    private func setupPoseDetectionCallback() {
        poseDetectionService.onDetectionResult = { [weak self] result in
            Task { @MainActor [weak self] in
                self?.handleDetectionResult(result)
            }
        }
        cameraService.delegate = self
    }

    // MARK: - 开始练习
    func startPractice() async {
        sessionStartTime = Date()
        movementScores = [:]
        movementFeedbacks = [:]

        // 检查摄像头权限
        guard await CameraService.checkPermission() else {
            sessionState = .errorState(message: CameraError.permissionDenied.localizedDescription)
            return
        }

        do {
            try await cameraService.configure()
        } catch {
            sessionState = .errorState(message: error.localizedDescription)
            return
        }

        beginPreparation(for: 0)
    }

    // MARK: - 开始某动作的预备倒计时
    func beginPreparation(for movementIndex: Int) {
        sessionState = .preparingMovement(index: movementIndex)
        preparationCountdown = 3

        // 后台初始化摄像头
        cameraService.startSession()

        preparationTimer?.invalidate()
        preparationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.preparationCountdown -= 1
                if self.preparationCountdown <= 0 {
                    timer.invalidate()
                    self.beginDetection(for: movementIndex)
                }
            }
        }
    }

    // MARK: - 用户点击"准备好了"（跳过倒计时）
    func userReadyForMovement() {
        preparationTimer?.invalidate()
        if case .preparingMovement(let index) = sessionState {
            beginDetection(for: index)
        }
    }

    // MARK: - 开始检测某动作
    private func beginDetection(for movementIndex: Int) {
        sessionState = .detectingMovement(index: movementIndex)
        detectionState = .waitingForPerson
        holdProgress = 0.0
        holdStartTime = nil
        poseAnalyzer.beginCollection(for: movementIndex)
    }

    // MARK: - 处理姿态检测结果
    private func handleDetectionResult(_ result: PoseDetectionResult) {
        guard case .detectingMovement(let movementIndex) = sessionState else { return }

        switch result {
        case .noPerson:
            handleNoPerson()

        case .detected(let frame):
            currentPoseFrame = frame
            lastPersonDetectedTime = Date()
            noPerson_continuousDuration = 0

            let movementScore = comparisonService.scoreForMovement(
                userPose: frame.joints,
                movementIndex: movementIndex
            )

            if movementScore.total >= 70 {
                // 姿态合格
                detectionState = .poseGood
                poseAnalyzer.addFrame(frame)
                updateHoldProgress(requiredDuration: holdDurations[movementIndex])

                // 节流更新纠正提示（1秒最多一次）
                updateFeedbackIfNeeded("")
            } else {
                // 姿态需要纠正
                holdStartTime = nil  // 重置计时
                detectionState = .poseNeedsCorrection(feedback: movementScore.corrections)

                if let primary = movementScore.primaryFeedback {
                    updateFeedbackIfNeeded(primary)
                }
            }
        }
    }

    // MARK: - 处理未检测到人体
    private func handleNoPerson() {
        let elapsed = Date().timeIntervalSince(lastPersonDetectedTime)
        if elapsed > 2.0 {
            // 连续2秒未检测到
            detectionState = .paused
            holdStartTime = nil  // 暂停计时但不清零进度
            updateFeedbackIfNeeded("未检测到您，请确保全身在画面内")
        }
    }

    // MARK: - 更新保持进度
    private func updateHoldProgress(requiredDuration: Double) {
        if holdStartTime == nil {
            holdStartTime = Date()
        }

        guard let start = holdStartTime else { return }
        let elapsed = Date().timeIntervalSince(start)
        holdProgress = min(1.0, elapsed / requiredDuration)

        // 进度满，动作完成
        if holdProgress >= 1.0 {
            completeCurrentMovement()
        }
    }

    // MARK: - 节流更新纠正提示
    private func updateFeedbackIfNeeded(_ feedback: String) {
        guard Date().timeIntervalSince(lastFeedbackUpdateTime) > 1.0 else { return }
        lastFeedbackUpdateTime = Date()
        currentFeedback = feedback
    }

    // MARK: - 完成当前动作
    private func completeCurrentMovement() {
        guard case .detectingMovement(let index) = sessionState else { return }

        let score = poseAnalyzer.finishCollection()
        let feedback = poseAnalyzer.generatePrimaryFeedback()
        movementScores[index] = score
        movementFeedbacks[index] = feedback

        sessionState = .movementCompleted(index: index)
        holdProgress = 1.0

        // 短暂停顿后进入下一动作或完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            if index < 7 {
                self.beginPreparation(for: index + 1)
            } else {
                self.completeSession()
            }
        }
    }

    // MARK: - 完成全部练习
    private func completeSession() {
        cameraService.stopSession()
        sessionState = .sessionCompleted

        // 计算最终评分
        let scores = (0..<8).map { movementScores[$0] ?? 50.0 }
        let feedbacks = (0..<8).map { movementFeedbacks[$0] ?? "" }
        let names = MovementLibrary.shared.movements.map { $0.name }

        practiceResult = ScoringEngine.calculateResult(
            movementScores: scores,
            movementFeedbacks: feedbacks,
            movementNames: names
        )
    }

    // MARK: - 保存练习记录到 SwiftData
    func saveSession(to context: ModelContext) {
        guard let result = practiceResult,
              let startTime = sessionStartTime else { return }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        let session = PracticeSession(
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            totalScore: result.totalScore,
            grade: result.grade
        )

        let movementDefs = MovementLibrary.shared.movements
        for (index, score) in result.movementScores.enumerated() {
            let name = index < movementDefs.count ? movementDefs[index].name : "第\(index+1)式"
            let feedback = index < (result.advice.count) ? result.advice.first(where: { $0.movementName == name })?.body ?? "" : ""
            let movementResult = MovementResult(
                movementIndex: index,
                movementName: name,
                score: score,
                feedback: movementFeedbacks[index] ?? "",
                keyPointsData: nil
            )
            movementResult.session = session
            context.insert(movementResult)
        }

        context.insert(session)
        updateUserStats(context: context, session: session)
        try? context.save()
    }

    // MARK: - 更新用户统计
    private func updateUserStats(context: ModelContext, session: PracticeSession) {
        let descriptor = FetchDescriptor<UserStats>()
        if let stats = try? context.fetch(descriptor).first {
            stats.updateAfterSession(session)
        } else {
            let stats = UserStats()
            stats.updateAfterSession(session)
            context.insert(stats)
        }
    }

    // MARK: - 用户请求放弃
    func requestAbandon() {
        showAbandonAlert = true
    }

    func confirmAbandon() {
        showAbandonAlert = false
        preparationTimer?.invalidate()
        holdTimer?.invalidate()
        cameraService.stopSession()
        sessionState = .abandonedByUser
    }

    func cancelAbandon() {
        showAbandonAlert = false
    }

    // MARK: - 暂停/恢复
    func pause() {
        detectionState = .paused
        holdStartTime = nil
    }

    func resume() {
        detectionState = .personDetected
    }

    // MARK: - 获取当前动作定义
    var currentMovementDefinition: MovementDefinition? {
        switch sessionState {
        case .preparingMovement(let index), .detectingMovement(let index), .movementCompleted(let index):
            return MovementLibrary.shared.movement(at: index)
        default:
            return nil
        }
    }
}

// MARK: - CameraServiceDelegate
extension PracticeViewModel: CameraServiceDelegate {
    nonisolated func cameraService(_ service: CameraService, didOutput sampleBuffer: CMSampleBuffer) {
        poseDetectionService.process(sampleBuffer: sampleBuffer)
    }

    nonisolated func cameraService(_ service: CameraService, didFailWith error: CameraError) {
        Task { @MainActor [weak self] in
            self?.sessionState = .errorState(message: error.localizedDescription)
        }
    }

    nonisolated func cameraServiceDidChangeRunningState(_ service: CameraService, isRunning: Bool) {}
}
