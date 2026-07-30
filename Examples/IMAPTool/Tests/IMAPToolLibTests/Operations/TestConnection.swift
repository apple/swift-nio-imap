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

@testable import IMAPCommands
import Foundation
@testable import IMAPToolLib
import NIO
import NIOIMAP

extension TestConnection {
    struct CommandAndResponses: Hashable, Sendable {
        var command: NIOIMAPCore.Command
        var responses: [Response]
        var completion: TaggedResponse.State
    }
}

extension TestConnection.CommandAndResponses {
    init(
        command: NIOIMAPCore.Command,
        untagged: [ResponsePayload],
        completion: TaggedResponse.State = .ok(.init(text: "Done"))
    ) {
        self.init(
            command: command,
            responses: untagged.map { .untagged($0) },
            completion: completion
        )
    }
}

extension TestConnection.CommandAndResponses {
    init(
        command: NIOIMAPCore.Command,
        fetchResponses: [FetchResponse],
        completion: TaggedResponse.State = .ok(.init(text: "Done"))
    ) {
        self.init(
            command: command,
            responses: fetchResponses.map { .fetch($0) },
            completion: completion
        )
    }
}

// MARK: -

/// A simple connection for tests — with expected commands and their responses.
final actor TestConnection: ConnectionProtocol {
    init(
        expectedOrdering: Ordering = .inOrder,
        expectedCommands: [CommandAndResponses]
    ) {
        self.expectedOrdering = expectedOrdering
        self.expectedCommands = expectedCommands
    }

    enum Ordering: Hashable, Sendable {
        case inOrder
        case anyOrder
    }

    var _nextTag = IMAPConnection.Tag.first

    func makeNextTag() -> IMAPConnection.Tag {
        defer { _nextTag = _nextTag.makeNext() }
        return _nextTag
    }

    let expectedOrdering: Ordering
    var expectedCommands: [CommandAndResponses]

    private var currentContinuations:
        [IMAPConnection.Tag: AsyncThrowingStream<Response, any Swift.Error>.Continuation] = [:]

    /// Isolated to the caller — like `IMAPConnection.send(_:isolation:_:)` — so that the
    /// handler runs in the caller's isolation domain and not on this actor.
    func send<Result>(
        _ command: NIOIMAPCore.Command,
        isolation: isolated (any Actor)? = #isolation,
        _ handler: (IMAPConnection.Tag, IMAPConnection.ResponseStream) async throws -> Result
    ) async throws -> Result {
        let (tag, responses) = try await beginCommand(command)
        let r = try await handler(tag, responses)
        await finishCommand(tag: tag)
        return r
    }

    private func beginCommand(
        _ command: NIOIMAPCore.Command
    ) throws -> (IMAPConnection.Tag, IMAPConnection.ResponseStream) {
        let commandAndResponses: TestConnection.CommandAndResponses
        switch expectedOrdering {
        case .inOrder:
            guard
                !expectedCommands.isEmpty,
                expectedCommands.first?.command == command
            else { throw Error.unexpectedCommand(command) }
            commandAndResponses = expectedCommands.removeFirst()
        case .anyOrder:
            guard
                let index = expectedCommands.firstIndex(where: { $0.command == command })
            else { throw Error.unexpectedCommand(command) }
            commandAndResponses = expectedCommands.remove(at: index)
        }

        let tag = makeNextTag()
        let responses = makeResponseStream(
            tag: tag,
            commandAndResponses: commandAndResponses
        )
        return (tag, responses)
    }

    private func finishCommand(tag: IMAPConnection.Tag) {
        currentContinuations.removeValue(forKey: tag)
    }

    private func makeResponseStream(
        tag: IMAPConnection.Tag,
        commandAndResponses: CommandAndResponses
    ) -> IMAPConnection.ResponseStream {
        let (stream, continuation) = AsyncThrowingStream<Response, any Swift.Error>.makeStream(of: Response.self)
        for r in commandAndResponses.responses {
            continuation.yield(r)
        }
        let state = commandAndResponses.completion
        continuation.yield(
            .tagged(
                TaggedResponse(
                    tag: "\(tag)",
                    state: state
                )
            )
        )
        continuation.finish()
        return IMAPConnection.ResponseStream(underlying: stream)
    }

    enum Error: Swift.Error {
        case unexpectedCommand(NIOIMAPCore.Command)
    }
}
