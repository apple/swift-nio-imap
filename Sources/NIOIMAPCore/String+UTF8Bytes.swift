//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

extension String {
    /// Decodes `bytes` as UTF-8, or returns `nil` if they are not valid UTF-8.
    ///
    /// This is `String(validating:as:)` under another name, and it is a thin wrapper on purpose. The
    /// hand-rolled decode loop it replaces — accumulate `[Unicode.Scalar]`, then
    /// `String(String.UnicodeScalarView(scalars))` — was a dominant source of the parser's
    /// allocations, because the `UnicodeScalarView` init appends scalar by scalar
    /// and regrows the string's storage as it goes. The stdlib initialiser decodes and validates in
    /// one pass into one correctly-sized allocation.
    ///
    /// Behaviour is identical, including the cases that are easy to get wrong: UTF-16 surrogates,
    /// overlong encodings and scalars above U+10FFFF are all rejected by both, NUL is valid UTF-8 and
    /// accepted by both, and an empty input yields `""` rather than `nil` in both.
    init?<T: Collection>(validatingUTF8Bytes bytes: T) where T.Element == UInt8 {
        guard let string = String(validating: bytes, as: UTF8.self) else { return nil }
        self = string
    }

    /// Decodes bytes as UTF-8, skipping any that are invalid.
    /// Ignores any invalid UTF8 bytes, and so should *only* be used when
    /// displaying the string to a user. Don't use over the network.
    ///
    /// - Note: Deliberately *not* `String(decoding:as:)`, which substitutes U+FFFD where this drops
    ///   the bytes outright. The difference is pinned by a test.
    init<T: Collection>(bestEffortDecodingUTF8Bytes buffer: T) where T.Element == UInt8 {
        // Fast path: valid UTF-8 is the overwhelmingly common case, and then there is nothing to skip
        // and the stdlib does the whole job in one allocation.
        if let string = String(validating: buffer, as: UTF8.self) {
            self = string
            return
        }
        // Slow path: decode scalar by scalar and drop what does not decode. No
        // `withContiguousStorageIfAvailable` — when that returned `nil` the old implementation yielded
        // `""` for the entire input rather than decoding it.
        var decoder = UTF8()
        var bytes = buffer.makeIterator()
        self = ""
        self.reserveCapacity(buffer.count)
        decodeLoop: while true {
            switch decoder.decode(&bytes) {
            case .scalarValue(let scalar):
                self.unicodeScalars.append(scalar)
            case .emptyInput:
                break decodeLoop
            case .error:
                continue  // Skip it, which is what "best effort" means here.
            }
        }
    }
}
