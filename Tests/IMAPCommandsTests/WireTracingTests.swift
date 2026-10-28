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
import Logging
import NIO
import Testing

/// `IMAPConnection.Configuration.Logging.logging` traces channel events through the logger rather
/// than to standard error, so the traces land in the same stream as everything else.
///
/// These drive the handlers through an `EmbeddedChannel`, so they need no socket.
@Suite("Wire tracing")
struct WireTracingTests {

    /// Channel handlers run on the event loop, outside any task, so the task-local logger is not
    /// available to them: the logger has to be passed in and captured.
    @Test
    func inboundEventsAreTracedThroughThePassedLogger() throws {
        let recorder = LogRecorder()
        let channel = EmbeddedChannel()
        try channel.pipeline.syncOperations.addHandler(
            makeInboundDebugHandler(logger: recorder.logger)
        )

        try channel.writeInbound(ByteBuffer(string: "* OK ready\r\n"))

        let traces = recorder.records(message: "Inbound channel event")
        #expect(!traces.isEmpty, "The inbound event should have been traced: \(recorder.records)")
        #expect(
            traces.allSatisfy { $0.level == .trace },
            "Wire tracing is noisy, so it belongs at `.trace`: \(traces.map(\.level))"
        )
        #expect(
            traces.contains { "\($0.metadata["imap.event"] ?? "")".contains("read(") },
            "The traced event should describe the read: \(traces.map(\.metadata))"
        )
        _ = try channel.finish()
    }

    @Test
    func outboundEventsAreTracedThroughThePassedLogger() throws {
        let recorder = LogRecorder()
        let channel = EmbeddedChannel()
        try channel.pipeline.syncOperations.addHandler(
            makeOutboundDebugHandler(logger: recorder.logger)
        )

        try channel.writeOutbound(ByteBuffer(string: "A1 NOOP\r\n"))

        let traces = recorder.records(message: "Outbound channel event")
        #expect(!traces.isEmpty, "The outbound event should have been traced: \(recorder.records)")
        #expect(traces.allSatisfy { $0.level == .trace })
        _ = try channel.finish()
    }

    /// Nothing is traced when the logger does not admit `.trace`, which is what keeps the
    /// tracing free for a caller who leaves `logging: .logging` on with a production logger.
    @Test
    func tracingIsSuppressedWhenTheLoggerDoesNotAdmitTrace() throws {
        let recorder = LogRecorder()
        var logger = recorder.logger
        logger.logLevel = .info
        let channel = EmbeddedChannel()
        try channel.pipeline.syncOperations.addHandler(makeInboundDebugHandler(logger: logger))

        try channel.writeInbound(ByteBuffer(string: "* OK ready\r\n"))

        #expect(recorder.records.isEmpty, "Expected no records: \(recorder.records)")
        _ = try channel.finish()
    }
}

extension LogRecorder {
    /// A `.trace`-level logger that writes into this recorder.
    var logger: Logger {
        var logger = Logger(label: "test.wire", factory: { _ in self.handler })
        logger.logLevel = .trace
        return logger
    }
}
