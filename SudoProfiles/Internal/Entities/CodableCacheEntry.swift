//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// A wrapper around a cached object and an associated version property.
struct CodableCacheEntry<T: Codable> {

    // MARK: - Properties

    /// Cached object.
    let object: T

    /// The version of the cached object.
    let version: Int

    // MARK: - Lifecycle
    
    /// Initialize a cache entry.
    /// - Parameters:
    ///   - object: The cached object.
    ///   - version: The version of the cached object.  Default: 0.
    init(object: T, version: Int = 0) {
        self.object = object
        self.version = version
    }
}
