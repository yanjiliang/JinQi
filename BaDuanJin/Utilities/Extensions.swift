// Extensions.swift
// 养生八段锦 iPad App - 常用扩展方法

import SwiftUI
import Foundation

// MARK: - Color 扩展（十六进制颜色支持）
extension Color {
    /// 从十六进制字符串创建颜色（如 "#FF9800"）
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Date 扩展
extension Date {
    /// 是否与另一日期是同一天
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    /// 格式化为 "MM月dd日"
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: self)
    }

    /// 格式化为 "HH:mm"
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }

    /// 格式化为 "yyyy年MM月dd日"
    var fullDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: self)
    }
}

// MARK: - Double 扩展
extension Double {
    /// 格式化为评分显示（整数）
    var scoreString: String {
        String(format: "%.0f", self)
    }

    /// 格式化为百分比（如 "85%"）
    var percentString: String {
        String(format: "%.0f%%", self)
    }
}

// MARK: - TimeInterval 扩展
extension TimeInterval {
    /// 格式化为 "X分X秒"
    var durationString: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return "\(minutes)分\(seconds)秒"
    }
}

// MARK: - View 扩展
extension View {
    /// 圆角背景卡片样式
    func cardStyle(backgroundColor: Color = Color(.systemBackground)) -> some View {
        self
            .background(backgroundColor)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    /// 标准内边距
    func standardPadding() -> some View {
        self.padding(.horizontal, 20).padding(.vertical, 16)
    }
}
