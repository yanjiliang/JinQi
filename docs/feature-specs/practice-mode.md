# 功能规格：练习模式 (Practice Mode)

**版本**: v1.0
**日期**: 2026-03-12

---

## 一、概述

练习模式是 App 的核心功能，通过前置摄像头实时检测用户的八段锦动作，对比标准姿态，提供即时纠正反馈，引导用户完整完成八段锦全套练习并生成评分报告。

---

## 二、完整流程

```
[首页点击开始] → [权限检查] → [练习预备页] → [摄像头检测页] → [动作完成] →
                                   ↑                ↓
                             [下一动作预备]  ←  [当前动作完成]
                                                       ↓
                                              [全部8式完成]
                                                       ↓
                                              [练习完成页]
                                                       ↓
                                              [自动保存记录]
                                                       ↓
                                              [进入报告页]
```

---

## 三、状态机

### 3.1 练习会话状态 (PracticeSessionState)

```
enum PracticeSessionState {
    case idle                           // 未开始
    case preparingMovement(index: Int)  // 预备页，倒计时中
    case detectingMovement(index: Int)  // 检测中
    case movementCompleted(index: Int)  // 单动作完成
    case sessionCompleted               // 全部完成
    case abandonedByUser                // 用户主动放弃
    case errorState(error: Error)       // 错误状态
}
```

### 3.2 检测状态 (DetectionState)

```
enum DetectionState {
    case waitingForPerson     // 未检测到人体
    case personDetected       // 检测到人体但姿态未评估
    case positionChecking     // 正在评估姿态
    case poseGood             // 姿态合格，计时中
    case poseNeedsCorrection(feedback: [CorrectionFeedback])  // 需要纠正
    case paused               // 用户手动暂停
}
```

### 3.3 状态转换规则

| 当前状态 | 触发事件 | 目标状态 |
|---------|---------|---------|
| idle | 用户点击开始练习 | preparingMovement(0) |
| preparingMovement(n) | 倒计时结束 / 用户点击"准备好了" | detectingMovement(n) |
| detectingMovement(n) | 动作完成计时达标 | movementCompleted(n) |
| movementCompleted(n) | n < 7 | preparingMovement(n+1) |
| movementCompleted(7) | 最后动作完成 | sessionCompleted |
| 任意状态 | 用户点击退出 → 确认 | abandonedByUser |
| 任意状态 | 权限或硬件错误 | errorState |

---

## 四、页面定义

### 4.1 练习预备页 (PracticePreparationView)

**显示内容**：
- 动作序号：`第 X 式`（大字，32pt）
- 动作名称（28pt）
- 动作功效简介（16pt，灰色）
- 关键要领列表（1-3条，每条 ≤ 25 字）
- 倒计时圆圈（3 → 2 → 1，直径 80pt）
- "准备好了"按钮（跳过倒计时）
- 右上角"×"退出按钮

**行为**：
- 进入页面时立刻开始3秒倒计时
- 倒计时期间摄像头在后台初始化（降低进入检测页的延迟）
- 倒计时结束或点击"准备好了"均进入检测页

**ViewModel**: `PracticePreparationViewModel`
- 输入：movementIndex: Int
- 输出：isReady: Bool（触发页面切换）

---

### 4.2 摄像头检测页 (PracticeDetectionView)

**布局**（横屏，16:9 或 4:3 比例）：
```
┌─────────────────────────────────────────────┐
│  [×退出]  第X式：动作名称        [⏸暂停]    │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │                                      │   │
│  │  摄像头画面（全宽显示）               │   │
│  │  + 标准骨架叠加（蓝色半透明）          │   │
│  │  + 用户骨架叠加（绿/红）              │   │
│  │                                      │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  [纠正提示文字区 ≥ 18pt]                      │
│  ████████████░░░ 保持 4.2s / 5s            │
└─────────────────────────────────────────────┘
```

**UI 组件**：

| 组件 | 说明 |
|-----|-----|
| `CameraPreviewLayer` | AVCaptureSession 输出的摄像头预览 |
| `StandardPoseOverlay` | 标准骨架线，蓝色，透明度 60% |
| `UserPoseOverlay` | 用户骨架线，绿色（合格）/ 红色（偏差） |
| `CorrectionBanner` | 底部纠正提示横幅，背景半透明黑，文字白色 |
| `HoldProgressBar` | 动作保持进度条，充满时触发完成 |
| `MovementHeader` | 顶部导航栏，显示动作名称和序号 |

**ViewModel**: `PracticeDetectionViewModel`
- 依赖：`PoseDetectionService`，`PoseComparisonService`
- 输出：`detectionState: DetectionState`，`holdProgress: Double`（0.0-1.0），`correctionFeedbacks: [CorrectionFeedback]`

