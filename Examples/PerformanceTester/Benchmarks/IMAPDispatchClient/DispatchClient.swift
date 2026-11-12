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

import Dispatch
import IMAPCorpus
import NIO
import NIOIMAP

/// A client whose transport is `DispatchData` in both directions, written twice.
///
/// This is the before-and-after measurement for the buffer migration as a `DispatchIO` or
/// Network.framework caller experiences it. The same cases run against two libraries — this working
/// tree, and a worktree of the pre-migration library, pinned by commit — selected by `IMAP_IMPL` in
/// `Package.swift`, which also defines `IMAP_LEGACY_BUFFERS` to pick the matching half of this driver:
///
/// | | before (`DispatchClient+Legacy.swift`) | after (`DispatchClient+Current.swift`) |
/// |---|---|---|
/// | read | copy every received region into one `ByteBuffer`, compact when the read prefix passes half | append every region to an ``IMAPInputBuffer``, parse where it landed |
/// | payload | copy it out of the accumulator | keep the `IMAPBuffer` the parser handed over |
/// | write | encode into the encoder's `ByteBuffer`, then `DispatchData(bytes:)` | encode into `IMAPOutputBuffer`, then `makeDispatchData()`, which donates large regions and copies short ones |
///
/// Two things about the shape of this comparison are worth stating, because they bound what the
/// numbers mean.
///
/// **The `main` side is the best client that API allows, not the client anybody wrote.** It reserves
/// capacity up front so appending never reallocates in steady state, it compacts amortised rather than
/// after every parse, and it copies each payload *out* of the accumulator rather than holding a slice
/// of it. That last one costs a copy per payload, and it is the deliberate choice: holding a slice
/// instead leaves the accumulator's storage multiply-referenced, so the next append copies the whole
/// thing on write — unpredictably, and usually for more bytes. A careful engineer on `main` pays the
/// payload copy to avoid that, so that is what is measured. The consequence is that every number here
/// is a **floor** on what the migration is worth: a less careful `main` client does worse.
///
/// **The `IMAPInputBuffer` side is the shape the library recommends, not the only one available.** A
/// client can hand a `DispatchData` to the parser directly — `DispatchData` conforms to
/// `ConsumableParserInputBuffer` — and that costs less code and more time: the gather walks every live
/// region twice per parse call, and extraction always copies, because `withStableRegions` passes no
/// owner. The existing `parse.dispatch.*` cases measure that path; these cases measure the recommended
/// one, where each received region is boxed once per read and payloads are delivered by reference.
public enum DispatchClient {
    /// Which library this build measures. For logging only — **never** part of a benchmark's name,
    /// because the two configurations have to register identical case names for
    /// `benchmark baseline compare` to pair them up.
    public static var implementation: String {
        #if IMAP_LEGACY_BUFFERS
        return "main (ByteBuffer)"
        #else
        return "branch (IMAPInputBuffer + IMAPOutputBuffer)"
        #endif
    }

    /// Splits `bytes` into socket-sized reads, one `DispatchData` per read.
    ///
    /// The conversion happens here, at registration time, so no measured region contains it. Each read
    /// is its own single-region `DispatchData`, which is what a transport hands over.
    ///
    /// - Parameters:
    ///   - bytes: The corpus to split.
    ///   - size: The read size, in bytes.
    /// - Returns: The reads, in order.
    public static func reads(_ bytes: ByteBuffer, ofSize size: Int) -> [DispatchData] {
        bytes.chunks(ofSize: size).map { chunk in
            chunk.withUnsafeReadableBytes { DispatchData(bytes: $0) }
        }
    }

    /// Server response options with the literal limit raised enough to stream a large message.
    ///
    /// The library's default caps a literal at 4 KB, which is right for a server defending itself and
    /// wrong for a client fetching a message.
    ///
    /// - Parameter literalSizeLimit: The largest literal the parser will accept.
    /// - Returns: The options.
    public static func streamingOptions(literalSizeLimit: Int = 16 * 1_024 * 1_024) -> ResponseParser.Options {
        var options = ResponseParser.Options()
        options.literalSizeLimit = literalSizeLimit
        return options
    }

    /// Parses `bytes` into response model values, for the encode cases to encode.
    ///
    /// Runs at registration time. Deliberately written against a `ByteBuffer` accumulator rather than
    /// through ``receiveResponses(_:options:sink:)``: both library versions accept a `ByteBuffer` here,
    /// so this one function serves both configurations and the corpus cannot differ between them.
    ///
    /// - Parameter bytes: One of the wire corpora in ``ResponseCorpus``.
    /// - Returns: The parsed responses, in order. Continuation requests are dropped — they are not
    ///   `Response` values.
    public static func responses(parsing bytes: ByteBuffer) -> [Response] {
        var parser = ResponseParser(options: streamingOptions())
        var buffer = bytes
        var result: [Response] = []
        do {
            while let event = try parser.parseResponseStream(buffer: &buffer) {
                if case .response(let response) = event {
                    result.append(response)
                }
            }
        } catch {
            fatalError("corpus does not parse: \(error)")
        }
        return result
    }

    /// Parses ``ClientCommandCorpus/lines`` into tagged commands, for the encode cases to encode.
    ///
    /// Runs at registration time. Each line is parsed on its own, so a line that does not parse names
    /// itself in the failure.
    ///
    /// - Returns: One `TaggedCommand` per corpus line, in order.
    public static func taggedCommands() -> [TaggedCommand] {
        ClientCommandCorpus.lines.map { entry in
            var parser = CommandParser()
            var buffer = ByteBuffer(string: entry.text + "\r\n")
            do {
                guard let synchronized = try parser.parseCommandStream(buffer: &buffer),
                    case .tagged(let tagged) = synchronized.commandPart
                else {
                    fatalError("corpus command '\(entry.name)' did not parse as one tagged command")
                }
                return tagged
            } catch {
                fatalError("corpus command '\(entry.name)' does not parse: \(error)")
            }
        }
    }
}
