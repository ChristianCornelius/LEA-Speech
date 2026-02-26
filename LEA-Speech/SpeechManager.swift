//
//  AzureSpeechManager.swift
//  LEA-Speech
//

import Foundation
import MicrosoftCognitiveServicesSpeech
import AVFoundation
import Combine

private enum AppSecrets {
    static var speechKey: String {
        Bundle.main.object(forInfoDictionaryKey: "AZURE_SPEECH_KEY") as? String ?? ""
    }

    static var translateKey: String {
        Bundle.main.object(forInfoDictionaryKey: "AZURE_TRANSLATE_KEY") as? String ?? ""
    }

    static var region: String {
        Bundle.main.object(forInfoDictionaryKey: "AZURE_REGION") as? String ?? ""
    }
}

@MainActor
final class AzureSpeechManager: NSObject, ObservableObject {

    override init() {
        super.init()
    }

    // MARK: - FINAL UI OUTPUT

    @Published var sourceText = ""
    @Published var translatedText = ""

    // MARK: - LIVE PREVIEW

    @Published var liveSourceText = ""
    @Published var liveTranslatedText = ""

    @Published var isRecording = false

    // MARK: - Azure Config

    private let speechKey = AppSecrets.speechKey
    private let translateKey = AppSecrets.translateKey
    private let region = AppSecrets.region

    private let ttsQueue = DispatchQueue(label: "azure.tts.queue", qos: .userInitiated)

    // MARK: - TTS Tuning
    // Negative = langsamer, positive = schneller
    private let ttsRatePercent = -15

    // MARK: - Internal State

    private var recognizer: SPXTranslationRecognizer?
    private var sourceBuffer = ""
    private var translationBuffer = ""

    private var silenceTimer: DispatchWorkItem?
    private let silenceTimeout: TimeInterval = 5.0

    // MARK: - STT/SST Language Mapping

    private func mappedSourceLanguageForSST(sourceLang: String, targetLang: String) -> String {
        let src = sourceLang.lowercased()
        let tgt = targetLang.lowercased()

        let isDari =
            src.hasPrefix("prs") ||
            src == "fa-af" ||
            src.hasPrefix("fa-af-")

        let isGerman =
            tgt == "de" ||
            tgt == "de-de" ||
            tgt.hasPrefix("de-")

        // Dari -> Deutsch: für SST stattdessen Farsi
        if isDari && isGerman {
            return "fa-IR"
        }

        return sourceLang
    }

    // MARK: - Start Translation

    func startTranslation(
        from sourceLang: String,
        to targetLang: String
    ) async {
        silenceTimer?.cancel()
        sourceBuffer = ""
        translationBuffer = ""

        sourceText = ""
        translatedText = ""
        liveSourceText = ""
        liveTranslatedText = ""

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)

            let config = try SPXSpeechTranslationConfiguration(
                subscription: speechKey,
                region: region
            )

            let effectiveSourceLang = mappedSourceLanguageForSST(
                sourceLang: sourceLang,
                targetLang: targetLang
            )
            config.speechRecognitionLanguage = effectiveSourceLang
            config.addTargetLanguage(targetLang)

            if effectiveSourceLang != sourceLang {
                print("ℹ️ SST Mapping aktiv: \(sourceLang) -> \(effectiveSourceLang), target=\(targetLang)")
            }

            let audioConfig = SPXAudioConfiguration()
            recognizer = try SPXTranslationRecognizer(
                speechTranslationConfiguration: config,
                audioConfiguration: audioConfig
            )

            recognizer?.addRecognizingEventHandler { [weak self] _, event in
                guard let self else { return }
                Task { @MainActor in
                    self.resetSilenceTimer()
                    self.liveSourceText = event.result.text ?? ""
                    self.liveTranslatedText = event.result.translations[targetLang] as? String ?? ""
                    print("📝 Live erkannt: '\(self.liveSourceText)'")
                }
            }

            recognizer?.addRecognizedEventHandler { [weak self] _, event in
                guard let self else { return }

                guard event.result.reason == .translatedSpeech || event.result.reason == .recognizedSpeech else { return }

                let original = event.result.text ?? ""
                let translated = event.result.translations[targetLang] as? String ?? ""
                guard !original.isEmpty else { return }

                Task { @MainActor in
                    self.resetSilenceTimer()

                    self.sourceBuffer += (self.sourceBuffer.isEmpty ? "" : " ") + original
                    self.translationBuffer += (self.translationBuffer.isEmpty ? "" : " ") + translated

                    self.liveSourceText = ""
                    self.liveTranslatedText = ""

                    self.sourceText = self.sourceBuffer
                    self.translatedText = self.translationBuffer

                    print("✅ Final erkannt: '\(original)' → '\(translated)'")
                    print("💾 sourceText gesetzt: '\(self.sourceText)'")
                    print("💾 translatedText gesetzt: '\(self.translatedText)'")
                }
            }

            recognizer?.addCanceledEventHandler { _, event in
                print("❌ Azure abgebrochen:", event.errorDetails ?? "Unbekannt")
            }

