import SwiftUI
import UIKit

struct PreferredKeyboardTextView: UIViewRepresentable {
    @Binding var text: String
    let preferredLanguages: [String]
    var autoFocus: Bool = true
    var usesSystemKeyboard: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> KeyboardAwareTextView {
        let textView = KeyboardAwareTextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.spellCheckingType = .no
        textView.preferredLanguages = preferredLanguages
        textView.usesSystemKeyboard = usesSystemKeyboard
        textView.text = text

        if autoFocus {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
            }
        }

        return textView
    }

    func updateUIView(_ uiView: KeyboardAwareTextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        let normalizedCurrent = uiView.preferredLanguages.map { $0.lowercased() }
        let normalizedNew = preferredLanguages.map { $0.lowercased() }
        if normalizedCurrent != normalizedNew {
            uiView.preferredLanguages = preferredLanguages
            if uiView.isFirstResponder && uiView.usesSystemKeyboard {
                uiView.reloadInputViews()
            }
        }
        if uiView.usesSystemKeyboard != usesSystemKeyboard {
            uiView.usesSystemKeyboard = usesSystemKeyboard
            if uiView.isFirstResponder {
                uiView.reloadInputViews()
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }
    }
}

final class KeyboardAwareTextView: UITextView {
    var preferredLanguages: [String] = []
    var usesSystemKeyboard: Bool = true

    // A stable context identifier lets iOS evaluate input mode selection for this editor.
    override var textInputContextIdentifier: String? { "lea-speech-sheet-editor" }

    override var textInputMode: UITextInputMode? {
        if !usesSystemKeyboard {
            return super.textInputMode
        }

        let preferred = preferredLanguages
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }

        for code in preferred {
            if let mode = UITextInputMode.activeInputModes.first(where: {
                ($0.primaryLanguage ?? "").lowercased().hasPrefix(code)
            }) {
                return mode
            }
        }

        return super.textInputMode
    }

    override var inputView: UIView? {
        get {
            usesSystemKeyboard ? super.inputView : UIView(frame: .zero)
        }
        set {
            super.inputView = newValue
        }
    }
}
