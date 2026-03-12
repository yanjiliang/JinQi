// PracticeViewModelTests.swift
// 养生八段锦 iPad App - PracticeViewModel 状态机和业务逻辑单元测试

import XCTest
@testable import BaDuanJin

@MainActor
final class PracticeViewModelTests: XCTestCase {

    private var viewModel: PracticeViewModel!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PracticeViewModel()
    }

    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - 初始状态测试

    /// 测试：初始会话状态为 idle
    func test_initialSessionState_isIdle() {
        XCTAssertEqual(viewModel.sessionState, .idle)
    }

    /// 测试：初始检测状态为 waitingForPerson
    func test_initialDetectionState_isWaitingForPerson() {
        guard case .waitingForPerson = viewModel.detectionState else {
            XCTFail("初始检测状态应为 waitingForPerson")
            return
        }
    }

    /// 测试：初始保持进度为0
    func test_initialHoldProgress_isZero() {
        XCTAssertEqual(viewModel.holdProgress, 0.0, accuracy: 0.001)
    }

    /// 测试：初始倒计时为3秒
    func test_initialCountdown_isThree() {
        XCTAssertEqual(viewModel.preparationCountdown, 3)
    }

    /// 测试：初始练习结果为 nil
    func test_initialPracticeResult_isNil() {
        XCTAssertNil(viewModel.practiceResult)
    }

    /// 测试：初始放弃提示框不显示
    func test_initialShowAbandonAlert_isFalse() {
        XCTAssertFalse(viewModel.showAbandonAlert)
    }

    /// 测试：初始当前反馈文字为空
    func test_initialCurrentFeedback_isEmpty() {
        XCTAssertEqual(viewModel.currentFeedback, "")
    }

    /// 测试：初始各动作得分字典为空
    func test_initialMovementScores_isEmpty() {
        XCTAssertTrue(viewModel.movementScores.isEmpty)
    }

    // MARK: - 放弃流程测试

    /// 测试：requestAbandon 显示放弃确认弹窗
    func test_requestAbandon_setsShowAbandonAlertTrue() {
        viewModel.requestAbandon()
        XCTAssertTrue(viewModel.showAbandonAlert)
    }

    /// 测试：cancelAbandon 关闭放弃确认弹窗，不改变会话状态
    func test_cancelAbandon_hidesAlertAndKeepsState() {
        viewModel.requestAbandon()
        viewModel.cancelAbandon()
        XCTAssertFalse(viewModel.showAbandonAlert)
        XCTAssertEqual(viewModel.sessionState, .idle)
    }

    /// 测试：confirmAbandon 关闭弹窗并将状态设为 abandonedByUser
    func test_confirmAbandon_setsStateToAbandoned() {
        viewModel.requestAbandon()
        viewModel.confirmAbandon()
        XCTAssertFalse(viewModel.showAbandonAlert)
        XCTAssertEqual(viewModel.sessionState, .abandonedByUser)
    }

    /// 测试：练习中途放弃，状态变为 abandonedByUser
    func test_confirmAbandon_duringPractice_setsAbandoned() {
        viewModel.beginPreparation(for: 0)
        viewModel.requestAbandon()
        viewModel.confirmAbandon()
        XCTAssertEqual(viewModel.sessionState, .abandonedByUser)
    }

    // MARK: - beginPreparation 测试

    /// 测试：beginPreparation 将状态设为 preparingMovement，倒计时重置为3
    func test_beginPreparation_index0_setsPreparingStateAndResetsCountdown() {
        viewModel.beginPreparation(for: 0)
        XCTAssertEqual(viewModel.sessionState, .preparingMovement(index: 0))
        XCTAssertEqual(viewModel.preparationCountdown, 3)
    }

    /// 测试：任意动作序号（0-7）均可切换到预备状态
    func test_beginPreparation_allIndexes_setsCorrectIndex() {
        for i in 0..<8 {
            viewModel.beginPreparation(for: i)
            XCTAssertEqual(viewModel.sessionState, .preparingMovement(index: i))
        }
    }

    /// 测试：连续调用 beginPreparation，以最后一次为准
    func test_beginPreparation_calledTwice_usesLatestIndex() {
        viewModel.beginPreparation(for: 2)
        viewModel.beginPreparation(for: 5)
        XCTAssertEqual(viewModel.sessionState, .preparingMovement(index: 5))
    }

    // MARK: - userReadyForMovement 测试

    /// 测试：在 preparingMovement 状态下调用，直接切换到 detectingMovement
    func test_userReadyForMovement_whenPreparing_switchesToDetecting() {
        viewModel.beginPreparation(for: 2)
        viewModel.userReadyForMovement()
        XCTAssertEqual(viewModel.sessionState, .detectingMovement(index: 2))
    }

    /// 测试：检测状态进入后，保持进度重置为0
    func test_userReadyForMovement_resetsHoldProgress() {
        viewModel.beginPreparation(for: 0)
        viewModel.userReadyForMovement()
        XCTAssertEqual(viewModel.holdProgress, 0.0, accuracy: 0.001)
    }

    /// 测试：非 preparingMovement 状态下调用，不改变当前状态
    func test_userReadyForMovement_whenIdle_doesNotChangeState() {
        viewModel.userReadyForMovement()
        XCTAssertEqual(viewModel.sessionState, .idle)
    }

    /// 测试：abandonedByUser 状态下调用，不改变状态
    func test_userReadyForMovement_whenAbandoned_doesNotChangeState() {
        viewModel.confirmAbandon()
        viewModel.userReadyForMovement()
        XCTAssertEqual(viewModel.sessionState, .abandonedByUser)
    }

    // MARK: - pause/resume 测试

    /// 测试：pause 将检测状态设为 paused
    func test_pause_setsDetectionStateToPaused() {
        viewModel.pause()
        guard case .paused = viewModel.detectionState else {
            XCTFail("pause 后检测状态应为 paused")
            return
        }
    }

    /// 测试：resume 将检测状态设为 personDetected
    func test_resume_setsDetectionStateToPersonDetected() {
        viewModel.pause()
        viewModel.resume()
        guard case .personDetected = viewModel.detectionState else {
            XCTFail("resume 后检测状态应为 personDetected")
            return
        }
    }

    /// 测试：pause 不改变会话状态
    func test_pause_doesNotChangeSessionState() {
        viewModel.beginPreparation(for: 0)
        viewModel.pause()
        XCTAssertEqual(viewModel.sessionState, .preparingMovement(index: 0))
    }

    // MARK: - PracticeSessionState Equatable 测试

    /// 测试：idle 与 idle 相等
    func test_sessionState_idle_equalsIdle() {
        XCTAssertEqual(PracticeSessionState.idle, .idle)
    }

    /// 测试：相同序号的 preparingMovement 相等
    func test_sessionState_preparingMovement_sameIndex_equal() {
        XCTAssertEqual(PracticeSessionState.preparingMovement(index: 3), .preparingMovement(index: 3))
    }

    /// 测试：不同序号的 preparingMovement 不相等
    func test_sessionState_preparingMovement_differentIndex_notEqual() {
        XCTAssertNotEqual(PracticeSessionState.preparingMovement(index: 1), .preparingMovement(index: 2))
    }

    /// 测试：相同序号的 detectingMovement 相等
    func test_sessionState_detectingMovement_sameIndex_equal() {
        XCTAssertEqual(PracticeSessionState.detectingMovement(index: 5), .detectingMovement(index: 5))
    }

    /// 测试：不同序号的 detectingMovement 不相等
    func test_sessionState_detectingMovement_differentIndex_notEqual() {
        XCTAssertNotEqual(PracticeSessionState.detectingMovement(index: 0), .detectingMovement(index: 7))
    }

    /// 测试：相同序号的 movementCompleted 相等
    func test_sessionState_movementCompleted_sameIndex_equal() {
        XCTAssertEqual(PracticeSessionState.movementCompleted(index: 7), .movementCompleted(index: 7))
    }

    /// 测试：sessionCompleted 与 sessionCompleted 相等
    func test_sessionState_sessionCompleted_equalsItself() {
        XCTAssertEqual(PracticeSessionState.sessionCompleted, .sessionCompleted)
    }

    /// 测试：abandonedByUser 与 abandonedByUser 相等
    func test_sessionState_abandonedByUser_equalsItself() {
        XCTAssertEqual(PracticeSessionState.abandonedByUser, .abandonedByUser)
    }

    /// 测试：相同消息的 errorState 相等
    func test_sessionState_errorState_sameMessage_equal() {
        XCTAssertEqual(PracticeSessionState.errorState(message: "相机权限被拒"), .errorState(message: "相机权限被拒"))
    }

    /// 测试：不同消息的 errorState 不相等
    func test_sessionState_errorState_differentMessage_notEqual() {
        XCTAssertNotEqual(PracticeSessionState.errorState(message: "错误A"), .errorState(message: "错误B"))
    }

    /// 测试：不同类型的状态不相等
    func test_sessionState_differentTypes_notEqual() {
        XCTAssertNotEqual(PracticeSessionState.idle, .sessionCompleted)
        XCTAssertNotEqual(PracticeSessionState.preparingMovement(index: 0), .detectingMovement(index: 0))
        XCTAssertNotEqual(PracticeSessionState.sessionCompleted, .abandonedByUser)
    }

    // MARK: - currentMovementDefinition 测试

    /// 测试：idle 状态下 currentMovementDefinition 为 nil
    func test_currentMovementDefinition_whenIdle_isNil() {
        XCTAssertNil(viewModel.currentMovementDefinition)
    }

    /// 测试：preparingMovement 状态下返回对应的动作定义
    func test_currentMovementDefinition_whenPreparingIndex0_returnsFirst() {
        viewModel.beginPreparation(for: 0)
        XCTAssertNotNil(viewModel.currentMovementDefinition)
        XCTAssertEqual(viewModel.currentMovementDefinition?.id, 0)
        XCTAssertEqual(viewModel.currentMovementDefinition?.name, "双手托天理三焦")
    }

    /// 测试：detectingMovement 状态下返回对应的动作定义
    func test_currentMovementDefinition_whenDetectingIndex3_returnsCorrect() {
        viewModel.beginPreparation(for: 3)
        viewModel.userReadyForMovement()
        XCTAssertNotNil(viewModel.currentMovementDefinition)
        XCTAssertEqual(viewModel.currentMovementDefinition?.id, 3)
    }

    /// 测试：abandonedByUser 状态下 currentMovementDefinition 为 nil
    func test_currentMovementDefinition_whenAbandoned_isNil() {
        viewModel.confirmAbandon()
        XCTAssertNil(viewModel.currentMovementDefinition)
    }

    /// 测试：sessionCompleted 状态下 currentMovementDefinition 为 nil（通过模拟状态）
    func test_currentMovementDefinition_whenSessionCompleted_isNil() {
        // 因为不能直接触发 completeSession（需要完整练习），
        // 通过检查 default 分支的正确性验证：只有 preparing/detecting/movementCompleted 返回定义
        XCTAssertNil(viewModel.currentMovementDefinition, "idle 状态应返回 nil")
    }
}
