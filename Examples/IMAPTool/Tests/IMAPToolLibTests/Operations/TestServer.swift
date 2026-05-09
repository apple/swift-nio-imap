//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import NIO
import NIOIMAP
import Testing
import IMAPCommands
@testable import IMAPToolLib

extension TestServer {
    /// Runs a test server that accepts a single client connection.
    ///
    /// Example:
    /// ```
    /// await TestServer.runSingleConnectionServer(
    ///     greeting: .ok(.init(text: "Hello")),
    ///     expectedCommands: [
    ///         .init(
    ///             command: .capability,
    ///             untagged: [.capabilityData([.imap4rev1, .imap4, .authenticate(AuthenticationMechanism("FOOBAR"))])],
    ///             completion: .ok(.init(text: "Done"))
    ///         ),
    ///
    ///         // add more expected commands here
    ///
    ///     ]
    /// ) { path in
    ///     try await IMAPConnection.withConnection(
    ///         configuration: IMAPConnection.Configuration(path)
    ///     ) { greeting, connection in
    ///
    ///         // add test code here
    ///
    ///     }
    /// }
    /// ```
    static func runSingleConnectionServer(
        greeting: UntaggedStatus,
        expectedCommands: [ExpectedCommand],
        sourceLocation: SourceLocation = #_sourceLocation,
        body: @Sendable @escaping (UnixDomainSocketPath) async throws -> Void
    ) async {
        let path = UnixDomainSocketPath(path: "/tmp/imap-\(String(UInt128.random(in: 0...UInt128.max), radix: 16))")
        do {
            try await runSingleConnectionTestServer(
                path: path,
                sourceLocation: sourceLocation,
                runClient: body
            ) { inbound, outbound in
                await TestServer(
                    inbound: inbound,
                    outbound: outbound,
                    greeting: greeting,
                    expectedCommands: expectedCommands,
                    sourceLocation: sourceLocation
                ).run()
            }
        } catch {
            Issue.record(error, sourceLocation: sourceLocation)
        }
    }
}

// MARK: -

