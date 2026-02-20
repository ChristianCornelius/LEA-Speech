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
                            
                            // 🔥 DIVIDER
                            if index < messages.count - 1 {
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.white)
                                    .padding(.vertical, 4)
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
        HStack(spacing: 12) {
            // 🔥 LINKE SEITE: Person + Bubble mit Pfeil
            if isLeft {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.mint)
                
                ZStack(alignment: .leading) {
                    // 🔥 PFEIL NACH LINKS
                    LeftTriangle()
                        .fill(Color.mint)
                        .frame(width: 12, height: 12)
                        .offset(x: -6)
                    
                    // 🔥 BUBBLE BACKGROUND
                    Text(bubbleText)
                        .padding()
                        .background(Color.mint.gradient)
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            // 🔥 RECHTE SEITE: Bubble mit Pfeil + Person
            else {
                Spacer()
                
                ZStack(alignment: .trailing) {
                    // 🔥 PFEIL NACH RECHTS
                    RightTriangle()
                        .fill(Color("lightBlue"))
                        .frame(width: 12, height: 12)
                        .offset(x: 6)
                    
                    // 🔥 BUBBLE BACKGROUND
                    Text(bubbleText)
                        .padding()
                        .background(Color("lightBlue").gradient)
                        .cornerRadius(10)
                }
                
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color("lightBlue"))
            }
        }
    }
}

// 🔥 PFEIL NACH LINKS
struct LeftTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))  // Spitze nach links
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        
        return path
    }
}

// 🔥 PFEIL NACH RECHTS
struct RightTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.maxX, y: rect.midY))  // Spitze nach rechts
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        
        return path
    }
}

struct TranslatedChatBubble: View {

    var bubbleText: String
    var isLeft: Bool
    var language: String

    @ObservedObject var speechManager: AzureSpeechManager
    @State private var isSpeaking = false


    var body: some View {
        HStack(spacing: 12) {
            // 🔥 LINKE SEITE: Speaker + Bubble
            if isLeft {
                // 🔥 SPEAKER BUTTON - SPRICHT DANEBEN STEHENDE BUBBLE
                Button(action: {
                    isSpeaking = true
                    speechManager.speak(
                        text: bubbleText,
                        language: language
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isSpeaking = false
                    }
                }) {
                    Image(systemName: "speaker.wave.2.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue.gradient, .mint)
                        .symbolRenderingMode(.palette)
                }
                
                Text(bubbleText)
                    .padding()
                    .background(isSpeaking ? Color.orange.gradient : Color.white.gradient)
                    .cornerRadius(12)
                
                Spacer()
            }
            // 🔥 RECHTE SEITE: Bubble + Speaker
            else {
                Spacer()
                
                Text(bubbleText)
                    .padding()
                    .background(isSpeaking ? Color.orange.gradient : Color.white.gradient)
                    .cornerRadius(12)
                
                // 🔥 SPEAKER BUTTON - SPRICHT DANEBEN STEHENDE BUBBLE
                Button(action: {
                    isSpeaking = true
                    speechManager.speak(
                        text: bubbleText,
                        language: language
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isSpeaking = false
                    }
                }) {
                    Image(systemName: "speaker.wave.2.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue.gradient, Color("lightBlue"))
                        .symbolRenderingMode(.palette)
                }
            }
        }
    }
}
