//
//  ContentView.swift
//  Apple Intelligence Chat
//
//  Created by Pallav Agarwal on 6/9/25.
//

import SwiftUI
import FoundationModels
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// 表示一个聊天会话
struct ChatSession: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var date: Date
    var previewText: String
    
    init(title: String, date: Date, previewText: String) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.previewText = previewText
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, date, previewText
    }
}

/// 用于编辑消息的标识符
struct EditingMessage: Identifiable {
    let id: UUID
    let text: String
}

/// Main chat interface view
struct ContentView: View {
    // MARK: - State Properties
    
    // UI State
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isResponding = false
    @State private var showSettings = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @FocusState private var isInputFocused: Bool
    @State private var editingMessage: EditingMessage? = nil
    @State private var editingMessageText: String = ""
    @State private var showDeleteConfirmation = false
    @State private var sessionToDelete: UUID? = nil
    
    // 聊天历史状态
    @State private var chatSessions: [ChatSession] = []
    @State private var selectedSessionId: UUID?
    @State private var currentSessionMessages: [UUID: [ChatMessage]] = [:]
    @State private var currentSessionTitle: String = "新的对话"
    
    // 导航状态
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    // Model State
    @State private var session: LanguageModelSession?
    @State private var streamingTask: Task<Void, Never>?
    @State private var model = SystemLanguageModel.default
    
    // Settings
    @AppStorage("useStreaming") private var useStreaming = AppSettings.useStreaming
    @AppStorage("temperature") private var temperature = AppSettings.temperature
    @AppStorage("systemInstructions") private var systemInstructions = AppSettings.systemInstructions
    
