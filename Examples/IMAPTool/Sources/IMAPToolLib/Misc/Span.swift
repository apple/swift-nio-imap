//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

extension Span<UInt8> {
    /// Decodes the bytes as UTF-8, repairing any ill-formed sequences.
    ///
    /// `Span` is not a `Collection`, so `String(decoding:as:)` can’t take it
    /// directly. This borrows the underlying buffer for the length of the call.
    var utf8String: String {
        withUnsafeBufferPointer { String(decoding: $0, as: UTF8.self) }
    }
}
