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

/// RFC 5092
public struct ISection: Equatable {
    public var encodedSection: EncodedSection

    public init(encodedSection: EncodedSection) {
        self.encodedSection = encodedSection
    }
}

/// RFC 5092
public struct ISectionOnly: Equatable {
    public var encodedSection: EncodedSection

    public init(encodedSection: EncodedSection) {
        self.encodedSection = encodedSection
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeISection(_ section: ISection) -> Int {
        self.writeString("/;SECTION=\(section.encodedSection.section)")
    }

    @discardableResult mutating func writeISectionOnly(_ section: ISectionOnly) -> Int {
        self.writeString(";SECTION=\(section.encodedSection.section)")
    }
}
