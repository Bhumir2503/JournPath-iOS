import Foundation
import Combine

class TimePickerVM: ObservableObject {
    @Published var selectedTime: Date
    
    init(initialTime: Date? = nil) {
        self.selectedTime = initialTime ?? Date()
    }
    
    func resetToCurrentTime() {
        self.selectedTime = Date()
    }
}
