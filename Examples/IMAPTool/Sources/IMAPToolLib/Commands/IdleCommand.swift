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

import ArgumentParser
import IMAPCommands
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIO
import NIOIMAP

struct IdleCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "idle",
        abstract: "Listen for IDLE (RFC 2177) updates.",
        discussion: #"""
            This writes each received event to standard output.
            """#
    )

    @OptionGroup()
    var connectionInfo: ConnectionInfo

    @Option(help: "How to format the result.")
    var outputFormat: ResultFormat = .text

    @Option(help: "Which delimiter to use to separate events in JSON output. Uses json-seq (RFC 7464) by default.")
    var recordSeparator: RecordSeparator = .recordSeparator

    @Option(
        name: .customLong("mailbox"),
        help: """
            The mailbox to listen for updates on.
            """
    )
    var mailboxName: MailboxName = .inbox

    func run() async throws {
        try await IMAPConnection.withAuthenticatedConnection(info: connectionInfo) { id, connection in
            _ = try await select(
                connection: connection,
                createMailbox: .fail,
                mailbox: mailboxName
            )

            let terminator: Data = {
                switch outputFormat {
                case .text: return Data("\n".utf8)
                case .json: return Data(recordSeparator.separatorBytes)
                }
            }()

            try await runIdle(connection: connection) { _, events in
                for try await event in events {
                    writeResult(
                        result: event,
                        format: outputFormat,
                        terminator: terminator
                    )
                }
            }
        }
    }
}

enum RecordSeparator: Equatable, Sendable {
    /// 0x1e
    case recordSeparator
    /// 0x0a
    case lineFeed
    /// 0x0d
    case carriageReturn
}

extension RecordSeparator: ExpressibleByArgument {
    init?(argument: String) {
        switch argument.lowercased() {
        case "1e", "rs", "recordseparator", "json-seq":
            self = .recordSeparator
        case "0a", "lf", "linefeed":
            self = .lineFeed
        case "0d", "cr", "carriagereturn":
            self = .carriageReturn
        default:
            return nil
        }
    }
}

extension RecordSeparator {
    var separatorBytes: [UInt8] {
        switch self {
        case .recordSeparator: [0x1e]
        case .lineFeed: [0x0a]
        case .carriageReturn: [0x0d]
        }
    }
}
