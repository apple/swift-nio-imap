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

import NIOIMAPCore

// The `DispatchData` half of the hand-out. `IMAPOutputBuffer` exists *because* of this path — a
// `ByteBuffer` can only be filled in place, so "no copy for a Dispatch caller" requires the encoder to
// fill memory it allocated itself and then donate it — and until these cases existed the path had
// correctness tests and no measurement at all.
//
// Note the 2×2 rather than a third sink. `DispatchData` is not an `EncoderOutputBuffer`; it is what a
// chunk is converted *to* after the encoder is done, so it crosses with ``OutputBufferKind`` instead of
// extending it. The four combinations are what the design's central claim is made of:
//
// | sink                | → `ByteBuffer`      | → `DispatchData`               |
// |---------------------|---------------------|--------------------------------|
// | `IMAPOutputBuffer`  | one copy per region | **donated**; short ones copied |
// | `ByteBufferOutput`  | **sliced**          | **donated**; short ones copied |
//
// Three of the four are zero-copy for large regions. `ByteBufferOutput`'s regions are donated because
// `ByteBuffer` conforms to `StableAddressByteRegion` — `bytesNoCopy` needs a pointer that outlives its
// accessor, and holding a copy of a `ByteBuffer` keeps its readable bytes in place. Only a segment
// converted to a `ByteBuffer` pays a copy per region. Either way, a region shorter than
// `IMAPBuffer.dispatchDonationThreshold` goes to a `DispatchData` as a copy, one allocation per run of
// them, because donating costs more than copying it.
//
// These are separate functions rather than a `handout:` parameter on the existing drivers on purpose:
// a switch inside `writeAsHandler` would put a branch in the middle of an already-measured loop, and
// every committed encode number would have to be re-taken to prove it cost nothing.

extension IMAPBufferList {
    /// Hands the bytes to `write` the way a handler whose transport takes `DispatchData` would.
    ///
    /// One `DispatchData` per chunk. There is no per-region fan-out to model here: a Dispatch transport
    /// wants the whole chunk as a single value, where a `Channel` wants a payload written on its own.
    /// ``IMAPBufferList/makeDispatchData()`` already special-cases the empty and single-region chunks,
    /// which are the overwhelmingly common ones.
    ///
    /// - Returns: The number of bytes handed over.
    @discardableResult
    internal func writeAsDispatchHandler(_ write: (DispatchData) -> Void) -> Int {
        let data = makeDispatchData()
        write(data)
        return data.count
    }
}

// MARK: - Commands

extension CommandEncoding {
    /// Encodes a command the way a handler with a `DispatchData` transport writes one.
    ///
    /// The `DispatchData` twin of ``encodeAsHandler(_:tag:options:output:write:)``. Paired across
    /// ``OutputBufferKind`` it says what the conversion costs on each sink: the same on either, since
    /// both donate large regions and copy short ones.
    ///
    /// - Parameters:
    ///   - command: The command to encode.
    ///   - tag: The command tag.
    ///   - options: The encoding options.
    ///   - output: Which sink to encode into.
    ///   - write: Called with each chunk's bytes, in order, as a transport write would be.
    /// - Returns: How many chunks were produced, and how many bytes in total.
    @discardableResult
    public static func encodeAsDispatchHandler(
        _ command: Command,
        tag: Command.Tag,
        options: CommandEncodingOptions = .rfc3501,
        output: OutputBufferKind,
        write: (DispatchData) -> Void
    ) -> Result {
        var encodeBuffer = makeDispatchEncodeBuffer(options: options, output: output)
        encodeBuffer.writeCommand(TaggedCommand(tag: tag, command: command))
        return drainAsDispatchHandler(&encodeBuffer, write: write)
    }

    /// Encodes a sequence of command stream parts the way a handler with a `DispatchData` transport
    /// writes them.
    ///
    /// - Parameters:
    ///   - parts: The parts to encode, in order.
    ///   - options: The encoding options.
    ///   - output: Which sink to encode into.
    ///   - write: Called with each chunk's bytes, in order.
    /// - Returns: How many chunks were produced in total, and how many bytes.
    @discardableResult
    public static func encodeAsDispatchHandler(
        parts: [CommandStreamPart],
        options: CommandEncodingOptions = .rfc3501,
        output: OutputBufferKind,
        write: (DispatchData) -> Void
    ) -> Result {
        var result = Result(chunkCount: 0, byteCount: 0)
        for part in parts {
            var encodeBuffer = makeDispatchEncodeBuffer(options: options, output: output)
            encodeBuffer.writeCommandStream(part)
            let partResult = drainAsDispatchHandler(&encodeBuffer, write: write)
            result.chunkCount += partResult.chunkCount
            result.byteCount += partResult.byteCount
        }
        return result
    }

    private static func makeDispatchEncodeBuffer(
        options: CommandEncodingOptions,
        output: OutputBufferKind
    ) -> CommandEncodeBuffer {
        switch output {
        case .segments:
            return CommandEncodeBuffer(sink: IMAPOutputBuffer(), options: options, loggingMode: false)
        case .byteBuffer:
            return CommandEncodeBuffer(sink: ByteBufferOutput(), options: options, loggingMode: false)
        }
    }

