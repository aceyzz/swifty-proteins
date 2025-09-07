import SwiftUI

enum FeedbackStyle { case success, error }

struct FeedbackItem: Identifiable, Equatable {
	let id = UUID()
	let text: String
	let style: FeedbackStyle
}

@MainActor
final class FeedbackCenter: ObservableObject {
	@Published var item: FeedbackItem?
	func show(_ text: String, style: FeedbackStyle, duration: TimeInterval = 2.2) {
		let newItem = FeedbackItem(text: text, style: style)
		item = newItem
		Task {
			try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
			if item == newItem { withAnimation(.snappy) { item = nil } }
		}
	}
	func dismiss() { withAnimation(.snappy) { item = nil } }
}

struct FeedbackBanner: View {
	var item: FeedbackItem
	var body: some View {
		HStack(spacing: 10) {
			Image(systemName: icon)
				.imageScale(.large)
			Text(item.text)
				.font(.subheadline.weight(.semibold))
				.lineLimit(2)
				.multilineTextAlignment(.leading)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
		.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color("OnSectionColor").opacity(0.15)))
		.foregroundStyle(Color("OnBackgroundColor"))
		.shadow(color: Color("OnSectionColor").opacity(0.25), radius: 20, x: 0, y: 10)
		.padding(.horizontal, 16)
		.padding(.top, 64)
	}
	private var icon: String {
		switch item.style { case .success: "checkmark.circle.fill"; case .error: "xmark.octagon.fill" }
	}
	private var background: Color {
		switch item.style {
		case .success: .green
		case .error: .red
		}
	}
}

struct FeedbackPresenter: ViewModifier {
	@ObservedObject var center: FeedbackCenter
	func body(content: Content) -> some View {
		ZStack(alignment: .top) {
			content
			if let item = center.item {
				FeedbackBanner(item: item)
					.transition(.move(edge: .top).combined(with: .opacity))
					.onTapGesture { center.dismiss() }
					.zIndex(1)
					.ignoresSafeArea(edges: .top)
			}
		}
		.animation(.snappy, value: center.item)
	}
}

extension View {
	func feedbackOverlay(_ center: FeedbackCenter) -> some View {
		modifier(FeedbackPresenter(center: center))
	}
}