final actor TestServer: Sendable {
    private let inbound: NIOAsyncChannelInboundStream<CommandStreamPart>
    private let outbound: NIOAsyncChannelOutboundWriter<Response>
    private let responseStream: AsyncStream<Response>
    private let responseContinuation: AsyncStream<Response>.Continuation
    let sourceLocation: SourceLocation

    enum Ordering: Hashable, Sendable {
        case inOrder
        case anyOrder
    }

    struct ExpectedCommand {
        var part: ExpectedPart
        var responses: [Response]
        var completion: TaggedResponse.State?

        enum ExpectedPart {
            case continuationResponse(ByteBuffer)
            case command(Command)
            case append(MailboxName, [NIOIMAPCore.AppendCommand])
        }

        /// Creates an expected command.
        ///
        /// - Parameters:
        ///   - command: The expected ``Command``.
        ///   - untagged: Untagged responses to send before the tagged response.
        ///   - completion: The tagged response to send.
        init(
            command: Command,
            untagged: [ResponsePayload] = [],
            completion: TaggedResponse.State = .ok(.init(text: "Done"))
        ) {
            self.part = .command(command)
            self.responses = untagged.map { .untagged($0) }
            self.completion = completion
        }

        init(
            part: ExpectedPart,
            responses: [Response],
            completion: TaggedResponse.State?
        ) {
            self.part = part
            self.responses = responses
            self.completion = completion
        }
    }

    let greeting: UntaggedStatus
    let expectedOrdering: Ordering
    private var expectedCommands: [ExpectedCommand]
    private var previousTag: String?
    private var runningAppend: RunningAppend?

    private init(
        inbound: NIOAsyncChannelInboundStream<CommandStreamPart>,
        outbound: NIOAsyncChannelOutboundWriter<Response>,
        greeting: UntaggedStatus,
        expectedOrdering: Ordering = .inOrder,
        expectedCommands: [ExpectedCommand],
        sourceLocation: SourceLocation
    ) {
        self.inbound = inbound
        self.outbound = outbound
        let (a, b) = AsyncStream<Response>.makeStream()
        self.responseStream = a
        self.responseContinuation = b
        self.greeting = greeting
        self.expectedOrdering = expectedOrdering
        self.expectedCommands = expectedCommands
        self.sourceLocation = sourceLocation
    }

    func waitForAll(
        deadline: Date = Date.init(timeIntervalSinceNow: 10),
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        while Date() < deadline {
            guard !expectedCommands.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(1))
        }
        let remaining = expectedCommands
        Issue.record("Timed out waiting. Remaining: \(remaining)", sourceLocation: sourceLocation)
    }

    private func run() async {
        let sourceLocation = self.sourceLocation
        let greeting = self.greeting
        let inbound = self.inbound
        let outbound = self.outbound
        await withTaskGroup { group in
            group.addTask {
                do {
                    for try await part in inbound {
                        try await self.didReceive(part)
                    }
                } catch is CancellationError {
                    // Ignore
                } catch {
                    Issue.record(error, "Error while receiving inbound", sourceLocation: sourceLocation)
                }
                await self.close()
                print("Inbound done.")
            }
            group.addTask {
                do {
                    try await outbound.write(.untagged(.conditionalState(greeting)))
                    print("Server sent greeting.")
                    for try await response in self.responseStream {
                        try await outbound.write(response)
                        print("S: \(String(reflecting: response)).")
                    }
                } catch is CancellationError {
                    // Ignore
                } catch {
                    Issue.record(error, "Error while sending outbound", sourceLocation: sourceLocation)
                }
                outbound.finish()
                print("Outbound done.")
            }
            await group.waitForAll()
        }
        let remaining = expectedCommands
        if !remaining.isEmpty {
            Issue.record(
                "Did not receive all expected commands. Remaining: \(remaining)",
                sourceLocation: sourceLocation
            )
        }
    }

    private func didReceive(_ part: CommandStreamPart) throws {
        switch part {
        case .tagged(let command):
            let expectation = try popExpected(
                command: command
            )
            try didReceive(
                command: command,
                expectation: expectation
            )
        case .continuationResponse(let response):
            let expectation = try popExpected(continuationResponse: response)
            try didReceive(
                continuationResponse: response,
                expectation: expectation
            )
        case .append(.start(tag: let tag, appendingTo: let mailbox)):
            let expectation = try popExpected(appendInto: mailbox)
            try didReceive(
                appendInto: mailbox,
                tag: tag,
                expectation: expectation
            )
        case .append(let command):
            try didReceive(appendCommand: command)
        default:
            struct UnexpectedCommandStreamPart: Swift.Error {
                var part: CommandStreamPart
            }
            throw UnexpectedCommandStreamPart(part: part)
        }
    }

    func close() {
        responseContinuation.finish()
    }
}

// MARK: Command

extension TestServer {
    private func popExpected(
        command: TaggedCommand,
    ) throws -> ExpectedCommand {
        struct UnexpectedCommand: Swift.Error {
            var command: TaggedCommand
        }

        let index: Int
        switch expectedOrdering {
        case .anyOrder:
            guard
                let i = expectedCommands.firstIndex(where: {
                    switch $0.part {
                    case .command(command.command): true
                    default: false
                    }
                })
            else {
                throw UnexpectedCommand(command: command)
            }
            index = i
        case .inOrder:
            guard
                case .command(command.command) = expectedCommands.first?.part
            else {
                throw UnexpectedCommand(command: command)
            }
            index = 0
        }

        return expectedCommands.remove(at: index)
    }

    private func didReceive(
        command: TaggedCommand,
        expectation: ExpectedCommand
    ) throws {
        print("S: -> Received command '\(command.tag)'")
        guard
            runningAppend == nil
        else { throw HasRunningAppend(mailbox: runningAppend!.mailbox) }

        guard
            previousTag == nil
        else {
            struct ReceivedCommandWhileWaitingForContinuation: Swift.Error {
                var previousTag: String
                var command: TaggedCommand
            }
            throw ReceivedCommandWhileWaitingForContinuation(
                previousTag: previousTag!,
                command: command
            )
        }

        for response in expectation.responses {
            print("S: <- Sending response")
            responseContinuation.yield(response)
        }
        if let c = expectation.completion {
            print("S: <- Sending completion for command '\(command.tag)'")
            responseContinuation.yield(
                .tagged(
                    TaggedResponse(
                        tag: command.tag,
                        state: c
                    )
                )
            )
        } else {
            previousTag = command.tag
        }
    }
}

