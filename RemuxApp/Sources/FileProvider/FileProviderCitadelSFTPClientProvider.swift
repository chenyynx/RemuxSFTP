import Foundation
import NIOCore

enum FileProviderSFTPClientProviderError: Error, Equatable, Sendable {
    case unsupportedAuthentication
}

struct FileProviderCitadelSFTPClientProvider: FileProviderSFTPClientProviding {
    private let sshRootService: RemuxSSHRootService
    private let trustedHosts: TrustedHostStore
    private let connectTimeout: TimeAmount
    private let operationTimeout: TimeAmount

    init(
        sshRootService: RemuxSSHRootService,
        trustedHosts: TrustedHostStore,
        connectTimeout: TimeAmount = .seconds(15),
        operationTimeout: TimeAmount = .seconds(15)
    ) {
        self.sshRootService = sshRootService
        self.trustedHosts = trustedHosts
        self.connectTimeout = connectTimeout
        self.operationTimeout = operationTimeout
    }

    func withClient<Value: Sendable>(
        server: SavedServer,
        authentication: ResolvedSSHAuth,
        operation: @Sendable (any RemuxSFTPFileProviderClient) async throws -> Value
    ) async throws -> Value {
        let credential = authentication.credential
        switch credential {
        case .password, .privateKey:
            break
        case .none:
            // Tailscale SSH needs the app's check-verification UI; the File
            // Provider extension cannot present it. Such identities have no
            // stored credential, so the domain reconciler normally excludes
            // them before this point.
            throw FileProviderSFTPClientProviderError.unsupportedAuthentication
        }

        let provider = RemuxCitadelSFTPClientProvider(
            sshRootService: sshRootService,
            rootKey: RemuxSSHRootKey(server: server, auth: authentication),
            rootConfiguration: RemuxSSHRootConfiguration(
                host: server.host,
                port: server.port,
                authenticationMethod: {
                    try SSHAuthenticationMethodFactory.make(
                        username: authentication.username,
                        credential: credential
                    )
                },
                hostKeyValidator: trustedHosts.validator(for: server),
                connectTimeout: connectTimeout
            ),
            operationTimeout: operationTimeout
        )

        return try await provider.withClient { client in
            try await operation(client)
        }
    }

    func closeIdleConnections(forServerID serverID: SavedServer.ID) async {
        await sshRootService.closeIdleConnections(forServerID: serverID)
    }
}
