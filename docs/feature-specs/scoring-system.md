# 功能规格：评分系统 (Scoring System)

**版本**: v1.0
**日期**: 2026-03-12

---

## 一、概述

评分系统负责对用户的八段锦练习进行量化评估，生成单动作评分和整体练习评分，并输出改进建议报告。

---

## 二、评分规则

### 2.1 评分层级

```
整体练习评分（PracticeScore）
    └─ 各动作评分（MovementScore × 8）
            └─ 各关节角度评分（AngleScore × N）
```

### 2.2 单动作评分

**输入**：该动作保持期间的若干帧检测结果
**输出**：0-100 的评分

**计算流程**：
1. 收集动作"保持阶段"（进度条充满后0.5秒内）的所有有效帧（置信度 > 0.3）
2. 每帧计算各关节角度得分（详见 pose-detection.md）
3. 对所有帧的加权得分取平均值（移动平均，去除最高最低各10%）
4. 输出最终动作得分

```swift
func calculateMovementScore(frames: [PoseFrame], criteria: MovementAngleCriteria) -> Double {
    let validFrames = frames.filter { $0.overallConfidence > 0.3 }
    guard !validFrames.isEmpty else { return 50.0 }  // 无有效帧给默认分

    let frameScores = validFrames.map { frame in
        scoreForMovement(userPose: frame.joints, criteria: criteria).total
    }

    // 去除极端值后取平均
    let sorted = frameScores.sorted()
    let trimCount = max(0, sorted.count / 10)
    let trimmed = Array(sorted.dropFirst(trimCount).dropLast(trimCount))
    return trimmed.isEmpty ? frameScores.reduce(0, +) / Double(frameScores.count)
                           : trimmed.reduce(0, +) / Double(trimmed.count)
}
```

### 2.3 整体练习评分

**公式**：整体评分 = 各动作评分的加权平均

**权重分配**（各动作难度不同，权重有所差异）：

| 动作 | 权重 | 说明 |
|-----|-----|-----|
| 第1式 双手托天理三焦 | 10% | 基础动作，易掌握 |
| 第2式 左右开弓似射雕 | 15% | 上肢协调性高，较难 |
| 第3式 调理脾胃须单举 | 12% | 双手配合，中等难度 |
| 第4式 五劳七伤往后瞧 | 10% | 颈部动作，检测相对不稳定 |
| 第5式 摇头摆尾去心火 | 15% | 全身协调，最难 |
| 第6式 两手攀足固肾腰 | 12% | 柔韧性考验，因人差异大 |
| 第7式 攒拳怒目增气力 | 13% | 动态动作，力量感评估 |
| 第8式 背后七颠百病消 | 13% | 踮脚计次，平衡感 |

```swift
let weights: [Double] = [0.10, 0.15, 0.12, 0.10, 0.15, 0.12, 0.13, 0.13]

func calculateTotalScore(movementScores: [Double]) -> Double {
    assert(movementScores.count == 8)
    return zip(movementScores, weights).map(*).reduce(0, +)
}
```

---

## 三、等级划分

| 分数范围 | 等级 | 标签颜色 | 评语模板 |
|---------|-----|---------|---------|
| 90-100 | 优秀 | 金色 #FFD700 | "动作非常标准，继续保持！" |
| 75-89 | 良好 | 绿色 #4CAF50 | "动作基本到位，细节上还可以更精准。" |
| 60-74 | 及格 | 蓝色 #2196F3 | "整体框架对了，需要多加练习细节。" |
| 0-59 | 需加强 | 橙色 #FF9800 | "八段锦需要慢慢体会，坚持练习会越来越好！" |

---

## 四、改进建议生成

### 4.1 建议优先级

每次练习最多展示 **2条** 主要改进建议（避免信息过载）。

优先级排序规则：
1. **得分最低的动作** → 该动作最低分关节角度的改进建议
2. **偏差最大的关节** → 出现频率最高（多帧一致偏差）的关节

### 4.2 建议文案规范

- 具体到身体部位（不使用模糊词汇如"动作不对"）
- 给出正向指导（告诉用户"应该怎么做"，不只是"不要怎么做"）
- 字数 ≤ 30 字
- 使用口语化中文