    // Haptics
#if os(iOS)
    private let hapticStreamGenerator = UISelectionFeedbackGenerator()
#endif
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // 侧边栏 - 聊天历史
            List(selection: $selectedSessionId) {
                Section {
                    Button(action: resetConversation) {
                        Label("新对话", systemImage: "plus.bubble")
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.blue.opacity(0.1))
                    .padding(.vertical, 4)
                }
                
                if !chatSessions.isEmpty {
                    Section {
                        ForEach(chatSessions) { session in
                            HStack {
                                Button(action: {
                                    loadChatSession(session.id)
                                }) {
                                    ChatHistoryRow(session: session)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                // 删除按钮
                                Button(action: {
                                    sessionToDelete = session.id
                                    showDeleteConfirmation = true
                                }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 8)
                                .opacity(selectedSessionId == session.id ? 1 : 0)
                            }
                        }
                    } header: {
                        Text("最近对话")
                    }
                } else {
                    Section {
                        VStack(spacing: 15) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                                .padding(.top, 20)
                            
                            Text("暂无历史记录")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Text("开始新对话以创建历史记录")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("对话历史")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: resetConversation) {
                        Label("新对话", systemImage: "square.and.pencil")
                    }
                }
            }
            .alert("确认删除", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {
                    sessionToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let id = sessionToDelete {
                        deleteSession(id)
                    }
                }
            } message: {
                Text("确定要删除这个对话吗？此操作无法撤销。")
            }
        } detail: {
            // 详情视图 - 聊天内容
            ZStack {
                // 渐变背景
                backgroundView
                
                // 聊天消息列表
                VStack(spacing: 0) {
                    chatMessagesView
                    
                    Spacer()
                    
                    // 底部输入框
                    ChatInputView(
                        text: $inputText,
                        isResponding: isResponding,
                        isFocused: _isInputFocused,
                        onSubmit: handleSendOrStop
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(currentSessionTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: openSettings) {
                        Label("设置", systemImage: "gearshape")
                    }
                }
            }
            .alert("错误", isPresented: $showErrorAlert) {
                Button("确定") {}
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            // 加载历史会话和消息
            loadSavedSessions()
            loadSavedMessages()
            
            // 如果没有选中的会话，创建一个新会话
            if selectedSessionId == nil {
                createNewSession(firstMessage: "")
            }
            
            // 设置通知监听器
            setupNotificationObservers()
            
            // 自动聚焦输入框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView {
                session = nil // Reset session on settings change
            }
            .interactiveDismissDisabled(false)
        }
        .sheet(item: $editingMessage) { message in
            VStack(spacing: 20) {
                // 标题
                HStack {
                    Text("编辑消息")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        editingMessage = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 4)
                
                // 编辑区域
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                    
                    TextEditor(text: $editingMessageText)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(8)
                        .frame(minHeight: 120)
                }
                
                // 按钮区域
                HStack {
                    Button("取消") {
                        editingMessage = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Spacer()
                    
                    Button("保存") {
                        updateMessage()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .frame(minWidth: 450, minHeight: 250)
            .background(
                ZStack {
                    Color(NSColor.windowBackgroundColor).opacity(0.6)
                    
                    // 背景装饰
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                        .offset(x: 150, y: -100)
                    
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                        .offset(x: -150, y: 100)
                }
            )
            .interactiveDismissDisabled(true)
            .onAppear {
                // 自动聚焦文本编辑器
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    #if os(iOS)
                    UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                }
            }
        }
    }
    
    // MARK: - 背景视图
    
    private var backgroundView: some View {
        ZStack {
            #if os(iOS)
            Color(UIColor.systemBackground)
                .opacity(0.8)
                .ignoresSafeArea()
            #else
            Color(NSColor.windowBackgroundColor)
                .opacity(0.8)
                .ignoresSafeArea()
            #endif
            
            // 渐变气泡效果
            VStack {
                Spacer()
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -50, y: 50)
                
                Circle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .blur(radius: 60)
                    .offset(x: 100, y: -100)
            }
            .ignoresSafeArea()
        }
    }
    
    // MARK: - 聊天消息视图
    
    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack {
                    ForEach(messages) { message in
                        MessageView(
                            message: message, 
                            isResponding: isResponding,
                            onCopy: {
                                copyMessage(message)
                            },
                            onEdit: message.role == .user ? {
                                editMessage(message)
                            } : nil,
                            onRegenerate: message.role == .assistant ? {
                                regenerateResponse(message)
                            } : nil
                        )
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeIn(duration: 0.3)),
                            removal: .opacity.animation(.easeOut(duration: 0.2))
                        ))
                        .padding(.bottom, 4)
                    }
                    // 底部空间，确保最后一条消息不会被输入框遮挡
                    Color.clear.frame(height: 20)
                        .id("bottomSpacer")
                }
                .padding()
            }
            .onChange(of: messages) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottomSpacer", anchor: .bottom)
                }
            }
            .onAppear {
                withAnimation {
                    proxy.scrollTo("bottomSpacer", anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - 通知处理
    
    private func setupNotificationObservers() {
        // 监听来自菜单的命令
        NotificationCenter.default.addObserver(
            forName: Notification.Name("NewChat"),
            object: nil,
            queue: .main
        ) { _ in
            resetConversation()
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ToggleHistory"),
            object: nil,
            queue: .main
        ) { _ in
            withAnimation {
                columnVisibility = columnVisibility == .detailOnly ? .automatic : .detailOnly
            }
        }
    }
    
    // MARK: - Model Interaction
    
    private func openSettings() {
        showSettings = true
    }
    
    private func handleSendOrStop() {
        if isResponding {
            stopStreaming()
        } else {
            guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            
            guard model.isAvailable else {
                showError(message: "语言模型不可用。原因: \(availabilityDescription(for: model.availability))")
                return
            }
            sendMessage()
        }
    }
    
    private func sendMessage() {
        isResponding = true
        let userMessage = ChatMessage(role: .user, text: inputText)
        
        withAnimation {
            messages.append(userMessage)
        }
        
        let prompt = inputText
        
        // 如果是新会话的第一条消息，创建会话
        if selectedSessionId == nil {
            createNewSession(firstMessage: inputText)
        } else {
            // 更新现有会话
            updateSessionPreview(with: inputText)
        }
        
        inputText = ""
        
        // Add empty assistant message for streaming
        withAnimation {
            messages.append(ChatMessage(role: .assistant, text: ""))
        }
        
        streamingTask = Task {
            do {
                if session == nil { session = createSession() }
                
                guard let currentSession = session else {
                    showError(message: "无法创建会话。")
                    isResponding = false
                    return
                }
                
                let options = GenerationOptions(temperature: temperature)
                
                if useStreaming {
                    let stream = currentSession.streamResponse(to: prompt, options: options)
                    for try await partialResponse in stream {
#if os(iOS)
                        hapticStreamGenerator.selectionChanged()
#endif
                        updateLastMessage(with: partialResponse)
                    }
                } else {
                    let response = try await currentSession.respond(to: prompt, options: options)
                    updateLastMessage(with: response.content)
                }
                
                // 保存当前会话消息
                saveCurrentSessionMessages()
                
                // 回答完成后自动聚焦输入框
                DispatchQueue.main.async {
                    isInputFocused = true
                }
                
            } catch is CancellationError {
                // User cancelled generation
            } catch {
                showError(message: "发生错误: \(error.localizedDescription)")
            }
            
            isResponding = false
            streamingTask = nil
        }
    }
    
    private func stopStreaming() {
        streamingTask?.cancel()
    }
    
    @MainActor
    private func updateLastMessage(with text: String) {
        messages[messages.count - 1].text = text
    }
    
    // MARK: - Session & Helpers
    
    private func createSession() -> LanguageModelSession {
        return LanguageModelSession(instructions: systemInstructions)
    }
    
    private func resetConversation() {
        stopStreaming()
        withAnimation {
            messages.removeAll()
        }
        session = nil
        
        // 创建新会话
        createNewSession(firstMessage: "")
        
        // 自动聚焦输入框
        DispatchQueue.main.async {
            isInputFocused = true
        }
    }
    
    private func createNewSession(firstMessage: String) {
        let newId = UUID()
        let newSession = ChatSession(
            title: "新对话",
            date: Date(),
            previewText: firstMessage.isEmpty ? "开始新对话..." : firstMessage
        )
        
        chatSessions.insert(newSession, at: 0)
        selectedSessionId = newId
        currentSessionTitle = "新对话"
        currentSessionMessages[newId] = messages
        
        // 保存会话列表和消息
        saveSessions()
        saveMessages()
    }
    
    private func updateSessionTitle() {
        // 如果有消息，使用第一条用户消息的前15个字作为标题
        if let firstUserMessage = messages.first(where: { $0.role == .user }),
           !firstUserMessage.text.isEmpty {
            let title = String(firstUserMessage.text.prefix(15))
            currentSessionTitle = title
            
            // 更新会话列表中的对应项
            if let index = chatSessions.firstIndex(where: { $0.id == selectedSessionId }) {
                chatSessions[index].title = title
                
                // 保存更新后的会话列表
                saveSessions()
            }
        }
    }
    
    private func updateSessionPreview(with text: String) {
        guard let sessionId = selectedSessionId,
              let index = chatSessions.firstIndex(where: { $0.id == sessionId }) else {
            return
        }
        
        chatSessions[index].previewText = text
        chatSessions[index].date = Date()
        
        // 将最近使用的会话移到顶部
        if index > 0 {
            let session = chatSessions.remove(at: index)
            chatSessions.insert(session, at: 0)
        }
        
        saveSessions()
    }
    
    private func loadChatSession(_ sessionId: UUID) {
        // 如果点击的是当前会话，不做任何操作
        if sessionId == selectedSessionId {
            return
        }
        
        // 保存当前会话消息
        if let currentId = selectedSessionId {
            currentSessionMessages[currentId] = messages
            saveMessages()
        }
        
        selectedSessionId = sessionId
        
        // 加载选中的会话消息
        if let sessionMessages = currentSessionMessages[sessionId] {
            withAnimation {
                messages = sessionMessages
            }
        } else {
            withAnimation {
                messages = []
            }
        }
        
        // 更新标题
        if let session = chatSessions.first(where: { $0.id == sessionId }) {
            currentSessionTitle = session.title
        }
        
        // 创建新的会话实例（重置状态）
        session = createSession()
    }
    
    private func saveSessions() {
        // 保存会话列表到UserDefaults
        if let encodedData = try? JSONEncoder().encode(chatSessions) {
            UserDefaults.standard.set(encodedData, forKey: "chatSessions")
        }
    }
    
    private func saveMessages() {
        // 保存所有会话消息到UserDefaults
        if let encodedData = try? JSONEncoder().encode(currentSessionMessages) {
            UserDefaults.standard.set(encodedData, forKey: "chatMessages")
        }
    }
    
    private func saveCurrentSessionMessages() {
        // 保存当前会话的消息
        if let sessionId = selectedSessionId {
            currentSessionMessages[sessionId] = messages
            
            // 更新会话标题（如果需要）
            updateSessionTitle()
            
            // 保存会话列表和消息
            saveSessions()
            saveMessages()
        }
    }
    
    private func loadSavedSessions() {
        // 从UserDefaults加载会话列表
        if let savedData = UserDefaults.standard.data(forKey: "chatSessions"),
           let decodedSessions = try? JSONDecoder().decode([ChatSession].self, from: savedData) {
            chatSessions = decodedSessions
            
            // 如果有会话，选择第一个
            if let firstSession = chatSessions.first {
                selectedSessionId = firstSession.id
                currentSessionTitle = firstSession.title
            }
        }
    }
    
    private func loadSavedMessages() {
        // 从UserDefaults加载所有会话消息
        if let savedData = UserDefaults.standard.data(forKey: "chatMessages"),
           let decodedMessages = try? JSONDecoder().decode([UUID: [ChatMessage]].self, from: savedData) {
            currentSessionMessages = decodedMessages
            
            // 加载当前选中会话的消息
            if let sessionId = selectedSessionId, let sessionMessages = currentSessionMessages[sessionId] {
                messages = sessionMessages
            }
        }
    }
    
    private func availabilityDescription(for availability: SystemLanguageModel.Availability) -> String {
        switch availability {
            case .available:
                return "可用"
            case .unavailable(let reason):
                switch reason {
                    case .deviceNotEligible:
                        return "设备不支持"
                    case .appleIntelligenceNotEnabled:
                        return "未在设置中启用Apple Intelligence"
                    case .modelNotReady:
                        return "模型资源未下载"
                    @unknown default:
                        return "未知原因"
                }
            @unknown default:
                return "未知状态"
        }
    }
    
    @MainActor
    private func showError(message: String) {
        self.errorMessage = message
        self.showErrorAlert = true
        self.isResponding = false
    }
    
    // MARK: - 消息操作功能
    
    /// 复制消息内容
    private func copyMessage(_ message: ChatMessage) {
        #if os(iOS)
        UIPasteboard.general.string = message.text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.text, forType: .string)
        #endif
    }
    
    /// 编辑用户消息
    private func editMessage(_ message: ChatMessage) {
        // 只允许编辑用户消息
        guard message.role == .user else { return }
        
        // 找到消息在数组中的位置
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            editingMessage = EditingMessage(id: message.id, text: message.text)
            editingMessageText = message.text
        }
    }
    
    /// 更新编辑后的消息
    private func updateMessage() {
        guard let message = editingMessage,
              let index = messages.firstIndex(where: { $0.id == message.id }) else {
            editingMessage = nil
            return
        }
        
        // 更新消息文本
        messages[index].text = editingMessageText
        
        // 如果编辑的是最后一条用户消息，则需要重新生成AI回复
        let isLastUserMessage = index == messages.count - 2 && 
                               messages[index].role == .user && 
                               messages[index + 1].role == .assistant
        
        if isLastUserMessage {
            // 删除AI回复，重新生成
            messages.removeLast()
            
            // 保存当前会话消息
            saveCurrentSessionMessages()
            
            // 重新发送请求
            isResponding = true
            let prompt = editingMessageText
            
            // 添加空的AI回复消息用于流式显示
            withAnimation {
                messages.append(ChatMessage(role: .assistant, text: ""))
            }
            
            streamingTask = Task {
                do {
                    if session == nil { session = createSession() }
                    
                    guard let currentSession = session else {
                        showError(message: "无法创建会话。")
                        isResponding = false
                        return
                    }
                    
                    let options = GenerationOptions(temperature: temperature)
                    
                    if useStreaming {
                        let stream = currentSession.streamResponse(to: prompt, options: options)
                        for try await partialResponse in stream {
                            #if os(iOS)
                            hapticStreamGenerator.selectionChanged()
                            #endif
                            updateLastMessage(with: partialResponse)
                        }
                    } else {
                        let response = try await currentSession.respond(to: prompt, options: options)
                        updateLastMessage(with: response.content)
                    }
                    
                    // 保存当前会话消息
                    saveCurrentSessionMessages()
                    
                } catch is CancellationError {
                    // User cancelled generation
                } catch {
                    showError(message: "发生错误: \(error.localizedDescription)")
                }
                
                isResponding = false
                streamingTask = nil
            }
        } else {
            // 保存当前会话消息
            saveCurrentSessionMessages()
        }
        
        editingMessage = nil
    }
    
    /// 重新生成AI回复
    private func regenerateResponse(_ message: ChatMessage) {
        // 只允许重新生成AI回复
        guard message.role == .assistant else { return }
        
        // 找到消息在数组中的位置
        if let index = messages.firstIndex(where: { $0.id == message.id }),
           index > 0,
           messages[index - 1].role == .user {
            
            // 获取前一条用户消息
            let userMessage = messages[index - 1]
            
            // 删除当前AI回复
            messages.remove(at: index)
            
            // 保存当前会话消息
            saveCurrentSessionMessages()
            
            // 重新发送请求
            isResponding = true
            let prompt = userMessage.text
            
            // 添加空的AI回复消息用于流式显示
            withAnimation {
                messages.append(ChatMessage(role: .assistant, text: ""))
            }
            
            streamingTask = Task {
                do {
                    if session == nil { session = createSession() }
                    
                    guard let currentSession = session else {
                        showError(message: "无法创建会话。")
                        isResponding = false
                        return
                    }
                    
                    let options = GenerationOptions(temperature: temperature)
                    
                    if useStreaming {
                        let stream = currentSession.streamResponse(to: prompt, options: options)
                        for try await partialResponse in stream {
                            #if os(iOS)
                            hapticStreamGenerator.selectionChanged()
                            #endif
                            updateLastMessage(with: partialResponse)
                        }
                    } else {
                        let response = try await currentSession.respond(to: prompt, options: options)
                        updateLastMessage(with: response.content)
                    }
                    
                    // 保存当前会话消息
                    saveCurrentSessionMessages()
                    
                } catch is CancellationError {
                    // User cancelled generation
                } catch {
                    showError(message: "发生错误: \(error.localizedDescription)")
                }
                
                isResponding = false
                streamingTask = nil
            }
        }
    }
    
    /// 删除会话
    private func deleteSession(_ sessionId: UUID) {
        // 从会话列表中删除
        chatSessions.removeAll(where: { $0.id == sessionId })
        
        // 从消息存储中删除
        currentSessionMessages.removeValue(forKey: sessionId)
        
        // 如果删除的是当前选中的会话，则选择第一个可用的会话
        if sessionId == selectedSessionId {
            // 如果还有其他会话，选择第一个
            if let firstSession = chatSessions.first {
                loadChatSession(firstSession.id)
            } else {
                // 如果没有会话，清空当前消息但不创建新会话
                withAnimation {
                    messages.removeAll()
                }
                session = nil
                selectedSessionId = nil
                currentSessionTitle = "新的对话"
            }
        }
        
        // 保存更新后的会话列表和消息
        saveSessions()
        saveMessages()
    }
}

