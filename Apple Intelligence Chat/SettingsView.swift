//
//  SettingsView.swift
//  Apple Intelligence Chat
//
//  Created by Pallav Agarwal on 6/9/25.
//

import SwiftUI

/// App-wide settings stored in UserDefaults
enum AppSettings {
    @AppStorage("useStreaming") static var useStreaming: Bool = true
    @AppStorage("temperature") static var temperature: Double = 0.7
    @AppStorage("systemInstructions") static var systemInstructions: String = "你是一个有帮助的助手。"
}

/// Settings screen for configuring AI behavior
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    var onDismiss: (() -> Void)?
    
    @AppStorage("useStreaming") private var useStreaming = AppSettings.useStreaming
    @AppStorage("temperature") private var temperature = AppSettings.temperature
    @AppStorage("systemInstructions") private var systemInstructions = AppSettings.systemInstructions
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("流式响应", systemImage: "text.line.first.and.arrowtriangle.forward")
                        Spacer()
                        Toggle("", isOn: $useStreaming)
                            .labelsHidden()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("温度值", systemImage: "thermometer")
                            Spacer()
                            Text(String(format: "%.1f", temperature))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        
                        Slider(value: $temperature, in: 0.0...2.0, step: 0.1)
                            .labelsHidden()
                        
                        HStack {
                            Text("更确定")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("更随机")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("生成设置", systemImage: "gear")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("系统指令", systemImage: "text.bubble")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        Text("自定义AI助手的行为指南")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextEditor(text: $systemInstructions)
                            .font(.body)
                            .frame(minHeight: 120)
                            .padding(6)
                            .background(colorScheme == .dark ? Color(.darkGray).opacity(0.3) : Color(.lightGray).opacity(0.2))
                            .cornerRadius(8)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24))
                            .foregroundStyle(.blue)
                        
                        Text("Apple Intelligence Chat")
                            .font(.headline)
                        
                        Text("基于iOS 26+的离线人工智能聊天应用")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("设置")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { 
                        dismiss()
                        onDismiss?()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    SettingsView()
}
