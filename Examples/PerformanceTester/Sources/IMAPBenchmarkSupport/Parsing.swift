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
import NIO
import NIOIMAP

/// Drivers that feed bytes to the parsers the way the NIO decoders do.
///
/// Each driver takes its input pre-split into chunks and a `sink` closure. The chunks model socket
/// reads: bytes are appended to an accumulator, everything parseable is parsed, and the remainder
/// waits for the next chunk. The sink exists so a benchmark can pass `blackHole` and keep the
/// optimizer from deleting the work — these drivers deliberately do not depend on `Benchmark`.
///
/// The chunked drivers accumulate into an `IMAPInputBuffer`, which is what `IMAPClientHandler` and
/// `IMAPServerHandler` do: each read is parsed where it landed, so nothing is copied when bytes arrive
/// and a message straddling two reads is parsed across them. They used to append into one `ByteBuffer`
/// and `discardReadBytes()` between reads — a memmove of the unparsed remainder per read, plus a copy of
/// every payload the parser handed out — which is what `ByteToMessageHandler` does and what this
/// migration removed. The single-shot driver takes a `ByteBuffer` too, but `IMAPInputBuffer` is the only
/// parse input, so it appends that one buffer to a fresh one and parses that.
public enum Parsing {
    /// Server response options with the size limits raised enough to stream a large literal.
    ///
    /// The library's defaults cap a literal at 4 KB, which is right for a server defending itself
    /// but wrong for a client fetching a message. A real client raises these.
    public static func streamingOptions(literalSizeLimit: Int = 16 * 1_024 * 1_024) -> ResponseParser.Options {
        var options = ResponseParser.Options()
        options.literalSizeLimit = literalSizeLimit
        return options
    }

    /// Parses server responses out of `chunks`, calling `sink` for each one.
    ///
    /// - Parameters:
    ///   - chunks: The input, split into the sizes a socket read would deliver.
    ///   - options: The parser options.
    ///   - sink: Called once per parsed response.
    /// - Returns: The number of responses parsed.
    /// - Throws: Whatever `ResponseParser` throws; a malformed corpus fails the benchmark.
    @discardableResult
    public static func parseResponses(
        chunks: [ByteBuffer],
        options: ResponseParser.Options = ResponseParser.Options(),
        sink: (ResponseOrContinuationRequest) -> Void
    ) throws -> Int {
        var parser = ResponseParser(options: options)
        var accumulator = IMAPInputBuffer()
        var count = 0
        for chunk in chunks {
            accumulator.append(chunk)
            while let response = try parser.parseResponseStream(buffer: &accumulator) {
                sink(response)
                count += 1
            }
        }
        return count
    }

    /// Parses client commands out of `chunks`, calling `sink` for each part.
    ///
    /// - Parameters:
    ///   - chunks: The input, split into the sizes a socket read would deliver.
    ///   - bufferLimit: The parser's buffer limit.
    ///   - literalSizeLimit: The parser's literal size limit.
    ///   - sink: Called once per parsed command part.
    /// - Returns: The number of command parts parsed.
    /// - Throws: Whatever `CommandParser` throws; a malformed corpus fails the benchmark.
    @discardableResult
    public static func parseCommands(
        chunks: [ByteBuffer],
        bufferLimit: Int = IMAPDefaults.lineLengthLimit,
        literalSizeLimit: Int = IMAPDefaults.literalSizeLimit,
        sink: (SynchronizedCommand) -> Void
    ) throws -> Int {
        var parser = CommandParser(bufferLimit: bufferLimit, literalSizeLimit: literalSizeLimit)
        var accumulator = IMAPInputBuffer()
        var count = 0
        for chunk in chunks {
            accumulator.append(chunk)
            while let command = try parser.parseCommandStream(buffer: &accumulator) {
                sink(command)
                count += 1
            }
        }
        return count
    }

    /// Parses one already-contiguous command, the way the previous hand-rolled tester did.
    ///
    /// The command is appended to a fresh `IMAPInputBuffer`, so the measurement includes that one append:
    /// a copy into the tail for a command under `IMAPBuffer.copyThreshold`, one small box above it.
    ///
    /// - Parameters:
    ///   - bytes: The encoded command.
    ///   - sink: Called once per parsed command part.
    /// - Returns: The number of command parts parsed.
    /// - Throws: Whatever `CommandParser` throws.
    @discardableResult
    public static func parseCommand(
        bytes: ByteBuffer,
        sink: (SynchronizedCommand) -> Void
    ) throws -> Int {
        var parser = CommandParser(bufferLimit: IMAPDefaults.lineLengthLimit)
        var input = IMAPInputBuffer()
        input.append(bytes)
        var count = 0
        while let command = try parser.parseCommandStream(buffer: &input) {
            sink(command)
            count += 1
        }
        return count
    }
}

