//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// `CodableCache` conforming cache which stores objects on disk.
class DiskCache<T: Codable>: CodableCache {

    // MARK: - Types

    typealias ResourceObject = (url: Foundation.URL, resourceValues: URLResourceValues)

    // MARK: - Properties

    /// The name of disk storage, this will be used as folder name within the caches directory.
    let name: String

    /// Data protection is used to store files in an encrypted format on disk and to decrypt them on demand.
    let protectionType: FileProtectionType?

    /// The computed path of the cache `directory+name`.
    let path: String

    /// File manager to read/write to the disk.
    let fileManager: FileManager

    /// The reentrant lock used to serialize mutating cache operations.
    let writeLock = NSRecursiveLock()

    // MARK: - Lifecycle

    /// Initialize a disk cache instance.
    /// - Parameters:
    ///   - name: The name of disk storage, this will be used as folder name within the caches directory.
    ///   - protectionType: Encryption policy for storing and decrypting files on disk. Defaults to `nil`.
    ///   - fileManager: File manager to read/write to the disk. A default instance is provided.
    init(name: String, protectionType: FileProtectionType? = nil, fileManager: FileManager = .default) throws {
        self.name = name
        self.protectionType = protectionType
        self.fileManager = fileManager
        let url = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        path = url.appendingPathComponent(name, isDirectory: true).path
        if !fileManager.fileExists(atPath: path) {
            try createCacheDirectory()
        }
    }

    // MARK: - Conformance: CodableCache: Reads

    func entry(forKey key: String) throws -> CodableCacheEntry<Value> {
        let url = try makeFileUrl(for: key)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as NSError where error.code == NSFileReadNoSuchFileError {
            throw CodableCacheError.notFound
        } catch {
            throw CodableCacheError.fileReadFailed(cause: error)
        }
        let object = try decodeFromData(data)
        let version = try url.resourceValues(forKeys: [.labelNumberKey]).labelNumber
        return CodableCacheEntry(object: object, version: version ?? 0)
    }

    func version(forKey key: String) throws -> Int {
        let url = try makeFileUrl(for: key)
        guard let version = try url.resourceValues(forKeys: [.labelNumberKey]).labelNumber else {
            throw CodableCacheError.notFound
        }
        return version
    }

    // MARK: - Conformance: CodableCache: Writes

    func setObject(_ object: T, forKey key: String, version: Int) throws {
        writeLock.lock()
        defer { writeLock.unlock() }

        let data = try encodeToData(object)
        var url = try makeFileUrl(for: key)

        // Ensure the intermediate directories exist
        let directory = url.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(atPath: directory.path, withIntermediateDirectories: true, attributes: nil)
        }
        let success = fileManager.createFile(atPath: url.path, contents: data)
        guard success else {
            throw CodableCacheError.fileCreationFailed
        }
        var resourceValues = URLResourceValues()
        resourceValues.labelNumber = version
        try url.setResourceValues(resourceValues)
    }

    func updateObject(forKey key: String, updateHandler: (CodableCacheEntry<Value>?) -> Updatable<CodableCacheEntry<Value>>) throws {
        writeLock.lock()
        defer { writeLock.unlock() }

        let existingEntry: CodableCacheEntry<Value>?
        do {
            existingEntry = try entry(forKey: key)
        } catch CodableCacheError.notFound {
            existingEntry = nil
        }
        switch updateHandler(existingEntry) {
        case .newValue(let updatedEntry):
            try setObject(updatedEntry.object, forKey: key, version: updatedEntry.version)
        case .oldValue:
            return
        }
    }

    func removeObject(forKey key: String) throws {
        writeLock.lock()
        defer { writeLock.unlock() }

        let url = try makeFileUrl(for: key)
        do {
            try fileManager.removeItem(atPath: url.path)
        } catch {
            throw CodableCacheError.fileDeletionFailed
        }
    }

    func removeObject(forKey key: String, withVersionLessThan version: Int) throws {
        writeLock.lock()
        defer { writeLock.unlock() }

        let cachedVersion = try self.version(forKey: key)
        if cachedVersion < version {
            try removeObject(forKey: key)
        }
    }

    func removeAll() throws {
        writeLock.lock()
        defer { writeLock.unlock() }
        do {
            try fileManager.removeItem(atPath: path)
        } catch {
            throw CodableCacheError.fileDeletionFailed
        }
        try createCacheDirectory()
    }

    // MARK: - Helpers

    func createCacheDirectory() throws {
        do {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            if let protectionType {
                try fileManager.setAttributes([FileAttributeKey.protectionKey: protectionType], ofItemAtPath: path)
            }
        } catch {
            throw CodableCacheError.directoryCreationFailed(cause: error)
        }
    }

    func makeFileUrl(for key: String) throws -> URL {
        guard let filename = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw CodableCacheError.invalidKey
        }
        let filePath = "\(path)/\(filename)"
        return URL(fileURLWithPath: filePath, isDirectory: false)
    }

    func encodeToData(_ value: Value) throws -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            throw CodableCacheError.encodingFailed
        }
    }

    func decodeFromData(_ data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            throw CodableCacheError.decodingFailed
        }
    }
}
