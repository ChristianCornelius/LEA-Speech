import SwiftUI

struct ContentView: View {
    
    @StateObject private var speechManager = AzureSpeechManager()
    
    @State private var myLanguage = "de-DE"
    @State private var selectedLanguage: Language = .english
    
    @State private var messages: [ChatMessage] = []
    @State private var lastProcessedText = "" // 🔥 TRACKING
    
    private var iconSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 48 : 34
    }
    
    var body: some View {
        
        ZStack {
            ContainerRelativeShape()
                .fill(Color.blue.opacity(0.4))
                .ignoresSafeArea()
            
            VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 10) {
                
                Text("Sprachmittler")
                    .font(.title)
                    .bold()
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .overlay(alignment: .leading) {
                        Button {
                            resetConversation()
                        } label: {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: iconSize))
                                .foregroundStyle(.blue.gradient, .white.gradient)
                                .symbolRenderingMode(.palette)
                        }
                        .buttonStyle(.plain)
                    }

                // 🔥 DROPDOWN MENÜ
                Menu {
                    ForEach(Language.allCases, id: \.self) { language in
                        Button(action: {
                            selectedLanguage = language
                        }) {
                            HStack {
                                Text(language.displayName)
                                if selectedLanguage == language {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedLanguage.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                                            
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(8)
                }
                
                // 🔥 SCROLLVIEW MIT READER
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                
                                let isLeft = index % 2 == 0
                                
                                VStack(spacing: 2) {
                                    ChatBubble(
                                        bubbleText: message.sourceText,
                                        isLeft: isLeft
                                    )

                                    TranslatedChatBubble(
                                        bubbleText: message.translatedText,
                                        isLeft: isLeft,
                                        language: isLeft ? selectedLanguage.rawValue : myLanguage,
                                        //language: selectedLanguage.rawValue,
                                        speechManager: speechManager
                                    )
                                }
                                // 🔥 ID FÜR SCROLL TARGET
                                .id(message.id)
                            }
                        }
                        .padding(.top, 10)
                    }
                    // 🔥 SCROLL ZU LETZTER MESSAGE
                    .onChange(of: messages.count) { _, newCount in
                        if newCount > 0 {
                            withAnimation {
                                scrollProxy.scrollTo(messages[newCount - 1].id, anchor: .bottom)
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
                            let nextIsLeft = messages.count % 2 == 0

                            let fromLanguage = nextIsLeft ? myLanguage : selectedLanguage.rawValue
                            let toLanguage = nextIsLeft ? selectedLanguage.rawValue : myLanguage

                            await speechManager.startTranslation(
                                from: fromLanguage,
                                to: toLanguage
                            )

                        }
                    }
                } label: {
                    Image(systemName: speechManager.isRecording ? "microphone.slash.fill" : "microphone.fill")
                        .font(.title)
                        .foregroundStyle(.white)
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
    
    private func resetConversation() {
        messages = []
        lastProcessedText = ""

        speechManager.sourceText = ""
        speechManager.translatedText = ""
        speechManager.liveSourceText = ""
        speechManager.liveTranslatedText = ""
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
    
    private var iconSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 48 : 34
    }
    
    private var paddingSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 16 : 8
    }
    
    private var fontSize: Font {
        UIDevice.current.userInterfaceIdiom == .pad ? .body : .callout
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 🔥 LINKE SEITE: Person + Bubble mit Pfeil
            if isLeft {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.white, .mint)
                    .symbolRenderingMode(.palette)
                
                ZStack(alignment: .leading) {
                    // 🔥 PFEIL NACH LINKS
                    LeftTriangle()
                        .fill(Color.mint)
                        .frame(width: 12, height: 12)
                        .offset(x: -6)
                    
                    // 🔥 BUBBLE BACKGROUND - NUR SO BREIT WIE NÖTIG
                    Text(bubbleText)
                        .font(fontSize)
                        .padding(paddingSize)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .background(Color.mint)
                        .cornerRadius(10)
                }
                
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.clear)
                
                
            }
            // 🔥 RECHTE SEITE: Bubble mit Pfeil + Person
            else {
                
                
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.clear)
                
                ZStack(alignment: .trailing) {
                    // 🔥 PFEIL NACH RECHTS
                    RightTriangle()
                        .fill(.purple)
                        .frame(width: 12, height: 12)
                        .offset(x: 6)
                    
                    // 🔥 BUBBLE BACKGROUND - NUR SO BREIT WIE NÖTIG
                    Text(bubbleText)
                        .font(fontSize)
                        .padding(paddingSize)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .background(.purple)
                        .cornerRadius(10)
                }
                
                Image(systemName: "person.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.white, .purple)
                    .symbolRenderingMode(.palette)
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
    
    private var iconSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 48 : 34
    }
    private var paddingSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 16 : 8
    }

    private var fontSize: Font {
        UIDevice.current.userInterfaceIdiom == .pad ? .body : .callout
    }

    var body: some View {
        HStack(spacing: 12) {
            // 🔥 LINKE SEITE: Speaker + Bubble
            if isLeft {
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.clear)
                
                // 🔥 BUBBLE PASST SICH AN ORIGINAL-BREITE AN
                Text(bubbleText)
                    .font(fontSize)
                    .padding(paddingSize)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .background(isSpeaking ? .orange : .white)
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
                        .font(.system(size: iconSize))
                        .foregroundStyle(.white.gradient, .mint.gradient)
                        .symbolRenderingMode(.palette)
                }
                
               
            }
            // 🔥 RECHTE SEITE: Bubble + Speaker
            else {
                
                
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
                        .font(.system(size: iconSize))
                        .foregroundStyle(.white.gradient, .purple.gradient)
                        .symbolRenderingMode(.palette)
                }
                
                // 🔥 BUBBLE PASST SICH AN ORIGINAL-BREITE AN
                Text(bubbleText)
                    .font(fontSize)
                    .padding(paddingSize)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .background(isSpeaking ? .orange : .white)
                    .cornerRadius(12)
                
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.clear)
            }
        }
    }
}
