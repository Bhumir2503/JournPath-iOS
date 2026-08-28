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
    @State private var uploads = UploadManager()

    @AppStorage("lastTripId") var lastTripId: String?
    @AppStorage("pendingTripId") var pendingTripId: String?
    @AppStorage("pendingInviteToken") var pendingInviteToken: String?

    @State private var isJoiningTrip = false
    @State private var deepLinkError: AnyAppError? = nil

    private var deepLinkService = DeepLinkService()
    
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                switch session.state {
                case .loading:
                    Color(UIColor.systemBackground).ignoresSafeArea()
                case .loggedIn:
                    mainContent
                case .loggedOut:
                    SignInView()
                }
            }
        .onOpenURL { url in
            if let deepLink = deepLinkService.handle(url: url) {
                pendingTripId = deepLink.tripId
                pendingInviteToken = deepLink.token
            }
            processDeepLinking()
        }
        .onChange(of: session.state) { oldState, newState in
            if oldState != .loading && newState == .loggedIn {
                processDeepLinking()
            }
            checkSplashDismissal()
        }
        .environment(session)
        .environment(uploads)
        .overlay { joiningTripOverlay }
        .alert(error: $deepLinkError)

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            checkSplashDismissal()
        }
    }
    
    private func checkSplashDismissal() {
        if session.state != .loading {
            Task {
                try? await Task.sleep(for: .seconds(0.2))
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSplash = false
                }
            }
        }
    }
}

// MARK: - Views
extension ContentView {

    fileprivate var mainContent: some View {
        NavigationStack(path: $router.path) {
            TripListView()
                .navigationDestination(for: AppRoute.self, destination: destination)
        }
        .onAppear {
            router.restoreLastTripIfNeeded()
        }
        .environment(router)
    }

    @ViewBuilder
    fileprivate func destination(for route: AppRoute) -> some View {
        switch route {
        case .notifications:
            EmptyView()
        case .settings:
            SettingsView()
        case .tripMap(let tripId):
            TripMapView(tripId: tripId)
        case .tripDashboard(let tripId):
            TripDashboardView(tripId: tripId)
        }
    }

    @ViewBuilder
    fileprivate var joiningTripOverlay: some View {
        if isJoiningTrip {
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()

                VStack(spacing: 24) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                        .tint(.accentColor)
                    
                    VStack(spacing: 6) {
                        Text("Joining Trip...")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Getting things ready")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 32)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 8)
            }
        }
    }
}

// MARK: - Deep Linking Logic
extension ContentView {

    fileprivate func processDeepLinking() {
        guard session.state == .loggedIn else {
            return
        }

        guard let tripId = pendingTripId, tripId != lastTripId, let token = pendingInviteToken else {
            pendingTripId = nil
            pendingInviteToken = nil
            return
        }

        router.popToRoot()

        isJoiningTrip = true

        Task {

            defer {
                isJoiningTrip = false
                pendingTripId = nil
                pendingInviteToken = nil
            }

            do {
                let verifiedTripId = try await deepLinkService.joinTrip(tripId: tripId, inviteToken: token)
                router.navigateToTrip(tripId: verifiedTripId)
            } catch let error as APIError {
                deepLinkError = AnyAppError(error)
            }
        }
    }
}
