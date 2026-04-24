import PhosphorSwift
import SwiftUI

struct AddEntryRouterSheet: View {
    enum Choice {
        case trial
        case subscription
    }

    var onSelectTrial: () -> Void
    var onSelectSubscription: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingChoice: Choice?

    var body: some View {
        NavigationStack {
            ScreenFrame {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Add to Subly")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(SublyTheme.primaryText)

                    VStack(spacing: 12) {
                        Button {
                            pendingChoice = .trial
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Ph.clock.fill
                                    .color(SublyTheme.background)
                                    .frame(width: 20, height: 20)
                                Text("Add Trial")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButton())

                        Button {
                            pendingChoice = .subscription
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Ph.repeat.fill
                                    .color(SublyTheme.background)
                                    .frame(width: 20, height: 20)
                                Text("Add Subscription")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButton())
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
        .presentationBackground(SublyTheme.background)
        .onDisappear {
            guard let pendingChoice else { return }
            switch pendingChoice {
            case .trial:
                onSelectTrial()
            case .subscription:
                onSelectSubscription()
            }
        }
    }
}