// MARK: - DispatchData input

// The other input backing: a transport that reads into `DispatchData` — `DispatchIO`,
// Network.framework — rather than `ByteBuffer`. Such a caller appends each read with
// `IMAPInputBuffer.append(contentsOf:)`, which walks the read's regions once: a region of at least
// `IMAPBuffer.copyThreshold` bytes is kept where it is, along with the `DispatchData` that keeps it
// alive, and a smaller one is copied into the shared tail. From there parsing is the same as for a
// `ByteBuffer` read, so the `parse.dispatch.*` cases measure what appending `DispatchData` costs against
// appending `ByteBuffer`, and how a kept literal differs when its owner is a `DispatchData`: it pins the
// whole read, and is referred to only if it is at least a third of it.
extension Parsing {
    /// Converts read-sized chunks into `DispatchData` reads.
    ///
    /// One `DispatchData` per chunk, copied once here so the conversion is not inside a measured region:
    /// what a caller reading through `DispatchIO` or Network.framework is handed per read.
    ///
    /// - Parameter chunks: The input, split into the sizes a socket read would deliver.
    /// - Returns: The same bytes, one `DispatchData` per chunk.
    public static func dispatchChunks(_ chunks: [ByteBuffer]) -> [DispatchData] {
        chunks.map { chunk in
            chunk.withUnsafeReadableBytes { DispatchData(bytes: $0) }
        }
    }

    /// Parses server responses out of `DispatchData` reads, calling `sink` for each one.
    ///
    /// The `DispatchData` twin of ``parseResponses(chunks:options:sink:)``: each read is appended with
    /// `IMAPInputBuffer.append(contentsOf:)`, the way a caller whose transport hands it `DispatchData`
    /// does.
    ///
    /// - Parameters:
    ///   - chunks: The input, one `DispatchData` per socket read.
    ///   - options: The parser options.
    ///   - sink: Called once per parsed response.
    /// - Returns: The number of responses parsed.
    /// - Throws: Whatever `ResponseParser` throws; a malformed corpus fails the benchmark.
    @discardableResult
    public static func parseResponses(
        dispatchChunks chunks: [DispatchData],
        options: ResponseParser.Options = ResponseParser.Options(),
        sink: (ResponseOrContinuationRequest) -> Void
    ) throws -> Int {
        var parser = ResponseParser(options: options)
        var accumulator = IMAPInputBuffer()
        var count = 0
        for chunk in chunks {
            accumulator.append(contentsOf: chunk)
            while let response = try parser.parseResponseStream(buffer: &accumulator) {
                sink(response)
                count += 1
            }
        }
        return count
    }

    /// Parses client commands out of `DispatchData` reads, calling `sink` for each part.
    ///
    /// The `DispatchData` twin of ``parseCommands(chunks:bufferLimit:literalSizeLimit:sink:)``: each
    /// read is appended with `IMAPInputBuffer.append(contentsOf:)`.
    ///
    /// - Parameters:
    ///   - chunks: The input, one `DispatchData` per socket read.
    ///   - bufferLimit: The parser's buffer limit.
    ///   - literalSizeLimit: The parser's literal size limit.
    ///   - sink: Called once per parsed command part.
    /// - Returns: The number of command parts parsed.
    /// - Throws: Whatever `CommandParser` throws; a malformed corpus fails the benchmark.
    @discardableResult
    public static func parseCommands(
        dispatchChunks chunks: [DispatchData],
        bufferLimit: Int = IMAPDefaults.lineLengthLimit,
        literalSizeLimit: Int = IMAPDefaults.literalSizeLimit,
        sink: (SynchronizedCommand) -> Void
    ) throws -> Int {
        var parser = CommandParser(bufferLimit: bufferLimit, literalSizeLimit: literalSizeLimit)
        var accumulator = IMAPInputBuffer()
        var count = 0
        for chunk in chunks {
            accumulator.append(contentsOf: chunk)
            while let command = try parser.parseCommandStream(buffer: &accumulator) {
                sink(command)
                count += 1
            }
        }
        return count
    }
}
