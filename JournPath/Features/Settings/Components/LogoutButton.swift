//
//  LogoutButton.swift
//  MyJourney
//
//  Created by Bhumir Patel on 3/13/26.
//

import FirebaseAuth
import SwiftUI

struct LogoutButton: View {
    @State private var showLogoutAlert: Bool = false
    @Environment(AppRouter.self) private var router

    var body: some View {

        Button {
            showLogoutAlert = true
        } label: {
            HStack {
                Spacer()
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Log Out")
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)

        .alert("Log Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                router.popToRoot()
                try? Auth.auth().signOut()
            }
        } message: {
            Text("Are you sure you want to log out of JournPath?")
        }
    }
}
