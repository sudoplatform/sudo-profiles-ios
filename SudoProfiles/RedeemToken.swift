//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSAppSync
import SudoLogging

/// List of possible errors returned by `RedeemToken` operation.
///
/// - invalidToken: Indicates that the token or the token type was invalid.
/// - invalidUserType: Indicates the signed in user is not of the correct type to redeem a token..
public enum RedeemTokenError: Error, Hashable {
    case invalidToken
    case invalidUserType
}

/// Operation to redeem a token for entitlements.
class RedeemToken: SudoOperation {

    private struct Constants {
        static let invalidTokenError = "sudoplatform.InvalidTokenError"
        static let invalidUserTypeError = "sudoplatform.InvalidUserTypeError"
    }

    private unowned let graphQLClient: AWSAppSyncClient

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
    init(graphQLClient: AWSAppSyncClient,
         logger: Logger = Logger.sudoProfilesClientLogger,
         token: String,
         type: String) {
        self.graphQLClient = graphQLClient
        self.token = token
        self.type = type

        super.init(logger: logger)
    }

    override func execute() {
        self.graphQLClient.perform(mutation: RedeemTokenMutation(input: RedeemTokenInput(token: self.token, type: self.type)), queue: self.queue) { (result, error) in
            if let error = error {
                self.logger.error("Failed to redeem a token for entitlements: \(error)")
                self.error = error
                return self.done()
            }

            guard let result = result else {
                self.error = SudoOperationError.fatalError(description: "Mutation completed successfully but result is missing.")
                return self.done()
            }

            if let error = result.errors?.first {
                let message = "Failed to redeem a token for entitlements: \(error)"
                self.logger.error(message)

                if let errorType = error[SudoOperation.SudoServiceError.type] as? String {
                    switch errorType {
                    case Constants.invalidTokenError:
                        self.error = RedeemTokenError.invalidToken
                    case Constants.invalidUserTypeError:
                        self.error = RedeemTokenError.invalidUserType
                    case SudoOperation.SudoServiceError.serviceError:
                        self.error = SudoOperationError.serviceError
                    default:
                        self.error = SudoOperationError.graphQLError(description: message)
                    }
                } else {
                    self.error = SudoOperationError.graphQLError(description: message)
                }

                return self.done()
            }

            guard let data = result.data else {
                self.error = SudoOperationError.fatalError(description: "Mutation result did not contain required object.")
                return self.done()
            }

            self.logger.info("Token redeemed successfully.")
            self.entitlements = data.redeemToken.map { Entitlement(name: $0.name, value: $0.value) }
            self.done()
        }
    }

}
