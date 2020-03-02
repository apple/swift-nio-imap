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

        private var parser = CommandParser()

        public init() {
            
        }

        public mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
            let save = buffer
            do {
                let result = try self.parser.parseCommandStream(buffer: &buffer)
                context.fireChannelRead(self.wrapInboundOut(result))
                return .continue
            } catch NIOIMAP.ParsingError.incompleteMessage {
                return .needMoreData
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
