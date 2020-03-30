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

    @discardableResult mutating func writeIMAPString(_ str: ByteBuffer) -> Int {
        var buffer = str
        
        // allSatisfy vs contains because IMO it's a little clearer
        var foundNull = false
        let canUseQuoted = buffer.readableBytesView.allSatisfy { c in
            foundNull = foundNull || (c == 0)
            return c.isQuotedChar && !foundNull
        }
        
        if canUseQuoted {
            return self.writeString("\"") + self.writeBuffer(&buffer) + self.writeString("\"")
        } else if foundNull {
            return self.writeLiteral8(str)
        } else {
            return self.writeLiteral(str)
        }
    }

    @discardableResult mutating func writeBase64(_ base64: ByteBuffer) -> Int {
        var buffer = base64
        return self.writeBuffer(&buffer)
    }

    @discardableResult mutating func writeLiteral(_ buffer: ByteBuffer) -> Int {
        var buffer = buffer
        let length = "{\(buffer.readableBytes)}\r\n"
        return self.writeString(length) + self.writeBuffer(&buffer)
    }
    
    @discardableResult mutating func writeLiteral8(_ buffer: ByteBuffer) -> Int {
        var buffer = buffer
        let length = "~{\(buffer.readableBytes)}\r\n"
        return
            self.writeString(length) +
            self.writeBuffer(&buffer)
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
}
