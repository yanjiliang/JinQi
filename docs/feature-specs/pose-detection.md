# 功能规格：姿态检测技术方案 (Pose Detection)

**版本**: v1.0
**日期**: 2026-03-12

---

## 一、概述

本文档定义使用 Apple Vision 框架进行八段锦姿态检测的完整技术方案，包括 API 使用方式、关节点定义、姿态对比算法和阈值参数。

---

## 二、Vision API 使用方案

### 2.1 核心类

| 类/结构 | 用途 |
|---------|-----|
| `VNDetectHumanBodyPoseRequest` | 人体姿态检测请求 |
| `VNHumanBodyPoseObservation` | 检测结果，包含关节点 |
| `VNHumanBodyPoseObservation.JointName` | 关节点枚举 |
| `VNRecognizedPoint` | 关节点坐标和置信度 |

### 2.2 摄像头配置

```swift
// 推荐配置
let session = AVCaptureSession()
session.sessionPreset = .hd1280x720  // 720p 平衡精度和性能

// 前置摄像头
let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)

// 视频输出
let videoOutput = AVCaptureVideoDataOutput()
videoOutput.videoSettings = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
]
videoOutput.alwaysDiscardsLateVideoFrames = true  // 丢弃晚帧，保持实时性
```

### 2.3 检测请求执行

```swift
// 在后台串行队列执行，避免阻塞 UI
private let detectionQueue = DispatchQueue(label: "pose-detection", qos: .userInteractive)

func captureOutput(_ output: AVCaptureOutput,
                   didOutput sampleBuffer: CMSampleBuffer,
                   from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
        guard let observations = request.results as? [VNHumanBodyPoseObservation],
              let observation = observations.first else {
            self?.handleNoPersonDetected()
            return
        }
        self?.processObservation(observation)
    }

    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                        orientation: .up,  // 横屏时需调整
                                        options: [:])
    try? handler.perform([request])
}
```

### 2.4 摄像头方向处理

前置摄像头在 iPad 横屏时图像方向为 `.leftMirrored`（需镜像翻转以匹配用户视角）：
```swift
// 预览层镜像设置
connection.isVideoMirrored = true

// Vision 请求的 orientation 映射（根据设备方向动态更新）
func imageOrientation(for deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
    switch deviceOrientation {
    case .landscapeLeft:  return .up
    case .landscapeRight: return .upMirrored
    default:              return .up
    }
}
```

---

## 三、19 个关节点定义

### 3.1 完整关节点枚举

| Vision JointName | 中文名称 | 身体部位 | 优先级 |
|-----------------|---------|---------|-----|
| `nose` | 鼻子 | 头部中心参考 | 高 |
| `leftEye` | 左眼 | 头部 | 中 |
| `rightEye` | 右眼 | 头部 | 中 |
| `leftEar` | 左耳 | 头部 | 中 |
| `rightEar` | 右耳 | 头部 | 中 |
| `leftShoulder` | 左肩 | 上肢起点 | **核心** |
| `rightShoulder` | 右肩 | 上肢起点 | **核心** |
| `leftElbow` | 左肘 | 上臂/前臂分界 | **核心** |
| `rightElbow` | 右肘 | 上臂/前臂分界 | **核心** |
| `leftWrist` | 左腕 | 手部参考 | **核心** |
| `rightWrist` | 右腕 | 手部参考 | **核心** |
| `leftHip` | 左髋 | 下肢起点/腰部 | **核心** |
| `rightHip` | 右髋 | 下肢起点/腰部 | **核心** |
| `leftKnee` | 左膝 | 大腿/小腿分界 | **核心** |
| `rightKnee` | 右膝 | 大腿/小腿分界 | **核心** |
| `leftAnkle` | 左踝 | 脚部参考 | 高 |
| `rightAnkle` | 右踝 | 脚部参考 | 高 |
| `neck` | 颈部 | 头颈参考 | 中 |
| `root` | 根节点 | 髋部中心，全身参考 | 高 |

### 3.2 关节点提取

