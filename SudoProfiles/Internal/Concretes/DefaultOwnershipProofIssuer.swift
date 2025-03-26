//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Foundation
import SudoKeyManager
import SudoUser
import SudoLogging
import SudoApiClient

/// `OwnershipProofIssuer` implementation that uses Sudo service to issue the required
/// ownership proof.
class DefaultOwnershipProofIssuer: OwnershipProofIssuer {

    // MARK: - Properties

    private let graphQLClient: SudoApiClient

    private let logger: Logger

    // MARK: - Lifecycle

    /// Initializes a `DefaultOwnershipProofIssuer`.
    /// - Parameters:
    ///   - graphQLClient: GraphQL client to use to contact Sudo service.
    ///   - logger: Logger to use for logging.
    init(graphQLClient: SudoApiClient, logger: Logger) {
        self.graphQLClient = graphQLClient
        self.logger = logger
    }

    // MARK: - Conformance: OwnershipProofIssuer

    func getOwnershipProof(ownerId: String, subject: String, audience: String) async throws -> String {
        do {
            let mutation = GetOwnershipProofMutation(input: GetOwnershipProofInput(sudoId: ownerId, audience: audience))
            let result = try await self.graphQLClient.perform(mutation: mutation)
            guard let jwt = result.getOwnershipProof?.jwt else {
                throw SudoProfilesClientError.fatalError(description: "Mutation result did not contain required object.")
            }
            return jwt
        } catch {
            throw SudoProfilesClientError.fromApiOperationError(error: error)
        }
    }
}
