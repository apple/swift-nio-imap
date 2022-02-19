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

/// IMAP uses a slightly modified version of UTF7, as documented in RFC 3501 section 5.1.3.
public enum ModifiedUTF7 {
    /// Thrown if an odd number of bytes is given to the UTF-7 decoder.
    public struct OddByteCountError: Error {
        /// The number of bytes given to the decoder.
        public var byteCount: Int
    }

    /// Thrown if bytes cannot successfully roundtrip through the encoder and decoder.
    public struct EncodingRoundtripError: Error {
        /// The buffer to roundtrip
        public var buffer: ByteBuffer
    }

    /// Encodes a `String` into UTF-7 bytes.
    /// - parameter string: The string to encode.
    /// - returns: A `ByteBuffer` containing UTF-7 bytes.
    static func encode(_ string: String) -> ByteBuffer {
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
                let b64 = Base64.encodeBytes(bytes: specials).map { $0 == UInt8(ascii: "/") ? UInt8(ascii: ",") : $0 }.filter { $0 != UInt8(ascii: "=") }
                buffer.writeInteger(UInt8(ascii: "&"))
                buffer.writeBytes(b64)
                buffer.writeInteger(UInt8(ascii: "-"))
            }
        }

        return buffer
    }

    /// Decodes a `ByteBuffer` containing UTF-7 bytes into a `String`
    /// - parameter buffer: The bytes to decode.
    /// - throws: An `OddByteCountError` if `buffer` contains an off number of bytes.
    /// - returns: A `String` that can be used to e.g. display to a user.
    static func decode(_ buffer: ByteBuffer) throws -> String {
        var string = ""
        string.reserveCapacity(buffer.readableBytes)

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
                        } else if byte == UInt8(ascii: ",") {
                            specials.append(UInt8(ascii: "/"))
                        } else {
                            specials.append(byte)
                        }
                    }

                    while specials.count % 4 > 0 {
                        specials.append(UInt8(ascii: "="))
                    }
                    let decoded = try Base64.decode(bytes: specials)
                    var iterator = decoded.makeIterator()

                    guard decoded.count % 2 == 0 else {
                        throw OddByteCountError(byteCount: decoded.count)
                    }

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

extension ModifiedUTF7 {
    /// Checks that a given ByteBuffer can rountrip through IMAP's UTF-7 encoding.
    /// - parameter buffer: The `ByteBuffer` to roundtrip.
    /// - throws: An `EncodingRoundtripError` if round-tripping was not successful.
    static func validate(_ buffer: ByteBuffer) throws {
        let decoded = try self.decode(buffer)
        let encoded = self.encode(decoded)
        guard encoded == buffer else {
            throw EncodingRoundtripError(buffer: buffer)
        }
    }
}
