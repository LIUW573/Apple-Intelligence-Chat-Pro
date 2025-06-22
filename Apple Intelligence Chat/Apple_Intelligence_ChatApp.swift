//
//  Apple_Intelligence_ChatApp.swift
//  Apple Intelligence Chat
//
//  Created by Pallav Agarwal on 6/9/25.
//

import SwiftUI

@main
struct Apple_Intelligence_ChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.none) // 跟随系统主题
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("新对话") {
                    NotificationCenter.default.post(name: Notification.Name("NewChat"), object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
                
                Button("显示/隐藏侧边栏") {
                    NotificationCenter.default.post(name: Notification.Name("ToggleHistory"), object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command])
            }
        }
    }
}

// MARK: - 视图扩展

/// 添加玻璃效果的视图扩展
extension View {
    /// 应用玻璃效果到视图
    @ViewBuilder
    func glassEffect(cornerRadius: CGFloat = 12) -> some View {
        self
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            .shadow(color: .white.opacity(0.2), radius: 2, x: 0, y: 0)
    }
}
