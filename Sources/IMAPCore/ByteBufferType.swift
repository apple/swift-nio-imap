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

public protocol EndiannessProtocol {
    
    static func bigEndian() -> Self
    static func littleEndian() -> Self
    
}

public protocol ByteBufferProtocol {
    
    associatedtype EndiannessType: EndiannessProtocol
    associatedtype ReadableBytesViewType: ByteBufferProtocolView
    
    var readableBytes: Int { get }
    var readerIndex: Int { get }
    var writerIndex: Int { get }
    var readableBytesView: ReadableBytesViewType { get }
    
    func asString() -> String
    
    func getInteger<T: FixedWidthInteger>(at index: Int, endianness: EndiannessType, as: T.Type) -> T?
    
    mutating func moveReaderIndex(forwardBy offset: Int)
    
    mutating func readString(length: Int) -> String?
    
    mutating func readSlice(length: Int) -> Self?
    
    mutating func readBytes(length: Int) -> [UInt8]?
    
    mutating func readInteger<T: FixedWidthInteger>(endianness: EndiannessType, as: T.Type) -> T?
    
    mutating func writeBytes<Bytes: Sequence>(_ bytes: Bytes) -> Int where Bytes.Element == UInt8
    
    mutating func writeString(_ string: String) -> Int
}

public protocol ByteBufferProtocolView: RandomAccessCollection where Self.Element == UInt8, Self.Index: FixedWidthInteger {
    
    
    
}

extension ByteBufferProtocol {
    
    @discardableResult public mutating func writeIMAPString(_ str: String) -> Int {
        self.writeIMAPString(str.utf8)
    }
    
    @discardableResult public mutating func writeIMAPString(_ str: Self) -> Int {
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

    @discardableResult public mutating func writeBase64(_ base64: [UInt8]) -> Int {
        return self.writeBytes(base64)
    }

    @discardableResult public mutating func writeLiteral<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        let length = "{\(bytes.count)}\r\n"
        return self.writeString(length) + self.writeBytes(bytes)
    }
    
    @discardableResult public mutating func writeLiteral8<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        let length = "~{\(bytes.count)}\r\n"
        return
            self.writeString(length) +
            self.writeBytes(bytes)
    }

    @discardableResult public mutating func writeNil() -> Int {
        return self.writeString("NIL")
    }

    @discardableResult public mutating func writeSpace() -> Int {
        return self.writeString(" ")
    }

    @discardableResult public mutating func writeArray<T>(_ array: [T], separator: String = " ", parenthesis: Bool = true, callback: (T, inout Self) -> Int) -> Int {
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

    @discardableResult public func writeIfExists<T>(_ value: T?, callback: (inout T) -> Int) -> Int {
        guard var value = value else {
            return 0
        }
        return callback(&value)
    }
    
    @discardableResult public func writeIfTrue(_ value: Bool, callback: () -> Int) -> Int {
        guard value else {
            return 0
        }
        return callback()
    }
    
    @discardableResult public mutating func writeIfArrayHasMinimumSize<T>(array: [T], minimum: Int = 1, callback: ([T], inout Self) -> Int) -> Int {
        guard array.count >= minimum else {
            return 0
        }
        return callback(array, &self)
    }
    
}