// MARK: Continuation Response

extension TestServer {
    private func popExpected(
        continuationResponse response: ByteBuffer
    ) throws -> ExpectedCommand {
        struct UnexpectedContinuationResponse: Swift.Error {
            var bytes: ByteBuffer
        }

        let index: Int
        switch expectedOrdering {
        case .anyOrder:
            guard
                let i = expectedCommands.firstIndex(where: {
                    switch $0.part {
                    case .continuationResponse(response): true
                    default: false
                    }
                })
            else {
                throw UnexpectedContinuationResponse(bytes: response)
            }
            index = i
        case .inOrder:
            guard
                case .continuationResponse(response) = expectedCommands.first?.part
            else {
                throw UnexpectedContinuationResponse(bytes: response)
            }
            index = 0
        }
        return expectedCommands.remove(at: index)
    }

    private func didReceive(
        continuationResponse: ByteBuffer,
        expectation: TestServer.ExpectedCommand
    ) throws {
        print("S: -> Received continuation response")
        guard
            runningAppend == nil
        else { throw HasRunningAppend(mailbox: runningAppend!.mailbox) }

        for response in expectation.responses {
            print("S: <- Sending response")
            responseContinuation.yield(response)
        }
        if let c = expectation.completion {
            struct NoPreviousTagForTaggedResponse: Swift.Error {
                var continuationResponse: ByteBuffer
            }

            guard
                let tag = previousTag
            else {
                throw NoPreviousTagForTaggedResponse(
                    continuationResponse: continuationResponse
                )
            }
            previousTag = nil

            print("S: <- Sending completion for command '\(tag)'")
            responseContinuation.yield(
                .tagged(
                    TaggedResponse(
                        tag: tag,
                        state: c
                    )
                )
            )
        }
    }
}

// MARK: Append

extension TestServer {
    private func popExpected(
        appendInto mailbox: MailboxName
    ) throws -> RunningAppend {
        struct UnexpectedAppend: Swift.Error {
            var mailbox: MailboxName
        }

        let index: Int
        switch expectedOrdering {
        case .anyOrder:
            guard
                let i = expectedCommands.firstIndex(where: {
                    switch $0.part {
                    case .append(mailbox, _): true
                    default: false
                    }
                })
            else {
                throw UnexpectedAppend(mailbox: mailbox)
            }
            index = i
        case .inOrder:
            guard
                case .append(mailbox, _) = expectedCommands.first?.part
            else {
                throw UnexpectedAppend(mailbox: mailbox)
            }
            index = 0
        }
        let e = expectedCommands.remove(at: index)
        guard
            case .append(_, let commands) = e.part
        else { fatalError() }
        return RunningAppend(
            mailbox: mailbox,
            remainingCommands: commands[...],
            responses: e.responses,
            completion: e.completion
        )
    }

    private func didReceive(
        appendInto mailbox: MailboxName,
        tag: String,
        expectation: RunningAppend
    ) throws {
        guard
            runningAppend == nil
        else { throw HasRunningAppend(mailbox: runningAppend!.mailbox) }

        runningAppend = expectation
        previousTag = tag
    }

