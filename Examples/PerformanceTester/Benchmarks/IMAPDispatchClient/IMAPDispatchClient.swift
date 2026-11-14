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

import Benchmark
import Dispatch
import IMAPCorpus
import NIO
import NIOIMAP

// What it costs a client whose transport is `DispatchData` in both directions — a `DispatchIO` or
// Network.framework client. See `DispatchClient.swift` for what the client does, and why it is the
// best client the API allows.
//
// Read the allocation counters, not the wall clock. `mallocBytesCount` is the stand-in for "bytes
// copied", and it is what the paired 1 MB / 4 MB cases are for: a copying implementation's allocated
// bytes scale with the payload, a zero-copy one's do not.
let benchmarks: @Sendable () -> Void = {
    let thresholds: [BenchmarkMetric: BenchmarkThresholds] = [
        .wallClock: .relaxed,
        .throughput: .relaxed,
        .peakMemoryResidentDelta: .relaxed,
        .mallocCountTotal: BenchmarkThresholds(relative: [.p90: 1.0]),
        .mallocBytesCount: BenchmarkThresholds(relative: [.p90: 1.0]),
        .objectAllocCount: BenchmarkThresholds(relative: [.p90: 1.0]),
        .retainCount: BenchmarkThresholds(relative: [.p90: 1.0]),
        .releaseCount: BenchmarkThresholds(relative: [.p90: 1.0]),
        .retainReleaseDelta: BenchmarkThresholds(relative: [.p90: 1.0]),
    ]

    Benchmark.defaultConfiguration = .init(
        metrics: [
            .wallClock,
            .throughput,
            .mallocCountTotal,
            .mallocBytesCount,
            .peakMemoryResidentDelta,
        ] + .arc,
        warmupIterations: 1,
        scalingFactor: .one,
        maxDuration: .seconds(3),
        maxIterations: 1_000,
        thresholds: thresholds
    )

    // Corpora, built here at registration time. All of them are wire bytes.
    let sweepMessageCount = ResponseCorpus.defaultMessageCount
    let sweep = ResponseCorpus.sweepBytes(messageCount: sweepMessageCount)
    let session = ResponseCorpus.sessionBytes()
    let bodyStructureMessageCount = 200
    let bodyStructures = ResponseCorpus.bodyStructureBytes(messageCount: bodyStructureMessageCount)
    let literalOptions = DispatchClient.streamingOptions()
    let commands = DispatchClient.taggedCommands()

    // Splits `corpus` into reads of `readSize`, and checks outside any measured region that they parse
    // to what one contiguous read does, ending on a complete response. `receiveResponses` fails on
    // unparsed bytes, so a corpus that stalls at some read boundary stops here instead of making its
    // benchmark fast and wrong. Payload chunks are compared by byte count, because how many there are
    // depends on the read size.
    func checkedReads(
        _ corpus: ByteBuffer,
        ofSize readSize: Int,
        options: ResponseParser.Options = ResponseParser.Options()
    ) -> [DispatchData] {
        func summary(_ reads: [DispatchData]) -> (events: Int, payloadBytes: Int) {
            var events = Hasher()
            var payloadBytes = 0
            var last: ResponseOrContinuationRequest?
            try! DispatchClient.receiveResponses(reads, options: options) { event in
                last = event
                guard case .response(.fetch(.streamingBytes(let payload))) = event else {
                    events.combine(event)
                    return
                }
                payloadBytes += payload.readableBytes
            }
            switch last {
            case .response(.tagged), .response(.fetch(.finish)):
                break
            default:
                preconditionFailure("corpus ends inside a response")
            }
            return (events.finalize(), payloadBytes)
        }
        let reads = DispatchClient.reads(corpus, ofSize: readSize)
        let parsed = summary(reads)
        let expected = summary(DispatchClient.reads(corpus, ofSize: corpus.readableBytes))
        precondition(parsed == expected, "\(readSize)-byte reads parse differently from one read")
        return reads
    }

    // MARK: Corpus checks

    // Outside any measured region: a corpus that stops parsing, or parses to something else, shows up
    // here rather than as an unexplained difference in the numbers.
    do {
        let sweepEvents = try! DispatchClient.receiveResponses(DispatchClient.reads(sweep, ofSize: ReadSize.mtu)) {
            _ in
        }
        precondition(
            sweepEvents == ResponseCorpus.expectedSweepEventCount(messageCount: sweepMessageCount),
            "response sweep parsed \(sweepEvents) events, expected "
                + "\(ResponseCorpus.expectedSweepEventCount(messageCount: sweepMessageCount))"
        )

        precondition(
            commands.count == ClientCommandCorpus.lines.count,
            "parsed \(commands.count) commands from \(ClientCommandCorpus.lines.count) corpus lines"
        )

        // How payloads are delivered, asserted rather than assumed. See `checkPayloadDelivery`.
        let literalReads = DispatchClient.reads(
            ResponseCorpus.literalFetchBytes(byteCount: 1_024 * 1_024),
            ofSize: ReadSize.mtu
        )
        DispatchClient.checkPayloadDelivery(literalReads)
    }

    // MARK: - Reading

    // The wide-grammar session preamble at MTU reads. Small in bytes, so this is where the per-read
    // and per-message costs show up without any payload traffic to hide behind.
    do {
        let reads = checkedReads(session, ofSize: ReadSize.mtu)
        Benchmark("dispatch-client.parse.session") { benchmark in
            for _ in benchmark.scaledIterations {
                try DispatchClient.receiveResponses(reads) { blackHole($0) }
            }
        }
    }

    // One read holding everything: the floor the read-size sweep below is measured against, and the
    // only shape in which the accumulator never compacts.
    do {
        let reads = DispatchClient.reads(sweep, ofSize: sweep.readableBytes)
        Benchmark("dispatch-client.parse.sweep.\(sweepMessageCount).contiguous") { benchmark in
            for _ in benchmark.scaledIterations {
                try DispatchClient.receiveResponses(reads) { blackHole($0) }
            }
        }
    }

    // ~70-byte responses across the read sizes a socket delivers. The client pays a copy per received
    // byte and a memmove per half-buffer, both of which get relatively cheaper as reads get larger.
    for readSize in ReadSize.sweep {
        let reads = checkedReads(sweep, ofSize: readSize)
        Benchmark("dispatch-client.parse.sweep.\(sweepMessageCount).read-\(readSize)") { benchmark in
            for _ in benchmark.scaledIterations {
                try DispatchClient.receiveResponses(reads) { blackHole($0) }
            }
        }
    }

    // ~1.4 KB responses, so at MTU reads nearly every message straddles a read boundary — the case
    // where read size costs the most, and the most expensive grammar a client parses per message.
    for readSize in [ReadSize.mtu, 65_536] {
        let reads = checkedReads(bodyStructures, ofSize: readSize)
        Benchmark("dispatch-client.parse.bodystructure.\(bodyStructureMessageCount).read-\(readSize)") { benchmark in
            for _ in benchmark.scaledIterations {
                try DispatchClient.receiveResponses(reads) { blackHole($0) }
            }
        }
    }

    // The payload path: a client fetching a message body. `mallocBytesCount` is the number to read. It
    // scales with the payload, because the bytes are copied into the accumulator and copied again out
    // of it.
    for payloadSize in [1_024 * 1_024, 4 * 1_024 * 1_024] {
        let label = "\(payloadSize / (1_024 * 1_024))MB"
        let corpus = ResponseCorpus.literalFetchBytes(byteCount: payloadSize)
        let readSizes = payloadSize == 1_024 * 1_024 ? ReadSize.sweep : [ReadSize.mtu, 65_536]
        for readSize in readSizes {
            let reads = checkedReads(corpus, ofSize: readSize, options: literalOptions)
            Benchmark("dispatch-client.parse.literal-\(label).read-\(readSize)") { benchmark in
                for _ in benchmark.scaledIterations {
                    try DispatchClient.receiveResponses(reads, options: literalOptions) { blackHole($0) }
                }
            }
        }
    }

    // MARK: - Writing

    // Every command a client sends in volume, encoded and handed to the transport. Many small writes.
    Benchmark("dispatch-client.encode.commands.all") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(DispatchClient.sendCommands(commands) { blackHole($0) })
        }
    }

    // The server's side of the same transport, and the encode-heavy shape: a `BODYSTRUCTURE` response
    // is hundreds of small writes through one reused buffer.
    do {
        let sessionResponses = DispatchClient.responses(parsing: session)
        Benchmark("dispatch-client.encode.responses.session") { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(DispatchClient.sendResponses(sessionResponses) { blackHole($0) })
            }
        }

        let bodyStructureResponses = DispatchClient.responses(parsing: bodyStructures)
        Benchmark("dispatch-client.encode.responses.bodystructure.\(bodyStructureMessageCount)") { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(DispatchClient.sendResponses(bodyStructureResponses) { blackHole($0) })
            }
        }
    }

    // `APPEND` of a payload the caller already holds. The write-side twin of the literal cases: the
    // bytes are copied twice on the way to the transport, so `mallocBytesCount` scales with the
    // payload. The parts are built once, outside the measured region, so that this is about encoding
    // rather than about getting a caller's array into the model — see `appendParts(payload:)`.
    for payloadSize in [1_024 * 1_024, 4 * 1_024 * 1_024] {
        let payload = [UInt8](repeating: UInt8(ascii: "x"), count: payloadSize)
        let parts = DispatchClient.appendParts(payload: payload)
        Benchmark("dispatch-client.encode.append.\(payloadSize / (1_024 * 1_024))MB") { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(DispatchClient.sendAppend(parts: parts) { blackHole($0) })
            }
        }
    }
}
