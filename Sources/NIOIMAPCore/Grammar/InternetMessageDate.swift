//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// A textual RFC-2822 date.
///
/// See RFC-2822 section 3.3. “Date and Time Specification”.
///
/// Use `String(init(_: InternetMessageDate)` to get the underlying string representation.
public struct InternetMessageDate: Equatable {
    
    var value: String
    
    /// Creates a new `InternetMessageDate` from a given `String`.
    /// - parameter string: A `String` containing some textual date value.
    public init(_ string: String) {
        self.value = string
    }
}

extension String {
    
    /// Creates a new `String` from an `InternetMessageDate`
    /// - parameter date: The `InternetMessageDate`.
    public init(_ date: InternetMessageDate) {
        self = date.value
    }
}

extension InternetMessageDate: ExpressibleByStringLiteral {
    
    /// Creates a new `InternetMessageDate` from a given `String`.
    /// - parameter stringLiteral: A `String` containing some textual date value.
    public init(stringLiteral value: String) {
        self.value = value
    }
}

// MARK: - Encoding
extension EncodeBuffer {
    
    @discardableResult mutating func writeInternetMessageDate(_ date: InternetMessageDate) -> Int {
        self.writeString(date.value)
    }
    
}
