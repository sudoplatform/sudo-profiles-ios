//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSAppSync
import SudoLogging

/// List of possible errors returned by `DeleteSudo` operation.
///
/// - sudoNotFound: Indicates that the specified Sudo could not be found.
public enum DeleteSudoError: Error, Hashable {
    case sudoNotFound
}

/// Operation to delete an existing Sudo.
class DeleteSudo: SudoOperation {

    private struct Constants {
        static let sudoNotFoundError = "sudoplatform.sudo.SudoNotFound"
    }

    private unowned let graphQLClient: AWSAppSyncClient

    var sudo: Sudo

    /// Initializes an operation to delete an existing Sudo.
    ///
    /// - Parameters:
    ///   - graphQLClient: GraphQL client to use to interact with Sudo service.
    ///   - logger: Logger to use for logging.
    ///   - sudo: Sudo to delete.
    init(graphQLClient: AWSAppSyncClient,
         logger: Logger = Logger.sudoProfilesClientLogger,
         sudo: Sudo) {
        self.graphQLClient = graphQLClient
        self.sudo = sudo

        super.init(logger: logger)
    }

    override func execute() {
        guard let id = sudo.id else {
            self.logger.error("Sudo ID is missing but is required to update an Sudo.")
            self.error = SudoOperationError.preconditionFailure
            return self.done()
        }

        self.graphQLClient.perform(mutation: DeleteSudoMutation(input: DeleteSudoInput(id: id, expectedVersion: sudo.version)), queue: self.queue) { (result, error) in
            if let error = error {
                self.logger.error("Failed to delete a Sudo: \(error)")
                self.error = error
                return self.done()
            }

            guard let result = result else {
                self.error = SudoOperationError.fatalError(description: "Mutation completed successfully but result is missing.")
                return self.done()
            }

            if let error = result.errors?.first {
                let message = "Failed to delete a Sudo: \(error)"
                self.logger.error(message)

                if let errorType = error[SudoOperation.SudoServiceError.type] as? String {
                    switch errorType {
                    case Constants.sudoNotFoundError:
                        self.error = DeleteSudoError.sudoNotFound
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

            self.logger.info("Sudo deleted successfully.")
            self.done()
        }
    }

}
