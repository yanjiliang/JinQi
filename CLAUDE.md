# 锦气 JinQi — iPad App

## 项目简介
锦气（JinQi）是一款原生 iPad app，通过前置摄像头实时检测用户八段锦动作是否标准，提供纠正提示和练习报告。

## 技术栈
- Swift 5.9+ / SwiftUI
- Apple Vision framework (Body Pose Detection)
- SwiftData (本地数据存储)
- iPadOS 17+
- 架构: MVVM

## 项目结构
- `BaDuanJin/` — 主项目 Xcode 工程
- `docs/` — 产品文档（PRD、用户故事、功能规格）
- `.claude/agents/` — Agent 定义文件

## 开发规范
- 语言: 中文注释，英文代码命名
- 遵循 Swift 官方命名规范
- MVVM 架构，视图层不包含业务逻辑
- 所有异步操作使用 async/await
- 摄像头和 Vision 处理在后台线程
- UI 简洁，适配全年龄段（大字体、高对比度）

## 团队协作
- 产品文档在 `docs/` 目录
- 开发前先阅读相关产品文档
- 代码变更需经过 review agent 审查
- 所有功能需要对应的测试用例
