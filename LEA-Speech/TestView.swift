//
//  TestView.swift
//  LEA-Speech
//
//  Created by Christian Cornelius on 11.02.26.
//

import SwiftUI

struct TestView: View {
    
    @StateObject private var speechManager = AzureSpeechManager()
    
    @State private var myLanguage = "de-DE"
    @State private var otherLanguage = "en-US"
    
    @State private var list: [String] = []
    @State private var translationList: [String] = []
    
    var body: some View {
        
        ZStack {
            ContainerRelativeShape()
                .fill(Color.blue.gradient)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                
                Text("Test Chat-Bubbles")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(Color.white.gradient)
                
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(list.enumerated()), id: \.offset) { index, text in
                            ChatBubble(bubbleText: text, isLeft: index % 2 == 0)
                        }
                        
                        Spacer()
                    }
                }
                
                // MARK: - Push-To-Talk Button
                Button {
                    Task {
                        if speechManager.isRecording {
                            await speechManager.stopTranslation()
                        } else {
                            await speechManager.startTranslation(
                                from: myLanguage,
                                to: otherLanguage
                            )
                        }
                    }
                } label: {
                    Text(speechManager.isRecording ? "⏹ Stop" : "🎤 Sprechen")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            speechManager.isRecording ? Color.red.gradient : Color.green.gradient
                        )
                        .cornerRadius(16)
                }
            }
            .padding()
            
        }
        .onChange(of: speechManager.isRecording) { _,isRecording in
            if !speechManager.isRecording && !speechManager.sourceText.isEmpty {
                list.append(speechManager.sourceText)
            }
        }
    }
}

#Preview {
    TestView()
}
