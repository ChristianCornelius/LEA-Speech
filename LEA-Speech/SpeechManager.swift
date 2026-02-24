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
        //speechSynthesizer.delegate = self
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
    
    private let ttsQueue = DispatchQueue(label: "azure.tts.queue", qos: .userInitiated)
    
    // MARK: - Internal State
    
    private var recognizer: SPXTranslationRecognizer?
    //private let speechSynthesizer = AVSpeechSynthesizer()
    
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
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            
            // 🔥 MIKROFONEMPFINDLICHKEIT ERHÖHEN
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
            
            let config = try SPXSpeechTranslationConfiguration(
                subscription: speechKey,
                region: region
            )
            
            config.speechRecognitionLanguage = sourceLang
            config.addTargetLanguage(targetLang)
            
            let audioConfig = SPXAudioConfiguration()
            
            recognizer = try SPXTranslationRecognizer(
                speechTranslationConfiguration: config,
                audioConfiguration: audioConfig
            )
            
            // 🩶 LIVE TEXT (Zwischenergebnisse)
            recognizer?.addRecognizingEventHandler { [weak self] _, event in
                guard let self = self else { return }
                
                Task { @MainActor in
                    self.resetSilenceTimer()
                    self.liveSourceText = event.result.text ?? ""
                    self.liveTranslatedText = event.result.translations[targetLang] as? String ?? ""
                    
                    // 📊 DEBUG LOGGING
                    print("📝 Live erkannt: '\(self.liveSourceText)'")
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
                    
                    // 🔥 SOFORT in sourceText/translatedText schreiben
                    self.sourceText = self.sourceBuffer
                    self.translatedText = self.translationBuffer
                    
                    // 📊 DEBUG LOGGING
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
        
        // 🔥 NICHT zurücksetzen! sourceText und translatedText werden aus messages gelesen
        liveSourceText = ""
        liveTranslatedText = ""
        isRecording = false
        
        print("🛑 Stop Translation - sourceText: '\(sourceText)', translatedText: '\(translatedText)'")
        
        // 3️⃣ TTS erst NACH kompletter Freigabe
        if speakTranslation, let lang = targetLanguage {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.speak(text: self.translatedText, language: lang)
            }
        }
    }
    
    // MARK: - Text To Speech (über Azure)
    
    func speakTranslatedText(language: String) {
        guard !translatedText.isEmpty else { return }
        speak(text: translatedText, language: language)
    }
    private func mappedTTSLanguageAndVoice(for language: String) -> (language: String, voiceName: String?) {
        let normalized = language.lowercased()

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
            return ("fa-IR", "fa-IR-DilaraNeural")
        }

        return (language, nil)
    }

    // MARK: - Speak arbitrary text (Azure TTS)
    
    func speak(text: String, language: String) {
        guard !text.isEmpty else { return }
        
        let key = speechKey
        let region = region
        let mapped = mappedTTSLanguageAndVoice(for: language)
        
        ttsQueue.async {
            do {
                let speechConfig = try SPXSpeechConfiguration(
                    subscription: key,
                    region: region
                )
                speechConfig.speechSynthesisLanguage = mapped.language
                if let voiceName = mapped.voiceName {
                    speechConfig.speechSynthesisVoiceName = voiceName
                }
                
                let audioConfig = SPXAudioConfiguration()
                let synthesizer = try SPXSpeechSynthesizer(
                    speechConfiguration: speechConfig,
                    audioConfiguration: audioConfig
                )
                
                let result = try synthesizer.speakText(text)
                
                if result.reason != SPXResultReason.synthesizingAudioCompleted {
                    let cancelReason = result.properties?.getPropertyByName("CancellationDetails_Reason") ?? ""
                    let cancelText = result.properties?.getPropertyByName("CancellationDetails_ReasonText") ?? ""
                    let cancelDetails = result.properties?.getPropertyByName("CancellationDetails_ReasonDetailedText") ?? ""
                    let serviceJson = result.properties?.getPropertyByName("SpeechServiceResponse_JsonResult") ?? ""

                    print("❌ Azure TTS fehlgeschlagen. reason=\(result.reason.rawValue), language=\(mapped.language), voice=\(mapped.voiceName ?? "default"), cancelReason=\(cancelReason), cancelText=\(cancelText), details=\(cancelDetails), json=\(serviceJson)")
                } else {
                    print("🔊 Azure TTS erfolgreich")
                }
            } catch {
                print("❌ Azure TTS Fehler:", error.localizedDescription)
            }
        }
    }
}
   
