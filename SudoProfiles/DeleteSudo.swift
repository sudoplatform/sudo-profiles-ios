//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSAppSync
import SudoLogging
import SudoApiClient

/// Operation to delete an existing Sudo.
class DeleteSudo: SudoOperation {

    private unowned let graphQLClient: SudoApiClient

    var sudo: Sudo

    /// Initializes an operation to delete an existing Sudo.
    ///
    /// - Parameters:
    ///   - graphQLClient: GraphQL client to use to interact with Sudo service.
    ///   - logger: Logger to use for logging.
    ///   - sudo: Sudo to delete.
    init(graphQLClient: SudoApiClient,
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

        do {
            try self.graphQLClient.perform(
                mutation: DeleteSudoMutation(input: DeleteSudoInput(id: id, expectedVersion: sudo.version)),
                queue: self.queue,
                resultHandler: { (result, error) in
                    if let error = error {
                        self.logger.error("Failed to delete a Sudo: \(error)")
                        self.error = SudoProfilesClientError.fromApiOperationError(error: error)
                        return self.done()
                    }

                    guard let result = result else {
                        self.error = SudoProfilesClientError.fatalError(description: "Mutation completed successfully but result is missing.")
                        return self.done()
                    }

                    if let error = result.errors?.first {
                        self.logger.error("Failed to delete a Sudo: \(error)")
                        self.error = SudoProfilesClientError.fromApiOperationError(error: error)
                        return self.done()
                    }

                    self.logger.info("Sudo deleted successfully.")
                    self.done()
                }
            )
        } catch {
            self.error = SudoProfilesClientError.fromApiOperationError(error: error)
            self.done()
        }
    }

}
