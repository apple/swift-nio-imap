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

extension NIOIMAP {
    
    public struct IMAPDecoderError: Error {
        public var parserError: Error
        public var buffer: ByteBuffer
    }
    
    public struct CommandDecoder: ByteToMessageDecoder {
        
        public typealias InboundOut = NIOIMAP.CommandStream

        private var ok: ByteBuffer?
        private var parser: CommandParser
        private var synchronisingLiteralParser = SynchronizingLiteralParser()
        private let autoSendContinuations: Bool
        
        public init(bufferLimit: Int = 1_000, autoSendContinuations: Bool = true) {
            self.parser = CommandParser(bufferLimit: bufferLimit)
            self.autoSendContinuations = autoSendContinuations
        }

        public mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
            let save = buffer
            do {
                let framingResult = try self.synchronisingLiteralParser.parseContinuationsNecessary(buffer)
                if self.autoSendContinuations {
                    for _ in 0..<framingResult.synchronizingLiteralCount {
                        if self.ok == nil {
                            self.ok = context.channel.allocator.buffer(capacity: 2)
                            self.ok!.writeString("OK")
                        }
                        let continuation = Response.continuationRequest(.responseText(.init(code: nil, text: self.ok!)))
                        // HACK: We shouldn't just emit those here, we should probably not be a B2MD anymore.
                        context.writeAndFlush(NIOAny(continuation), promise: nil)
                    }
                }

                if let result = try self.parser.parseCommandStream(buffer: &buffer) {
                    context.fireChannelRead(self.wrapInboundOut(result))
                    let consumedBytes = buffer.readerIndex - save.readerIndex
                    assert(buffer.writerIndex == save.writerIndex,
                           "the writer index of the buffer moved whilst parsing which is not supported: \(buffer), \(save)")
                    assert(consumedBytes > 0,
                           "allegedly, we consumed a negative amount of bytes: \(consumedBytes)")
                    self.synchronisingLiteralParser.consumed(consumedBytes)
                    assert(consumedBytes <= framingResult.maximumValidBytes,
                           "We consumed \(consumedBytes) which is more than the framing parser thought are maximally " +
                            "valid: \(framingResult), \(self.synchronisingLiteralParser)")
                    return .continue
                } else {
                    return .needMoreData
                }
            } catch {
                throw IMAPDecoderError(parserError: error, buffer: save)
            }
        }

        public mutating func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
            while try self.decode(context: context, buffer: &buffer) != .needMoreData {}
            return .needMoreData
        }
    }
    
}
