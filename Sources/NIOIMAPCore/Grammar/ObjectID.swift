//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// An RFC 8747 object identifier.
///
/// This is an internal type used to share code between stronger public types.
internal struct ObjectID: Hashable, Sendable {
    /// The `String` representation.
    fileprivate var rawValue: String

    /// Creates a new `ObjectID` from a `String`.
    ///
    /// Valid Object IDs are 1-255 alphanumeric or `-` or `_` characters.
    init?(_ rawValue: String) {
        guard (1...255).contains(rawValue.count) else {
            return nil
        }
        guard rawValue.utf8.allSatisfy({ $0.isObjectIDChar }) else {
            return nil
        }

        self.rawValue = rawValue
    }
}

extension String {
    internal init(_ objectID: ObjectID) {
        self = objectID.rawValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeObjectID(_ id: ObjectID) -> Int {
        self.writeString("\(id.rawValue)")
    }
}
