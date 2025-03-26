//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// A type that represents either a new value for an update or `oldValue`, the equivalent of no update.
///
/// You can use the `Updatable` type whenever you need to update an entity without providing the
/// entity itself.  For example:
///
///     struct Dog {
///         let id: String
///         let name: String
///         let breed: String?
///     }
///     struct DogUpdateInput {
///         let name: Updatable<String>
///         let breed: Updatable<String?>
///     }
///     let breedUpdate = DogUpdateInput(name: .oldValue, breed: .newValue("labradoodle"))
///     updateDog(withId: "1234", input: breedUpdate)
public enum Updatable<Wrapped>: CustomDebugStringConvertible {
    /// No update to the value.
    case oldValue
    /// The new value stored as `Wrapped`.
    case newValue(Wrapped)

    // MARK: - Lifecycle

    /// Creates an instance that stores the new value.
    public init(_ newValue: Wrapped) {
        self = .newValue(newValue)
    }

    /// Bool flag indicating if the input is a new value
    var isNewValue: Bool {
        switch self {
        case .newValue:
            return true
        case .oldValue:
            return false
        }
    }

    /// Will return the wrapped value if the case is a `newValue`
    var newValue: Wrapped? {
        switch self {
        case .newValue(let value):
            return value
        case .oldValue:
            return nil
        }
    }

    // MARK: - Conformance: CustomDebugStringConvertible

    public var debugDescription: String {
        switch self {
        case .newValue(let value):
            var result = "Updatable("
            debugPrint(value, terminator: "", to: &result)
            result += ")"
            return result
        case .oldValue:
            return "oldValue"
        }
    }
}

extension Updatable: Equatable where Wrapped: Equatable {

    /// Returns a Boolean value indicating whether two `Updatable` instances are
    /// equal.
    ///
    /// Use this equal-to operator (`==`) to compare any two optional instances of
    /// a type that conforms to the `Equatable` protocol. The comparison returns
    /// `true` if both arguments are `oldValue` or if the two arguments wrap values
    /// that are equal. Conversely, the comparison returns `false` if only one of
    /// the arguments is `oldValue` or if the two arguments wrap values that are not
    /// equal.
    ///
    ///     let firstName: Updatable<String> = "Boo"
    ///     let lastName: Updatable<String> = "Boo"
    ///     if firstName == lastName {
    ///         print("The two names are the same.")
    ///     }
    ///     // Prints "The two names are the same."
    ///
    /// - Parameters:
    ///   - lhs: An `Updatable` value to compare.
    ///   - rhs: Another `Updatable` value to compare.
    @inlinable
    public static func == (lhs: Updatable<Wrapped>, rhs: Updatable<Wrapped>) -> Bool {
        switch (lhs, rhs) {
        case (.newValue(let lhsValue), .newValue(let rhsValue)):
            return lhsValue == rhsValue
        case (.oldValue, .oldValue):
            return true
        case (.newValue, .oldValue), (.oldValue, .newValue):
            return false
        }
    }
}

extension Updatable: Hashable where Wrapped: Hashable {

    /// Hashes the essential components of this value by feeding them into the
    /// given hasher.
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .oldValue:
            hasher.combine(0 as UInt8)
        case .newValue(let wrapped):
            hasher.combine(1 as UInt8)
            hasher.combine(wrapped)
        }
    }
}
