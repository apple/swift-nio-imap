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

import IMAPCommands
import NIO
import NIOIMAP

/// A protocol for sending commands and receiving responses, enabling testability.
///
/// In production, this is always an ``IMAPConnection``. In tests, a mock can send
/// simple commands without requiring `AUTHENTICATE` or `APPEND` support.
///
/// ## When operations use `<C: ConnectionProtocol>` vs. concrete `IMAPConnection`
///
/// Most operations in `IMAPToolLib/Operations` are generic over `ConnectionProtocol`.
/// A few — `append`, `authenticate`, `runIdle` — are written against the concrete
/// `IMAPConnection` type because they use methods (`append`, `sendAuthenticate`,
/// `sendIdle`) that are not part of this protocol. Those methods deal with
/// continuation-driven flows (literals, SASL challenges, IDLE) that don't fit the
/// simple "send a `Command`, consume the `IMAPConnection.ResponseStream`" shape, so adding them
/// here would complicate the mock surface used by tests.
///
/// ## Closure isolation
///
/// The requirement mirrors `IMAPConnection.send(_:_:)`: the handler is
/// `nonisolated(nonsending)`, so it needs to be neither `@Sendable` nor `@escaping` and runs in
/// the caller's isolation domain. Unlike an `isolated (any Actor)?` parameter — which a protocol
/// requirement cannot give a default argument — this needs nothing at the call site.
protocol ConnectionProtocol: Sendable {
    func send<Result>(
        _ command: Command,
        _ handler: nonisolated(nonsending) (IMAPConnection.Tag, IMAPConnection.ResponseStream) async throws -> Result
    ) async throws -> Result
}

extension IMAPConnection: ConnectionProtocol {}
