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

extension NIOIMAP.Body {

    public indirect enum TypeSinglepartType: Equatable {
        case basic(TypeBasic)
        case message(TypeMessage)
        case text(TypeText)
    }

    /// IMAPv4 `body-type-1part`
    public struct TypeSinglepart: Equatable {
        public var type: TypeSinglepartType
        public var `extension`: ExtensionSinglepart?

        /// Convenience function for a better experience when chaining multiple types.
        public static func type(_ type: TypeSinglepartType, extension: ExtensionSinglepart?) -> Self {
            return Self(type: type, extension: `extension`)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyTypeSinglepart(_ part: NIOIMAP.Body.TypeSinglepart) -> Int {
        var size = 0
        switch part.type {
        case .basic(let basic):
            size += self.writeBodyTypeBasic(basic)
        case .message(let message):
            size += self.writeBodyTypeMessage(message)
        case .text(let text):
            size += self.writeBodyTypeText(text)
        }

        if let ext = part.extension {
            size += self.writeSpace()
            size += self.writeBodyExtensionSinglePart(ext)
        }
        return size
    }

}
