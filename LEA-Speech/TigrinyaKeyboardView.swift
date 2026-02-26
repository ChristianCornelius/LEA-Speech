import SwiftUI

struct TigrinyaKeyboardView: View {
    @Binding var text: String

    private let rows: [[String]] = [
        ["ሀ", "ለ", "መ", "ረ", "ሰ", "ሸ", "ቀ", "በ", "ቨ", "ተ"],
        ["ኀ", "ነ", "ኘ", "አ", "ከ", "ኸ", "ወ", "ዐ", "ዘ", "ዠ"],
        ["የ", "ደ", "ጀ", "ገ", "ጠ", "ጨ", "ጰ", "ጸ", "ፀ", "ፈ"]
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    ForEach(rows[rowIndex], id: \.self) { key in
                        keyButton(title: key) {
                            text.append(key)
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                keyButton(title: "።") { text.append("።") }
                keyButton(title: "፣") { text.append("፣") }
                keyButton(title: "␣", minWidth: 120) { text.append(" ") }
                keyButton(title: "↵") { text.append("\n") }
                keyButton(title: "⌫") {
                    guard !text.isEmpty else { return }
                    text.removeLast()
                }
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func keyButton(title: String, minWidth: CGFloat = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3)
                .frame(minWidth: minWidth, maxWidth: .infinity, minHeight: 42)
                .background(Color.white)
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
