//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import Foundation
import SudoApiClient

/// List of possible errors thrown by `SudoProfilesClient` implementation.
/// - sudoServiceConfigNotFound: Indicates the configuration related to Sudo Service is not found.
///     This may indicate that Sudo Service is not deployed into your runtime instance or the config
///     file that you are using is invalid..
/// - invalidInput: Indicates that the input to the API was invalid.
/// - notSignedIn: Indicates the API being called requires the client to sign in.
/// - badData: Indicates the bad data was found in cache or in backend response.
/// - graphQLError: Indicates that a GraphQL error was returned by the backend.
/// - fatalError: Indicates that a fatal error occurred. This could be due to coding error, out-of-memory
///     condition or other conditions that is beyond control of `SudoProfilesClient` implementation.
public enum SudoProfilesClientError: Error {

    /// Indicates that the configuration dictionary passed to initialize the client was not valid.
    case invalidConfig

    /// Indicates the configuration related to Sudo Service is not found. This may indicate that Sudo Service
    /// is not deployed into your runtime instance or the config file that you are using is invalid..
    case sudoServiceConfigNotFound

    /// Indicates that the input to the API was invalid.
    case invalidInput

    /// Indicates the requested operation failed because the user account is locked.
    case accountLocked

    /// Indicates the API being called requires the client to sign in.
    case notSignedIn

    /// Indicates that the request operation failed due to authorization error. This maybe due to the authentication
    /// token being invalid or other security controls that prevent the user from accessing the API.
    case notAuthorized

    /// Indicates that the user does not have sufficient entitlements to perform the requested operation.
    case insufficientEntitlements

    /// Indicates the version of the Sudo that is getting updated does not match the current version of the Sudo stored
    /// in the backend. The caller should retrieve the current version of the Sudo and reconcile the difference..
    case versionMismatch

    /// Indicates that an internal server error caused the operation to fail. The error is possibly transient and
    /// retrying at a later time may cause the operation to complete successfully
    case serviceError

    /// Indicates that the request failed due to connectivity, availability or access error.
    case requestFailed(response: HTTPURLResponse?, cause: Error?)

    /// Indicates that there were too many attempts at sending API requests within a short period of time.
    case rateLimitExceeded

    /// Indicates the bad data was found in cache or in backend response.
    case badData

    /// Indicates the specified Sudo or blob claim was not found.
    case notFound

    /// Indicates that a GraphQL error was returned by the backend.
    case graphQLError(description: String)

    /// Indicates that a fatal error occurred. This could be due to coding error, out-of-memory condition or other
    /// conditions that is beyond control of `SudoProfilesClient` implementation.
    case fatalError(description: String)
}

extension SudoProfilesClientError {

    struct Constants {
        static let errorType = "errorType"
        static let sudoNotFoundError = "sudoplatform.sudo.SudoNotFound"
        static let invalidTokenError = "sudoplatform.InvalidTokenError"
        static let invalidUserTypeError = "sudoplatform.InvalidUserTypeError"
    }

    static func fromApiOperationError(error: Error) -> SudoProfilesClientError {
        if let clientError = error as? SudoProfilesClientError {
            return clientError
        }
        switch error {
        case ApiOperationError.accountLocked:
            return .accountLocked
        case ApiOperationError.notSignedIn:
            return .notSignedIn
        case ApiOperationError.notAuthorized:
            return .notAuthorized
        case ApiOperationError.insufficientEntitlements:
            return .insufficientEntitlements
        case ApiOperationError.serviceError:
            return .serviceError
        case ApiOperationError.invalidRequest:
            return .invalidInput
        case ApiOperationError.rateLimitExceeded:
            return .rateLimitExceeded
        case ApiOperationError.versionMismatch:
            return .versionMismatch
        case ApiOperationError.graphQLError(let underlyingError):
            guard 
                let graphQLError = underlyingError as? GraphQLError,
                let errorType = graphQLError.extensions?[Constants.errorType]?.stringValue
            else {
                return .fatalError(
                    description: "GraphQL operation failed but error type was not found in the response. \(error.localizedDescription)"
                )
            }
            switch errorType {
            case Constants.sudoNotFoundError:
                return .notFound
            case Constants.invalidTokenError, Constants.invalidUserTypeError:
                return .invalidInput
            default:
                return .graphQLError(description: "Unexpected GraphQL error: \(underlyingError.localizedDescription)")
            }
        case ApiOperationError.requestFailed(let response, let cause):
            return .requestFailed(response: response, cause: cause)
        default:
            return .fatalError(description: "Unexpected API operation error: \(error)")
        }
    }

    static func fromStorageError(error: Error) -> SudoProfilesClientError {
        if let clientError = error as? SudoProfilesClientError {
            return clientError
        }
        guard let storageError = error as? StorageError else {
            return SudoProfilesClientError.serviceError
        }
        switch storageError {
        case .keyNotFound, .localFileNotFound, .accessDenied:
            return .notFound

        case .authError:
            return .notSignedIn

        case .configuration:
            return .invalidConfig

        case .httpStatusError(_, _, let underlyingError):
            return .requestFailed(response: nil, cause: underlyingError)

        case .validation:
            return .invalidInput

        case .service, .unknown:
            return .serviceError
        }
    }
}
