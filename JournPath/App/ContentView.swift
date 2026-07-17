//
//  ContentView.swift
//  MyJourney
//
//  Created by Bhumir Patel on 12/12/25.
//

import FirebaseAuth
import SwiftUI

struct ContentView: View {
    @State private var session = SessionStore()
    @State private var router = AppRouter()
    @State private var uploadManager = UploadManager()

    @AppStorage("lastTripId") var lastTripId: String?
    @AppStorage("pendingTripId") var pendingTripId: String?
    @AppStorage("pendingInviteToken") var pendingInviteToken: String?

    @State private var isJoiningTrip = false
    @State private var showingDeepLinkError = false
    @State private var deepLinkErrorMessage = ""

    private var deepLinkService = DeepLinkService()

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                EmptyView()
            case .loggedIn:
                mainContent
            case .loggedOut:
                OnboardingView()
            }
        }
        .onOpenURL { url in
            if let deepLink = deepLinkService.handle(url: url) {
                pendingTripId = deepLink[0]
                pendingInviteToken = deepLink[1]
            }
            processDeepLinking()
        }
        .onChange(of: session.state) { oldState, newState in
            if oldState != .loading && newState == .loggedIn {
                processDeepLinking()
            }
        }
        .environment(session)
        .overlay { joiningTripOverlay }
        .alert("Could Not Join Trip", isPresented: $showingDeepLinkError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deepLinkErrorMessage)
        }
    }
}

// MARK: - Views
private extension ContentView {
    
    var mainContent: some View {
        NavigationStack(path: $router.path) {
            TripListView()
                .navigationDestination(for: AppRoute.self, destination: destination)
        }
        .onAppear {
            router.restoreLastTripIfNeeded()
        }
        .environment(router)
        .environment(uploadManager)
    }

    @ViewBuilder
    func destination(for route: AppRoute) -> some View {
        switch route {
        case .notifications:
            EmptyView()
        case .settings:
            SettingsView()
        case .tripMap(let mapTripId):
            TripMapView(tripId: mapTripId, tripName: "Map")
        case .tripDashboard(let tripId):
            TripDashboardView(tripId: tripId)
        }
    }

    @ViewBuilder
    var joiningTripOverlay: some View {
        if isJoiningTrip {
            ZStack {
                Color.black.opacity(0.3).ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                    Text("Joining Trip...")
                        .font(.headline)
                }
                .padding(32)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(28)
            }
        }
    }
}

// MARK: - Deep Linking Logic
private extension ContentView {
    
    func processDeepLinking() {
        guard session.state == .loggedIn else {
            return
        }

        guard let tripId = pendingTripId, tripId != lastTripId, let token = pendingInviteToken else {
            return
        }

        router.popToRoot()
        isJoiningTrip = true
        
        Task {
            do {
                let verifiedTripId = try await deepLinkService.joinTrip(tripId: tripId, inviteToken: token)
                pendingTripId = nil
                pendingInviteToken = nil
                isJoiningTrip = false
                router.navigateToTrip(tripId: verifiedTripId)
            } catch {
                print("Failed to join trip: \(error)")
                deepLinkErrorMessage = error.localizedDescription
                showingDeepLinkError = true
                pendingTripId = nil
                pendingInviteToken = nil
                isJoiningTrip = false
            }
        }
    }
}