    private func didReceive(
        appendCommand command: NIOIMAPCore.AppendCommand
    ) throws {
        switch command {
        case .start: print("S: -> Received append command (start)")
        case .beginMessage: print("S: -> Received append command (beginMessage)")
        case .messageBytes: print("S: -> Received append command (messageBytes)")
        case .endMessage: print("S: -> Received append command (endMessage)")
        case .beginCatenate: print("S: -> Received append command (beginCatenate)")
        case .catenateURL: print("S: -> Received append command (catenateURL)")
        case .catenateData: print("S: -> Received append command (catenateData)")
        case .endCatenate: print("S: -> Received append command (endCatenate)")
        case .finish: print("S: -> Received append command (finish)")
        }

        struct UnexpectedAppendCommand: Swift.Error {
            var command: NIOIMAPCore.AppendCommand
        }

        guard var runningAppend else { throw UnexpectedAppendCommand(command: command) }

        let expected = runningAppend.remainingCommands.popFirst()
        guard command == expected else { throw UnexpectedAppendCommand(command: command) }

        guard
            runningAppend.remainingCommands.isEmpty
        else {
            self.runningAppend = runningAppend
            return
        }

        self.runningAppend = nil

        for response in runningAppend.responses {
            print("S: <- Sending response")
            responseContinuation.yield(response)
        }
        if let c = runningAppend.completion {
            struct NoPreviousTagForTaggedResponse: Swift.Error {
                var append: MailboxName
            }

            guard
                let tag = previousTag
            else {
                throw NoPreviousTagForTaggedResponse(
                    append: runningAppend.mailbox
                )
            }
            previousTag = nil

            print("S: <- Sending completion for append command '\(tag)'")
            responseContinuation.yield(
                .tagged(
                    TaggedResponse(
                        tag: tag,
                        state: c
                    )
                )
            )
        }
    }

    struct HasRunningAppend: Swift.Error {
        var mailbox: MailboxName
    }

    struct RunningAppend {
        var mailbox: MailboxName
        var remainingCommands: ArraySlice<NIOIMAPCore.AppendCommand>
        var responses: [Response]
        var completion: TaggedResponse.State?
    }
}

struct UnixDomainSocketPath: Hashable, Sendable {
    var path: String
}

extension IMAPConnection.Configuration {
    init(
        _ path: UnixDomainSocketPath
    ) {
        self.init(
            endpoint: .unixDomainSocket(path: path.path),
            useTLS: false,
            logging: .logging
        )
    }
}

private func runSingleConnectionTestServer(
    path: UnixDomainSocketPath,
    sourceLocation: SourceLocation,
    runClient: @Sendable @escaping (UnixDomainSocketPath) async throws -> Void,
    runConnection:
        @Sendable @escaping (NIOAsyncChannelInboundStream<CommandStreamPart>, NIOAsyncChannelOutboundWriter<Response>)
        async throws -> Void,
) async throws {
    let channel = try await makeServerChannel(path: path)
    try await withThrowingTaskGroup { group in
        try await channel.executeThenClose { serverChannelInbound in
            group.addTask {
                print("Client started.")
                do {
                    try await runClient(path)
                } catch {
                    Issue.record(error, sourceLocation: sourceLocation)
                    throw error
                }
                print("Client done.")
            }

            for try await connectionChannel in serverChannelInbound {
                group.addTask {
                    print("New server connection.")
                    do {
                        try await connectionChannel.executeThenClose { inbound, outbound in
                            try await runConnection(inbound, outbound)
                        }
                    } catch {
                        print("Server error: \(error)")
                    }
                    print("Server connection done.")
                }
                // Exit the loop. We only want 1 connection.
                break
            }

            _ = await group.nextResult()
            group.cancelAll()
        }
        print("Server done.")
    }
}

private func makeServerChannel(
    path: UnixDomainSocketPath,
) async throws -> NIOAsyncChannel<NIOAsyncChannel<CommandStreamPart, Response>, Never> {
    try await ServerBootstrap(
        group: MultiThreadedEventLoopGroup.sharedEventLoopGroup
    ).bind(
        unixDomainSocketPath: path.path,
        cleanupExistingSocketFile: true,
        serverBackPressureStrategy: nil
    ) { childChannel in
        childChannel.eventLoop.makeCompletedFuture {
            try childChannel.pipeline.syncOperations.addHandler(ByteToMessageHandler(FrameDecoder()))
            try childChannel.pipeline.syncOperations.addHandler(makeInboundDebugHandler(name: "S"))
            try childChannel.pipeline.syncOperations.addHandler(makeOutboundDebugHandler(name: "S"))
            try childChannel.pipeline.syncOperations.addHandler(IMAPServerHandler())
            return try NIOAsyncChannel<CommandStreamPart, Response>(
                wrappingChannelSynchronously: childChannel
            )
        }
    }
}
