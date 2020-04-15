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

import NIO

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeMediaBasicType(_ type: NIOIMAP.Media.BasicType) -> Int {
        switch type {
        case .application:
            return self.writeString(#""APPLICATION""#)
        case .audio:
            return self.writeString(#""AUDIO""#)
        case .image:
            return self.writeString(#""IMAGE""#)
        case .message:
            return self.writeString(#""MESSAGE""#)
        case .video:
            return self.writeString(#""VIDEO""#)
        case .font:
            return self.writeString(#""FONT""#)
        case .other(let buffer):
            return self.writeIMAPString(buffer)
        }
    }

    @discardableResult mutating func writeMediaBasic(_ media: NIOIMAP.Media.Basic) -> Int {
        self.writeMediaBasicType(media.type) +
        self.writeSpace() +
        self.writeIMAPString(media.subtype)
    }

}
