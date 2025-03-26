//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// The entity provided to the `SudoProfilesClient.deleteSudo(input:)` method.
public struct SudoDeleteInput: Equatable {

    // MARK: - Properties

    /// The unique identifier of the Sudo to delete.
    public let sudoId: String
    
    /// The expected version of the Sudo.
    public let version: Int

    // MARK: - Lifecycle
    
    /// Initialize a delete input.
    /// - Parameters:
    ///   - sudoId: The unique identifier of the Sudo to delete.
    ///   - version: The expected version of the Sudo.
    public init(sudoId: String, version: Int) {
        self.sudoId = sudoId
        self.version = version
    }
}
