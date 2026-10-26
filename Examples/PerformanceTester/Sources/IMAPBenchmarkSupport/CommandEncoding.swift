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

import NIO
import NIOIMAP

import NIOIMAPCore

/// Which ``EncoderOutputBuffer`` a driver encodes into.
///
/// The two shipped sinks make different trades — segments never move a byte already written but are
/// copied on their way into a `ByteBuffer`, while a `ByteBuffer`-backed sink hands out slices but has to
/// start a fresh buffer once it has — so the cases that matter are registered as pairs.
public enum OutputBufferKind: String, Sendable, CaseIterable {
    /// `IMAPOutputBuffer`: the library's own `malloc`'d segments.
    case segments = "imap-sink"
    /// `ByteBufferOutput`: straight into a `ByteBuffer`, which is what a NIO caller can ask for.
    case byteBuffer = "bytebuffer-sink"
}

extension IMAPBufferList {
    /// Hands the bytes to `write` exactly the way `IMAPClientHandler` and `IMAPServerHandler` do.
    ///
    /// Including their fast paths, because those are most of what the measurement is about: one region
    /// is written without building an array, and only a chunk carrying a by-reference payload takes the
    /// general path.
    ///
    /// - Returns: The number of bytes handed over.
    @discardableResult
    internal func writeAsHandler(_ write: (ByteBuffer) -> Void) -> Int {
        switch regionCount {
        case 0:
            write(ByteBuffer())
            return 0
        case 1:
            let buffer = regions[0].byteBuffer
            write(buffer)
            return buffer.readableBytes
        default:
            var total = 0
            for buffer in makeOutboundBuffers() {
                total += buffer.readableBytes
                write(buffer)
            }
            return total
        }
    }
}

/// Drivers that encode client commands the way `ClientStateMachine` does.
public enum CommandEncoding {
    /// The result of encoding one command or command stream.
    public struct Result {
        /// The number of chunks `nextChunk()` produced.
        ///
        /// More than one means the encoding contained a synchronizing literal and the client
        /// would have had to wait for a continuation request between chunks.
        public var chunkCount: Int
        /// The total number of encoded bytes.
        public var byteCount: Int
    }

    /// Encodes a tagged command into `output`, draining every chunk.
    ///
    /// - Parameters:
    ///   - command: The command to encode.
    ///   - tag: The command tag.
    ///   - options: The encoding options. `.rfc3501` uses synchronizing literals.
    ///   - output: The buffer the encoded bytes are appended to.
    /// - Returns: How many chunks were produced, and how many bytes in total.
    @discardableResult
    public static func encode(
        _ command: Command,
        tag: Command.Tag,
        options: CommandEncodingOptions = .rfc3501,
        into output: inout ByteBuffer
    ) -> Result {
        var encodeBuffer = CommandEncodeBuffer(options: options, loggingMode: false)
        encodeBuffer.writeCommand(TaggedCommand(tag: tag, command: command))
        return drain(&encodeBuffer, into: &output)
    }

    /// Encodes a sequence of command stream parts into `output`, draining every chunk.
    ///
    /// Uses a fresh `CommandEncodeBuffer` per part, which is what `ClientStateMachine` does: a
    /// part is encoded, its chunks are written, and the next part is only encoded once the
    /// server's continuation request has arrived.
    ///
    /// - Parameters:
    ///   - parts: The parts to encode, in order.
    ///   - options: The encoding options.
    ///   - output: The buffer the encoded bytes are appended to.
    /// - Returns: How many chunks were produced in total, and how many bytes.
    @discardableResult
    public static func encode(
        parts: [CommandStreamPart],
        options: CommandEncodingOptions = .rfc3501,
        into output: inout ByteBuffer
    ) -> Result {
        var result = Result(chunkCount: 0, byteCount: 0)
        for part in parts {
            var encodeBuffer = CommandEncodeBuffer(options: options, loggingMode: false)
            encodeBuffer.writeCommandStream(part)
            let partResult = drain(&encodeBuffer, into: &output)
            result.chunkCount += partResult.chunkCount
            result.byteCount += partResult.byteCount
        }
        return result
    }

    private static func drain(_ encodeBuffer: inout CommandEncodeBuffer, into output: inout ByteBuffer) -> Result {
        var result = Result(chunkCount: 0, byteCount: 0)
        while let chunk = encodeBuffer.nextChunk() {
            result.chunkCount += 1
            // One write per region, which is what a networking caller does. `writeBytes` copies each
            // region's bytes into `output` exactly once.
            for region in chunk.bytes.regions {
                result.byteCount += region.withUnsafeBytes { output.writeBytes($0) }
            }
        }
        return result
    }
}

// MARK: - The handler's shape

