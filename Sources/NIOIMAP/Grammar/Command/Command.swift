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

extension ByteBuffer {

    @discardableResult public mutating func writeCommand(_ command: NIOIMAP.Command) -> Int {
        var size = 0
        size += self.writeString("\(command.tag) ")
        size += self.writeCommandType(command.type)
        
        switch command.type {
        case .append(to: _, firstMessageMetadata: _):
            break
        default:
            size += self.writeString("\r\n")
        }
        return size
    }

}
