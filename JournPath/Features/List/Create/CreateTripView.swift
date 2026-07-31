//
//  CreateTripView.swift
//  MyJourney
//
//  Created by Bhumir Patel on 5/5/26.
//

import Foundation
import SwiftUI

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    @State private var vm = CreateTripViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Background()
                InputForm()
            }
            .ignoresSafeArea()
            .toolbar { toolbar }

        }
        .environment(vm)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .cancel) {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(role: .confirm) {
                Task {
                    let tripId = await vm.createTrip()
                    print("Trip created with ID: \(tripId ?? "")")
                    dismiss()
                }
            } label: {
                if vm.isProcessing {
                    ProgressView()
                } else {
                    Text("Create Trip")
                }
            }
            .disabled(!vm.isValid || vm.isProcessing)
        }
    }
}