```swift
func extractKeyPoints(from observation: VNHumanBodyPoseObservation) -> [JointName: RecognizedPoint] {
    let joints: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .leftShoulder, .rightShoulder,
        .leftElbow, .rightElbow, .leftWrist, .rightWrist,
        .leftHip, .rightHip, .leftKnee, .rightKnee,
        .leftAnkle, .rightAnkle, .neck, .root
    ]

    var result: [JointName: RecognizedPoint] = [:]
    for joint in joints {
        if let point = try? observation.recognizedPoint(joint),
           point.confidence > 0.3 {  // 低置信度关节点不使用
            result[joint] = RecognizedPoint(
                normalizedPoint: point.location,
                confidence: point.confidence
            )
        }
    }
    return result
}
```

### 3.3 置信度阈值

| 阈值 | 含义 |
|-----|-----|
| < 0.3 | 忽略此关节点（标记为未检测到） |
| 0.3 - 0.6 | 低置信度，使用但权重降低 |
| > 0.6 | 高置信度，正常使用 |

---

## 四、姿态对比算法

### 4.1 整体思路

采用**关节角度对比法**，而非直接对比关节点坐标（避免因用户距摄像头远近不同导致误差）。

核心步骤：
1. 从关节点坐标计算关键骨段的角度
2. 将用户角度与标准角度对比
3. 计算偏差分数
4. 聚合成动作总分

### 4.2 骨段角度计算

```swift
/// 计算两个向量之间的角度（度）
func angleBetween(pointA: CGPoint, vertex: CGPoint, pointB: CGPoint) -> Double {
    let vectorAX = pointA.x - vertex.x
    let vectorAY = pointA.y - vertex.y
    let vectorBX = pointB.x - vertex.x
    let vectorBY = pointB.y - vertex.y

    let dot = vectorAX * vectorBX + vectorAY * vectorBY
    let magA = sqrt(vectorAX * vectorAX + vectorAY * vectorAY)
    let magB = sqrt(vectorBX * vectorBX + vectorBY * vectorBY)

    guard magA > 0, magB > 0 else { return 0 }
    let cosAngle = max(-1.0, min(1.0, dot / (magA * magB)))
    return acos(cosAngle) * 180 / .pi
}
```

### 4.3 关键角度定义（每个动作的评估维度）

针对每个动作，定义需要评估的关键角度列表：

```swift
struct MovementAngleCriteria {
    let movementIndex: Int
    let angleChecks: [AngleCheck]
}

struct AngleCheck {
    let name: String              // 如 "左臂上举角度"
    let jointA: JointName         // 起点关节
    let vertex: JointName         // 顶点关节
    let jointB: JointName         // 终点关节
    let targetAngle: Double       // 标准角度（度）
    let toleranceDegrees: Double  // 允许偏差范围（度）
    let weight: Double            // 该角度在总分中的权重（0-1，所有权重之和=1）
    let feedbackWhenLow: String   // 角度偏小时的提示
    let feedbackWhenHigh: String  // 角度偏大时的提示
}
```

**第1式 双手托天理三焦** 关键角度：

| 角度名称 | 关节A | 顶点 | 关节B | 标准角度 | 容差 | 权重 |
|---------|------|-----|------|---------|-----|-----|
| 左臂上举角度 | leftElbow | leftShoulder | leftHip | 170° | ±20° | 0.25 |
| 右臂上举角度 | rightElbow | rightShoulder | rightHip | 170° | ±20° | 0.25 |
| 左肘伸直角度 | leftShoulder | leftElbow | leftWrist | 170° | ±15° | 0.15 |
| 右肘伸直角度 | rightShoulder | rightElbow | rightWrist | 170° | ±15° | 0.15 |
| 背部挺直角度 | neck | root | leftKnee | 175° | ±10° | 0.20 |

（其余7式的角度定义由开发 Agent 根据此格式参照八段锦标准动作定义）

### 4.4 单关节角度评分

```swift
/// 单个角度检查的得分（0-100）
func scoreForAngle(userAngle: Double, check: AngleCheck) -> Double {
    let deviation = abs(userAngle - check.targetAngle)

    if deviation <= check.toleranceDegrees {
        // 在容差范围内：线性映射到 80-100 分
        let ratio = deviation / check.toleranceDegrees
        return 100 - ratio * 20
    } else {
        // 超出容差：每多1度扣2分，最低20分
        let extra = deviation - check.toleranceDegrees
        return max(20, 80 - extra * 2)
    }
}
```

### 4.5 动作总分计算

