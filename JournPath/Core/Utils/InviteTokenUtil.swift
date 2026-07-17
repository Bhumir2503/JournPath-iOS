//
//  InviteTokenUtil.swift
//  MyJourney
//

import Foundation

enum InviteTokenUtil {
    static func generate(length: Int = 6) -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  // Omitted 'I', 'O', '1', and '0' to avoid user confusion
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}
