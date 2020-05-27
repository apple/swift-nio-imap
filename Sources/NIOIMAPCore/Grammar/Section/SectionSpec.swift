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

/// IMAPv4 `section-spec`
public enum SectionSpecifier: Equatable {
    case text(_ text: SectionMessageText)
    case part(_ part: [Int], text: SectionText?)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSection(_ section: SectionSpecifier?) -> Int {
        self.writeString("[") +
            self.writeIfExists(section) { (spec) -> Int in
                self.writeSectionSpecifier(spec)
            } +
            self.writeString("]")
    }

    @discardableResult mutating func writeSectionSpecifier(_ spec: SectionSpecifier?) -> Int {
        guard let spec = spec else {
            return 0 // do nothing
        }

        switch spec {
        case .text(let text):
            return self.writeSectionMessageText(text)
        case .part(let part, text: let text):
            return
                self.writeSectionPart(part) +
                self.writeIfExists(text) { (text) -> Int in
                    self.writeString(".") +
                        self.writeSectionText(text)
                }
        }
    }
}
