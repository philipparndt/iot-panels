import SwiftUI

extension View {
    /// Applies `.navigationBarTitleDisplayMode(.inline)` on iOS, no-op on macOS
    /// (which doesn't have the modifier).
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }


    /// Gives macOS sheets a sensible fixed size so Form/List content scrolls
    /// instead of expanding the sheet infinitely. No-op on iOS.
    func macSheet(width: CGFloat = 560, height: CGFloat = 500) -> some View {
        #if os(macOS)
        self.frame(width: width, height: height)
        #else
        self
        #endif
    }
}

#if os(macOS)

// MARK: - iOS-only text input shims
//
// On macOS the iOS text input modifiers don't exist. We declare lookalike
// shim types so that call sites like `.keyboardType(.decimalPad)` and
// `.textInputAutocapitalization(.never)` resolve against these on macOS
// without having to wrap every field in an `#if`.

struct UIKeyboardType {
    static let `default` = UIKeyboardType()
    static let asciiCapable = UIKeyboardType()
    static let numbersAndPunctuation = UIKeyboardType()
    static let URL = UIKeyboardType()
    static let numberPad = UIKeyboardType()
    static let phonePad = UIKeyboardType()
    static let namePhonePad = UIKeyboardType()
    static let emailAddress = UIKeyboardType()
    static let decimalPad = UIKeyboardType()
    static let twitter = UIKeyboardType()
    static let webSearch = UIKeyboardType()
    static let asciiCapableNumberPad = UIKeyboardType()
}

struct TextInputAutocapitalization {
    static let never = TextInputAutocapitalization()
    static let words = TextInputAutocapitalization()
    static let sentences = TextInputAutocapitalization()
    static let characters = TextInputAutocapitalization()
}

extension View {
    func keyboardType(_ type: UIKeyboardType) -> some View { self }

    func textInputAutocapitalization(_ autocapitalization: TextInputAutocapitalization?) -> some View { self }
}

#endif
