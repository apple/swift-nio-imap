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

import IMAPCorpus
import NIO
import NIOIMAP

/// A client whose transport is `ByteBuffer` in both directions, written twice: a `Channel`-style
/// client, reads arriving as `ByteBuffer`s and writes leaving as `ByteBuffer`s, with no `DispatchData`
/// anywhere.
///
/// The sibling of `DispatchClient`, answering the question that one cannot: what the migration is
/// worth to a client that never needed a conversion. Its `main` side pays no `DispatchData` copies, so
/// every difference is the parser and encoder themselves. The same cases run against two libraries,
/// selected by `IMAP_IMPL` in `Package.swift`, which also defines `IMAP_LEGACY_BUFFERS`:
///
/// | | before (`ByteBufferClient+Legacy.swift`) | after (`ByteBufferClient+Current.swift`) |
/// |---|---|---|
/// | read | copy every received `ByteBuffer` into one accumulator, compact when the read prefix passes half | append every `ByteBuffer` to an `IMAPInputBuffer`, parse where it landed |
/// | payload | copy it out of the accumulator | keep the `IMAPBuffer` the parser handed over |
/// | write | encode into the encoder's `ByteBuffer`, write each chunk | encode into `IMAPOutputBuffer`, write each chunk the way `IMAPClientHandler` does |
///
/// As in `DispatchClient`, **the `main` side is the best client that API allows**: capacity reserved
/// once, compaction amortised, each payload copied out of the accumulator rather than sliced from it
/// (a slice makes the next append copy the whole accumulator). Every difference is therefore a floor.
///
/// The write side uses the library's default sink, not the benchmark-local `ByteBufferOutput`: that is
/// what `IMAPClientHandler` uses, so it is what a `ByteBuffer` client gets. `ByteBufferOutput` is
/// measured against it in `IMAPEncoding`.
public enum ByteBufferClient {
    /// Sizes the cases and drivers share.
    public enum Size {
        /// 1 MiB, the unit of the payload cases.
        public static let mebibyte = 1_024 * 1_024
        /// The payload sizes of the literal and `APPEND` cases.
        public static let payloads = [mebibyte, 4 * mebibyte]
        /// A read as large as a socket buffer commonly delivers.
        public static let largeRead = 65_536
        /// The literal limit that lets a whole message stream through the parser.
        public static let streamingLiteralLimit = 16 * mebibyte
        /// What the legacy accumulator reserves up front; one `largeRead` fits.
        public static let accumulatorCapacity = 64 * 1_024
    }

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

    /// Splits `bytes` into socket-sized reads, one `ByteBuffer` per read.
    ///
    /// Each read has storage of its own, as a `Channel` read does; see `ByteBuffer.chunks(ofSize:)`.
    /// Done at registration time, so no measured region contains it.
    ///
    /// - Parameters:
    ///   - bytes: The corpus to split.
    ///   - size: The read size, in bytes.
    /// - Returns: The reads, in order.
    public static func reads(_ bytes: ByteBuffer, ofSize size: Int) -> [ByteBuffer] {
        bytes.chunks(ofSize: size)
    }

    /// The address ranges `reads` occupy, for the payload checks to tell a reference from a copy.
    ///
    /// - Parameter reads: The received buffers.
    /// - Returns: One range per read.
    static func receivedRanges(_ reads: [ByteBuffer]) -> [Range<UInt>] {
        reads.compactMap { read in
            read.withUnsafeReadableBytes { bytes in
                guard let base = bytes.baseAddress else { return nil }
                let start = UInt(bitPattern: base)
                return start..<(start + UInt(bytes.count))
            }
        }
    }

    /// Server response options with the literal limit raised enough to stream a large message.
    ///
    /// The library's default caps a literal at 4 KB, which is right for a server defending itself and
    /// wrong for a client fetching a message.
    ///
    /// - Parameter literalSizeLimit: The largest literal the parser will accept.
    /// - Returns: The options.
    public static func streamingOptions(literalSizeLimit: Int = Size.streamingLiteralLimit) -> ResponseParser.Options {
        var options = ResponseParser.Options()
        options.literalSizeLimit = literalSizeLimit
        return options
    }

    /// Parses `bytes` into response model values, for the encode cases to encode.
    ///
    /// Runs at registration time, through the same `ByteBuffer` entry point in both configurations so
    /// the corpus cannot differ between them.
    ///
    /// - Parameter bytes: One of the wire corpora in `ResponseCorpus`.
    /// - Returns: The parsed responses, in order. Continuation requests are dropped.
    public static func responses(parsing bytes: ByteBuffer) -> [Response] {
        var parser = ResponseParser(options: streamingOptions())
        #if IMAP_LEGACY_BUFFERS
        var buffer = bytes
        #else
        var buffer = IMAPInputBuffer()
        buffer.append(bytes)
        #endif
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

    /// Parses `ClientCommandCorpus.lines` into tagged commands, for the encode cases to encode.
    ///
    /// Runs at registration time. Each line is parsed on its own, so a line that does not parse names
    /// itself in the failure.
    ///
    /// - Returns: One `TaggedCommand` per corpus line, in order.
    public static func taggedCommands() -> [TaggedCommand] {
        ClientCommandCorpus.lines.map { entry in
            var parser = CommandParser()
            #if IMAP_LEGACY_BUFFERS
            var buffer = ByteBuffer(string: entry.text + "\r\n")
            #else
            var buffer = IMAPInputBuffer()
            buffer.append(ByteBuffer(string: entry.text + "\r\n"))
            #endif
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
