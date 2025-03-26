//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// `CodableCache` conforming instances save and load `Codable` conforming objects.
protocol CodableCache<Value> {

    // MARK: - Types

    associatedtype Value: Codable

    // MARK: - Methods

    /// Get cache entry which includes object with metadata.
    /// - Parameter key: Unique key to identify the object in the cache.
    /// - Returns: Object wrapper with metadata.
    func entry(forKey key: String) throws -> CodableCacheEntry<Value>

    /// Tries to retrieve the object from the storage.
    /// - Parameter key: Unique key to identify the object in the cache.
    /// - Returns: Cached object.
    func object(forKey key: String) throws -> Value

    /// Returns the version of the cached object with the provided key.
    /// - Parameter key: The key of the cached object.
    /// - Returns: A version integer.
    func version(forKey key: String) throws -> Int

    /// Removes the object by the given key.
    /// - Parameter key: Unique key to identify the object.
    func removeObject(forKey key: String) throws

    /// Removes the cached object associated with the given key if its version is
    /// lower than the specified value.
    /// - Parameters:
    ///   - key: The unique key identifying the cached object.
    ///   - version: The minimum required version. If the cached object's version is
    ///     lower than this value, it will be removed.
    func removeObject(forKey key: String, withVersionLessThan version: Int) throws

    /// Saves passed object.  If an object already exists in the cache with the same
    /// key it will be overwritten.
    /// - Parameters:
    ///   - object: Object that needs to be cached.
    ///   - key: Unique key to identify the object in the cache.
    ///   - version: Version number for the cached object.  This can be retrieved by calling `version(forKey:)`.
    ///   Default: 0.
    func setObject(_ object: Value, forKey key: String, version: Int) throws

    /// Updates the cache entry for the specified key by applying the provided `updateHandler` block.
    /// - Parameters:
    ///   - key: The unique key identifying the cache entry to update.
    ///   - updateHandler: A closure that is called with the existing cache entry, or `nil` if it was not found in the cache.
    ///   It returns an `Updatable` value which specifies whether to update the cache entry or leave it unchanged.
    func updateObject(forKey key: String, updateHandler: (CodableCacheEntry<Value>?) -> Updatable<CodableCacheEntry<Value>>) throws

    /// Removes all objects from the cache storage.
    func removeAll() throws
}

extension CodableCache {

    func object(forKey key: String) throws -> Value {
        return try entry(forKey: key).object
    }

    func setObject(_ object: Value, forKey key: String, version: Int = 0) throws {
        try setObject(object, forKey: key, version: version)
    }
}
