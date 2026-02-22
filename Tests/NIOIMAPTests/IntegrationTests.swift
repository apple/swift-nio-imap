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
import NIOIMAP
import NIOIMAPCore
import NIOTestUtils

import Testing

@Suite struct ParserIntegrationTests {
    @Test("it works with an actual connection")
    func itWorksWithAnActualConnection() {
        class CollectEverythingHandler: ChannelInboundHandler {
            typealias InboundIn = CommandStreamPart

            var allCommands: [CommandStreamPart] = []
            let collectionDonePromise: EventLoopPromise<[CommandStreamPart]>

            init(collectionDonePromise: EventLoopPromise<[CommandStreamPart]>) {
                self.collectionDonePromise = collectionDonePromise
            }

            func channelRead(context: ChannelHandlerContext, data: NIOAny) {
                let command = self.unwrapInboundIn(data)
                self.allCommands.append(command)
            }

            func errorCaught(context: ChannelHandlerContext, error: Error) {
                self.collectionDonePromise.fail(error)
                context.close(promise: nil)
            }

            func channelInactive(context: ChannelHandlerContext) {
                self.collectionDonePromise.succeed(self.allCommands)
            }

            func handlerRemoved(context: ChannelHandlerContext) {
                struct DidNotReceiveAnything: Error {}
                self.collectionDonePromise.fail(DidNotReceiveAnything())
            }
        }

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            #expect(throws: Never.self) { try group.syncShutdownGracefully() }
        }

        let collectionDonePromise = group.next().makePromise(of: [CommandStreamPart].self)
        var server: Channel?
        #expect(throws: Never.self) {
            server = try ServerBootstrap(group: group)
                .serverChannelOption(ChannelOptions.socket(.init(SOL_SOCKET), .init(SO_REUSEADDR)), value: 1)
                .childChannelInitializer { channel in
                    channel.eventLoop.makeCompletedFuture {
                        try! channel.pipeline.syncOperations.addHandlers([
                            ByteToMessageHandler(FrameDecoder()),
                            IMAPServerHandler(),
                            CollectEverythingHandler(collectionDonePromise: collectionDonePromise),
                        ])
                    }
                }
                .bind(to: .init(ipAddress: "127.0.0.1", port: 0))
                .wait()
        }
        #expect(server != nil)
        defer {
            #expect(throws: Never.self) { try server?.close().wait() }
        }

        var maybeClient: Channel?
        #expect(throws: Never.self) {
            maybeClient = try ClientBootstrap(group: group)
                .connect(to: server?.localAddress ?? SocketAddress(unixDomainSocketPath: "should fail"))
                .wait()
        }
        guard let client = maybeClient else {
            Issue.record("couldn't connect client")
            return
        }

        // try a couple of examples
        #expect(throws: Never.self) { try client.writeAndFlush("tag LOGIN \"1\" \"2\"\r\n" as ByteBuffer).wait() }
        #expect(throws: Never.self) { try client.writeAndFlush("tag NOOP\r\n" as ByteBuffer).wait() }
        #expect(throws: Never.self) { try client.close().wait() }

        let expected: [CommandStreamPart] = [
            .tagged(.init(tag: "tag", command: .login(username: "1", password: "2"))),
            .tagged(.init(tag: "tag", command: .noop)),
        ]
        var result: [CommandStreamPart]?
        #expect(throws: Never.self) {
            result = try collectionDonePromise.futureResult.wait()
        }
        #expect(result == expected)
    }
}
