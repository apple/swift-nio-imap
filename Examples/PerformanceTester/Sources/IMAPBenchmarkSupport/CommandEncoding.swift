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
