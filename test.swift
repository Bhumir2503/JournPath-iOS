import Foundation

func test() async {
    let _ = try? await offMain {
        return 1
    }
}

private func offMain<T: Sendable>(
    _ work: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await Task.detached(priority: .userInitiated, operation: work).value
}
