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

import Logging
import NIO
import NIOExtras

/// Creates a channel handler that logs inbound channel events to `logger` at the `.trace` level.
///
/// The event description includes the data that was read, so these lines carry message content
/// and anything else the server sends. See ``IMAPConnection/Configuration/Logging/logging``.
///
/// - Parameter logger: The logger to write to. Channel handlers run on the event loop, outside
///   any task, so `Logger.current` is not meaningful there and the logger has to be passed in.
public func makeInboundDebugHandler(
    logger: Logger
) -> some ChannelHandler {
    DebugInboundEventsHandler(
        logger: { event, _ in
            logger.trace(
                "Inbound channel event",
                metadata: ["imap.event": "\(eventDescription(event))"]
            )
        }
    )
}

/// Creates a channel handler that logs outbound channel events to `logger` at the `.trace` level.
///
/// The event description includes the data that was written, so these lines carry the commands
/// sent to the server — including credentials.
/// See ``IMAPConnection/Configuration/Logging/logging``.
///
/// - Parameter logger: The logger to write to. Channel handlers run on the event loop, outside
///   any task, so `Logger.current` is not meaningful there and the logger has to be passed in.
public func makeOutboundDebugHandler(
    logger: Logger
) -> some ChannelHandler {
    DebugOutboundEventsHandler(
        logger: { event, _ in
            logger.trace(
                "Outbound channel event",
                metadata: ["imap.event": "\(eventDescription(event))"]
            )
        }
    )
}

private func eventDescription(
    _ event: DebugInboundEventsHandler.Event
) -> String {
    switch event {
    case .registered: "registered"
    case .unregistered: "unregistered"
    case .active: "active"
    case .inactive: "inactive"
    case .read(data: let data): "read(\(String(reflecting: data)))"
    case .readComplete: "readComplete"
    case .writabilityChanged(isWritable: let isWritable): "writabilityChanged(\(isWritable ? "true" : "false"))"
    case .userInboundEventTriggered: "userInboundEventTriggered"
    case .errorCaught(let error): "errorCaught(\(error))"
    }
}

private func eventDescription(
    _ event: DebugOutboundEventsHandler.Event
) -> String {
    switch event {
    case .register: "register"
    case .bind: "bind"
    case .connect: "connect"
    case .write(data: let data): "write(\(String(reflecting: data)))"
    case .flush: "flush"
    case .read: "read"
    case .close(mode: let mode): "close(\(mode))"
    case .triggerUserOutboundEvent: "triggerUserOutboundEvent"
    }
}
