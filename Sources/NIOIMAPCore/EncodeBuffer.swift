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
import struct NIO.ByteBufferView
import struct NIO.CircularBuffer

public struct EncodeBuffer {
    public enum Mode: Equatable {
        case client
        case server(streamingAttributes: Bool = false)
    }

    var hasMoreChunks: Bool {
        self._buffer.readableBytes > 0
    }

    var mode: Mode
    var capabilities: [Capability]
    @usableFromInline internal var _buffer: ByteBuffer
    @usableFromInline internal var _stopPoints: CircularBuffer<Int> = []

    public init(_ buffer: ByteBuffer, mode: Mode, capabilities: [Capability]) {
        self._buffer = buffer
        self.mode = mode
        self.capabilities = capabilities
    }

    func preconditionCapability(_ capability: Capability, file: StaticString = #file, line: UInt = #line) {
        precondition(self.capabilities.contains(capability), "Missing capability: \(capability.rawValue)", file: file, line: line)
    }
}

extension EncodeBuffer {
    public struct Chunk {
        public var bytes: ByteBuffer
        public var waitForContinuation: Bool
    }

    public mutating func nextChunk() -> Chunk {
        switch self.mode {
        case .client:
            if let stopPoint = self._stopPoints.popFirst() {
                return .init(bytes: self._buffer.readSlice(length: stopPoint - self._buffer.readerIndex)!,
                             waitForContinuation: stopPoint != self._buffer.writerIndex)
            } else {
                precondition(self._buffer.readableBytes > 0, "No next chunk to send.")
                return .init(bytes: self._buffer.readSlice(length: self._buffer.readableBytes)!, waitForContinuation: false)
            }
        case .server:
            return .init(bytes: self._buffer.readSlice(length: self._buffer.readableBytes)!, waitForContinuation: false)
        }
    }

    @discardableResult
    public mutating func markStopPoint() -> Int {
        if self.mode == .client {
            self._stopPoints.append(self._buffer.writerIndex)
        }
        return 0
    }
}

extension EncodeBuffer {
    @discardableResult
    @inlinable
    public mutating func writeString(_ string: String) -> Int {
        self._buffer.writeString(string)
    }

    @discardableResult
    @inlinable
    public mutating func writeBytes<Bytes: Sequence>(_ bytes: Bytes) -> Int where Bytes.Element == UInt8 {
        return self._buffer.writeBytes(bytes)
    }

    @discardableResult
    @inlinable
    public mutating func writeBuffer(_ buffer: inout ByteBuffer) -> Int {
        self._buffer.writeBuffer(&buffer)
    }

    @inlinable
    public mutating func clear() {
        self._stopPoints.removeAll()
        self._buffer.clear()
    }
}
