//
//  String+Extensions.swift
//  MyJourney
//
//  Created by Bhumir Patel on 3/17/26.
//

import Foundation
import Swift

extension String {
    var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }

    var cleanUpEmail: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isBlank: Bool {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var trimmed: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }


    var containsUppercase: Bool {
        range(of: "[A-Z]", options: .regularExpression) != nil
    }
    
    var containsLowercase: Bool {
        range(of: "[a-z]", options: .regularExpression) != nil
    }
    
    var containsNumber: Bool {
        range(of: "[0-9]", options: .regularExpression) != nil
    }
    
    var isValidPassword: Bool {
        count >= 8 && containsUppercase && containsLowercase && containsNumber
    }

    func toDate() -> Date? {
        return DateFormatter.yyyyMMdd.date(from: self)
    }

}
