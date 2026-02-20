import SwiftUI

// 🔥 SPRACHEN ENUM
enum Language: String, CaseIterable {
    case albanian = "sq-AL"
    case arabic = "ar-SA"
    case armenian = "hy-AM"
    case azeriCyrillic = "az-AZ"
    case chinese = "zh-CN"
    case dari = "prs-AF"
    case english = "en-US"
    case farsi = "fa-IR"
    case french = "fr-FR"
    case georgian = "ka-GE"
    case kurmanji = "ku-TR"
    case macedonian = "mk-MK"
    case pashto = "ps-AF"
    case portuguese = "pt-BR"
    case punjabi = "pa-IN"
    case russian = "ru-RU"
    case spanish = "es-ES"
    case tamil = "ta-IN"
    case turkish = "tr-TR"
    case ukrainian = "uk-UA"
    case urdu = "ur-PK"
    
    var displayName: String {
        switch self {
        case .albanian:
            return "🇦🇲 Albanisch"
        case .arabic:
            return "🇦🇪 Arabisch"
        case .armenian:
            return "🇦🇲 Armenisch"
        case .azeriCyrillic:
            return "🇦🇿 Azeri"
        case .chinese:
            return "🇨🇳 Chinese"
        case .dari:
            return "🇩🇿 Dari"
        case .english:
            return "🇬🇧 Englisch"
        case .farsi:
            return "🇮🇷 Farsi"
        case .french:
            return "🇫🇷 Französisch"
        case .georgian:
            return "🇬🇪 Georgisch"
        case .kurmanji:
            return "🇹🇷 Kurmandschi"
        case .macedonian:
            return "🇲🇰 Mazedonisch"
        case .pashto:
            return "🇦🇫 Paschtu"
        case .punjabi:
            return "🇵🇰 Punjabi"
        case .portuguese:
            return "🇧🇷 Portugiesisch"
        case .russian:
            return "🇷🇺 Russisch"
        case .spanish:
            return "🇪🇸 Spanisch"
        case .tamil:
            return "🇮🇳 Tamil"
        case .turkish:
            return "🇹🇷 Türkei"
        case .ukrainian:
            return "🇺🇦 Ukrainisch"
        case .urdu:
            return "🇮🇳 Urdu"
        }
    }
}

struct ContentView: View {
    
    @StateObject private var speechManager = AzureSpeechManager()
    
    @State private var myLanguage = "de-DE"
    @State private var selectedLanguage: Language = .english
    
    @State private var messages: [ChatMessage] = []
    @State private var lastProcessedText = "" // 🔥 TRACKING
    
