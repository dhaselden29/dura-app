#if os(macOS)
import SwiftUI

struct ReaderSettingsView: View {
    @AppStorage("readerFontSize") private var fontSize: Double = ReaderDefaults.fontSize
    @AppStorage("readerLineSpacing") private var lineSpacing: Double = ReaderDefaults.lineSpacing
    @AppStorage("readerMaxWidth") private var maxWidth: Double = ReaderDefaults.maxWidth
    @AppStorage("readerTheme") private var themeRaw: String = ReaderDefaults.theme
    @AppStorage("readerFont") private var fontFamilyRaw: String = ReaderDefaults.font

    private var theme: ReaderTheme {
        ReaderTheme(rawValue: themeRaw) ?? .light
    }

    private var fontFamily: ReaderFont {
        ReaderFont(rawValue: fontFamilyRaw) ?? .system
    }

    var body: some View {
        Form {
            // Font size
            LabeledContent("Font Size") {
                HStack {
                    Slider(value: $fontSize, in: 12...28, step: 1)
                        .frame(width: 200)
                    Text("\(Int(fontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 45, alignment: .trailing)
                }
            }

            // Line spacing
            LabeledContent("Line Spacing") {
                HStack {
                    Slider(value: $lineSpacing, in: 0...12, step: 2)
                        .frame(width: 200)
                    Text("\(Int(lineSpacing)) pt")
                        .monospacedDigit()
                        .frame(width: 45, alignment: .trailing)
                }
            }

            // Max width
            LabeledContent("Reading Width") {
                HStack {
                    Slider(value: $maxWidth, in: 500...1200, step: 50)
                        .frame(width: 200)
                    Text("\(Int(maxWidth)) px")
                        .monospacedDigit()
                        .frame(width: 55, alignment: .trailing)
                }
            }

            // Theme
            Picker("Default Theme", selection: $themeRaw) {
                ForEach(ReaderTheme.allCases, id: \.rawValue) { t in
                    Label(t.displayName, systemImage: t.iconName)
                        .tag(t.rawValue)
                }
            }

            // Font
            Picker("Default Font", selection: $fontFamilyRaw) {
                ForEach(ReaderFont.allCases, id: \.rawValue) { f in
                    Text(f.displayName).tag(f.rawValue)
                }
            }

            Divider()

            // Preview
            LabeledContent("Preview") {
                Text("The quick brown fox jumps over the lazy dog. 0123456789")
                    .font(.system(size: fontSize))
                    .lineSpacing(lineSpacing)
                    .padding(8)
                    .frame(maxWidth: 300, alignment: .leading)
                    .background(theme.swiftUIBackground)
                    .foregroundStyle(theme.swiftUITextColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Divider()

            Button("Reset to Defaults") {
                fontSize = ReaderDefaults.fontSize
                lineSpacing = ReaderDefaults.lineSpacing
                maxWidth = ReaderDefaults.maxWidth
                themeRaw = ReaderDefaults.theme
                fontFamilyRaw = ReaderDefaults.font
            }
        }
        .padding()
    }
}
#endif
