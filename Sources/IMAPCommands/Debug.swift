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

import NIO
import NIOExtras
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// Creates a channel handler that logs inbound events to standard error.
public func makeInboundDebugHandler(
    name: String
) -> some ChannelHandler {
    DebugInboundEventsHandler(
        logger: { event, _ in
            debugLog(
                name: name,
                event: event
            )
        }
    )
}

/// Creates a channel handler that logs outbound events to standard error.
public func makeOutboundDebugHandler(
    name: String
) -> some ChannelHandler {
    DebugOutboundEventsHandler(
        logger: { event, _ in
            debugLog(
                name: name,
                event: event
            )
        }
    )
}

private func debugLog(
    name: String,
    event: DebugInboundEventsHandler.Event
) {
    writeStatus("\(name): Event <- \(eventDescription(event))")
}

private func debugLog(
    name: String,
    event: DebugOutboundEventsHandler.Event
) {
    writeStatus("\(name): Event -> \(eventDescription(event))")
}

/// Writes the given text to standard error.
///
/// This writes to the file descriptor directly: the C `stderr` stream is a mutable global,
/// and hence not usable from concurrent code.
func writeStatus(_ output: String, terminator: String = "\n") {
    var text = output + terminator
    text.withUTF8 { bytes in
        guard var pointer = bytes.baseAddress else { return }
        var remaining = bytes.count
        while 0 < remaining {
            // Debug output is best effort: give up when the write fails instead of retrying.
            let written = write(2, pointer, remaining)
            guard 0 < written else { break }
            pointer += written
            remaining -= written
        }
    }
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
