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
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The subcommands provided by `IMAPToolLib`.
///
/// This is exposed so that an embedding tool can build its own root command
/// that combines these built-in subcommands with additional ones.
public let builtinSubcommands: [any ParsableCommand.Type] = [
    AppendCommand.self,
    DeleteMessagesCommand.self,
    DownloadCommand.self,
    IdentifyCommand.self,
    IdleCommand.self,
    MailboxCommand.self,
    MessageInfoCommand.self,
    MessageFlagCommand.self,
    MoveMessageCommand.self,
    SearchMessagesCommand.self,
]

struct RootCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "imap-tool",
        subcommands: builtinSubcommands
    )
}

/// Describes how the CLI should terminate for an error thrown while parsing or
/// running a command.
///
/// ArgumentParser signals `--help`, `--version`, and other "clean" exits by
/// throwing. Those must be written to standard output with a `0` exit code,
/// whereas genuine parsing/validation errors belong on standard error with a
/// non-zero exit code (e.g. `EX_USAGE`).
struct TerminationInfo: Equatable {
    var message: String
    /// A clean exit (help/version) — print to standard output and exit `0`.
    var isCleanExit: Bool
    var code: Int32
}

func terminationInfo(for error: any Swift.Error) -> TerminationInfo {
    let exitCode = RootCommand.exitCode(for: error)
    return TerminationInfo(
        message: RootCommand.fullMessage(for: error),
        isCleanExit: exitCode == .success,
        code: exitCode.rawValue
    )
}

/// Parses command-line arguments and runs the specified IMAP tool subcommand.
public func main() async {
    do {
        var command = try RootCommand.parseAsRoot()
        if var asyncCommand = command as? AsyncParsableCommand {
            try await asyncCommand.run()
        } else {
            try command.run()
        }
    } catch {
        let info = terminationInfo(for: error)
        if info.isCleanExit {
            // Help / version / other clean exits belong on standard output.
            if !info.message.isEmpty {
                writeStandardOutput(info.message + "\n")
            }
        } else if !info.message.isEmpty {
            writeStatus("\(info.message)")
            flushStatus()
        }
        _exit(info.code)
    }
}
