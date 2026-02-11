//
//  AzureSpeechManager.swift
//  LEA-Speech
//

import Foundation
import MicrosoftCognitiveServicesSpeech
import AVFoundation
import Combine

@MainActor
final class AzureSpeechManager: NSObject, ObservableObject {
    

        override init() {
            super.init()
            speechSynthesizer.delegate = self
        }
    
    // MARK: - FINAL UI OUTPUT

    @Published var sourceText = ""          // schwarz
    @Published var translatedText = ""      // schwarz

    // MARK: - LIVE PREVIEW (GRAU)

    @Published var liveSourceText = ""      // grau
    @Published var liveTranslatedText = ""  // grau

    @Published var isRecording = false

    // MARK: - Azure Config

    private let speechKey = "EkLKrM2xPmlotL6xLfO8JpZBNCySmxigQjsy8mRMGyf5YKDhWq0MJQQJ99CAACPV0roXJ3w3AAAYACOGtFaZ"
    private let region = "germanywestcentral"

    // MARK: - Internal State

    private var recognizer: SPXTranslationRecognizer?
    private let speechSynthesizer = AVSpeechSynthesizer()

    private var sourceBuffer = ""
    private var translationBuffer = ""

    // Silence timeout
    private var silenceTimer: DispatchWorkItem?
    private let silenceTimeout: TimeInterval = 5.0

    // MARK: - Start Translation

    func startTranslation(
        from sourceLang: String,
        to targetLang: String
    ) async {

        // Reset
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
                options: [.defaultToSpeaker, .allowBluetooth]
            )

            /*
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
             */
            try session.setActive(true)

            let config = try SPXSpeechTranslationConfiguration(
                subscription: speechKey,
                region: region
            )

            config.speechRecognitionLanguage = sourceLang
            config.addTargetLanguage(targetLang)

            let audioConfig = try SPXAudioConfiguration()

            recognizer = try SPXTranslationRecognizer(
                speechTranslationConfiguration: config,
                audioConfiguration: audioConfig
            )

            // 🩶 LIVE TEXT (Zwischenergebnisse)
            recognizer?.addRecognizingEventHandler { [weak self] _, event in
                guard let self = self else { return }

                Task { @MainActor in
                    self.resetSilenceTimer()   // 🔥 DAS IST DER FIX
                    self.liveSourceText = event.result.text ?? ""
                    self.liveTranslatedText =
                        event.result.translations[targetLang] as? String ?? ""
                }
            }

            // 🖤 FINAL SEGMENTS
            recognizer?.addRecognizedEventHandler { [weak self] _, event in
                guard let self = self else { return }

                guard
                    event.result.reason == .translatedSpeech ||
                    event.result.reason == .recognizedSpeech
                else { return }

                let original = event.result.text ?? ""
                let translated =
                    event.result.translations[targetLang] as? String ?? ""

                guard !original.isEmpty else { return }

                Task { @MainActor in
                    self.resetSilenceTimer()

                    self.sourceBuffer +=
                        (self.sourceBuffer.isEmpty ? "" : " ") + original

                    self.translationBuffer +=
                        (self.translationBuffer.isEmpty ? "" : " ") + translated

                    // Live-Text leeren, wenn Satz final ist
                    self.liveSourceText = ""
                    self.liveTranslatedText = ""
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

    // MARK: - Silence Timer

    private func resetSilenceTimer() {
        silenceTimer?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.isRecording else { return }

            print("⏱️ Stille → automatischer Stop")
            Task {
                await self.stopTranslation()
            }
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

        // 1️⃣ Azure hart stoppen
        do {
            try recognizer?.stopContinuousRecognition()
        } catch {
            print("❌ Stop Fehler:", error.localizedDescription)
        }

        recognizer = nil   // 🔥 EXTREM WICHTIG

        // 2️⃣ AudioSession KOMPLETT deaktivieren
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: [.notifyOthersOnDeactivation]
            )
        } catch {
            print("❌ AudioSession deactivate Fehler:", error.localizedDescription)
        }

        sourceText = sourceBuffer
        translatedText = translationBuffer
        liveSourceText = ""
        liveTranslatedText = ""
        isRecording = false

        // 3️⃣ TTS erst NACH kompletter Freigabe
        if speakTranslation, let lang = targetLanguage {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.speak(text: self.translatedText, language: lang)
            }
        }
    }

    /*
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

        sourceText = sourceBuffer
        translatedText = translationBuffer
        liveSourceText = ""
        liveTranslatedText = ""
        isRecording = false

        if speakTranslation, let lang = targetLanguage {
            speakTranslatedText(language: lang)
        }
    }
*/
    // MARK: - Text To Speech

    func speakTranslatedText(language: String) {
        guard !translatedText.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: translatedText)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.48
        utterance.volume = 1.0

        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }
    
    // MARK: - Speak arbitrary text (for chat bubbles)
/*
    func speak(text: String, language: String) {
        guard !text.isEmpty else { return }

        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers]
            )
            try session.setActive(true)
        } catch {
            print("❌ AudioSession (TTS) Fehler:", error.localizedDescription)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.48
        utterance.volume = 1.0

        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }
*/
    func speak(text: String, language: String) {
        guard !text.isEmpty else { return }

        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers]
            )
            try session.setActive(true)
        } catch {
            print("❌ TTS AudioSession Fehler:", error.localizedDescription)
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.48
        utterance.volume = 1.0

        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }


    
}

extension AzureSpeechManager: AVSpeechSynthesizerDelegate {

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("❌ AudioSession finalize Fehler:", error.localizedDescription)
        }
    }
}


