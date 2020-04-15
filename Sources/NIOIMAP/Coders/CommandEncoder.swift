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
import IMAPCore

extension NIOIMAP {

    public struct CommandEncoder: MessageToByteEncoder {
        
        public typealias OutboundIn = IMAPCore.CommandStream

        public init() {
            
        }
        
        public func encode(data: IMAPCore.CommandStream, out: inout ByteBuffer) throws {
            switch data {
            case .bytes(let buffer):
                out = ByteBuffer(ByteBufferView(buffer))
            case .idleDone:
                out.writeString("DONE\r\n")
            case .command(let command):
                out.writeCommand(command)
            }
        }
    }
    
}
