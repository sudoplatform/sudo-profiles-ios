//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Input used to update a claim when calling the `SudoProfilesClient.updateSudo(input:)` method.
public struct ClaimUpdateInput: Equatable, Hashable {

    // MARK: - Supplementary

    /// Claim value.
    /// - string: String value.
    /// - blob: Blob value represented as a `DataReference`.
    public enum Value: Equatable {
        case string(String)
        case blob(DataReference)
    }

    // MARK: - Properties

    /// The name of the claim to update.
    public let name: String

    /// The value of the claim.  Set as `nil` to delete the claim.
    public let value: Value?

    // MARK: - Lifecycle
    
    /// Initialize an input to update a claim.
    /// - Parameters:
    ///   - name: The name of the claim to update.
    ///   - value: The value of the claim.  Set as `nil` to delete the claim.
    public init(name: String, value: Value?) {
        self.name = name
        self.value = value
    }
    
    /// Initialize an input to update a claim.
    /// - Parameters:
    ///   - name: The name of the claim to update.
    ///   - stringValue: The updated `String` value of the claim.
    public init(name: String, stringValue: String?) {
        self.init(name: name, value: stringValue.flatMap { .string($0) })
    }

    /// Initializes an input to update a blob claim.
    /// - Parameters:
    ///   - name: The name of the claim to update.
    ///   - dataReference: The updated `DataReference` value of the `blob` type claim.
    public init(name: String, dataReference: DataReference?) {
        self.init(name: name, value: dataReference.flatMap { .blob($0) })
    }

    /// Initializes an input to update a blob claim.
    /// - Parameters:
    ///   - name: The name of the claim to update.
    ///   - data: The updated blob data.
    public init(name: String, data: Data?) {
        self.init(name: name, dataReference: data.flatMap { .data($0) })
    }

    /// Initializes an input to update a blob claim.
    /// - Parameters:
    ///   - name: The name of the claim to create.
    ///   - fileUrl: The file URL pointing at the updated data of the `blob` type claim.
    public init(name: String, fileUrl: URL?) {
        self.init(name: name, dataReference: fileUrl.flatMap { .fileUrl($0) })
    }

    // MARK: - Conformance: Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension ClaimUpdateInput {
    
    /// Whether the claim is has a value of type `blob`.
    var isBlob: Bool {
        if case .blob = value {
            return true
        }
        return false
    }
}