**示例**：
| 偏差类型 | 建议文案 |
|---------|---------|
| 手臂上举不够高 | "双手上托时，尽量让双臂贴近耳朵，充分伸展" |
| 腰部弯曲不够 | "两手攀足时，膝盖伸直，尽量让手指触碰脚尖" |
| 头转动幅度不够 | "往后瞧时，眼睛要看向正后方，感受颈部拉伸" |
| 马步不够低 | "摇头摆尾时，膝盖弯曲角度约90°，重心下沉" |

### 4.3 建议生成逻辑

```swift
struct ImprovementAdvice {
    let movementName: String   // 涉及的动作
    let body: String           // 建议文案
    let targetScore: Double    // 提升后的预估分数（激励性）
}

func generateAdvice(movementResults: [MovementResult]) -> [ImprovementAdvice] {
    // 找出得分最低的两个动作
    let sorted = movementResults.sorted { $0.score < $1.score }
    return sorted.prefix(2).map { result in
        ImprovementAdvice(
            movementName: result.movementName,
            body: result.feedback,  // 由 PoseComparisonService 生成
            targetScore: min(100, result.score + 15)  // 激励性：提升15分
        )
    }
}
```

---

## 五、报告模板

### 5.1 单次练习报告结构

```
┌─────────────────────────────────────────────┐
│           本次练习报告                        │
│                                              │
│  总评分: [大数字] 分    等级: [标签]           │
│  评语: [1句评语]                              │
│  练习时长: XX分XX秒                           │
│                                              │
│  ─── 各动作评分 ───                          │
│  第1式 双手托天理三焦  ████████░░  82分       │
│  第2式 左右开弓似射雕  ██████░░░░  68分       │
│  第3式 调理脾胃须单举  █████████░  90分       │
│  ...                                         │
│                                              │
│  ─── 本次亮点 ───                            │
│  最佳动作: 第3式 (90分) 🌟                   │
│                                              │
│  ─── 改进建议 ───                            │
│  1. [第X式] [建议文案]                        │
│  2. [第X式] [建议文案]                        │
│                                              │
│  [查看上次对比] [再练一次] [返回首页]          │
└─────────────────────────────────────────────┘
```

### 5.2 各动作评分卡颜色

| 分数范围 | 进度条颜色 |
|---------|---------|
| ≥ 85 | 绿色 #4CAF50 |
| 70-84 | 蓝色 #2196F3 |
| 55-69 | 黄色 #FFC107 |
| < 55 | 红色 #F44336 |

---

## 六、历史对比（可选功能，P3 阶段）

当用户有 ≥ 2 次练习记录时，报告页可显示"与上次相比"对比数据：

| 展示内容 | 逻辑 |
|---------|-----|
| 总分变化 | `本次 - 上次`，显示 +/- 数字，绿色/红色 |
| 进步最大的动作 | 分数差值最大的动作 |
| 退步的动作 | 分数差为负的动作（若有） |

---

## 七、评分持久化

### 7.1 存储内容

每次练习完成后，将以下数据持久化到 SwiftData：

```swift
// PracticeSession 中存储
totalScore: Double          // 总评分
grade: String               // 等级

// MovementResult 中存储（8条）
movementIndex: Int
movementName: String
score: Double               // 单动作评分
feedback: String            // 主要改进建议（最多一条）
keyPointsData: Data         // 各角度得分详情（JSON，备查）
```

### 7.2 keyPointsData JSON 格式

```json
{
  "angleScores": [
    {"name": "左臂上举角度", "userAngle": 145.5, "targetAngle": 170, "score": 72},
    {"name": "右臂上举角度", "userAngle": 168.2, "targetAngle": 170, "score": 98}
  ],
  "sampleFrameCount": 45,
  "detectionConfidence": 0.85
}
```

---

## 八、边界条件与错误处理

| 情况 | 处理方式 |
|-----|---------|
| 某动作有效帧 < 5 帧 | 该动作评分 = 50（中间值），不给出改进建议 |
| 所有8个动作均完成，但某式有效帧不足 | 仍生成报告，标注"部分动作数据不足，评分仅供参考" |
| 总分计算出 NaN/Inf | 兜底处理，总分显示 0，附提示"本次检测异常" |
| 同一天多次练习 | 每次均保存，打卡日历以当天有至少一次为准 |

---

*文档由产品经理 Agent 生成*
