//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSAppSync
import SudoUser
import SudoLogging

/// List of possible errors returned by `UpdateSudo` operation.
///
/// - sudoNotFound: Indicates that the specified Sudo could not be found.
/// - versionMismatch: Indicates the version of the Sudo that is getting updated does not match
///     the current version of the Sudo stored in the backend. The caller should retrieve the
///     current version of the Sudo and reconcile the difference..
public enum UpdateSudoError: Error, Hashable {
    case sudoNotFound
    case versionMismatch
}

/// Operation to update an existing Sudo.
class UpdateSudo: SudoOperation {

    private struct Constants {
        static let sudoNotFoundError = "sudoplatform.sudo.SudoNotFound"
        static let conditionalCheckFailedException = "DynamoDB:ConditionalCheckFailedException"
    }

    private unowned let cryptoProvider: CryptoProvider
    private unowned let graphQLClient: AWSAppSyncClient

    private let region: String
    private let bucket: String
    private let identityId: String

    var sudo: Sudo

    /// Initializes an operation to update an existing Sudo.
    ///
    /// - Parameters:
    ///   - cryptoProvider: `CryptoProvider` to use for encryption.
    ///   - graphQLClient: GraphQL client to use to interact with Sudo service.
    ///   - logger: Logger to use for logging.
    ///   - region: AWS region hosting Sudo service.
    ///   - bucket: Name of S3 bucket to store any blob associated with Sudo.
    ///   - identityId: ID of identity to own the blob in AWS S3.
    ///   - sudo: Sudo to update.
    init(cryptoProvider: CryptoProvider,
         graphQLClient: AWSAppSyncClient,
         logger: Logger = Logger.sudoProfilesClientLogger,
         region: String,
         bucket: String,
         identityId: String,
         sudo: Sudo) {
        self.cryptoProvider = cryptoProvider
        self.graphQLClient = graphQLClient
        self.region = region
        self.bucket = bucket
        self.identityId = identityId
        self.sudo = sudo

        super.init(logger: logger)
    }

    override func execute() {
        guard let id = sudo.id else {
            self.logger.error("Sudo ID is missing but is required to update an Sudo.")
            self.error = SudoOperationError.preconditionFailure
            return self.done()
        }

        // Process secure claims or secure S3 objects associated with Sudo.
        var secureClaims: [SecureClaimInput] = []
        var secureS3Objects: [SecureS3ObjectInput] = []
        do {
            for claim in sudo.claims {
                switch (claim.visibility, claim.value) {
                case (.private, .string(let value)):
                    secureClaims.append(try self.createSecureClaim(name: claim.name, value: value))
                case (.private, .blob(let value)):
                    secureS3Objects.append(try self.createSecureS3Object(name: claim.name, key: "\(self.identityId)/sudo/\(id)/\(value.lastPathComponent)"))
                default:
                    // No other claim type currently supported.
                    break
                }
            }
        } catch {
            self.logger.error("Failed to process secure claims and objects: \(error)")
            self.error = error
            return self.done()
        }

        let input = UpdateSudoInput(
            id: id,
            claims: secureClaims,
            objects: secureS3Objects,
            expectedVersion: sudo.version
        )

        self.graphQLClient.perform(mutation: UpdateSudoMutation(input: input), queue: self.queue) { (result, error) in
            if let error = error {
                self.logger.error("Failed to update a Sudo: \(error)")
                self.error = error
                return self.done()
            }

            guard let result = result else {
                self.error = SudoOperationError.fatalError(description: "Mutation completed successfully but result is missing.")
                return self.done()
            }

            if let error = result.errors?.first {
                let message = "Failed to update a Sudo: \(error)"
                self.logger.error(message)

                if let errorType = error[SudoOperation.SudoServiceError.type] as? String {
                    switch errorType {
                    case Constants.sudoNotFoundError:
                        self.error = UpdateSudoError.sudoNotFound
                    case Constants.conditionalCheckFailedException:
                        self.error = UpdateSudoError.versionMismatch
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

            guard let sudo = result.data?.updateSudo else {
                self.error = SudoOperationError.fatalError(description: "Mutation result did not contain required object.")
                return self.done()
            }

            self.sudo.id = sudo.id
            self.sudo.version = sudo.version
            self.sudo.createdAt = Date(millisecondsSinceEpoch: sudo.createdAtEpochMs)
            self.sudo.updatedAt = Date(millisecondsSinceEpoch: sudo.updatedAtEpochMs)

            self.logger.info("Sudo updated successfully.")
            self.done()
        }
    }

    /// Create a secure claim from a name and a String value.
    ///
    /// - Parameters:
    ///   - name: Claim name.
    ///   - value: String value of the claim.
    /// - Returns: Secure claim.
    private func createSecureClaim(name: String, value: String) throws -> SecureClaimInput {
        let keyId = try self.cryptoProvider.getSymmetricKeyId()
        let encrypted = try self.cryptoProvider.encrypt(keyId: keyId, algorithm: SymmetricKeyEncryptionAlgorithm.aesCBCPKCS7Padding, data: value.data(using: .utf8)!)
        return SecureClaimInput(name: name,
                                version: 1,
                                algorithm: SymmetricKeyEncryptionAlgorithm.aesCBCPKCS7Padding.rawValue,
                                keyId: keyId,
                                base64Data: encrypted.base64EncodedString())
    }

    /// Creates a secure S3 object from a name and a key.
    ///
    /// - Parameters:
    ///   - name: Object name.
    ///   - key: Object key.
    /// - Returns: Secure S3 object.
    private func createSecureS3Object(name: String, key: String) throws -> SecureS3ObjectInput {
        let keyId = try self.cryptoProvider.getSymmetricKeyId()
        return SecureS3ObjectInput(name: name,
                                   version: 1,
                                   algorithm: SymmetricKeyEncryptionAlgorithm.aesCBCPKCS7Padding.rawValue,
                                   keyId: keyId,
                                   bucket: self.bucket,
                                   region: self.region,
                                   key: key)
    }

}
