import SwiftUI

struct ContentView: View {

    @StateObject private var speechManager = AzureSpeechManager()

    @State private var myLanguage = "de-DE"
    @State private var otherLanguage = "ar"

    var body: some View {
        VStack(spacing: 24) {

            Text("🌍 Sprachübersetzer")
                .font(.largeTitle)
                .bold()

            // MARK: - Sprachauswahl
            VStack {
                Picker("Meine Sprache", selection: $myLanguage) {
                    Text("Deutsch").tag("de-DE")
                    Text("Englisch").tag("en-US")
                }
                .pickerStyle(.segmented)

                Picker("Sprache Gegenüber", selection: $otherLanguage) {
                    Text("Arabisch").tag("ar")
                    Text("Ukrainisch").tag("uk")
                    Text("Türkisch").tag("tr")
                    Text("Englisch").tag("en-US")
                }
                .pickerStyle(.segmented)
            }

            // MARK: - Texte
            VStack(alignment: .leading, spacing: 12) {

                // ORIGINAL
                Text("🗣 Original")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    // Finaler Text (schwarz)
                    if !speechManager.sourceText.isEmpty {
                        Text(speechManager.sourceText)
                            .foregroundColor(.primary)
                    }

                    // Live-Text (grau)
                    if speechManager.isRecording,
                       !speechManager.liveSourceText.isEmpty {
                        Text(speechManager.liveSourceText)
                            .foregroundColor(.gray)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                // ÜBERSETZUNG
                Text("🔁 Übersetzung")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    // Finaler Text (schwarz)
                    if !speechManager.translatedText.isEmpty {
                        Text(speechManager.translatedText)
                            .foregroundColor(.primary)
                    }

                    // Live-Übersetzung (grau)
                    if speechManager.isRecording,
                       !speechManager.liveTranslatedText.isEmpty {
                        Text(speechManager.liveTranslatedText)
                            .foregroundColor(.gray)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

                // Vorlesen
                Button {
                    speechManager.speakTranslatedText(language: otherLanguage)
                } label: {
                    Label("🔊 Übersetzung vorlesen", systemImage: "speaker.wave.2.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(14)
                }
                .disabled(speechManager.translatedText.isEmpty)
            }

            Spacer()

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
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        speechManager.isRecording ? Color.red : Color.green
                    )
                    .cornerRadius(16)
            }
        }
        .padding()
    }
}


/*
import SwiftUI

struct ContentView: View {

    @StateObject private var speechManager = AzureSpeechManager()

    @State private var myLanguage = "de-DE"
    @State private var otherLanguage = "ar"

    var body: some View {
        VStack(spacing: 24) {

            Text("🌍 Sprachübersetzer")
                .font(.largeTitle)
                .bold()

            // Sprachauswahl
            VStack {
                Picker("Meine Sprache", selection: $myLanguage) {
                    Text("Deutsch").tag("de-DE")
                    Text("Englisch").tag("en-US")
                }
                .pickerStyle(.segmented)

                Picker("Sprache Gegenüber", selection: $otherLanguage) {
                    Text("Arabisch").tag("ar")
                    Text("Ukrainisch").tag("uk")
                    Text("Türkisch").tag("tr")
                    Text("Englisch").tag("en-US")
                }
                .pickerStyle(.segmented)
            }

            // Texte
            VStack(alignment: .leading, spacing: 12) {
                Text("🗣 Original")
                    .font(.headline)
                Text(speechManager.sourceText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)

                Text("🔁 Übersetzung")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(speechManager.translatedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                
                Button {
                    speechManager.speakTranslatedText(language: otherLanguage)
                } label: {
                    Label("🔊 Übersetzung vorlesen", systemImage: "speaker.wave.2.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(14)
                }
                .disabled(speechManager.translatedText.isEmpty)

            }

            Spacer()

            // Push-To-Talk Button
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
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        speechManager.isRecording ? Color.red : Color.green
                    )
                    .cornerRadius(16)
            }
        }
        .padding()
    }
}
*/