            try recognizer?.startContinuousRecognition()
            isRecording = true
            resetSilenceTimer()
        } catch {
            print("❌ Speech Fehler:", error.localizedDescription)
        }
    }

    // MARK: - Text translation (fallback when STT is unavailable)

    private struct TranslatorRequestBody: Encodable {
        let text: String

        enum CodingKeys: String, CodingKey {
            case text = "Text"
        }
    }

    private struct TranslatorResponseItem: Decodable {
        let translations: [TranslatorTranslation]
    }

    private struct TranslatorTranslation: Decodable {
        let text: String
        let to: String
    }

    private func mappedLanguageForTextTranslation(_ language: String) -> String {
        let normalized = language.lowercased()

        if normalized.hasPrefix("kmr") {
            return "kmr"
        }
        if normalized == "ku-tr" || normalized.hasPrefix("ku-tr-") {
            return "ckb"
        }
        if normalized.hasPrefix("ti-et") || normalized == "ti" {
            return "ti"
        }
        if normalized.hasPrefix("prs") || normalized == "fa-af" || normalized.hasPrefix("fa-af-") {
            return "fa"
        }

        if let base = normalized.split(separator: "-").first, !base.isEmpty {
            return String(base)
        }

        return normalized
    }

    private func performTextTranslationRequest(
        text: String,
        from mappedSource: String?,
        to mappedTarget: String
    ) async throws -> (translated: String, statusCode: Int?) {
        guard var components = URLComponents(string: "https://api.cognitive.microsofttranslator.com/translate") else {
            return ("", nil)
        }

        var queryItems = [URLQueryItem(name: "api-version", value: "3.0")]
        if let mappedSource, !mappedSource.isEmpty {
            queryItems.append(URLQueryItem(name: "from", value: mappedSource))
        }
        queryItems.append(URLQueryItem(name: "to", value: mappedTarget))
        components.queryItems = queryItems

        guard let url = components.url else { return ("", nil) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(translateKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue(region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-ClientTraceId")
        request.httpBody = try JSONEncoder().encode([TranslatorRequestBody(text: text)])

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode

        if let statusCode, !(200...299).contains(statusCode) {
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print("❌ Textübersetzung fehlgeschlagen. status=\(statusCode), body=\(responseText)")
            return ("", statusCode)
        }

        let decoded = try JSONDecoder().decode([TranslatorResponseItem].self, from: data)
        let translated = decoded.first?.translations.first?.text ?? ""
        return (translated, statusCode)
    }

    func translateTypedText(
        _ text: String,
        from sourceLang: String,
        to targetLang: String
    ) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let mappedSource = mappedLanguageForTextTranslation(sourceLang)
        let mappedTarget = mappedLanguageForTextTranslation(targetLang)

        do {
            var translated = try await performTextTranslationRequest(
                text: trimmed,
                from: mappedSource,
                to: mappedTarget
            ).translated

            if translated.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
                trimmed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                let fallback = try await performTextTranslationRequest(
                    text: trimmed,
                    from: nil,
                    to: mappedTarget
                )
                if !fallback.translated.isEmpty {
                    translated = fallback.translated
                    print("ℹ️ Textübersetzung Fallback genutzt (auto-detect statt from=\(mappedSource))")
                }
            }

            guard !translated.isEmpty else {
                print("❌ Textübersetzung ohne Ergebnis")
                return false
            }

            sourceBuffer = trimmed
            translationBuffer = translated

            sourceText = sourceBuffer
            translatedText = translationBuffer
            liveSourceText = ""
            liveTranslatedText = ""

            print("✅ Texteingabe übersetzt: '\(sourceText)' → '\(translatedText)'")
            return true
        } catch {
            print("❌ Textübersetzung Fehler:", error.localizedDescription)
            return false
        }
    }

    // MARK: - Silence Timer

    private func resetSilenceTimer() {
        silenceTimer?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isRecording else { return }
            print("⏱️ Stille → automatischer Stop")
            Task { await self.stopTranslation() }
        }

        silenceTimer = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + silenceTimeout,
            execute: workItem
        )
    }

    // MARK: - Stop Translation

    func stopTranslation(
        speakTranslation: Bool = false,
        targetLanguage: String? = nil
    ) async {
        silenceTimer?.cancel()
        silenceTimer = nil

        do {
            try recognizer?.stopContinuousRecognition()
        } catch {
            print("❌ Stop Fehler:", error.localizedDescription)
        }

        recognizer = nil

        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: [.notifyOthersOnDeactivation]
            )
        } catch {
            print("❌ AudioSession deactivate Fehler:", error.localizedDescription)
        }

        liveSourceText = ""
        liveTranslatedText = ""
        isRecording = false

        print("🛑 Stop Translation - sourceText: '\(sourceText)', translatedText: '\(translatedText)'")

        if speakTranslation, let lang = targetLanguage {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.speak(text: self.translatedText, language: lang)
            }
        }
    }

    // MARK: - Kurdish Transliteration (Arabic script -> Latin/Hawar)

    private func transliterateKuTRToLatin(_ text: String) -> String {
        let map: [Character: String] = [
            "ا": "a", "ە": "e", "ێ": "ê", "و": "u", "ۆ": "o", "ی": "î",
            "ب": "b", "پ": "p", "ت": "t", "ج": "c", "چ": "ç", "ح": "h",
            "خ": "x", "د": "d", "ر": "r", "ڕ": "rr", "ز": "z", "ژ": "j",
            "س": "s", "ش": "ş", "ع": "'", "غ": "x", "ف": "f", "ڤ": "v",
            "ق": "q", "ک": "k", "گ": "g", "ل": "l", "ڵ": "l", "م": "m",
            "ن": "n", "ه": "h", "ھ": "h", "ء": "'", "ئ": "", "ى": "î",
            "ؤ": "u", "إ": "i", "أ": "e", "ة": "e"
        ]

        var out = ""
        out.reserveCapacity(text.count)

        for ch in text {
            if let repl = map[ch] {
                out += repl
            } else {
                out.append(ch)
            }
        }

        return out
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Text To Speech

    func speakTranslatedText(language: String) {
        guard !translatedText.isEmpty else { return }
        speak(text: translatedText, language: language)
    }

    private func mappedTTSLanguageAndVoice(for language: String) -> (language: String, voiceName: String) {
        let normalized = language.lowercased()

        // Ausnahmen beibehalten
        if normalized.hasPrefix("prs") || normalized == "fa-af" || normalized.hasPrefix("fa-af-") {
            return ("fa-IR", "fa-IR-DilaraNeural")
        }
        if normalized.hasPrefix("ti") || normalized == "tir" || normalized == "ti-et" || normalized.hasPrefix("ti-et-") {
            return ("am-ET", "am-ET-MekdesNeural")
        }
        if normalized == "pa" || normalized == "pa-in" || normalized.hasPrefix("pa-in-") {
            return ("pa-IN", "pa-IN-VaaniNeural")
        }
        if normalized == "ku-tr" || normalized.hasPrefix("ku-tr-") || normalized == "ku" {
            return ("tr-TR", "tr-TR-EmelNeural")
        }
        if normalized == "kmr-tr" || normalized.hasPrefix("kmr-tr-") || normalized == "kmr" {
            return ("tr-TR", "tr-TR-EmelNeural")
        }

        // Standard: Voice aus Language-Enum
        if let enumLang = Language.allCases.first(where: { $0.rawValue.lowercased() == normalized }) {
            return (enumLang.rawValue, enumLang.ttsVoiceName)
        }

        // Stabiler Fallback
        return (Language.english.rawValue, Language.english.ttsVoiceName)
    }

    private func xmlEscaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    // MARK: - Speak arbitrary text (Azure TTS)

    func speak(text: String, language: String) {
        guard !text.isEmpty else { return }

        let normalized = language.lowercased()
        let ttsText: String
        if normalized == "ku-tr" || normalized.hasPrefix("ku-tr-") {
            ttsText = transliterateKuTRToLatin(text)
        } else {
            ttsText = text
        }

        let key = speechKey
        let region = region
        let mapped = mappedTTSLanguageAndVoice(for: language)
        let escaped = xmlEscaped(ttsText)
        let rate = "\(ttsRatePercent)%"

        let ssml = """
        <speak version='1.0' xml:lang='\(mapped.language)'>
          <voice name='\(mapped.voiceName)'>
            <prosody rate='\(rate)'>\(escaped)</prosody>
          </voice>
        </speak>
        """

        ttsQueue.async {
            do {
                let speechConfig = try SPXSpeechConfiguration(
                    subscription: key,
                    region: region
                )
                speechConfig.speechSynthesisLanguage = mapped.language
                speechConfig.speechSynthesisVoiceName = mapped.voiceName

                let audioConfig = SPXAudioConfiguration()
                let synthesizer = try SPXSpeechSynthesizer(
                    speechConfiguration: speechConfig,
                    audioConfiguration: audioConfig
                )

                let result = try synthesizer.speakSsml(ssml)

                if result.reason != SPXResultReason.synthesizingAudioCompleted {
                    let cancelReason = result.properties?.getPropertyByName("CancellationDetails_Reason") ?? ""
                    let cancelText = result.properties?.getPropertyByName("CancellationDetails_ReasonText") ?? ""
                    let cancelDetails = result.properties?.getPropertyByName("CancellationDetails_ReasonDetailedText") ?? ""
                    let serviceJson = result.properties?.getPropertyByName("SpeechServiceResponse_JsonResult") ?? ""

                    print("❌ Azure TTS fehlgeschlagen. reason=\(result.reason.rawValue), language=\(mapped.language), voice=\(mapped.voiceName), cancelReason=\(cancelReason), cancelText=\(cancelText), details=\(cancelDetails), json=\(serviceJson)")
                } else {
                    print("🔊 Azure TTS erfolgreich")
                }
            } catch {
                print("❌ Azure TTS Fehler:", error.localizedDescription)
            }
        }
    }
}

