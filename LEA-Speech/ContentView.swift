import SwiftUI

struct ContentView: View {
    
    @StateObject private var speechManager = AzureSpeechManager()
    
    @State private var myLanguage = "de-DE"
    @State private var otherLanguage = "en-US"
    
    @State private var messages: [ChatMessage] = []
    @State private var lastProcessedText = "" // 🔥 TRACKING
    
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
                    VStack(spacing: 12) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            
                            let isLeft = index % 2 == 0
                            
                            VStack(spacing: 4) {
                                ChatBubble(
                                    bubbleText: message.sourceText,
                                    isLeft: isLeft
                                )

                                TranslatedChatBubble(
                                    bubbleText: message.translatedText,
                                    isLeft: isLeft,
                                    language: otherLanguage,
                                    speechManager: speechManager
                                )
                            }
                        }
                    }
                    .padding(.top, 10)
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
        // 🔥 PRIMÄR: Wenn Recording stoppt
        .onChange(of: speechManager.isRecording) { oldValue, newValue in
            if oldValue && !newValue { // Recording gerade gestoppt
                addMessageIfNeeded()
            }
        }
        // 🔥 FALLBACK: Falls sourceText sich ändert
        .onChange(of: speechManager.sourceText) { _, newSourceText in
            if !newSourceText.isEmpty && !speechManager.isRecording {
                addMessageIfNeeded()
            }
        }

    }
    
    // 🔥 NEUE HELPER-FUNKTION
    private func addMessageIfNeeded() {
        let currentSource = speechManager.sourceText.trimmingCharacters(in: .whitespaces)
        let currentTranslated = speechManager.translatedText.trimmingCharacters(in: .whitespaces)
        
        // Verhindere Duplikate
        if !currentSource.isEmpty,
           !currentTranslated.isEmpty,
           lastProcessedText != currentSource {
            
            print("✅ Message hinzugefügt: '\(currentSource)' → '\(currentTranslated)'")
            
            messages.append(
                ChatMessage(
                    sourceText: currentSource,
                    translatedText: currentTranslated
                )
            )
            
            lastProcessedText = currentSource
        } else {
            print("⚠️ Message ignoriert - Source: '\(currentSource)', Translated: '\(currentTranslated)', LastProcessed: '\(lastProcessedText)'")
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let sourceText: String
    let translatedText: String
}

struct ChatBubble: View {
    
    var bubbleText: String
    var isLeft: Bool
    
    var body: some View {
        HStack {
            VStack {
                if isLeft {
                    Text(bubbleText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.mint.gradient)
                        .cornerRadius(10)
                }
                
            }
            .frame(maxWidth: .infinity)
            
            VStack {
                if !isLeft {
                    Text(bubbleText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("lightBlue").gradient)
                        .cornerRadius(10)
                }
            }
            .frame(maxWidth: .infinity)
            
        }
    }
}

struct TranslatedChatBubble: View {

    var bubbleText: String
    var isLeft: Bool
    var language: String

    @ObservedObject var speechManager: AzureSpeechManager
    @State private var isSpeaking = false


    var body: some View {
        HStack {
            VStack {
                if isLeft {
                    bubble
                }
            }
            .frame(maxWidth: .infinity)
            
            VStack {
                if !isLeft {
                    bubble
                }
            }
            .frame(maxWidth: .infinity)
            
        }
    }

    private var bubble: some View {
        Text(bubbleText)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSpeaking ? Color.orange.gradient : Color.white.gradient)
            .cornerRadius(12)
            .onTapGesture {
                isSpeaking = true
                speechManager.speak(
                    text: bubbleText,
                    language: language
                )

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isSpeaking = false
                }
            }
    }
}
/*
import SwiftUI

struct ContentView: View {
    
    @StateObject private var speechManager = AzureSpeechManager()
    
    @State private var myLanguage = "de-DE"
    @State private var otherLanguage = "en-US"
    
    @State private var messages: [ChatMessage] = []
    
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
                    VStack(spacing: 12) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            
                            let isLeft = index % 2 == 0
                            
                            VStack(spacing: 4) {
                                ChatBubble(
                                    bubbleText: message.sourceText,
                                    isLeft: isLeft
                                )

                                TranslatedChatBubble(
                                    bubbleText: message.translatedText,
                                    isLeft: isLeft,
                                    language: otherLanguage,
                                    speechManager: speechManager
                                )
                            }
                        }
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
        .onChange(of: speechManager.isRecording) { _, isRecording in
            if !isRecording,
               !speechManager.sourceText.isEmpty,
               !speechManager.translatedText.isEmpty {

                messages.append(
                    ChatMessage(
                        sourceText: speechManager.sourceText,
                        translatedText: speechManager.translatedText
                    )
                )
            }
        }

    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let sourceText: String
    let translatedText: String
}

struct ChatBubble: View {
    
    var bubbleText: String
    var isLeft: Bool
    
    var body: some View {
        HStack {
            VStack {
                if isLeft {
                    Text(bubbleText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.mint.gradient)
                        .cornerRadius(10)
                }
                
            }
            .frame(maxWidth: .infinity)
            
            VStack {
                if !isLeft {
                    Text(bubbleText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("lightBlue").gradient)
                        .cornerRadius(10)
                }
            }
            .frame(maxWidth: .infinity)
            
        }
    }
}

struct TranslatedChatBubble: View {

    var bubbleText: String
    var isLeft: Bool
    var language: String

    @ObservedObject var speechManager: AzureSpeechManager
    @State private var isSpeaking = false


    var body: some View {
        HStack {
            VStack {
                if isLeft {
                    bubble
                }
            }
            .frame(maxWidth: .infinity)
            
            VStack {
                if !isLeft {
                    bubble
                }
            }
            .frame(maxWidth: .infinity)
            
        }
    }

    private var bubble: some View {
        Text(bubbleText)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSpeaking ? Color.orange.gradient : Color.white.gradient)
            .cornerRadius(12)
            .onTapGesture {
                isSpeaking = true
                speechManager.speak(
                    text: bubbleText,
                    language: language
                )

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isSpeaking = false
                }
            }
    }
}
*/
