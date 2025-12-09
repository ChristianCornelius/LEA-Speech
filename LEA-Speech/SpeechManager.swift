//
//  AzureSpeechManager.swift
//  LEA-Speech
//

import Foundation
import MicrosoftCognitiveServicesSpeech
import AVFoundation
import Combine

@MainActor
final class AzureSpeechManager: ObservableObject {

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
    private let silenceTimeout: TimeInterval = 3.0

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
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
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
}


/*
//
//  AzureSpeechManager.swift
//  LEA-Speech
//
//  Created by Christian Cornelius on 22.01.26.
//

import Foundation
import MicrosoftCognitiveServicesSpeech
import AVFoundation
import Combine

@MainActor
final class AzureSpeechManager: ObservableObject {

    // MARK: - UI State

    @Published var sourceText = ""
    @Published var translatedText = ""
    @Published var isRecording = false

    // MARK: - Azure Config

    private let speechKey = "EkLKrM2xPmlotL6xLfO8JpZBNCySmxigQjsy8mRMGyf5YKDhWq0MJQQJ99CAACPV0roXJ3w3AAAYACOGtFaZ"
    private let region = "germanywestcentral"

    // MARK: - Internal State

    private var recognizer: SPXTranslationRecognizer?
    private let speechSynthesizer = AVSpeechSynthesizer()

    private var sourceBuffer = ""
    private var translationBuffer = ""

    // Silence handling
    private var silenceTimer: DispatchWorkItem?
    private let silenceTimeout: TimeInterval = 6.0

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

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
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

            print("⏱️ Stille erkannt → Stop")
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

        do {
            try recognizer?.stopContinuousRecognition()
        } catch {
            print("❌ Stop Fehler:", error.localizedDescription)
        }

        recognizer = nil

        sourceText = sourceBuffer
        translatedText = translationBuffer
        isRecording = false

        if speakTranslation, let lang = targetLanguage {
            speakTranslatedText(language: lang)
        }
    }

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
}
*/
