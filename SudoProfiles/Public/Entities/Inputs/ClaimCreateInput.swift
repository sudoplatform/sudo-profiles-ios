//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Input used to create a claim when calling the `SudoProfilesClient.createSudo(input:)` method.
public struct ClaimCreateInput: Equatable, Hashable {

    // MARK: - Supplementary

    /// Claim value.
    /// - string: String value.
    /// - blob: Blob value represented as a `DataReference`.
    public enum Value: Equatable {
        case string(String)
        case blob(DataReference)
    }

    // MARK: - Properties
    
    /// The name of the claim to create.
    public let name: String
    
    /// The value of the claim.
    public let value: Value

    // MARK: - Lifecycle
    
    /// Initialize a claim create input.
    /// - Parameters:
    ///   - name: The name of the claim to create.
    ///   - value: The value of the claim.
    public init(name: String, value: Value) {
        self.name = name
        self.value = value
    }

    /// Initialize a claim create input.
    /// - Parameters:
    ///   - name: The name of the claim to create.
    ///   - stringValue: The `String` value of the claim.
    public init(name: String, stringValue: String) {
        self.init(name: name, value: .string(stringValue))
    }

    /// Initializes an input to create a blob claim.
    /// - Parameters:
    ///   - name: The name of the claim to create.
    ///   - dataReference: The `DataReference` value of the `blob` type claim.
    public init(name: String, dataReference: DataReference) {
        self.init(name: name, value: .blob(dataReference))
    }

    /// Initializes an input to create a blob claim.
    /// - Parameters:
    ///   - name: The name of the claim to create.
    ///   - data: The `Data` value of the `blob` type claim.
    public init(name: String, data: Data) {
        self.init(name: name, dataReference: .data(data))
    }

    /// Initializes an input to create a blob claim.
    /// - Parameters:
    ///   - name: The name of the claim to create.
    ///   - fileUrl: The file URL pointing at the data of the `blob` type claim.
    public init(name: String, fileUrl: URL) {
        self.init(name: name, dataReference: .fileUrl(fileUrl))
    }

    // MARK: - Conformance: Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
