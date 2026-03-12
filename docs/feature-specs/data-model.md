# 功能规格：数据模型详细设计 (Data Model)

**版本**: v1.0
**日期**: 2026-03-12

---

## 一、概述

本文档定义 App 所有 SwiftData 模型的完整设计，包括字段定义、关系、索引和迁移策略。

---

## 二、SwiftData 模型定义

### 2.1 PracticeSession（练习记录）

```swift
import SwiftData
import Foundation

@Model
final class PracticeSession {
    // MARK: - 主键
    @Attribute(.unique) var id: UUID

    // MARK: - 时间字段
    var startTime: Date       // 练习开始时间
    var endTime: Date         // 练习结束时间
    var duration: TimeInterval // 实际练习时长（秒）

    // MARK: - 评分字段
    var totalScore: Double     // 总评分（0-100）
    var grade: String          // 等级："优秀"|"良好"|"及格"|"需加强"

    // MARK: - 关系
    @Relationship(deleteRule: .cascade, inverse: \MovementResult.session)
    var movementResults: [MovementResult] = []

    // MARK: - 派生属性（不存储）
    var dateOnly: Date {
        Calendar.current.startOfDay(for: startTime)
    }

    // MARK: - 初始化
    init(id: UUID = UUID(),
         startTime: Date,
         endTime: Date,
         duration: TimeInterval,
         totalScore: Double,
         grade: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.totalScore = totalScore
        self.grade = grade
    }
}
```

**索引**：
- `startTime`：用于按日期排序查询（历史列表、打卡日历）
- `dateOnly`：派生属性，不作为 SwiftData 索引，通过 `startTime` 过滤实现

**查询示例**：
```swift
// 获取所有记录，按时间倒序
let descriptor = FetchDescriptor<PracticeSession>(
    sortBy: [SortDescriptor(\.startTime, order: .reverse)]
)

// 获取某日期范围内的记录（打卡日历）
let calendar = Calendar.current
let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
let descriptor = FetchDescriptor<PracticeSession>(
    predicate: #Predicate { $0.startTime >= startOfMonth && $0.startTime < endOfMonth },
    sortBy: [SortDescriptor(\.startTime)]
)
```

---

### 2.2 MovementResult（单动作练习结果）

```swift
@Model
final class MovementResult {
    // MARK: - 主键
    @Attribute(.unique) var id: UUID

    // MARK: - 关联
    var session: PracticeSession?  // 所属练习记录

    // MARK: - 动作信息
    var movementIndex: Int         // 动作序号（0-7）
    var movementName: String       // 动作名称（冗余存储，便于查询）

    // MARK: - 评分信息
    var score: Double              // 单动作评分（0-100）
    var feedback: String           // 主要改进建议（单条，可为空串""）

    // MARK: - 详情数据
    @Attribute(.externalStorage)
    var keyPointsData: Data?       // JSON，角度评分详情（大数据外部存储）

    // MARK: - 初始化
    init(id: UUID = UUID(),
         movementIndex: Int,
         movementName: String,
         score: Double,
         feedback: String,
         keyPointsData: Data? = nil) {
        self.id = id
        self.movementIndex = movementIndex
        self.movementName = movementName
        self.score = score
        self.feedback = feedback
        self.keyPointsData = keyPointsData
    }
}
```

**注意事项**：
- `keyPointsData` 使用 `@Attribute(.externalStorage)` 存储在独立文件，避免主表膨胀
- 每次 `PracticeSession` 有且仅有 8 条 `MovementResult`（强制约束由 App 逻辑保证）
- 删除 `PracticeSession` 时，关联的 `MovementResult` 级联删除（`deleteRule: .cascade`）

---

### 2.3 UserStats（用户统计，单例）

用于缓存统计数据，避免每次打开首页时全表扫描：

```swift
@Model
final class UserStats {
    // MARK: - 单例标识
    @Attribute(.unique) var key: String = "default"

    // MARK: - 累计统计
    var totalSessionCount: Int      // 总练习次数
    var totalDuration: TimeInterval // 累计练习时长（秒）

    // MARK: - 连续打卡
    var currentStreak: Int          // 当前连续打卡天数
    var longestStreak: Int          // 历史最长连续打卡天数
    var lastPracticeDate: Date?     // 最后一次练习日期（取日期部分）

    // MARK: - 更新方法（在保存 PracticeSession 后调用）
    func updateAfterSession(_ session: PracticeSession) {
        totalSessionCount += 1
        totalDuration += session.duration

        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        if let last = lastPracticeDate {
            if Calendar.current.isDate(last, inSameDayAs: yesterday) {
                currentStreak += 1
            } else if Calendar.current.isDate(last, inSameDayAs: today) {
                // 今日重复练习，不重复计数
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        lastPracticeDate = today
    }

    init() {
        self.totalSessionCount = 0
        self.totalDuration = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastPracticeDate = nil
    }
}
```

---

## 三、静态数据（不存储在 SwiftData）

### 3.1 MovementDefinition（动作定义，内置 JSON）

