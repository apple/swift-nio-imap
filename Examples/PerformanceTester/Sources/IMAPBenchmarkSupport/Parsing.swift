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
/// migration removed. The single-shot drivers still take a `ByteBuffer`: parsing a contiguous buffer with
/// no accumulator at all is still a supported shape, and it is the one that isolates the parser.
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
        var buffer = bytes
        var count = 0
        while let command = try parser.parseCommandStream(buffer: &buffer) {
            sink(command)
            count += 1
        }
        return count
    }
}

// MARK: - DispatchData input

// The other input backing, and the one the input protocols were shaped around: `DispatchData` is the
// genuinely multi-region source, so it is what `StableRegionParserInputBuffer` and the one-pass
// `enumerateBytes` gather exist for. Until these drivers there was no benchmark feeding one, so the
// gather that avoids the recursive descent was measured only on the type that does not use it.
//
// Three costs live only on this path, all of them per parse call rather than per read:
//
// - **Two walks of every live region.** The gather asks for `regionCount` to size its table and then
//   `withStableRegions` to fill it, and each walks the whole `dispatch_data_t` tree. So the work to
//   parse one message is O(live regions), twice, where an `IMAPInputBuffer` keeps a count.
// - **A new dispatch object per consume.** `discardFirst` is `subdata(in:)`, which copies nothing but
//   creates a subrange object, once per parsed message.
// - **Extraction always copies.** `withStableRegions` passes `owner: nil`, because vouching for a region
//   would mean boxing it on every parse, where `IMAPInputBuffer` boxes a read once, on append (a read
//   under `copyThreshold` is copied into a shared tail instead). So a literal arriving as `DispatchData`
//   is copied out, and the `parse.dispatch.literal-*` cases are what that costs against the
//   `IMAPInputBuffer` ones.
//
// None of that is a defect — it is the price of a general mechanism over a type the library does not
// own — but it was undocumented as a cost and unmeasured, which is what these cases fix.
extension Parsing {
    /// Converts read-sized chunks into `DispatchData` regions.
    ///
    /// One `DispatchData` per chunk, copied once here so the conversion is not inside a measured region.
    /// Appending them builds a multi-region value that copies nothing, which is exactly the shape a
    /// caller reading through `DispatchIO` or Network.framework accumulates.
    ///
    /// - Parameter chunks: The input, split into the sizes a socket read would deliver.
    /// - Returns: The same bytes, one `DispatchData` per chunk.
    public static func dispatchChunks(_ chunks: [ByteBuffer]) -> [DispatchData] {
        chunks.map { chunk in
            chunk.withUnsafeReadableBytes { DispatchData(bytes: $0) }
        }
    }

    /// Parses server responses out of `chunks`, accumulating into a `DispatchData`.
    ///
    /// The `DispatchData` twin of ``parseResponses(chunks:options:sink:)``. Appending a region copies
    /// nothing, and `discardFirst` takes a subrange rather than moving bytes down, so this models a
    /// caller whose transport hands it `DispatchData` and who never coalesces.
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
        var accumulator = DispatchData.empty
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

    /// Parses client commands out of `chunks`, accumulating into a `DispatchData`.
    ///
    /// The `DispatchData` twin of ``parseCommands(chunks:bufferLimit:literalSizeLimit:sink:)``.
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
        var accumulator = DispatchData.empty
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
}
