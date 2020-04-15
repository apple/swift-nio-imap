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

extension ByteBuffer: ByteBufferProtocol {
    
    public typealias EndiannessType = Endianness
    public typealias ReadableBytesViewType = ByteBufferView
    
    public func asString() -> String {
        return String(buffer: self)
    }
}

extension ByteBufferView: ByteBufferProtocolView {
    
}

extension Endianness: EndiannessProtocol {
    public static func bigEndian() -> Endianness {
        return .big
    }
    
    public static func littleEndian() -> Endianness {
        return .little
    }
}

extension ByteBuffer {
    
    @discardableResult mutating func writeIMAPString(_ str: String) -> Int {
        self.writeIMAPString(str.utf8)
    }
    
    @discardableResult mutating func writeIMAPString(_ str: ByteBuffer) -> Int {
        self.writeIMAPString(str.readableBytesView)
    }

    fileprivate mutating func writeIMAPString<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        
        // allSatisfy vs contains because IMO it's a little clearer
        var foundNull = false
        let canUseQuoted = bytes.allSatisfy { c in
            foundNull = foundNull || (c == 0)
            return c.isQuotedChar && !foundNull
        }
        
        if canUseQuoted {
            return self.writeString("\"") + self.writeBytes(bytes) + self.writeString("\"")
        } else if foundNull {
            return self.writeLiteral8(bytes)
        } else {
            return self.writeLiteral(bytes)
        }
    }

    @discardableResult mutating func writeBase64(_ base64: [UInt8]) -> Int {
        return self.writeBytes(base64)
    }

    @discardableResult mutating func writeLiteral<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        let length = "{\(bytes.count)}\r\n"
        return self.writeString(length) + self.writeBytes(bytes)
    }
    
    @discardableResult mutating func writeLiteral8<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        let length = "~{\(bytes.count)}\r\n"
        return
            self.writeString(length) +
            self.writeBytes(bytes)
    }

    @discardableResult mutating func writeNil() -> Int {
        return self.writeString("NIL")
    }

    @discardableResult mutating func writeSpace() -> Int {
        return self.writeString(" ")
    }

    @discardableResult mutating func writeArray<T>(_ array: [T], separator: String = " ", parenthesis: Bool = true, callback: (T, inout ByteBuffer) -> Int) -> Int {
        self.writeIfTrue(parenthesis) { () -> Int in
            return self.writeString("(")
        } +
        array.enumerated().reduce(0) { (size, row) in
            let (i, element) = row
            return
                size +
                callback(element, &self) +
                self.writeIfTrue(i < array.count - 1) { () -> Int in
                    self.writeString(separator)
                }
        } +
        self.writeIfTrue(parenthesis) { () -> Int in
            return self.writeString(")")
        }
    }

    @discardableResult func writeIfExists<T>(_ value: T?, callback: (inout T) -> Int) -> Int {
        guard var value = value else {
            return 0
        }
        return callback(&value)
    }
    
    @discardableResult func writeIfTrue(_ value: Bool, callback: () -> Int) -> Int {
        guard value else {
            return 0
        }
        return callback()
    }
    
    @discardableResult mutating func writeIfArrayHasMinimumSize<T>(array: [T], minimum: Int = 1, callback: ([T], inout ByteBuffer) -> Int) -> Int {
        guard array.count >= minimum else {
            return 0
        }
        return callback(array, &self)
    }
    
}
