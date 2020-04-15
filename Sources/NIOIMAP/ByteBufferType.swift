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
}

public protocol ByteBufferProtocolView: RandomAccessCollection where Self.Element == UInt8, Self.Index: FixedWidthInteger {
    
    
    
}
