import SwiftUI
import UIKit

final class RichUITextView: UITextView {
    var onHighlight: (() -> Void)?
    var onTextColor: ((UIColor?) -> Void)?
    var onClearFormatting: (() -> Void)?

    override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        let highlight = UIAction(title: "Highlight", image: UIImage(systemName: "highlighter")) { [weak self] _ in
            self?.onHighlight?()
        }
        let colorMenu = UIMenu(title: "Text Color", image: UIImage(systemName: "paintpalette"), children: [
            UIAction(title: "Red") { [weak self] _ in self?.onTextColor?(.systemRed) },
            UIAction(title: "Orange") { [weak self] _ in self?.onTextColor?(.systemOrange) },
            UIAction(title: "Green") { [weak self] _ in self?.onTextColor?(.systemGreen) },
            UIAction(title: "Blue") { [weak self] _ in self?.onTextColor?(.systemBlue) },
            UIAction(title: "Default") { [weak self] _ in self?.onTextColor?(nil) },
        ])
        let clear = UIAction(title: "Clear Formatting", image: UIImage(systemName: "xmark.circle")) { [weak self] _ in
            self?.onClearFormatting?()
        }
        let customGroup = UIMenu(title: "", options: .displayInline, children: [highlight, colorMenu, clear])
        return UIMenu(children: suggestedActions + [customGroup])
    }
}

struct RichTextView: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var isEditable: Bool = true

    func makeUIView(context: Context) -> RichUITextView {
        let textView = RichUITextView()
        textView.delegate = context.coordinator
        textView.allowsEditingTextAttributes = true
        textView.isScrollEnabled = false
        textView.isEditable = isEditable
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.attributedText = attributedText
        textView.onHighlight = { context.coordinator.applyHighlight(to: textView) }
        textView.onTextColor = { color in context.coordinator.applyTextColor(color, to: textView) }
        textView.onClearFormatting = { context.coordinator.clearFormatting(on: textView) }
        return textView
    }

    func updateUIView(_ uiView: RichUITextView, context: Context) {
        if uiView.attributedText != attributedText {
            let selectedRange = uiView.selectedRange
            uiView.attributedText = attributedText
            uiView.selectedRange = selectedRange
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: RichUITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(size.height, 22))
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextView
        init(_ parent: RichTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = textView.attributedText
        }

        func applyHighlight(to textView: UITextView) {
            let range = textView.selectedRange
            guard range.length > 0 else { return }
            let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
            let hasHighlight = mutable.attribute(.backgroundColor, at: range.location, effectiveRange: nil) != nil
            if hasHighlight {
                mutable.removeAttribute(.backgroundColor, range: range)
            } else {
                mutable.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.4), range: range)
            }
            commit(mutable, to: textView, preservingSelection: range)
        }

        func applyTextColor(_ color: UIColor?, to textView: UITextView) {
            let range = textView.selectedRange
            guard range.length > 0 else { return }
            let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
            if let color {
                mutable.addAttribute(.foregroundColor, value: color, range: range)
            } else {
                mutable.removeAttribute(.foregroundColor, range: range)
            }
            commit(mutable, to: textView, preservingSelection: range)
        }

        func clearFormatting(on textView: UITextView) {
            let range = textView.selectedRange
            guard range.length > 0 else { return }
            let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
            let plain = mutable.attributedSubstring(from: range).string
            mutable.replaceCharacters(
                in: range,
                with: NSAttributedString(string: plain, attributes: [.font: UIFont.preferredFont(forTextStyle: .body)])
            )
            commit(mutable, to: textView, preservingSelection: NSRange(location: range.location, length: plain.count))
        }

        private func commit(_ mutable: NSAttributedString, to textView: UITextView, preservingSelection range: NSRange) {
            textView.attributedText = mutable
            textView.selectedRange = range
            parent.attributedText = mutable
        }
    }
}
