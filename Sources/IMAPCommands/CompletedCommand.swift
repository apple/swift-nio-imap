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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOIMAP

/// A command that has completed with a tagged response from the server.
public struct CompletedCommand: Equatable, Sendable {
    /// The tag identifying this command.
    public var tag: IMAPConnection.Tag
    /// The completion status from the server.
    public var status: TaggedResponse.State
    /// The time span from sending to completion.
    public var duration: Duration
}

/// A command that completed with an `OK` response.
public struct SuccessfulCommand: Equatable, Sendable {
    /// The tag identifying this command.
    public var tag: IMAPConnection.Tag
    /// The response text from the server.
    public var text: ResponseText
    /// The time span from sending to completion.
    public var duration: Duration
}

// MARK: -

extension SuccessfulCommand {
    init(_ completed: CompletedCommand) throws {
        guard case .ok(let text) = completed.status else {
            throw CommandFailed(completedCommand: completed)
        }
        self.init(
            tag: completed.tag,
            text: text,
            duration: completed.duration
        )
    }
}

private struct CommandFailed: Swift.Error {
    var completedCommand: CompletedCommand
}

extension CommandFailed: CustomStringConvertible {
    var description: String {
        let s: String
        let text: ResponseText
        switch self.completedCommand.status {
        case .ok(let t):
            s = "OK"
            text = t
        case .no(let t):
            s = "NO"
            text = t
        case .bad(let t):
            s = "BAD"
            text = t
        }
        guard let code = text.code else {
            return "Command \(self.completedCommand.tag) failed: \(s) \(text.text)"
        }
        return "Command \(self.completedCommand.tag) failed: \(s) \(String(reflecting: code)) \(text.text)"
    }
}
