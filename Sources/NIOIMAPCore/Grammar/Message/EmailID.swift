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

/// An RFC 8747 message identifier.
public struct EmailID: Hashable, Sendable {
    fileprivate var objectID: ObjectID

    /// Creates a new `EmailID` from an `ObjectID`.
    init(_ objectID: ObjectID) {
        self.objectID = objectID
    }

    /// Creates a new `EmailID` from a `String`.
    ///
    /// Valid email IDs are 1-255 alphanumeric or `-` or `_` characters.
    public init?(_ rawValue: String) {
        guard let objectID = ObjectID(rawValue) else {
            return nil
        }

        self.init(objectID)
    }
}

extension String {
    public init(_ emailID: EmailID) {
        self = String(emailID.objectID)
    }
}

// MARK: - ExpressibleByStringLiteral

extension EmailID: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)!
    }
}

// MARK: - CustomDebugStringConvertible

extension EmailID: CustomDebugStringConvertible {
    /// `value` as a `String`.
    public var debugDescription: String {
        "(\(String(self)))"
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEmailID(_ id: EmailID) -> Int {
        self.writeObjectID(id.objectID)
    }
}
