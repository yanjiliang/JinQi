// BaDuanJinApp.swift
// 养生八段锦 iPad App - 应用入口

import SwiftUI
import SwiftData

@main
struct BaDuanJinApp: App {
    // MARK: - SwiftData 容器
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
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("无法初始化 SwiftData 容器: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
