import SwiftUI

struct TestView: View {
    let tripId: String?
    @AppStorage var currencyCode: String
    @State private var someState = false
    
    init(tripId: String?) {
        self.tripId = tripId
        let key = "currency_\(tripId ?? "default")"
        self._currencyCode = AppStorage(wrappedValue: "USD", key)
    }
    
    var body: some View {
        Text(currencyCode)
    }
}
