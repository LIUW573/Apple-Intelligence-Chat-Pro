//
//  MessageView.swift
//  Apple Intelligence Chat
//
//  Created by Pallav Agarwal on 6/9/25.
//

import SwiftUI

/// Represents the role of a chat participant
enum ChatRole: Codable {
    case user
    case assistant
    
    enum CodingKeys: String, CodingKey {
        case rawValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)
        switch rawValue {
        case 0:
            self = .user
        case 1:
            self = .assistant
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Invalid ChatRole raw value: \(rawValue)"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .user:
            try container.encode(0, forKey: .rawValue)
        case .assistant:
            try container.encode(1, forKey: .rawValue)
        }
    }
}

/// Represents a single message in the chat conversation
struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    var role: ChatRole
    var text: String
    
    init(role: ChatRole, text: String) {
        self.id = UUID()
        self.role = role
        self.text = text
    }
    
    enum CodingKeys: String, CodingKey {
        case id, role, text
    }
}

/// View for displaying a single chat message
struct MessageView: View {
    let message: ChatMessage
    let isResponding: Bool
    
    // 添加操作回调
    var onCopy: (() -> Void)?
    var onEdit: (() -> Void)?
    var onRegenerate: (() -> Void)?
    
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 10
    @State private var isHovering = false
    @State private var isActionBarHovering = false // 单独跟踪操作栏的悬停状态
    
    // 计算是否应该显示操作按钮
    private var shouldShowActions: Bool {
        return (isHovering || isActionBarHovering) && !message.text.isEmpty && !isResponding
    }
    
    var body: some View {
        VStack(alignment: message.role == .assistant ? .leading : .trailing, spacing: 8) {
            // 消息内容
            Group {
                if message.role == .assistant {
                    if message.text.isEmpty && isResponding {
                        PulsingDotView()
                            .frame(width: 60, height: 25)
                            .padding(.leading, 8)
                    } else {
                        Text(message.text)
                            .textSelection(.enabled)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .glassEffect()
                            .padding(.leading, 8) // 添加左边距
                    }
                } else {
                    Text(message.text)
                        .padding(12)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .glassEffect()
                        .padding(.trailing, 8) // 添加右边距
                }
            }
            .padding(.vertical, 2)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            
            // 操作按钮区域 - 始终保留空间但仅在悬停时显示内容
            HStack {
                if message.role == .assistant {
                    // AI消息的操作按钮靠左对齐
                    HStack(spacing: 12) { // 增大按钮间距
                        if shouldShowActions {
                            // 复制按钮
                            Button(action: {
                                if let onCopy = onCopy {
                                    onCopy()
                                } else {
                                    #if os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(message.text, forType: .string)
                                    #else
                                    UIPasteboard.general.string = message.text
                                    #endif
                                }
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(MessageActionButtonStyle())
                            .help("复制消息")
                            
                            // 重新生成按钮
                            Button(action: {
                                if let onRegenerate = onRegenerate {
                                    onRegenerate()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(MessageActionButtonStyle())
                            .help("重新生成回答")
                        }
                        
                        Spacer()
                    }
                    .frame(height: 36) // 增大高度，提供更大的悬停区域
                    .padding(.leading, 8) // 添加左边距，对齐消息
                } else {
                    // 用户消息的操作按钮靠右对齐
                    HStack(spacing: 12) { // 增大按钮间距
                        Spacer()
                        
                        if shouldShowActions {
                            // 编辑按钮
                            Button(action: {
                                if let onEdit = onEdit {
                                    onEdit()
                                }
                            }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(MessageActionButtonStyle())
                            .help("编辑消息")
                            
                            // 复制按钮
                            Button(action: {
                                if let onCopy = onCopy {
                                    onCopy()
                                } else {
                                    #if os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(message.text, forType: .string)
                                    #else
                                    UIPasteboard.general.string = message.text
                                    #endif
                                }
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(MessageActionButtonStyle())
                            .help("复制消息")
                        }
                    }
                    .frame(height: 36) // 增大高度，提供更大的悬停区域
                    .padding(.trailing, 8) // 添加右边距，对齐消息
                }
            }
            .contentShape(Rectangle()) // 确保整个操作栏区域都可以接收悬停事件
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isActionBarHovering = hovering
                }
            }
        }
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 1
                offset = 0
            }
        }
    }
}

/// 消息操作按钮样式
struct MessageActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? .blue.opacity(0.7) : .secondary)
            .padding(8) // 增大内边距
            .frame(width: 32, height: 32) // 固定大小，确保点击区域足够大
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Animated loading indicator shown while AI is generating a response
struct PulsingDotView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(.primary.opacity(0.5))
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .glassEffect()
        .onAppear { isAnimating = true }
    }
}

#Preview {
    VStack {
        MessageView(message: ChatMessage(role: .user, text: "你好，今天天气怎么样？"), isResponding: false)
        MessageView(message: ChatMessage(role: .assistant, text: "你好！今天天气晴朗，温度适宜，是个出门活动的好日子。"), isResponding: false)
        MessageView(message: ChatMessage(role: .assistant, text: ""), isResponding: true)
    }
    .padding()
}
