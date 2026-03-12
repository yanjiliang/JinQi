// ContentView.swift
// 养生八段锦 iPad App - 主导航框架（TabView）

import SwiftUI

struct ContentView: View {
    // MARK: - 当前选中的 Tab
    @State private var selectedTab: Tab = .dashboard

    // MARK: - Tab 定义
    enum Tab {
        case dashboard      // 首页
        case practice       // 练习
        case library        // 动作库
        case history        // 记录
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // 首页仪表盘
            DashboardView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(Tab.dashboard)

            // 练习入口
            PracticeView()
                .tabItem {
                    Label("练习", systemImage: "figure.mind.and.body")
                }
                .tag(Tab.practice)

            // 动作库
            MovementLibraryView()
                .tabItem {
                    Label("动作库", systemImage: "book.fill")
                }
                .tag(Tab.library)

            // 练习记录
            HistoryView()
                .tabItem {
                    Label("记录", systemImage: "calendar")
                }
                .tag(Tab.history)
        }
        // 适配 iPad 大字体高对比度风格
        .accentColor(.green)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PracticeSession.self, MovementResult.self, UserStats.self],
                        inMemory: true)
}
