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
            let char = string[index]
            
            // check if it's a simple character that can be copied straight in
            if let ascVal = char.asciiValue, ascVal > 0x1F && ascVal < 0x7F {
                if char == Character(.init(UInt8(ascii: "&"))) {
                    buffer.writeBytes(char.utf8 + [0x2D]) // "&" needs to be encoded as "&-"
                } else {
                    buffer.writeBytes(char.utf8)
                }
                index = string.index(after: index)
            } else {
                
                // complicated character, time for Base64
                var specials: [UInt8] = []
                while index < string.endIndex { // append all non-ascii chars to an array
                    let char = string[index]
                    if let ascVal = char.asciiValue, ascVal > 0x1F && ascVal < 0x7F {
                        break
                    } else {
                        for uint16 in char.utf16 {
                            specials.append(UInt8(truncatingIfNeeded: uint16 >> 8))
                            specials.append(UInt8(truncatingIfNeeded: uint16 & 0xFF))
                        }
                        index = string.index(after: index)
                    }
                }
                
                // convert the buffer to base64
                let b64 = Base64.encode(bytes: specials)
                buffer.writeString("&\(b64.filter { $0 != "="} )-")
                
            }
        }
        
        return buffer
    }
    
    public static func decode(_ buffer: ByteBuffer) -> String {
        return ""
    }
    
}