    var body: some View {
        
        ZStack {
            ContainerRelativeShape()
                .fill(Color.blue.gradient)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                
                Text("Sprachmittler")
                    .font(.title)
                    .bold()
                    .foregroundStyle(Color.white.gradient)
                
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
                    .background(Color.white.opacity(0.2))
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
                                        language: selectedLanguage.rawValue,
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
                            await speechManager.startTranslation(
                                from: myLanguage,
                                to: selectedLanguage.rawValue
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
                    
                    // 🔥 BUBBLE BACKGROUND - NUR SO BREIT WIE NÖTIG
                    Text(bubbleText)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.mint.gradient)
                        .cornerRadius(10)
                }
                
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.clear)
                
                
            }
            // 🔥 RECHTE SEITE: Bubble mit Pfeil + Person
            else {
                
                
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.clear)
                
                ZStack(alignment: .trailing) {
                    // 🔥 PFEIL NACH RECHTS
                    RightTriangle()
                        .fill(Color("lightBlue"))
                        .frame(width: 12, height: 12)
                        .offset(x: 6)
                    
                    // 🔥 BUBBLE BACKGROUND - NUR SO BREIT WIE NÖTIG
                    Text(bubbleText)
                        .padding()
                        .frame(maxWidth: .infinity)
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
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.clear)
                
                // 🔥 BUBBLE PASST SICH AN ORIGINAL-BREITE AN
                Text(bubbleText)
                    .padding()
                    .frame(maxWidth: .infinity)
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
                        .foregroundStyle(.blue.gradient, .mint)
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
                        .font(.system(size: 48))
                        .foregroundStyle(.blue.gradient, Color("lightBlue"))
                        .symbolRenderingMode(.palette)
                }
                
                // 🔥 BUBBLE PASST SICH AN ORIGINAL-BREITE AN
                Text(bubbleText)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isSpeaking ? Color.orange.gradient : Color.white.gradient)
                    .cornerRadius(12)
                
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.clear)
            }
        }
    }
}
/*
import SwiftUI

// 🔥 SPRACHEN ENUM
enum Language: String, CaseIterable {
    case arabic = "ar-SA"
    case chinese = "zh-CN"
    case dari = "diq-DZ"
    case english = "en-US"
    case farsi = "fa-IR"
    case french = "fr-FR"
    case kurmanji = "ku-TR"
    case pashto = "ps-AF"
    case portuguese = "pt-BR"
    case russian = "ru-RU"
    case spanish = "es-ES"
    case turkish = "tr-TR"
    case ukrainian = "uk-UA"
    
    var displayName: String {
        switch self {
        case .arabic:
            return "🇦🇪 Arabisch"
        case .chinese:
            return "🇨🇳 Chinese"
        case .dari:
            return "🇩🇿 Dari"
        case .english:
            return "🇬🇧 Englisch"
        case .farsi:
            return "🇮🇷 Farsi"
        case .french:
            return "🇫🇷 Französisch"
        case .kurmanji:
            return "🇹🇷 Kurmandschi"
        case .pashto:
            return "🇦🇫 Paschtu"
        case .portuguese:
            return "🇧🇷 Portugiesisch"
        case .russian:
            return "🇷🇺 Russisch"
        case .spanish:
            return "🇪🇸 Spanisch"
        case .turkish:
            return "🇹🇷 Türkei"
        case .ukrainian:
            return "🇺🇦 Ukrainisch"
        }
    }
}

struct ContentView: View {
    
    @StateObject private var speechManager = AzureSpeechManager()
    
    @State private var myLanguage = "de-DE"
    @State private var selectedLanguage: Language = .english
    
    @State private var messages: [ChatMessage] = []
    @State private var lastProcessedText = "" // 🔥 TRACKING
    
    var body: some View {
        
        ZStack {
            ContainerRelativeShape()
                .fill(Color.blue.gradient)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                
                Text("Sprachmittler")
                    .font(.title)
                    .bold()
                    .foregroundStyle(Color.white.gradient)
                
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
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                }
                
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
                                    language: selectedLanguage.rawValue,
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
                                to: selectedLanguage.rawValue
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
                    
                    // 🔥 BUBBLE BACKGROUND - NUR SO BREIT WIE NÖTIG
                    Text(bubbleText)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.mint.gradient)
                        .cornerRadius(10)
                }
                
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.clear)
                
                
            }
            // 🔥 RECHTE SEITE: Bubble mit Pfeil + Person
            else {
                
                
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.clear)
                
                ZStack(alignment: .trailing) {
                    // 🔥 PFEIL NACH RECHTS
                    RightTriangle()
                        .fill(Color("lightBlue"))
                        .frame(width: 12, height: 12)
                        .offset(x: 6)
                    
                    // 🔥 BUBBLE BACKGROUND - NUR SO BREIT WIE NÖTIG
                    Text(bubbleText)
                        .padding()
                        .frame(maxWidth: .infinity)
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
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.clear)
                
                // 🔥 BUBBLE PASST SICH AN ORIGINAL-BREITE AN
                Text(bubbleText)
                    .padding()
                    .frame(maxWidth: .infinity)
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
                        .foregroundStyle(.blue.gradient, .mint)
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
                        .font(.system(size: 48))
                        .foregroundStyle(.blue.gradient, Color("lightBlue"))
                        .symbolRenderingMode(.palette)
                }
                
                // 🔥 BUBBLE PASST SICH AN ORIGINAL-BREITE AN
                Text(bubbleText)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isSpeaking ? Color.orange.gradient : Color.white.gradient)
                    .cornerRadius(12)
                
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.clear)
            }
        }
    }
}
*/
