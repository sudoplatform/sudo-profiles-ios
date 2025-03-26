//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// The errors returned by `CodableCache` conforming instances.
enum CodableCacheError: LocalizedError, Equatable {

    /// An error occurred while attempting to create the cache directory.
    case directoryCreationFailed(cause: Error)

    /// The requested object was not found in the cache.
    case notFound

    /// An error occurred while decoding the object stored in the cached.
    case decodingFailed

    /// An error occurred while encoding the provided object.
    case encodingFailed

    /// An error occurred while creating a new file on disk.
    case fileCreationFailed

    /// An error occurred while removing an existing file on disk.
    case fileDeletionFailed

    /// An error occurred while attempting to read a file URL.
    case fileReadFailed(cause: Error)

    /// The provided cache key could not be percent encoded correctly.
    case invalidKey

    // MARK: - Conformance: Equatable

    static func == (lhs: CodableCacheError, rhs: CodableCacheError) -> Bool {
        switch (lhs, rhs) {
        case (.directoryCreationFailed(let lhsError), .directoryCreationFailed(let rhsError)),
             (.fileReadFailed(let lhsError), .fileReadFailed(let rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)

        case (.notFound, .notFound),
             (.decodingFailed, .decodingFailed),
             (.encodingFailed, .encodingFailed),
             (.fileCreationFailed, .fileCreationFailed),
             (.fileDeletionFailed, .fileDeletionFailed),
             (.invalidKey, .invalidKey):
            return true

        default:
            return false
        }
    }
}
