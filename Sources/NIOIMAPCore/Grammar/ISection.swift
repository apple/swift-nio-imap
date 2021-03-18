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

/// Wraps a percent-encoded section to be used in an IMAP URL.
public struct ISection: Equatable {
    /// The percent-encoded section.
    public var encodedSection: EncodedSection

    /// Creates a new `ISection`.
    /// - parameter encodedSection: The percent-encoded section.
    public init(encodedSection: EncodedSection) {
        self.encodedSection = encodedSection
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeISection(_ section: ISection) -> Int {
        self._writeString("/;SECTION=\(section.encodedSection.section)")
    }

    @discardableResult mutating func writeISectionOnly(_ section: ISection) -> Int {
        self._writeString(";SECTION=\(section.encodedSection.section)")
    }
}