    private static func drainAsDispatchHandler(
        _ encodeBuffer: inout CommandEncodeBuffer,
        write: (DispatchData) -> Void
    ) -> Result {
        var result = Result(chunkCount: 0, byteCount: 0)
        while let chunk = encodeBuffer.nextChunk() {
            result.chunkCount += 1
            result.byteCount += chunk.bytes.writeAsDispatchHandler(write)
        }
        return result
    }
}

// MARK: - Responses

extension ResponseEncoding {
    /// Encodes `responses` through one long-lived buffer, handing each one to a `DispatchData`
    /// transport.
    ///
    /// The `DispatchData` twin of ``encodeAsHandler(_:options:output:write:)``.
    ///
    /// - Parameters:
    ///   - responses: The responses to encode, in order.
    ///   - options: The encoding options.
    ///   - output: Which sink to encode into.
    ///   - write: Called with each response's bytes, in order.
    /// - Returns: The total number of bytes encoded.
    @discardableResult
    public static func encodeAsDispatchHandler(
        _ responses: [Response],
        options: ResponseEncodingOptions = ResponseEncodingOptions(),
        output: OutputBufferKind,
        write: (DispatchData) -> Void
    ) -> Int {
        var encodeBuffer: ResponseEncodeBuffer
        switch output {
        case .segments:
            encodeBuffer = ResponseEncodeBuffer(sink: IMAPOutputBuffer(), options: options, loggingMode: false)
        case .byteBuffer:
            encodeBuffer = ResponseEncodeBuffer(sink: ByteBufferOutput(), options: options, loggingMode: false)
        }

        var byteCount = 0
        for response in responses {
            encodeBuffer.writeResponse(response)
            byteCount += encodeBuffer.readBytes().writeAsDispatchHandler(write)
        }
        return byteCount
    }
}

// MARK: - The conversion on its own

/// The `DispatchData` conversion measured without an encoder in front of it.
///
/// This is the in-tree home for the microbenchmark the encoder design rests on. The design concluded that
/// a `DispatchData` costs a flat ~150 ns to create regardless of size plus ~40 ns per additional region,
/// and that therefore "the number of output regions per chunk is the thing to minimise" — which is where
/// the 64 KB segment cap, the refusal to split eagerly, and the 64-region cap all come from. Those numbers
/// were taken in a scratch directory under `/tmp` that no longer exists, so until now the load-bearing
/// measurement behind three design decisions was unreproducible. Sweeping
/// ``makeRegionList(regionCount:regionSize:)`` over region counts re-derives it in the suite instead — and
/// says the per-region cost was understated: it is ~5 allocations and ~1 KB.
public enum DispatchConversion {
    /// The most regions the encoder hands out in one chunk.
    ///
    /// The library's cap is internal, so it is spelled here; it is 64 there too.
    static let encoderRegionCap = 64

    /// The region counts to sweep, smallest first.
    ///
    /// Ends at the encoder's per-chunk cap, so the sweep also records what the most expensive chunk the
    /// library will ever produce costs to convert.
    public static let regionCountSweep = [1, 4, 16, encoderRegionCap]

    /// Builds a chunk of exactly `regionCount` regions of `regionSize` bytes each.
    ///
    /// Goes through ``IMAPOutputBuffer`` rather than constructing an ``IMAPBufferList`` directly, so the
    /// result is a list the encoder could really have produced. The regions are appended *by reference*,
    /// which needs `regionSize` at or above ``IMAPBuffer/copyThreshold`` — below it the sink copies them
    /// into one segment and coalesces, and the list comes back with one region instead of `regionCount`.
    ///
    /// Whether a region is a segment the encoder wrote or an array somebody else owns does not change
    /// what the conversion costs: both donate, because both promise a fixed address — as does a
    /// `ByteBuffer`, the region the paired sinks above cover.
    ///
    /// - Parameters:
    ///   - regionCount: How many regions the chunk should hold.
    ///   - regionSize: How many bytes in each region. Must be at least ``IMAPBuffer/copyThreshold``.
    /// - Returns: A chunk of `regionCount` regions.
    public static func makeRegionList(regionCount: Int, regionSize: Int) -> IMAPBufferList {
        precondition(
            regionSize >= IMAPBuffer.copyThreshold,
            "a region of \(regionSize) bytes is below copyThreshold and would be copied and coalesced"
        )

        var sink = IMAPOutputBuffer()
        let payload = IMAPBuffer([UInt8](repeating: UInt8(ascii: "x"), count: regionSize))
        for _ in 0..<regionCount {
            sink.append(payload)
        }
        let list = sink.takeFirst(sink.byteCount)
        precondition(
            list.regionCount == regionCount,
            "asked for \(regionCount) regions and got \(list.regionCount)"
        )
        return list
    }
}
