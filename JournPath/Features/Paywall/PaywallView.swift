import Lottie
import SwiftUI

struct PaywallView: View {

    @Environment(TripStore.self) private var trip
    @Environment(\.dismiss) private var dismiss

    @State private var vm = PaywallVM()

    var body: some View {
        Group {
            if vm.cantLoadProducts {
                loadFailedView
            } else {
                mainContentView
            }
        }
        .interactiveDismissDisabled(vm.isDismissDisabled)
        .task(id: trip.tripId) {
            await vm.onAppear(tripID: trip.tripId)
        }
    }

    private var mainContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            headline
            Spacer(minLength: 24)
            LottieView(animation: .named("PaywallLottie"))
                .playing(loopMode: .autoReverse)
            statusLine
            priceLine
            purchaseButton
            legalRow
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }

    private var loadFailedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Couldn't load products")
                    .font(.title2.weight(.bold))

                Text("Check your connection and try again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await vm.retryLoadProducts() }
            } label: {
                Text("Retry")
                    .font(.headline)
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary, in: .rect(cornerRadius: 32))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.top, 10)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Unlock\n\(trip.name)")
                .font(.system(size: 38, weight: .bold))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("Live flight alerts, groups of up to 20 people, and space for every booking and boarding pass.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    @ViewBuilder
    private var statusLine: some View {
        switch vm.state {
        case .awaitingApproval:
            NoticeText(
                "Waiting for approval. The trip unlocks as soon as it's approved.",
                tone: .secondary
            )
            .padding(.top, 16)
        case .failed(let message, let paymentTaken):
            // A charged-but-unfinished purchase is not an error to the
            // customer, so it doesn't get error styling — red here makes
            // people think it failed and buy a second time.
            NoticeText(message, tone: paymentTaken ? .secondary : .red)
                .padding(.top, 16)
        default:
            EmptyView()
        }
    }

    private var priceLine: some View {
        HStack(spacing: 6) {
            // The placeholder only shows for the instant before products
            // land; the button stays disabled until the real price arrives.
            Text(vm.tripUnlockPrice ?? "loading...")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .redacted(reason: vm.isPriceLoading ? .placeholder : [])
            Text("once, for the whole group")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var purchaseButton: some View {
        AsyncIconTextButton(
            title: vm.buttonTitle,
            isDisabled: vm.isPurchaseDisabled,
            textColor: Color(.systemBackground),
            buttonColor: Color.primary,
            successColor: Color.primary,
            action: {
                try await vm.purchaseTripUnlock()
            },
            closingAction: {
                dismiss()
            }
        )
        .padding(.top, 16)
    }

    private var legalRow: some View {
        HStack(spacing: 10) {
            Button("Restore") {
                Task { await vm.restore() }
            }
            Text("•")
            Link("Terms", destination: vm.termsURL)
            Text("•")
            Link("Privacy", destination: vm.privacyURL)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .disabled(vm.isDismissDisabled)
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
}

// MARK: - Pieces

private struct NoticeText: View {
    let text: String
    let tone: Color

    init(_ text: String, tone: Color) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(tone)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }
}
