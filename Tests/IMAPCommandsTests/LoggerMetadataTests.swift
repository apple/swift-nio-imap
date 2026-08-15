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
import Testing

/// Pins the logger metadata `IMAPConnection` binds around command handlers.
///
/// These need no socket. The end-to-end wiring — that a command handler really does run inside
/// this scope — is covered for `send` only, by
/// `IMAPConnectionLifecycleTests.commandHandlersSeeTheCommandTagInTheTaskLocalLogger()`, which
/// needs a real socket. `sendIdle`, `sendAuthenticate` and `append` bind the same metadata at
/// their handler call sites, but that is not covered by a test.
@Suite("Logger metadata")
struct LoggerMetadataTests {

    /// The key is part of what users see in their own logs, so it is namespaced and stable.
    @Test
    func tagMetadataUsesANamespacedKey() {
        #expect(IMAPConnection.Tag.first.loggerMetadata == ["imap.tag": "A1"])
        #expect(
            IMAPConnection.Tag.first.makeNext().loggerMetadata == ["imap.tag": "A2"],
            "The metadata has to carry the tag as it goes over the wire."
        )
    }

    /// The tag is *merged onto* whatever logger the caller has bound: the handler keeps the
    /// caller's log level, handler, and metadata, and just gains `imap.tag`.
    @Test
    func tagMetadataIsLayeredOntoTheCallersLogger() async {
        var outer = Logger(label: "test.outer")
        outer.logLevel = .trace
        outer[metadataKey: "test.scope"] = "outer"

        let observed: (label: String, tag: String?, scope: String?, level: Logger.Level) =
            await withLogger(outer) { _ in
                await withLogger(mergingMetadata: IMAPConnection.Tag.first.loggerMetadata) { _ in
                    // Suspend inside the scope, as a real handler does: this both selects the
                    // async `withLogger` overload the library uses and checks that the binding
                    // survives a suspension point.
                    await Task.yield()
                    let current = Logger.current
                    return (
                        current.label,
                        current[metadataKey: "imap.tag"].map { "\($0)" },
                        current[metadataKey: "test.scope"].map { "\($0)" },
                        current.logLevel
                    )
                }
            }

        #expect(observed.tag == "A1")
        #expect(observed.label == "test.outer", "Merging must not replace the caller's logger.")
        #expect(observed.scope == "outer", "The caller's metadata must survive the merge.")
        #expect(observed.level == .trace, "The caller's log level must survive the merge.")
    }

    /// Nothing leaks out of the scope: the tag is gone once the handler returns, so a second
    /// command cannot inherit the first one's tag.
    @Test
    func tagMetadataDoesNotOutliveItsScope() async {
        let outer = Logger(label: "test.outer")

        let after = await withLogger(outer) { _ in
            await withLogger(mergingMetadata: IMAPConnection.Tag.first.loggerMetadata) { _ in
                await Task.yield()
                #expect(Logger.current[metadataKey: "imap.tag"] != nil)
            }
            return Logger.current[metadataKey: "imap.tag"]
        }

        #expect(after == nil)
    }
}
