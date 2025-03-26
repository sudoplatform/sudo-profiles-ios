//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import Foundation
import SudoApiClient

/// Utility that manages a list of subscribers.
class SubscriberStore {

    // MARK: - Supplementary

    /// Struct that holds a weak reference to a SudoSubscriber instance.
    private struct WeakSudoSubscriber: Equatable {

        /// The identifier of the subscriber.
        let id: String

        /// The type of change the subscriber will be notified of.
        let changeType: SudoChangeType

        /// Weak reference to the subscriber instance.
        weak var subscriber: SudoSubscriber?

        // MARK: - Conformance: Equatable

        static func == (lhs: SubscriberStore.WeakSudoSubscriber, rhs: SubscriberStore.WeakSudoSubscriber) -> Bool {
            lhs.id == rhs.id && lhs.changeType == rhs.changeType
        }
    }

    // MARK: - Properties

    /// An array of weak references to subscribed instances.
    private var subscribers: [WeakSudoSubscriber] = []

    /// Queue to use for thread-safe access to subscribers list.
    private let queue = DispatchQueue(label: "com.sudoplatform.sudoprofiles.subscription.manager", attributes: .concurrent)

    // MARK: - Methods
    
    /// Will return the subscribers currently subscribed to the provided change type.
    /// - Parameter changeType: The type of change that returned subscribers are subscribed to.
    /// - Returns: An array of `SudoSubscriber`.
    func getSubscribers(forChangeType changeType: SudoChangeType) -> [SudoSubscriber] {
        queue.sync {
            subscribers.compactMap { $0.changeType == changeType ? $0.subscriber : nil }
        }
    }

    /// Adds or replaces a subscriber with the specified ID and change types.
    /// - Parameters:
    ///   - id: Subscriber ID.
    ///   - changeTypes: The set of change types associated with the SudoSubscriber.
    ///   - subscriber: Subscriber.
    func replaceSubscriber(id: String, changeTypes: Set<SudoChangeType>, subscriber: SudoSubscriber) {
        queue.async(flags: .barrier) {
            let weakSubscribers = changeTypes.map { WeakSudoSubscriber(id: id, changeType: $0, subscriber: subscriber) }
            self.subscribers.removeAll(where: {  weakSubscribers.contains($0) || $0.subscriber == nil })
            self.subscribers.append(contentsOf: weakSubscribers)
        }
    }

    /// Removes the subscriber with the specified ID.
    /// - Parameters:
    ///   - id: Subscriber ID.
    ///   - changeType: The type of `Sudo` change associated with the SudoSubscriber.
    /// - Returns: The updated list of subscribers for the provided change type.
    @discardableResult func removeSubscriber(id: String, changeType: SudoChangeType) -> [SudoSubscriber] {
        queue.sync {
            subscribers.removeAll(where: { ($0.id == id && $0.changeType == changeType) || $0.subscriber == nil })
            return subscribers.compactMap { $0.changeType == changeType ? $0.subscriber : nil }
        }
    }

    /// Removes all subscribers for the provided change type.
    /// - Parameter changeType: The change type to remove all subscribers.
    func removeSubscribers(forChangeType changeType: SudoChangeType) {
        queue.sync {
            subscribers.removeAll(where: { ( $0.changeType == changeType) || $0.subscriber == nil })
        }
    }

    /// Removes all subscribers.
    func removeAllSubscribers() {
        queue.async(flags: .barrier) {
            self.subscribers.removeAll()
        }
    }
}
