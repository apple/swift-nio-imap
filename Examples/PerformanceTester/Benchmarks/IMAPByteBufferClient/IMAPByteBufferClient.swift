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
import IMAPCorpus
import NIO
import NIOIMAP

// What the buffer migration is worth to a client whose transport is `ByteBuffer` in both directions
// — a NIO `Channel` client, the usual one. The sibling of `IMAPDispatchClient`, whose `main` side also
// pays `DispatchData` conversions; here neither side does, so the numbers isolate the parser and
// encoder.
//
// Every case here runs twice, against two libraries, from one set of case names:
//
//     IMAP_IMPL=main swift package … benchmark baseline update main   --filter 'bytebuffer-client.*'
//                    swift package … benchmark baseline update branch --filter 'bytebuffer-client.*'
//                    swift package … benchmark baseline compare main branch --filter 'bytebuffer-client.*'
//
// `dev/compare-dispatch-client.sh` runs exactly that. See `ByteBufferClient.swift` for what each side does
// and for the caveat that bounds the result — the `main` side is the best client that API allows,
// which makes every difference a floor rather than an estimate.
//
// `mallocBytesCount` is the stand-in for "bytes copied", and it is what the paired 1 MB / 4 MB cases
// are for: a copying implementation's allocated bytes scale with the payload, a zero-copy one's do not.
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

    // The write cases take the default configuration, ARC metrics included — unlike
    // `IMAPDispatchClient`'s. That target donates regions to a `DispatchData`, which frees on a
    // background queue, so how many releases land inside a measured region is up to the scheduler.
    // Nothing here leaves the calling thread: a `ByteBuffer` write frees synchronously, and the ARC
    // counters were identical across iterations and across three runs of the same binary.

    // Corpora, built here at registration time. All of them are wire bytes, so both configurations
    // are fed byte-identical input.
    let sweepMessageCount = ResponseCorpus.defaultMessageCount
    let sweep = ResponseCorpus.sweepBytes(messageCount: sweepMessageCount)
    let session = ResponseCorpus.sessionBytes()
    let bodyStructureMessageCount = 200
    let bodyStructures = ResponseCorpus.bodyStructureBytes(messageCount: bodyStructureMessageCount)
    let literalOptions = ByteBufferClient.streamingOptions()
    let commands = ByteBufferClient.taggedCommands()

    // Splits `corpus` into reads of `readSize`, and checks outside any measured region that they parse
    // to what one contiguous read does, ending on a complete response. `receiveResponses` fails on
    // unparsed bytes, so a corpus that stalls at some read boundary stops here instead of making its
    // benchmark fast and wrong. Payload chunks are compared by byte count, because how many there are
    // depends on the read size.
    func checkedReads(
        _ corpus: ByteBuffer,
        ofSize readSize: Int,
        options: ResponseParser.Options = ResponseParser.Options()
    ) -> [ByteBuffer] {
        func summary(_ reads: [ByteBuffer]) -> (events: Int, payloadBytes: Int) {
            var events = Hasher()
            var payloadBytes = 0
            var last: ResponseOrContinuationRequest?
            try! ByteBufferClient.receiveResponses(reads, options: options) { event in
                last = event
                guard case .response(.fetch(.streamingBytes(let payload))) = event else {
                    events.combine(event)
                    return
                }
                #if IMAP_LEGACY_BUFFERS
                payloadBytes += payload.readableBytes
                #else
                payloadBytes += payload.count
                #endif
            }
            switch last {
            case .response(.tagged), .response(.fetch(.finish)):
                break
            default:
                preconditionFailure("corpus ends inside a response")
            }
            return (events.finalize(), payloadBytes)
        }
        let reads = ByteBufferClient.reads(corpus, ofSize: readSize)
        let parsed = summary(reads)
        let expected = summary(ByteBufferClient.reads(corpus, ofSize: corpus.readableBytes))
        precondition(parsed == expected, "\(readSize)-byte reads parse differently from one read")
        return reads
    }

    // MARK: Corpus checks

    // Outside any measured region, and worth more here than in the other suites: this target is
    // compiled twice against two libraries, so "the corpus parses, and parses to the same thing" is
    // the property that makes the two runs comparable at all. A drift shows up here rather than as an
    // unexplained difference in the numbers.
    do {
        let sweepEvents = try! ByteBufferClient.receiveResponses(ByteBufferClient.reads(sweep, ofSize: ReadSize.mtu)) {
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

        // The zero-copy claim, asserted rather than assumed — in both configurations, each against its
        // own expectation. See `checkPayloadDelivery` in either driver half.
        let literalReads = ByteBufferClient.reads(
            ResponseCorpus.literalFetchBytes(byteCount: ByteBufferClient.Size.mebibyte),
            ofSize: ReadSize.mtu
        )
        ByteBufferClient.checkPayloadDelivery(literalReads)

        print("// bytebuffer-client: measuring \(ByteBufferClient.implementation)")
    }

    // MARK: - Reading

    // The wide-grammar session preamble at MTU reads. Small in bytes, so this is where the per-read
    // and per-message costs show up without any payload traffic to hide behind.
    do {
        let reads = checkedReads(session, ofSize: ReadSize.mtu)
        Benchmark("bytebuffer-client.parse.session") { benchmark in
            for _ in benchmark.scaledIterations {
                try ByteBufferClient.receiveResponses(reads) { blackHole($0) }
            }
        }
    }

    // One read holding everything: the floor the read-size sweep below is measured against, and the
    // only shape in which the `main` side never compacts.
    do {
        let reads = ByteBufferClient.reads(sweep, ofSize: sweep.readableBytes)
        Benchmark("bytebuffer-client.parse.sweep.\(sweepMessageCount).contiguous") { benchmark in
            for _ in benchmark.scaledIterations {
                try ByteBufferClient.receiveResponses(reads) { blackHole($0) }
            }
        }
    }

    // ~70-byte responses across the read sizes a socket delivers. This is the axis where the two
    // implementations differ structurally: the `main` side pays a copy per received byte and a
    // memmove per half-buffer, both of which get relatively cheaper as reads get larger, while this
    // side pays a box and a few retains per read, which gets cheaper too. Whether the gap narrows or
    // widens is the thing the sweep answers.
    for readSize in ReadSize.sweep {
        let reads = checkedReads(sweep, ofSize: readSize)
        Benchmark("bytebuffer-client.parse.sweep.\(sweepMessageCount).read-\(readSize)") { benchmark in
            for _ in benchmark.scaledIterations {
                try ByteBufferClient.receiveResponses(reads) { blackHole($0) }
            }
        }
    }

    // ~1.4 KB responses, so at MTU reads nearly every message straddles a read boundary — the case
    // that made read size look expensive on the `ByteBuffer` side, and the most expensive grammar a
    // client parses per message.
    for readSize in [ReadSize.mtu, ByteBufferClient.Size.largeRead] {
        let reads = checkedReads(bodyStructures, ofSize: readSize)
        Benchmark("bytebuffer-client.parse.bodystructure.\(bodyStructureMessageCount).read-\(readSize)") { benchmark in
            for _ in benchmark.scaledIterations {
                try ByteBufferClient.receiveResponses(reads) { blackHole($0) }
            }
        }
    }

    // The payload path, and the case the migration was built for: a client fetching a message body.
    // `mallocBytesCount` is the number to read. On `main` it scales with the payload — the bytes are
    // copied into the accumulator and copied again out of it — and here it should not, because the
    // payload is delivered as a reference to the received region.
    for payloadSize in ByteBufferClient.Size.payloads {
        let label = "\(payloadSize / ByteBufferClient.Size.mebibyte)MB"
        let corpus = ResponseCorpus.literalFetchBytes(byteCount: payloadSize)
        let isSmallest = payloadSize == ByteBufferClient.Size.mebibyte
        let readSizes = isSmallest ? ReadSize.sweep : [ReadSize.mtu, ByteBufferClient.Size.largeRead]
        for readSize in readSizes {
            let reads = checkedReads(corpus, ofSize: readSize, options: literalOptions)
            Benchmark("bytebuffer-client.parse.literal-\(label).read-\(readSize)") { benchmark in
                for _ in benchmark.scaledIterations {
                    try ByteBufferClient.receiveResponses(reads, options: literalOptions) { blackHole($0) }
                }
            }
        }
    }

    // MARK: - Writing

    // Every command a client sends in volume, encoded and handed to the transport. Many small writes,
    // which is the traffic shape the segment sink was chosen for; a chunk of one region reaches the
    // channel as a slice, without a copy.
    Benchmark("bytebuffer-client.encode.commands.all") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(ByteBufferClient.sendCommands(commands) { blackHole($0) })
        }
    }

    // The server's side of the same transport, and the encode-heavy shape: a `BODYSTRUCTURE` response
    // is hundreds of small writes through one reused buffer.
    do {
        let sessionResponses = ByteBufferClient.responses(parsing: session)
        Benchmark("bytebuffer-client.encode.responses.session") { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(ByteBufferClient.sendResponses(sessionResponses) { blackHole($0) })
            }
        }

        let bodyStructureResponses = ByteBufferClient.responses(parsing: bodyStructures)
        Benchmark("bytebuffer-client.encode.responses.bodystructure.\(bodyStructureMessageCount)") { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(ByteBufferClient.sendResponses(bodyStructureResponses) { blackHole($0) })
            }
        }
    }

    // `APPEND` of a payload the caller already holds. The write-side twin of the literal cases: on
    // `main` the bytes are copied once into the encoder's buffer, and here they are copied not at all,
    // so `mallocBytesCount` should stop scaling with the payload. The parts are built once, outside
    // the measured region, so that this is about encoding rather than about how each version gets a
    // caller's bytes into its model — see `appendParts(payload:)` in either driver half.
    for payloadSize in ByteBufferClient.Size.payloads {
        let payload = [UInt8](repeating: UInt8(ascii: "x"), count: payloadSize)
        let parts = ByteBufferClient.appendParts(payload: payload)
        Benchmark("bytebuffer-client.encode.append.\(payloadSize / ByteBufferClient.Size.mebibyte)MB") { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(ByteBufferClient.sendAppend(parts: parts) { blackHole($0) })
            }
        }
    }
}
