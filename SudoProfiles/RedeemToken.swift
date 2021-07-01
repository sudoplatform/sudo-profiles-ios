//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSAppSync
import SudoLogging
import SudoApiClient

/// Operation to redeem a token for entitlements.
class RedeemToken: SudoOperation {

    private unowned let graphQLClient: SudoApiClient

    var token: String
    var type: String
    var entitlements: [Entitlement] = []

    /// Initializes an operation to redeem a token for entitlements..
    ///
    /// - Parameters:
    ///   - graphQLClient: GraphQL client to use to interact with Sudo service.
    ///   - logger: Logger to use for logging.
    ///   - token: Token to redeem.
    ///   - type: Token type.
    init(graphQLClient: SudoApiClient,
         logger: Logger = Logger.sudoProfilesClientLogger,
         token: String,
         type: String) {
        self.graphQLClient = graphQLClient
        self.token = token
        self.type = type
        super.init(logger: logger)
    }

    override func execute() {
        do {
            try self.graphQLClient.perform(
                mutation: RedeemTokenMutation(input: RedeemTokenInput(token: self.token, type: self.type)),
                queue: self.queue, resultHandler: { (result, error) in
                    if let error = error {
                        self.logger.error("Failed to redeem a token for entitlements: \(error)")
                        self.error = SudoProfilesClientError.fromApiOperationError(error: error)
                        return self.done()
                    }

                    guard let result = result else {
                        self.error = SudoProfilesClientError.fatalError(description: "Mutation completed successfully but result is missing.")
                        return self.done()
                    }

                    if let error = result.errors?.first {
                        self.logger.error("Failed to redeem a token for entitlements: \(error)")
                        self.error = SudoProfilesClientError.fromApiOperationError(error: error)
                        return self.done()
                    }

                    guard let data = result.data else {
                        self.error = SudoProfilesClientError.fatalError(description: "Mutation result did not contain required object.")
                        return self.done()
                    }

                    self.logger.info("Token redeemed successfully.")
                    self.entitlements = data.redeemToken.map { Entitlement(name: $0.name, value: $0.value) }
                    self.done()
                }
            )
        } catch {
            self.error = SudoProfilesClientError.fromApiOperationError(error: error)
            self.done()
        }
    }

}