```swift
func scoreForMovement(userPose: [JointName: CGPoint],
                      criteria: MovementAngleCriteria) -> MovementScore {
    var weightedScore = 0.0
    var corrections: [CorrectionFeedback] = []

    for check in criteria.angleChecks {
        guard let pointA = userPose[check.jointA],
              let vertex = userPose[check.vertex],
              let pointB = userPose[check.jointB] else {
            // 关节不可见：该角度按50分计
            weightedScore += 50 * check.weight
            continue
        }

        let userAngle = angleBetween(pointA: pointA, vertex: vertex, pointB: pointB)
        let score = scoreForAngle(userAngle: userAngle, check: check)
        weightedScore += score * check.weight

        // 生成纠正反馈
        if score < 75 {
            let feedback = userAngle < check.targetAngle
                ? check.feedbackWhenLow
                : check.feedbackWhenHigh
            corrections.append(CorrectionFeedback(
                joint: check.vertex,
                message: feedback,
                severity: score < 50 ? .high : .medium
            ))
        }
    }

    return MovementScore(
        total: weightedScore,
        corrections: corrections.sorted { $0.severity.rawValue > $1.severity.rawValue }
    )
}
```

---

## 五、归一化与坐标转换

### 5.1 Vision 坐标系

Vision 返回的坐标系：原点在**左下角**，Y轴向上，范围 [0, 1]。
SwiftUI/UIKit 坐标系：原点在**左上角**，Y轴向下。

```swift
func convertToViewCoordinates(normalizedPoint: CGPoint, viewSize: CGSize) -> CGPoint {
    return CGPoint(
        x: normalizedPoint.x * viewSize.width,
        y: (1 - normalizedPoint.y) * viewSize.height  // Y轴翻转
    )
}
```

### 5.2 镜像处理（前置摄像头）

前置摄像头画面已设置 `isVideoMirrored = true`，但 Vision 处理的原始帧未镜像，因此：
- **Vision 坐标**：左关节点在画面右侧（用户视角）
- **显示时**：预览层已镜像，与用户肢体对应
- **关节点映射**：leftShoulder 在用户左肩（画面右侧），无需额外处理（Vision 已做镜像校正）

---

## 六、性能优化

### 6.1 帧率控制

```swift
// 每3帧处理一次（约10FPS），减少CPU负载
private var frameCount = 0
func captureOutput(...) {
    frameCount += 1
    guard frameCount % 3 == 0 else { return }
    // 执行检测
}
```

### 6.2 处理队列

- **摄像头捕获**：在 AVCaptureSession 回调线程（系统管理）
- **Vision 推理**：在 `detectionQueue`（后台串行队列）
- **UI 更新**：切换到 `DispatchQueue.main`

```swift
// 推理完成后发布状态
DispatchQueue.main.async {
    self.detectionState = newState
}
```

### 6.3 节流（Throttle）纠正提示

纠正提示文字更新频率限制为每1秒最多更新一次，避免文字闪烁：

```swift
private var lastFeedbackUpdateTime = Date.distantPast

func updateCorrectionFeedback(_ feedback: CorrectionFeedback) {
    guard Date().timeIntervalSince(lastFeedbackUpdateTime) > 1.0 else { return }
    lastFeedbackUpdateTime = Date()
    currentFeedback = feedback
}
```

---

## 七、标准姿态数据存储

### 7.1 数据格式

每个动作的标准姿态以关节角度列表存储（而非像素坐标），存储在 App Bundle 内 JSON 文件：

```json
// Resources/StandardPoses/movement_0.json
{
  "movementIndex": 0,
  "movementName": "双手托天理三焦",
  "holdPhase": "双臂充分上举后",
  "angleChecks": [
    {
      "name": "左臂上举",
      "jointA": "leftElbow",
      "vertex": "leftShoulder",
      "jointB": "leftHip",
      "targetAngle": 170,
      "toleranceDegrees": 20,
      "weight": 0.25,
      "feedbackWhenLow": "请将左臂继续向上举高",
      "feedbackWhenHigh": "左臂不必过度后仰，保持竖直向上"
    }
  ]
}
```

### 7.2 数据加载

App 启动时预加载所有8个动作的标准姿态数据，缓存在内存中。

---

*文档由产品经理 Agent 生成*
