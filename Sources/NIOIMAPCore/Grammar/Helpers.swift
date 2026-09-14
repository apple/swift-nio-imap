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

import struct NIO.ByteBuffer

extension EncodeBuffer {
    /// Writes an `atom` verbatim.
    ///
    /// An atom is written as-is — there is no quoting or escaping to fall back on — so anything
    /// that isn’t an atom would be injected straight into the stream.
    ///
    /// - Precondition: `str` is an `atom`. Pass a value that an owning type has already validated;
    ///   the assert only catches a violation in debug builds.
    mutating func writeAtom(_ str: String) -> Int {
        assert(str.isIMAPAtom, "\(String(reflecting: str)) is not an atom")
        return self.writeString(str)
    }
}

extension StringProtocol {
    /// Whether writing this verbatim would produce an `atom` as defined by
    /// [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501#section-9):
    /// ```
    /// atom            = 1*ATOM-CHAR
    /// ATOM-CHAR       = <any CHAR except atom-specials>
    /// ```
    ///
    /// This is a question about the encoder, not the parser: an atom carries no quoting or
    /// escaping, so its bytes and its `String` are the same thing. That does not hold for the
    /// grammar’s other string forms — a quoted string or literal can carry bytes no atom may.
    var isIMAPAtom: Bool {
        !self.isEmpty && self.utf8.allSatisfy { $0.isAtomChar }
    }
}
