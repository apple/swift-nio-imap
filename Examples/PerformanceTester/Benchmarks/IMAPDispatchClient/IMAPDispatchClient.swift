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

// What the buffer migration is worth to a client whose transport is `DispatchData` in both directions
// — a `DispatchIO` or Network.framework client, which is the second backing the whole abstraction
// exists for and the one with no measurement at all until now.
//
// Every case here runs twice, against two libraries, from one set of case names:
//
//     IMAP_IMPL=main swift package … benchmark baseline update main   --filter 'dispatch-client.*'
//                    swift package … benchmark baseline update branch --filter 'dispatch-client.*'
//                    swift package … benchmark baseline compare main branch --filter 'dispatch-client.*'
//
// See `DispatchClient.swift` for what each side
// does and for the two caveats that bound the result — chiefly that the `main` side is the best client
// that API allows, which makes every difference a floor rather than an estimate.
//
// Read the allocation counters, not the wall clock. `mallocBytesCount` is the stand-in for "bytes
// copied", and it is what the paired 1 MB / 4 MB cases are for: a copying implementation's allocated
// bytes scale with the payload, a zero-copy one's do not. The wall clock here is additionally
// suspect because donated segments are freed asynchronously on a background queue, so a case's time
// depends on how much destruction the queue is still retiring from the case before it.
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

    // The write cases gate no ARC metric. `DispatchClient+Current` donates every large region, and
    // `DispatchData` frees adopted memory on a background queue. How many of a chunk's releases land
    // inside the measured region depends on how far that queue has got: `encode.responses.session`
    // reported retain deltas of 38 and 58 across two runs of the same binary with identical allocation
    // counters. Gating that gates noise, and quoting it in a before/after would be quoting the
    // scheduler. The allocation counters stay; an asynchronous `free` cannot change how many times
    // something was allocated. `encode.dispatch.*` in `IMAPEncoding` has the same treatment; see the
    // long note there.
    let encodeMetrics: [BenchmarkMetric] = [
        .wallClock,
        .throughput,
        .mallocCountTotal,
        .mallocBytesCount,
        .peakMemoryResidentDelta,
    ]
    let encodeThresholds: [BenchmarkMetric: BenchmarkThresholds] = [
        .wallClock: .relaxed,
        .throughput: .relaxed,
        .peakMemoryResidentDelta: .relaxed,
        .mallocCountTotal: BenchmarkThresholds(relative: [.p90: 1.0]),
        .mallocBytesCount: BenchmarkThresholds(relative: [.p90: 1.0]),
    ]
    let encodeConfiguration = Benchmark.Configuration(
        metrics: encodeMetrics,
        maxIterations: 1_000,
        thresholds: encodeThresholds
    )

    // Corpora, built here at registration time. All of them are wire bytes, so both configurations
    // are fed byte-identical input.
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
        let reads = DispatchClient.reads(corpus, ofSize: readSize)
        let parsed = summary(reads)
        let expected = summary(DispatchClient.reads(corpus, ofSize: corpus.readableBytes))
        precondition(parsed == expected, "\(readSize)-byte reads parse differently from one read")
        return reads
    }

    // MARK: Corpus checks

    // Outside any measured region, and worth more here than in the other suites: this target is
    // compiled twice against two libraries, so "the corpus parses, and parses to the same thing" is
    // the property that makes the two runs comparable at all. A drift shows up here rather than as an
    // unexplained difference in the numbers.
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

        // The zero-copy claim, asserted rather than assumed — in both configurations, each against its
        // own expectation. See `checkPayloadDelivery` in either driver half.
        let literalReads = DispatchClient.reads(
            ResponseCorpus.literalFetchBytes(byteCount: 1_024 * 1_024),
            ofSize: ReadSize.mtu
        )
        DispatchClient.checkPayloadDelivery(literalReads)

        print("// dispatch-client: measuring \(DispatchClient.implementation)")
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
    // only shape in which the `main` side never compacts.
    do {
        let reads = DispatchClient.reads(sweep, ofSize: sweep.readableBytes)
        Benchmark("dispatch-client.parse.sweep.\(sweepMessageCount).contiguous") { benchmark in
            for _ in benchmark.scaledIterations {
                try DispatchClient.receiveResponses(reads) { blackHole($0) }
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
        Benchmark("dispatch-client.parse.sweep.\(sweepMessageCount).read-\(readSize)") { benchmark in
            for _ in benchmark.scaledIterations {
                try DispatchClient.receiveResponses(reads) { blackHole($0) }
            }
        }
    }

    // ~1.4 KB responses, so at MTU reads nearly every message straddles a read boundary — the case
    // that made read size look expensive on the `ByteBuffer` side, and the most expensive grammar a
    // client parses per message.
    for readSize in [ReadSize.mtu, 65_536] {
        let reads = checkedReads(bodyStructures, ofSize: readSize)
        Benchmark("dispatch-client.parse.bodystructure.\(bodyStructureMessageCount).read-\(readSize)") { benchmark in
            for _ in benchmark.scaledIterations {
                try DispatchClient.receiveResponses(reads) { blackHole($0) }
            }
        }
    }

    // The payload path, and the case the migration was built for: a client fetching a message body.
    // `mallocBytesCount` is the number to read. On `main` it scales with the payload — the bytes are
    // copied into the accumulator and copied again out of it — and here it should not, because the
    // payload is delivered as a reference to the received region.
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

    // Every command a client sends in volume, encoded and handed to the transport. Many small writes,
    // which is the traffic shape where the segment sink was measured to beat writing into a
    // `ByteBuffer`; the conversion at the end is where it wins again, by donating large regions and
    // copying each run of short ones once.
    Benchmark("dispatch-client.encode.commands.all", configuration: encodeConfiguration) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(DispatchClient.sendCommands(commands) { blackHole($0) })
        }
    }

    // The server's side of the same transport, and the encode-heavy shape: a `BODYSTRUCTURE` response
    // is hundreds of small writes through one reused buffer.
    do {
        let sessionResponses = DispatchClient.responses(parsing: session)
        Benchmark("dispatch-client.encode.responses.session", configuration: encodeConfiguration) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(DispatchClient.sendResponses(sessionResponses) { blackHole($0) })
            }
        }

        let bodyStructureResponses = DispatchClient.responses(parsing: bodyStructures)
        Benchmark(
            "dispatch-client.encode.responses.bodystructure.\(bodyStructureMessageCount)",
            configuration: encodeConfiguration
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(DispatchClient.sendResponses(bodyStructureResponses) { blackHole($0) })
            }
        }
    }

    // `APPEND` of a payload the caller already holds. The write-side twin of the literal cases: on
    // `main` the bytes are copied twice on the way to the transport, and here they are copied not at
    // all, so `mallocBytesCount` should stop scaling with the payload. The parts are built once,
    // outside the measured region, so that this is about encoding rather than about how each version
    // gets a caller's array into its model — see `appendParts(payload:)` in either driver half.
    for payloadSize in [1_024 * 1_024, 4 * 1_024 * 1_024] {
        let payload = [UInt8](repeating: UInt8(ascii: "x"), count: payloadSize)
        let parts = DispatchClient.appendParts(payload: payload)
        Benchmark(
            "dispatch-client.encode.append.\(payloadSize / (1_024 * 1_024))MB",
            configuration: encodeConfiguration
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(DispatchClient.sendAppend(parts: parts) { blackHole($0) })
            }
        }
    }
}