存储在 App Bundle 的 `Resources/movements.json`，App 启动时加载到内存，不写入 SwiftData。

```swift
struct MovementDefinition: Codable, Identifiable {
    let id: Int                      // 动作序号（0-7）
    let name: String                 // 动作名称
    let subtitle: String             // 功效副标题（≤ 20字）
    let description: String          // 功效详细说明
    let steps: [MovementStep]        // 分步骤说明
    let keyPoints: [String]          // 关键要领（1-3条）
    let commonErrors: [CommonError]  // 常见错误
    let breathingGuide: String       // 呼吸配合说明
    let repeatCount: String          // 练习次数建议（如"左右各做3-5次"）
    let holdDuration: Double         // 标准保持时长（秒）
    let hasSides: Bool               // 是否有左右两侧
}

struct MovementStep: Codable {
    let order: Int
    let instruction: String       // 步骤说明文字
    let bodyFocus: String         // 重点关注的身体部位（如"双臂"）
}

struct CommonError: Codable {
    let error: String            // 错误描述
    let correction: String       // 纠正方法
}
```

### 3.2 标准姿态数据（内置 JSON）

存储在 `Resources/StandardPoses/movement_{0-7}.json`，格式见 `pose-detection.md` 第七节。

---

## 四、关系图

```
┌────────────────────┐     1:N    ┌───────────────────┐
│   PracticeSession  │───────────>│   MovementResult  │
│                    │            │                   │
│  id (UUID, PK)     │            │  id (UUID, PK)    │
│  startTime         │            │  session (FK)     │
│  endTime           │            │  movementIndex    │
│  duration          │            │  movementName     │
│  totalScore        │            │  score            │
│  grade             │            │  feedback         │
└────────────────────┘            │  keyPointsData    │
                                  └───────────────────┘

┌────────────────────┐
│    UserStats       │  (单例，key="default")
│                    │
│  totalSessionCount │
│  totalDuration     │
│  currentStreak     │
│  longestStreak     │
│  lastPracticeDate  │
└────────────────────┘
```

---

## 五、SwiftData 容器配置

```swift
// App 入口配置
@main
struct BaDuanJinApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            PracticeSession.self,
            MovementResult.self,
            UserStats.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        container = try! ModelContainer(for: schema, configurations: config)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
```

---

## 六、数据操作规范

### 6.1 保存练习记录

```swift
@MainActor
func savePracticeSession(
    context: ModelContext,
    startTime: Date,
    movementScores: [(index: Int, name: String, score: Double, feedback: String)]
) {
    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)
    let weights: [Double] = [0.10, 0.15, 0.12, 0.10, 0.15, 0.12, 0.13, 0.13]
    let totalScore = zip(movementScores.map(\.score), weights).map(*).reduce(0, +)
    let grade = gradeFrom(score: totalScore)

    let session = PracticeSession(
        startTime: startTime,
        endTime: endTime,
        duration: duration,
        totalScore: totalScore,
        grade: grade
    )

    for ms in movementScores {
        let result = MovementResult(
            movementIndex: ms.index,
            movementName: ms.name,
            score: ms.score,
            feedback: ms.feedback
        )
        result.session = session
        context.insert(result)
    }

    context.insert(session)

    // 更新统计
    updateUserStats(context: context, session: session)

    try? context.save()
}
```

### 6.2 查询打卡日历（月视图）

```swift
func practiceDate(for month: Date, context: ModelContext) -> Set<Date> {
    let calendar = Calendar.current
    guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
          let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
        return []
    }

    let descriptor = FetchDescriptor<PracticeSession>(
        predicate: #Predicate { session in
            session.startTime >= startOfMonth && session.startTime < endOfMonth
        }
    )
    let sessions = (try? context.fetch(descriptor)) ?? []
    return Set(sessions.map { calendar.startOfDay(for: $0.startTime) })
}
```

### 6.3 删除练习记录

```swift
@MainActor
func deleteSession(_ session: PracticeSession, context: ModelContext) {
    // MovementResult 会因 cascade 自动删除
    context.delete(session)
    // 需重新计算 UserStats（连续打卡可能受影响）
    recalculateUserStats(context: context)
    try? context.save()
}
```

---

## 七、存储容量估算

| 数据项 | 单条大小 | 1000次练习 |
|-------|---------|---------|
| PracticeSession | ~100B | ~100KB |
| MovementResult × 8 | ~200B/条 | ~1.6MB |
| keyPointsData (JSON) | ~1KB/条 | ~8MB |
| UserStats | ~50B | ~50B（单例）|
| **总计** | | **~10MB** |

> App 使用1年（约365次练习）存储占用约 4MB，可忽略不计。

---

## 八、数据迁移策略

当前为 v1.0，无历史版本需迁移。

未来版本变更时使用 SwiftData 的 `VersionedSchema` 和 `SchemaMigrationPlan`：

```swift
// 预留迁移入口（v1.0 暂不实现）
enum BaDuanJinSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        PracticeSession.self, MovementResult.self, UserStats.self
    ]
}
```

---

*文档由产品经理 Agent 生成*
