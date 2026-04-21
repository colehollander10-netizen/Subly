import SwiftUI

// MARK: - Liquid glass background

/// Animated mesh-gradient background. Shifts slowly so it feels alive
/// without demanding attention. Used behind onboarding and the Home tab.
struct LiquidGlassBackground: View {
    @State private var t: CGFloat = 0

    var body: some View {
        ZStack {
            // Base gradient.
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.18),
                    Color(red: 0.10, green: 0.04, blue: 0.22),
                    Color(red: 0.02, green: 0.08, blue: 0.28),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft animated blobs.
            Circle()
                .fill(Color(red: 0.35, green: 0.15, blue: 0.90).opacity(0.55))
                .frame(width: 420, height: 420)
                .offset(x: -160 + cos(t) * 40, y: -260 + sin(t) * 60)
                .blur(radius: 90)

            Circle()
                .fill(Color(red: 0.15, green: 0.55, blue: 0.95).opacity(0.40))
                .frame(width: 380, height: 380)
                .offset(x: 180 + sin(t * 0.7) * 50, y: 320 + cos(t * 0.7) * 50)
                .blur(radius: 90)

            Circle()
                .fill(Color(red: 0.95, green: 0.35, blue: 0.55).opacity(0.25))
                .frame(width: 320, height: 320)
                .offset(x: 140 + cos(t * 1.1) * 30, y: -180 + sin(t * 1.1) * 40)
                .blur(radius: 100)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                t = .pi * 2
            }
        }
    }
}

// MARK: - Glass card

/// Frosted-glass rounded card. Works on top of `LiquidGlassBackground`
/// or any dark surface.
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 24

    init(padding: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
            .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 8)
    }
}

// MARK: - Glass button

struct GlassButton: View {
    let title: String
    let systemImage: String?
    let isBusy: Bool
    let action: () -> Void

    init(title: String, systemImage: String? = nil, isBusy: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isBusy = isBusy
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isBusy {
                    ProgressView()
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.35), lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        }
        .disabled(isBusy)
    }
}
