import MapKit
import SwiftUI

struct PlaceInfoCard: View {
    let place: MKMapItem
    @State private var isAddressCopied: Bool = false
    @State private var showingBrowserAlert: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let addressText = place.address?.fullAddress ?? "Unknown Address"

            InfoRowView(
                icon: isAddressCopied ? "clipboard.fill" : "mappin.and.ellipse",
                text: isAddressCopied ? "Address Copied" : addressText,
                isLink: false,
                showDivider: (place.phoneNumber != nil || place.url != nil),
                iconColor: isAddressCopied ? .green : nil,
                textColor: isAddressCopied ? .green : nil,
                action: copyAddress
            )

            if let url = place.url {
                InfoRowView(
                    icon: "safari",
                    text: url.absoluteString,
                    isLink: true,
                    showDivider: (place.phoneNumber != nil),
                    action: { showingBrowserAlert = true }
                )
            }

            if let phoneNumber = place.phoneNumber {
                InfoRowView(
                    icon: "phone",
                    text: phoneNumber,
                    isLink: true,
                    showDivider: false,
                    action: {
                        let digits = phoneNumber.filter { $0.isNumber || $0 == "+" }
                        if let url = URL(string: "tel://\(digits)"), UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }
                )
            }
        }
        .padding(.vertical, 2)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .alert("Open in Browser?", isPresented: $showingBrowserAlert) {
            if let url = place.url {
                Button("Open in Browser", role: .confirm) {
                    UIApplication.shared.open(url)
                }
                Button("Cancel", role: .cancel) {}
            }
        } message: {
            if let url = place.url {
                Text(url.absoluteString)
            }
        }
    }

    func copyAddress() {
        UIPasteboard.general.string = place.address?.fullAddress ?? "Unknown Address"
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation { isAddressCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { isAddressCopied = false }
        }
    }
}

struct InfoRowView: View {
    let icon: String
    let text: String
    let isLink: Bool
    let showDivider: Bool
    var iconColor: Color? = nil
    var textColor: Color? = nil
    let action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor ?? (isLink ? Color.blue : Color.secondary))

                VStack(spacing: 0) {
                    HStack {
                        Text(text)
                            .foregroundStyle(textColor ?? (isLink ? Color.blue : Color.primary))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.vertical, 14)

                    if showDivider {
                        Divider()
                    }
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
