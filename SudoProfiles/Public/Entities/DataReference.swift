//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// A reference to data that can be either a raw `Data` object or a file stored at a URL.
public enum DataReference: Equatable {

    /// A reference to data stored in a file.
    /// - Parameter fileUrl: The URL of the file containing the data.
    case fileUrl(URL)

    /// A reference to raw in-memory data.
    /// - Parameter data: The `Data` instance representing the content.
    case data(Data)

    // MARK: - Methods

    /// Loads the data from this reference.
    /// - Returns: The `Data` object.
    /// - Throws: An error if the file at `fileUrl` cannot be read.
    func loadData() throws -> Data {
        switch self {
        case .data(let data):
            return data
        case .fileUrl(let fileUrl):
            return try Data(contentsOf: fileUrl)
        }
    }
}
