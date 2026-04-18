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

/// Encodes and decodes modified UTF-7 as used in IMAP mailbox names.
///
/// IMAP defines a modified version of UTF-7 encoding in RFC 3501 Section 5.1.3 for
/// representing non-ASCII characters in mailbox names. This encoding is necessary because
/// mailbox names must be transmitted as UTF-7 in the IMAP protocol, even when the client
/// and server both support UTF-8.
///
/// ## Modified UTF-7 Rules
///
/// The modified UTF-7 encoding replaces the standard UTF-7 "shift" characters:
/// - Uses `&` (U+0026) instead of `+` to begin Base64 sequences
/// - Uses `-` (U+002D) instead of `-` to end Base64 sequences (when no non-ASCII characters)
/// - The sequence `&-` encodes a literal `&` character
///
/// All other ASCII printable characters (0x20-0x7E) are encoded literally.
///
/// ## Example
///
/// ```swift
/// let mailbox = "Sent &Aw0-Items"  // "Sent & Items" with & encoded
/// let decoded = ModifiedUTF7.decode(mailbox)
/// // decoded ≈ "Sent & Items"
/// ```
///
/// - SeeAlso: [RFC 3501 Section 5.1.3](https://datatracker.ietf.org/doc/html/rfc3501#section-5.1.3)
public enum ModifiedUTF7 {
    /// Thrown when a UTF-7 decoder receives an odd number of bytes.
    ///
    /// UTF-7 Base64 encoding produces an even number of bytes, so an odd count
    /// indicates corrupted or invalid data.
    public struct OddByteCountError: Error {
        /// The number of bytes given to the decoder.
        public var byteCount: Int
    }

    /// Thrown when bytes cannot successfully roundtrip through encoding and decoding.
    ///
    /// This typically indicates the encoded data is corrupted or uses invalid UTF-7 sequences.
    public struct EncodingRoundtripError: Error {
        /// The buffer that failed to roundtrip.
        public var buffer: ByteBuffer
    }

    /// Encodes a `String` into modified UTF-7 bytes for use as an IMAP mailbox name.
    ///
    /// This function converts a Unicode string into modified UTF-7 format, where
    /// non-ASCII characters are represented using Base64 encoding with `&` as the
    /// escape character.
    ///
    /// - Parameter string: The Unicode string to encode.
    /// - Returns: A `ByteBuffer` containing modified UTF-7 bytes.
    ///
    /// - SeeAlso: [RFC 3501 Section 5.1.3](https://datatracker.ietf.org/doc/html/rfc3501#section-5.1.3)
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
                while index < string.endIndex {  // append all non-ascii chars to an array
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
                let b64 = Base64.encodeBytes(bytes: specials).map { $0 == UInt8(ascii: "/") ? UInt8(ascii: ",") : $0 }
                    .filter { $0 != UInt8(ascii: "=") }
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
