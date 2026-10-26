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

// The model half of ``ResponseCorpus``, kept out of `IMAPCorpus` because it names `Response` and
// `IMAPBuffer` — types the buffer migration changed, and therefore types the `IMAPDispatchClient`
// comparison's corpus target cannot name if it is to compile against both library versions. The wire
// bytes are the shared definition; these two helpers turn them into what the encode side needs.
extension ResponseCorpus {
    /// Parses `bytes` and returns the responses, for use as an encoder corpus.
    ///
    /// Runs at registration time, never inside a measured region. Continuation requests are dropped:
    /// they are not `Response` values and the encoder writes them through a different entry point.
    ///
    /// - Parameter bytes: One of the wire corpora in ``ResponseCorpus``.
    /// - Returns: The parsed responses, in order.
    public static func responses(parsing bytes: ByteBuffer) -> [Response] {
        var result: [Response] = []
        do {
            try Parsing.parseResponses(chunks: [bytes], options: Parsing.streamingOptions()) { event in
                if case .response(let response) = event {
                    result.append(response)
                }
            }
        } catch {
            fatalError("corpus does not parse: \(error)")
        }
        return result
    }

    /// The model form of ``ResponseCorpus/literalFetchBytes(byteCount:)``, streamed at `chunkSize`
    /// per event.
    ///
    /// Built directly rather than by parsing, because the chunk size a parse produces depends on the
    /// read size it was fed, and this corpus needs to pin it.
    ///
    /// - Parameters:
    ///   - byteCount: The total size of the streamed payload.
    ///   - chunkSize: How many bytes each `streamingBytes` event carries.
    /// - Returns: The responses a server would write, in order.
    public static func literalFetchResponses(byteCount: Int, chunkSize: Int) -> [Response] {
        let payload = ByteBuffer(repeating: UInt8(ascii: "x"), count: byteCount)
        var responses: [Response] = [
            .fetch(.start(SequenceNumber(rawValue: 1))),
            .fetch(.streamingBegin(kind: .rfc822Text, byteCount: byteCount)),
        ]
        for chunk in payload.chunks(ofSize: chunkSize) {
            // Wrapped, not copied — the ByteBuffer's storage is what the encoder should see.
            responses.append(.fetch(.streamingBytes(IMAPBuffer(chunk))))
        }
        responses.append(.fetch(.streamingEnd))
        responses.append(.fetch(.finish))
        return responses
    }
}
