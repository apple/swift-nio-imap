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
    
    public struct ResponseDecoder: ByteToMessageDecoder {

        public typealias InboundOut = ResponseStream

        internal(set) var parser: ResponseParser

        public init(bufferLimit: Int = 1_000) {
            self.parser = ResponseParser(bufferLimit: bufferLimit)
        }

        public mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
            let save = buffer
            do {
                let result = try self.parser.parseResponseStream(buffer: &buffer)
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
