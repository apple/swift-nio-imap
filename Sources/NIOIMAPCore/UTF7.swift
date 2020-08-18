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
            if let asciiValue = char.asciiValue, asciiValue > 0x1F, asciiValue < 0x7F {
                buffer.writeInteger(asciiValue)
                if asciiValue == UInt8(ascii: "&") {
                    buffer.writeInteger(UInt8(ascii: "-"))
                }
                index = string.index(after: index)
            } else {
                // complicated character, time for Base64
                var specials: [UInt8] = []
                while index < string.endIndex { // append all non-ascii chars to an array
                    let char = string[index]
                    if let ascVal = char.asciiValue, ascVal > 0x1F, ascVal < 0x7F {
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
                buffer.writeInteger(UInt8(ascii: "&"))
                buffer.writeSubstring(b64.prefix { $0 != Character(.init(UInt8(ascii: "=")))})
                buffer.writeInteger(UInt8(ascii: "-"))
            }
        }

        return buffer
    }

    public static func decode(_ buffer: ByteBuffer) throws -> String {
        var string: String = ""

        var buffer = buffer
        while let byte = buffer.readInteger(as: UInt8.self) {
            if byte == UInt8(ascii: "&") {
                // check if the string is &-, if so then ignore the -
                if buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) == UInt8(ascii: "-") {
                    buffer.moveReaderIndex(forwardBy: 1)
                    string.append("&")
                } else {
                    // get all the specials until we return to normal non-base64
                    var specials: [UInt8] = []
                    while let byte = buffer.readInteger(as: UInt8.self) {
                        if byte == UInt8(ascii: "-") {
                            break
                        } else {
                            specials.append(byte)
                        }
                    }

                    while specials.count % 4 > 0 {
                        specials.append(UInt8(ascii: "="))
                    }
                    let decoded = try Base64.decode(encoded: specials)
                    var iterator = decoded.makeIterator()

                    precondition(decoded.count % 2 == 0, "Expected an even number of bytes.")
                    var output: [UInt16] = []
                    while let high = iterator.next(), let low = iterator.next() {
                        output.append(UInt16(high) << 8 | UInt16(low))
                    }
                    string.append(String(decoding: output, as: Unicode.UTF16.self))
                }
            } else {
                string.append(Character(.init(byte)))
            }
        }

        return string
    }
}
