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

/// A parameter value that can be a sequence reference or a composite value array.
///
/// This type serves as a catch-all for future extension parameter values in the RFC 4466 extension mechanism.
/// It supports both `$` references to the last command result and arrays of string components for complex
/// extension data structures.
///
/// - SeeAlso: [RFC 4466 IMAP4 Extensions: Collected Extensions](https://datatracker.ietf.org/doc/html/rfc4466)
/// - SeeAlso: [RFC 5182 SEARCHRES Extension](https://datatracker.ietf.org/doc/html/rfc5182)
public enum ParameterValue: Hashable, Sendable {
    /// Specifies a `SequenceSet` as the value.
    case sequence(LastCommandSet<SequenceNumber>)

    /// Uses an array of `String` as the value.
    case comp([String])
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeParameterValue(_ value: ParameterValue) -> Int {
        switch value {
        case .sequence(let set):
            return self.writeLastCommandSet(set)
        case .comp(let comp):
            return
                self.writeString("(") + self.writeTaggedExtensionComp(comp) + self.writeString(")")
        }
    }
}
