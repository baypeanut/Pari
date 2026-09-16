import SwiftUI

/// The journal's visual vocabulary: ink, rules and useful annotations.
struct PariRule: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Rectangle().fill(PariTheme.divider(for: scheme)).frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct PariEyebrow: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(.caption2, weight: .medium)).tracking(1.6)
            .foregroundStyle(PariTheme.textSecondary(for: scheme))
    }
}

struct PariSectionTab: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title).font(.system(.subheadline, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? PariTheme.accent(for: scheme) : PariTheme.textSecondary(for: scheme))
                    .frame(maxWidth: .infinity, minHeight: 46)
                Rectangle().fill(selected ? PariTheme.accent(for: scheme) : Color.clear).frame(height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// At accessibility sizes the words keep their shape; extra tabs remain reachable.
struct PariTabStrip<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        if typeSize.isAccessibilitySize {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .bottom, spacing: 24) { content }
                    .fixedSize(horizontal: true, vertical: false)
            }
        } else {
            HStack(alignment: .bottom, spacing: 16) { content }
        }
    }
}

struct PariScore: View {
    @Environment(\.colorScheme) private var scheme
    let value: Double
    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value.formatted(.number.precision(.fractionLength(0...1))))
                .font(PariTheme.editorialFont(size: 28))
                .foregroundStyle(PariTheme.accent(for: scheme))
            Text("/ 10").font(.system(.caption2, design: .monospaced))
                .foregroundStyle(PariTheme.textSecondary(for: scheme))
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rated \(value.formatted()) out of 10")
    }
}

struct PariRatingEvidence: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let rating: Double?
    let count: Int
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
            Spacer(minLength: 8)
            if let rating, count > 0 {
                Text(rating.formatted(.number.precision(.fractionLength(1))))
                    .foregroundStyle(PariTheme.textPrimary(for: scheme))
                Text("· \(count) \(count == 1 ? "tasting" : "tastings")")
            } else { Text("No ratings yet") }
        }
        .font(.subheadline)
        .foregroundStyle(PariTheme.textSecondary(for: scheme))
    }
}

struct PariEmptyNote: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PariRule()
            Text(title).font(PariTheme.editorialFont(size: 27))
                .foregroundStyle(PariTheme.textPrimary(for: scheme))
            Text(message).font(.subheadline).lineSpacing(4)
                .foregroundStyle(PariTheme.textSecondary(for: scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }
}