---

### 4.3 练习完成页 (PracticeCompletionView)

**显示内容**：
- 大字总评分（64pt）+ 等级标签
- 评语（1句，如"太棒了！动作越来越标准了！"）
- 本次练习时长
- 8个动作的评分简略横条图
- "查看详细报告"按钮（主要 CTA）
- "再练一次"按钮（次要）
- "返回首页"文字按钮

---

### 4.4 放弃确认弹窗 (AbandonConfirmationAlert)

```
标题: "放弃本次练习？"
内容: "本次练习记录不会被保存"
按钮:
  - "继续练习"（默认，蓝色）
  - "放弃"（红色）
```

---

## 五、每个动作的保持时长要求

| 动作 | 说明 | 要求保持时长（合格姿态） | 左右各练 |
|-----|-----|-----|-----|
| 第1式 双手托天理三焦 | 双臂上托，手掌向上 | 3秒 | 否 |
| 第2式 左右开弓似射雕 | 一手拉弓，一手指射 | 3秒 | 是（各3秒）|
| 第3式 调理脾胃须单举 | 一手上举，一手下按 | 3秒 | 是（各3秒）|
| 第4式 五劳七伤往后瞧 | 头转向一侧后望 | 3秒 | 是（各3秒）|
| 第5式 摇头摆尾去心火 | 马步，头摆向一侧 | 3秒 | 是（各3秒）|
| 第6式 两手攀足固肾腰 | 弯腰双手触脚 | 3秒 | 否 |
| 第7式 攒拳怒目增气力 | 出拳，怒目圆睁 | 2秒 | 是（各2秒）|
| 第8式 背后七颠百病消 | 踮脚跟，放松站立 | 5次（计次） | 否 |

> **注**：第8式计次而非计时，需检测 5 次踮脚动作（脚跟离地+落地为一次）。

---

## 六、检测暂停机制

**自动暂停触发条件**：
- 连续2秒未检测到人体关节点（用户离开画面）
- 环境光线过暗（由 Vision 框架返回低置信度触发）

**暂停时行为**：
- HoldProgressBar 停止计时（不清零）
- 显示提示：`"未检测到您，请确保全身在画面内"`
- 标准骨架叠加仍然显示（辅助用户调整位置）

**恢复条件**：
- 重新检测到有效人体关节点，0.3秒后恢复计时

---

## 七、骨架叠加渲染规范

### 关节点（19个）映射到屏幕坐标
Vision 框架返回归一化坐标（0-1），需乘以摄像头预览层尺寸转换。

### 颜色编码
| 颜色 | 含义 |
|-----|-----|
| 蓝色（#4A90E2，60%透明） | 标准骨架参考 |
| 绿色（#4CAF50） | 用户骨架，该关节角度在合格范围 |
| 红色（#F44336） | 用户骨架，该关节角度偏差超阈值 |
| 灰色（#9E9E9E） | 用户骨架，该关节未被检测到（置信度低） |

### 骨架连线
按以下关节对绘制连线：
```
头部:    nose — leftEye, nose — rightEye
颈部:    nose — neck（通过肩膀中点估算）
肩膀:    leftShoulder — rightShoulder
左臂:    leftShoulder — leftElbow — leftWrist
右臂:    rightShoulder — rightElbow — rightWrist
躯干:    leftShoulder — leftHip, rightShoulder — rightHip
腰部:    leftHip — rightHip
左腿:    leftHip — leftKnee — leftAnkle
右腿:    rightHip — rightKnee — rightAnkle
```

---

## 八、错误处理

| 错误场景 | 处理方式 |
|---------|---------|
| 摄像头权限被拒 | 退出练习，首页显示权限引导 |
| 摄像头占用（另一 App 使用） | 显示提示"摄像头被其他应用占用，请关闭后重试"，不进入检测页 |
| 设备过热（AVCaptureSession 中断） | 显示提示"设备温度过高，练习已暂停，稍后继续" |
| Vision 处理队列堆积（帧率下降至<10fps） | 自动降低处理分辨率 |

---

## 九、数据流

```
AVCaptureSession (前置摄像头)
    ↓ CMSampleBuffer (每帧)
PoseDetectionService
    ↓ VNHumanBodyPoseObservation
PoseComparisonService
    ↓ PoseComparisonResult (得分 + 偏差关节列表)
PracticeDetectionViewModel
    ↓ 发布 State 更新
PracticeDetectionView (SwiftUI)
    ↓ 更新 UI（骨架颜色、提示文字、进度条）
```

---

*文档由产品经理 Agent 生成*
