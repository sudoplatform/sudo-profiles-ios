//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSAppSync
import SudoUser
import SudoLogging

/// Operation to create a new Sudo.
class CreateSudo: SudoOperation {

    private unowned let cryptoProvider: CryptoProvider
    private unowned let graphQLClient: AWSAppSyncClient

    private let region: String
    private let bucket: String
    private let identityId: String

    var sudo: Sudo

    /// Initializes an operation to create a new Sudo.
    ///
    /// - Parameters:
    ///   - cryptoProvider:`CryptoProvider` to use for encryption.
    ///   - graphQLClient: GraphQL client to use to interact with Sudo service.
    ///   - logger: Logger to use for logging.
    ///   - region: AWS region hosting Sudo service.
    ///   - bucket: Name of S3 bucket to store any blob associated with Sudo.
    ///   - identityId: ID of identity to own the blob in AWS S3.
    ///   - sudo: Sudo to create.
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
        // Process secure claims or secure S3 objects associated with Sudo.
        var secureClaims: [SecureClaimInput] = []
        var secureS3Objects: [SecureS3ObjectInput] = []
        do {
            for claim in sudo.claims {
                switch (claim.visibility, claim.value) {
                case (.private, .string(let value)):
                    secureClaims.append(try self.createSecureClaim(name: claim.name, value: value))
                case (.private, .blob(let value)):
                    secureS3Objects.append(try self.createSecureS3Object(name: claim.name, key: "\(self.identityId)/\(value.lastPathComponent)"))
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

        self.logger.info("Creating a Sudo.")
        let input = CreateSudoInput(claims: secureClaims, objects: secureS3Objects)
        self.graphQLClient.perform(mutation: CreateSudoMutation(input: input), queue: self.queue) { (result, error) in
            if let error = error {
                self.logger.error("Failed to create a Sudo: \(error)")
                self.error = error
                return self.done()
            }

            guard let result = result else {
                self.error = SudoOperationError.fatalError(description: "Mutation completed successfully but result is missing.")
                return self.done()
            }

            if let error = result.errors?.first {
                let message = "Failed to create a Sudo: \(error)"
                self.logger.error(message)

                if let errorType = error[SudoOperation.SudoServiceError.type] as? String {
                    switch errorType {
                    case SudoOperation.SudoServiceError.insufficientEntitlementsError:
                        self.error = SudoOperationError.insufficientEntitlementsError
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

            guard let sudo = result.data?.createSudo else {
                self.error = SudoOperationError.fatalError(description: "Mutation result did not contain required object.")
                return self.done()
            }

            self.sudo.id = sudo.id
            self.sudo.version = sudo.version
            self.sudo.createdAt = Date(millisecondsSinceEpoch: sudo.createdAtEpochMs)
            self.sudo.updatedAt = Date(millisecondsSinceEpoch: sudo.updatedAtEpochMs)

            self.logger.info("Sudo created successfully.")
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
        guard let keyId = try self.cryptoProvider.getSymmetricKeyId() else {
            throw SudoProfilesClientError.fatalError(description: "Symmetric key missing.")
        }
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
        guard let keyId = try self.cryptoProvider.getSymmetricKeyId() else {
            throw SudoProfilesClientError.fatalError(description: "Symmetric key missing.")
        }
        return SecureS3ObjectInput(name: name,
                                   version: 1,
                                   algorithm: SymmetricKeyEncryptionAlgorithm.aesCBCPKCS7Padding.rawValue,
                                   keyId: keyId,
                                   bucket: self.bucket,
                                   region: self.region,
                                   key: key)
    }

}
