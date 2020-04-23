//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoKeyManager
import SudoUser
import AWSAppSync
import SudoLogging

/// List of possible errors thrown by `OwnershipProofIssuer` implementation.
///
/// - invalidConfig: Indicates the input to initializing or configuring the issuer was invalid.
/// - sudoNotFound: Indicates the specified Sudo does not exists.
/// - graphQLError: Sudo service's GraphQL endpoint returned an error.
/// - serviceError: Indicates that an internal server error caused the operation to fail. The error is
///     possibly transient and retrying at a later time may cause the operation to complete
///     successfully
public enum OwnershipProofIssuerError: Error {
    case invalidConfig
    case serviceError
    case sudoNotFound
    case graphQLError(description: String)
}

/// Result returned by APIs for retrieve Sudo owernship proof. The API can fail
/// with an error or return a signed proof in form of JWT.
///
/// - success: Ownership proof was retrieved successfully.
/// - failure: Ownership proof retrieval failed with an error.
public enum GetOwnershipProofResult {
    case success(jwt: String)
    case failure(cause: Error)
}

// Protocol encapsulating APIs for issuing ownership proofs.
// These APIs are used by other Sudo platform clients and any
// app developed using this SDK is not expected to use these
// APIs directly.
public protocol OwnershipProofIssuer: class {

    /// Retrieves a signed owernship proof for the specified owner. The owership
    /// proof JWT has the follow payload.
    ///
    /// {
    ///  "jti": "DBEEF4EB-F84A-4AB7-A45E-02B05B93F5A3",
    ///  "owner": "cd73a478-23bd-4c70-8c2b-1403e2085845",
    ///  "iss": "sudoplatform.sudoservice",
    ///  "aud": "sudoplatform.virtualcardservice",
    ///  "exp": 1578986266,
    ///  "sub": "da17f346-cf49-4db4-98c2-862f85515fc4",
    ///  "iat": 1578982666
    /// }
    ///
    /// "owner" is an unique ID of an identity managed by the issuing service. In
    /// case of Sudo service this represents unique reference to a Sudo.
    /// "sub" is the subject to which this proof is issued to i.e. the user.
    /// "aud" is the target audience of the proof.
    ///
    /// - Parameters:
    ///   - ownerId: Owner ID.
    ///   - subject: Subject to which the proof is issued to.
    ///   - audience: Target audience for this proof.
    ///   - completion: Completion handler to pass back the proof or any error.
    func getOwnershipProof(ownerId: String, subject: String, audience: String, completion: @escaping (GetOwnershipProofResult) -> Void) throws

}

/// `OwnershipProofIssuer` implementation that uses Sudo service to issue the required
/// ownership proof.
class DefaultOwnershipProofIssuer: OwnershipProofIssuer {

    private struct Constants {
        static let sudoNotFoundError = "sudoplatform.sudo.SudoNotFound"
        static let serviceError = "sudoplatform.ServiceError"
    }

    private let graphQLClient: AWSAppSyncClient

    private let logger: Logger

    private let queue = DispatchQueue(label: "com.sudoplatform.sudoprofiles.client.ownership.issuer")

    /// Initializes a `DefaultOwnershipProofIssuer`.
    ///
    /// - Parameters:
    ///   - graphQLClient: GraphQL client to use to contact Sudo service.
    ///   - logger: Logger to use for logging.
    init(graphQLClient: AWSAppSyncClient, logger: Logger = Logger.sudoProfilesClientLogger) throws {
        self.graphQLClient = graphQLClient
        self.logger = logger
    }

    func getOwnershipProof(ownerId: String, subject: String, audience: String, completion: @escaping (GetOwnershipProofResult) -> Void) throws {
        self.graphQLClient.perform(mutation: GetOwnershipProofMutation(input: GetOwnershipProofInput(sudoId: ownerId, audience: audience)), queue: self.queue) { (result, error) in
            if let error = error {
                self.logger.error("Failed to retrieve ownership proof: \(error)")
                return completion(.failure(cause: error))
            }

            guard let result = result else {
                return completion(.failure(cause: SudoOperationError.fatalError(description: "Mutation completed successfully but result is missing.")))
            }

            if let error = result.errors?.first {
                let message = "Failed to retrieve ownership proof: \(error)"
                self.logger.error(message)

                let result: GetOwnershipProofResult
                if let errorType = error[SudoOperation.SudoServiceError.type] as? String {
                    switch errorType {
                    case Constants.sudoNotFoundError:
                        result = .failure(cause: OwnershipProofIssuerError.sudoNotFound)
                    case Constants.serviceError:
                        result = .failure(cause: OwnershipProofIssuerError.serviceError)
                    default:
                        result = .failure(cause: OwnershipProofIssuerError.graphQLError(description: message))
                    }
                } else {
                    result = .failure(cause: OwnershipProofIssuerError.graphQLError(description: message))
                }

                return completion(result)
            }

            guard let jwt = result.data?.getOwnershipProof?.jwt else {
                return completion(.failure(cause: SudoProfilesClientError.fatalError(description: "Mutation result did not contain required object.")))
            }

            completion(.success(jwt: jwt))
        }
    }

}

/// `OwnershipProofIssuer` implementation that uses a locally stored RSA private key
/// to generated the ownership proof. Mainly used for testing.
public class ClientOwnershipProofIssuer: OwnershipProofIssuer {

    private let keyManager: SudoKeyManager

    private let keyId: String

    private let issuer: String

    /// Initializes a `ClientOwnershipProofIssuer`.
    ///
    /// - Parameters:
    ///   - privateKey: PEM encoded RSA private key to use for signing the ownership proof.
    ///   - keyManager: `KeyManager` instance to use for cryptographic operations.
    ///   - keyId: Key ID to use for storing the RSA private key in the keychain.
    ///   - issuer: Issuer name to use for the ownership proof.
    public init(privateKey: String, keyManager: SudoKeyManager, keyId: String, issuer: String) throws {
        var privateKey = privateKey
        privateKey = privateKey.replacingOccurrences(of: "\n", with: "")
        privateKey = privateKey.replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
        privateKey = privateKey.replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")

        guard let keyData = Data(base64Encoded: privateKey) else {
            throw OwnershipProofIssuerError.invalidConfig
        }

        self.keyManager = keyManager
        self.keyId = keyId
        self.issuer = issuer

        try self.keyManager.deleteKeyPair(keyId)
        try self.keyManager.addPrivateKey(keyData, name: keyId)
    }

    public func getOwnershipProof(ownerId: String, subject: String, audience: String, completion: @escaping (GetOwnershipProofResult) -> Void) throws {
        let jwt = JWT(issuer: self.issuer, audience: audience, subject: subject, id: UUID().uuidString)
        jwt.payload["owner"] = ownerId
        let encoded = try jwt.signAndEncode(keyManager: self.keyManager, keyId: self.keyId)
        completion(GetOwnershipProofResult.success(jwt: encoded))
    }

}