extension CommandEncoding {
    /// Encodes a command the way `IMAPClientHandler` writes one: one `ByteBuffer` per region, with no
    /// coalescing anywhere.
    ///
    /// The difference from ``encode(_:tag:options:into:)`` is what happens to the bytes *after* they are
    /// encoded. That driver copies every region into one buffer, which is what a caller has to do when
    /// its transport needs contiguous bytes; this one converts each region to a `ByteBuffer` and hands it
    /// over, which is what a `Channel` write costs — free when the sink wrote into a `ByteBuffer` in the
    /// first place, one copy per region when it did not. Paired across ``OutputBufferKind``, that
    /// difference is what the measurement is for.
    ///
    /// - Parameters:
    ///   - command: The command to encode.
    ///   - tag: The command tag.
    ///   - options: The encoding options.
    ///   - output: Which sink to encode into.
    ///   - write: Called with each buffer, in order, as a channel write would be.
    /// - Returns: How many chunks were produced, and how many bytes in total.
    @discardableResult
    public static func encodeAsHandler(
        _ command: Command,
        tag: Command.Tag,
        options: CommandEncodingOptions = .rfc3501,
        output: OutputBufferKind,
        write: (ByteBuffer) -> Void
    ) -> Result {
        var encodeBuffer = makeEncodeBuffer(options: options, output: output)
        encodeBuffer.writeCommand(TaggedCommand(tag: tag, command: command))
        return drainAsHandler(&encodeBuffer, write: write)
    }

    /// Encodes a sequence of command stream parts the way `IMAPClientHandler` writes them.
    ///
    /// - Parameters:
    ///   - parts: The parts to encode, in order.
    ///   - options: The encoding options.
    ///   - output: Which sink to encode into.
    ///   - write: Called with each buffer, in order.
    /// - Returns: How many chunks were produced in total, and how many bytes.
    @discardableResult
    public static func encodeAsHandler(
        parts: [CommandStreamPart],
        options: CommandEncodingOptions = .rfc3501,
        output: OutputBufferKind,
        write: (ByteBuffer) -> Void
    ) -> Result {
        var result = Result(chunkCount: 0, byteCount: 0)
        for part in parts {
            var encodeBuffer = makeEncodeBuffer(options: options, output: output)
            encodeBuffer.writeCommandStream(part)
            let partResult = drainAsHandler(&encodeBuffer, write: write)
            result.chunkCount += partResult.chunkCount
            result.byteCount += partResult.byteCount
        }
        return result
    }

    private static func makeEncodeBuffer(
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

    private static func drainAsHandler(
        _ encodeBuffer: inout CommandEncodeBuffer,
        write: (ByteBuffer) -> Void
    ) -> Result {
        var result = Result(chunkCount: 0, byteCount: 0)
        while let chunk = encodeBuffer.nextChunk() {
            result.chunkCount += 1
            result.byteCount += chunk.bytes.writeAsHandler(write)
        }
        return result
    }
}

extension CommandEncoding {
    /// The command stream parts for an `APPEND` of a single message of `byteCount` bytes.
    ///
    /// With `.rfc3501` options the message data is written as a synchronizing literal, so this is
    /// also the corpus for the chunking path: encoding these parts produces a chunk boundary that
    /// the client may not cross until the server sends a continuation request.
    public static func appendParts(tag: Command.Tag, payload: IMAPBuffer) -> [CommandStreamPart] {
        [
            .append(.start(tag: tag, appendingTo: .inbox)),
            .append(
                .beginMessage(
                    message: AppendMessage(
                        options: AppendOptions(flagList: [.seen]),
                        data: AppendData(byteCount: payload.count)
                    )
                )
            ),
            .append(.messageBytes(payload)),
            .append(.endMessage),
            .append(.finish),
        ]
    }
}

extension CommandCorpus {
    /// A tag per command in ``all``: its index, e.g. `"7"`.
    ///
    /// Built once so the benchmarks don't measure validating tags.
    public static let tags: [Command.Tag] = all.indices.map { Command.Tag("\($0)")! }

    /// Every command in the corpus, pre-encoded with `.rfc3501` options.
    ///
    /// Built once so the parse benchmarks measure parsing only. Tags are the corpus index, which
    /// keeps them one or two bytes and out of the way of what is being measured.
    public static let encodedAll: [(name: String, bytes: ByteBuffer)] =
        all.enumerated().map { index, entry in
            var buffer = ByteBuffer()
            CommandEncoding.encode(entry.command, tag: tags[index], into: &buffer)
            return (entry.name, buffer)
        }

    /// ``hot`` pre-encoded with `.rfc3501` options.
    public static let encodedHot: [(name: String, bytes: ByteBuffer)] =
        hot.map { entry in
            guard let encoded = encodedAll.first(where: { $0.name == entry.name }) else {
                fatalError("no command named '\(entry.name)' in the corpus")
            }
            return encoded
        }
}
