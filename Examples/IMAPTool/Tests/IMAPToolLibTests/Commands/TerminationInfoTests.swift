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
@testable import IMAPToolLib
import Testing

/// Verifies how ``main()`` decides to terminate: `--help`/`--version` must be
/// treated as "clean" exits (standard output, exit code `0`), while genuine
/// parsing errors must be non-clean (standard error, non-zero exit code).
@Suite("Termination Info")
enum TerminationInfoTests {
    /// Mirrors ``main()``: parse, then run, returning whichever step throws.
    ///
    /// This matters because ArgumentParser signals `--help`/`--version` by
    /// having `run()` throw a clean-exit error — `parseAsRoot` itself does not
    /// throw for those. None of the arguments used below parse to a runnable
    /// subcommand that performs I/O.
    private static func terminationError(for arguments: [String]) async -> (any Error)? {
        do {
            var command = try RootCommand.parseAsRoot(arguments)
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
            return nil
        } catch {
            return error
        }
    }

    @Test
    static func helpRequestIsACleanExit() async throws {
        let info = terminationInfo(for: try #require(await terminationError(for: ["--help"])))
        #expect(info.isCleanExit)
        #expect(info.code == 0)
        #expect(!info.message.isEmpty)
    }

    @Test
    static func subcommandHelpRequestIsACleanExit() async throws {
        let info = terminationInfo(for: try #require(await terminationError(for: ["idle", "--help"])))
        #expect(info.isCleanExit)
        #expect(info.code == 0)
    }

    @Test
    static func parsingErrorIsNotACleanExit() async throws {
        // An unknown flag on a known subcommand is a usage error, not a clean exit.
        let info = terminationInfo(
            for: try #require(await terminationError(for: ["idle", "--this-flag-does-not-exist"]))
        )
        #expect(!info.isCleanExit)
        #expect(info.code != 0)
    }

    @Test
    static func unknownSubcommandIsNotACleanExit() async throws {
        let info = terminationInfo(
            for: try #require(await terminationError(for: ["definitely-not-a-subcommand"]))
        )
        #expect(!info.isCleanExit)
        #expect(info.code != 0)
    }
}