/// 聊天历史行项目
struct ChatHistoryRow: View {
    let session: ChatSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
                
                Text(session.title)
                    .font(.headline)
                    .lineLimit(1)
            }
            
            Text(session.previewText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(.leading, 2)
            
            Text(formatDate(session.date))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.leading, 2)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// 现代化的聊天输入视图，类似Xcode 26 beta
struct ChatInputView: View {
    @Binding var text: String
    var isResponding: Bool
    @FocusState var isFocused: Bool
    var onSubmit: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        // 现代化输入框
        ZStack(alignment: .leading) {
            // 背景
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    .ultraThinMaterial.shadow(.inner(color: .black.opacity(0.1), radius: 1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isHovering ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2),
                            lineWidth: 1
                        )
                )
            
            // 输入区域
            HStack(alignment: .center, spacing: 8) {
                // 文本输入
                TextField("请输入问题...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...2)
                    .padding(.leading, 12)
                    .padding(.vertical, 6)
                    .disabled(isResponding)
                    .focused($isFocused)
                    .onSubmit {
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSubmit()
                        }
                    }
                
                Spacer()
                
                // 发送按钮 - 内嵌在输入框中
                Button(action: onSubmit) {
                    ZStack {
                        Circle()
                            .fill(isSendButtonDisabled ? Color.gray.opacity(0.5) : Color.blue)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: isResponding ? "stop.fill" : "arrow.up")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(isSendButtonDisabled)
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: isResponding)
                .animation(.easeInOut(duration: 0.2), value: isSendButtonDisabled)
                .padding(.trailing, 8)
            }
        }
        .frame(height: 36) // 稍微增加高度，使按钮有足够空间
        .padding(.horizontal, 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    private var isSendButtonDisabled: Bool {
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isResponding
    }
}

#Preview {
    ContentView()
}
