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

import Base64Kit
import struct NIO.ByteBuffer

public enum UTF7 {
    
    public static func encode(_ string: String) -> ByteBuffer {
        var buffer = ByteBuffer()
        buffer.reserveCapacity(string.utf8.count)
        
        var index = string.startIndex
        while index < string.endIndex {
            let char = string.utf8[index]
            
            // check if it's a simple character that can be copied straight in
            if char > 0x1F && char < 0x7F {
                if char == UInt8(ascii: "&") {
                    buffer.writeBytes([char, 0x2D]) // "&" needs to be encoded as "&-"
                } else {
                    buffer.writeInteger(char)
                }
                index = string.index(after: index)
            } else {
                
                // complicated character, time for Base64
                var specials: [UInt8] = []
                while index < string.endIndex { // append all non-ascii chars to an array
                    let char = string.utf8[index]
                    if char > 0x1F && char < 0x7F {
                        break
                    } else {
                        specials.append(char)
                        index = string.index(after: index)
                    }
                }
                
                // convert the buffer to base64
                let b64 = Base64.encode(bytes: specials)
                buffer.writeString("&\(b64)-")
                
            }
        }
        
        return buffer
    }
    
    public static func decode(_ buffer: ByteBuffer) -> String {
        return ""
    }
    
}
