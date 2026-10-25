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
import IMAPBenchmarkSupport
import NIO
import NIOIMAP

// Parser benchmarks, both directions: client commands (what a server parses) and server responses
// (what a client parses).
//
// The allocation and ARC counters are the point of this suite, not the wall clock: the goals are
// "zero bytes copied" and "no retain/release attributable to the cursor", both of which are gated
// here. Wall clock is measured too, but with a relaxed threshold, because it is the noisiest number
// in the set.
let benchmarks: @Sendable () -> Void = {
    // Threshold tolerances, used when a run is compared against a stored baseline.
    //
    // The allocation and ARC counters are deterministic — in a smoke run every percentile from p0 to
    // p100 reported the same value — so they are gated tightly and are what a regression should trip.
    // Wall clock, throughput and resident memory are sampled and machine-dependent, so they are
    // recorded but deliberately not gated.
    let imapThresholds: [BenchmarkMetric: BenchmarkThresholds] = [
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
        maxIterations: 10_000,
        thresholds: imapThresholds
    )

    // Bound to locals so the corpora are built here, at registration time, rather than lazily
    // inside the first measured iteration.
    let encodedCommands = CommandCorpus.encodedAll
    let hotCommands = CommandCorpus.encodedHot
    let sweep = ResponseCorpus.sweepBytes()
    let session = ResponseCorpus.sessionBytes()
    let bodyStructureMessageCount = 200
    let bodyStructures = ResponseCorpus.bodyStructureBytes(messageCount: bodyStructureMessageCount)

    // MARK: Corpus checks

    // Run once here, outside any measured region. A corpus that silently fails to exercise the path
    // it is named after would make every number below meaningless, and these are the properties that
    // are easiest to break by accident.
    do {
        let sweepEvents = try! Parsing.parseResponses(chunks: [sweep]) { _ in }
        precondition(
            sweepEvents == ResponseCorpus.expectedSweepEventCount(),
            "response sweep parsed \(sweepEvents) events, expected \(ResponseCorpus.expectedSweepEventCount())"
        )

        // Eight events per message — a start, six attributes and a finish — plus the tagged
        // completion. If the body structure ever stops parsing as a single attribute, this trips.
        let expectedBodyStructureEvents = bodyStructureMessageCount * 8 + 1
        var sawMultipartBodyStructure = false
        let bodyStructureEvents = try! Parsing.parseResponses(chunks: [bodyStructures]) { event in
            guard case .response(.fetch(.simpleAttribute(.body(let structure, _)))) = event else { return }
            if case .valid(.multipart) = structure {
                sawMultipartBodyStructure = true
            }
        }
        precondition(
            bodyStructureEvents == expectedBodyStructureEvents,
            "body-structure corpus parsed \(bodyStructureEvents) events, expected \(expectedBodyStructureEvents)"
        )
        precondition(sawMultipartBodyStructure, "body-structure corpus produced no multipart BODYSTRUCTURE")

        // The session corpus is checked by shape rather than by count, because its point is breadth:
        // if any of these response kinds stops appearing it is no longer covering what it claims to.
        var seen: Set<String> = []
        try! Parsing.parseResponses(chunks: [session]) { event in
            switch event {
            case .continuationRequest:
                seen.insert("continuation")
            case .response(.untagged(.capabilityData)):
                seen.insert("capability")
            case .response(.untagged(.mailboxData(.list))):
                seen.insert("list")
            case .response(.untagged(.mailboxData(.lsub))):
                seen.insert("lsub")
            case .response(.untagged(.mailboxData(.status))):
                seen.insert("status")
            case .response(.untagged(.mailboxData(.search))):
                seen.insert("search")
            case .response(.untagged(.mailboxData(.extendedSearch))):
                seen.insert("esearch")
            case .response(.untagged(.mailboxData(.exists))):
                seen.insert("exists")
            case .response(.untagged(.messageData(.expunge))):
                seen.insert("expunge")
            case .response(.untagged(.id)):
                seen.insert("id")
            case .response(.untagged(.mailboxData(.namespace))):
                seen.insert("namespace")
            case .response(.tagged):
                seen.insert("tagged")
            default:
                break
            }
        }
        let required: Set<String> = [
            "continuation", "capability", "list", "lsub", "status", "search", "esearch", "exists",
            "expunge", "id", "namespace", "tagged",
        ]
        precondition(
            required.isSubset(of: seen),
            "session corpus is missing \(required.subtracting(seen).sorted().joined(separator: ", "))"
        )

        for (name, bytes) in encodedCommands {
            let parts = try! Parsing.parseCommand(bytes: bytes) { _ in }
            precondition(parts > 0, "command '\(name)' parsed into nothing")
        }
    }

    // MARK: Commands

    Benchmark("parse.commands.all") { benchmark in
        for _ in benchmark.scaledIterations {
            for (_, bytes) in encodedCommands {
                try Parsing.parseCommand(bytes: bytes) { blackHole($0) }
            }
        }
    }

    for (name, bytes) in hotCommands {
        Benchmark("parse.command.\(name)") { benchmark in
            for _ in benchmark.scaledIterations {
                try Parsing.parseCommand(bytes: bytes) { blackHole($0) }
            }
        }
    }

    // The old hand-rolled tester measured encode and parse together. Keeping one combined case makes
    // the split between the two attributable.
    let commands = CommandCorpus.all
    Benchmark("roundtrip.commands.all") { benchmark in
        for _ in benchmark.scaledIterations {
            for (index, entry) in commands.enumerated() {
                var bytes = ByteBuffer()
                CommandEncoding.encode(entry.command, tag: CommandCorpus.tags[index], into: &bytes)
                try Parsing.parseCommand(bytes: bytes) { blackHole($0) }
            }
        }
    }

    // MARK: Responses — session preamble

    // Wide rather than deep: capabilities, the mailbox tree, STATUS, the SELECT preamble, search
    // results, an unsolicited flag update, an EXPUNGE, a continuation request, BYE. Most of the
    // distinct response grammar a client has to handle is in this one case.
    Benchmark("parse.responses.session") { benchmark in
        for _ in benchmark.scaledIterations {
            try Parsing.parseResponses(chunks: [session]) { blackHole($0) }
        }
    }

    // MARK: Responses — heavy FETCH

    // ENVELOPE plus a nested BODYSTRUCTURE per message: the most expensive thing a client parses per
    // message, and the deepest recursion in the grammar.
    Benchmark(
        "parse.responses.bodystructure.\(bodyStructureMessageCount)",
        configuration: .init(maxIterations: 1_000)
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            try Parsing.parseResponses(chunks: [bodyStructures]) { blackHole($0) }
        }
    }

    for readSize in [ReadSize.mtu, 65_536] {
        let chunks = bodyStructures.chunks(ofSize: readSize)
        Benchmark(
            "parse.responses.bodystructure.\(bodyStructureMessageCount).read-\(readSize)",
            configuration: .init(maxIterations: 1_000)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                try Parsing.parseResponses(chunks: chunks) { blackHole($0) }
            }
        }
    }

    // MARK: Responses — light FETCH

    Benchmark(
        "parse.responses.\(ResponseCorpus.defaultMessageCount).contiguous",
        configuration: .init(maxIterations: 1_000)
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            try Parsing.parseResponses(chunks: [sweep]) { blackHole($0) }
        }
    }

    // Every region costs something regardless of how few bytes it carries, so a sweep across read
    // sizes is the measurement that says how much. `1448` is the size that matters most: it is what
    // a socket read actually delivers, and `copyThreshold` is set below it on purpose.
    for readSize in ReadSize.sweep {
        let chunks = sweep.chunks(ofSize: readSize)
        Benchmark(
            "parse.responses.\(ResponseCorpus.defaultMessageCount).read-\(readSize)",
            configuration: .init(maxIterations: 1_000)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                try Parsing.parseResponses(chunks: chunks) { blackHole($0) }
            }
        }
    }

    // The pathological case: one byte per read isolates the per-read overhead — an append, which
    // copies the byte into `IMAPInputBuffer`'s tail, and a parse attempt over the partial response.
    // A smaller corpus keeps the run to a sane length — it is ~45× slower per message than the
    // contiguous case.
    let smallSweep = ResponseCorpus.sweepBytes(messageCount: 100)
    let singleByteChunks = smallSweep.chunks(ofSize: ReadSize.single)
    Benchmark(
        "parse.responses.100.read-1",
        configuration: .init(maxIterations: 100)
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            try Parsing.parseResponses(chunks: singleByteChunks) { blackHole($0) }
        }
    }

    // MARK: Streaming a large literal

    // The case zero-copy parsing is for: a multi-megabyte literal delivered through
    // `FetchResponse.streamingBytes` with zero bytes copied, by `ParseInput.extractBuffer(upTo:)`;
    // these numbers are the baseline that has to hold.
    //
    // `peakMemoryResidentDelta` is here for the footprint half of the `copyThreshold` trade: with
    // a low threshold the received buffers get pinned instead of copied, and this is where an
    // unexpected amount of pinning would show up.
    let literalSize = 1_024 * 1_024
    let literalOptions = Parsing.streamingOptions()

    // The corpus check for the streaming path: every byte of the literal must arrive as
    // `streamingBytes`, not as one buffered attribute. If the parser ever stops streaming this,
    // the benchmark below silently starts measuring something else.
    do {
        var streamedBytes = 0
        var sawStreamingBegin = false
        let chunks = ResponseCorpus.literalFetchBytes(byteCount: literalSize).chunks(ofSize: ReadSize.mtu)
        try! Parsing.parseResponses(chunks: chunks, options: literalOptions) { event in
            guard case .response(.fetch(let fetch)) = event else { return }
            switch fetch {
            case .streamingBegin:
                sawStreamingBegin = true
            case .streamingBytes(let bytes):
                streamedBytes += bytes.count
            default:
                break
            }
        }
        precondition(sawStreamingBegin, "1 MB literal did not produce a streamingBegin event")
        precondition(streamedBytes == literalSize, "streamed \(streamedBytes) bytes, expected \(literalSize)")
    }

    for readSize in ReadSize.sweep {
        let chunks = ResponseCorpus.literalFetchBytes(byteCount: literalSize).chunks(ofSize: readSize)
        Benchmark(
            "parse.literal-1MB.read-\(readSize)",
            configuration: .init(maxIterations: 1_000)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                try Parsing.parseResponses(chunks: chunks, options: literalOptions) { blackHole($0) }
            }
        }
    }

    // MARK: DispatchData input

    // The other input backing. `DispatchData` is the genuinely multi-region source — appending copies
    // nothing, so a buffer assembled from many reads really does arrive as many regions — and it is what
    // `StableRegionParserInputBuffer` and the one-pass `enumerateBytes` gather were built for. Until
    // these cases, every parse benchmark fed an `IMAPInputBuffer` or a bare `ByteBuffer`, so the gather
    // that exists to avoid the recursive descent was only ever measured on types that take a different
    // path.
    //
    // Read each against the `IMAPInputBuffer` case of the same name. Three costs are unique to this side
    // and all of them are per parse call rather than per read: the gather walks every live region twice
    // (once for `regionCount`, once to fill the table) where `IMAPInputBuffer` keeps a count;
    // `discardFirst` creates a subrange object per parsed message; and extraction always *copies*,
    // because `withStableRegions` passes no owner. That last one means the literal cases below are the
    // price of not owning the buffer — the zero-copy literal path is a property of `IMAPInputBuffer`
    // alone, which is a design decision worth having a number against rather than only a paragraph.
    do {
        let dispatchSession = Parsing.dispatchChunks([session])
        let dispatchSweepContiguous = Parsing.dispatchChunks([sweep])

        // The corpus check, for the same reason the others have one: this driver reaches the parser
        // through a different conformance, so "it parses at all" is not implied by the cases above.
        let events = try! Parsing.parseResponses(dispatchChunks: dispatchSession) { _ in }
        let reference = try! Parsing.parseResponses(chunks: [session]) { _ in }
        precondition(
            events == reference,
            "DispatchData input parsed \(events) session events, ByteBuffer input parsed \(reference)"
        )

        Benchmark("parse.dispatch.responses.session") { benchmark in
            for _ in benchmark.scaledIterations {
                try Parsing.parseResponses(dispatchChunks: dispatchSession) { blackHole($0) }
            }
        }

        // One region, so this isolates what reaching the parser through `DispatchData`'s conformance
        // costs with no multi-region work at all — the floor the sweep below is measured against.
        Benchmark(
            "parse.dispatch.responses.\(ResponseCorpus.defaultMessageCount).contiguous",
            configuration: .init(maxIterations: 1_000)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                try Parsing.parseResponses(dispatchChunks: dispatchSweepContiguous) { blackHole($0) }
            }
        }

        // The read-size sweep is where the two-walks-per-call cost has to show up: live regions grow
        // with the number of unparsed reads, and the per-call work is proportional to them. The MTU end
        // is the one that matters, because that is what a socket read delivers.
        for readSize in ReadSize.sweep {
            let chunks = Parsing.dispatchChunks(sweep.chunks(ofSize: readSize))
            Benchmark(
                "parse.dispatch.responses.\(ResponseCorpus.defaultMessageCount).read-\(readSize)",
                configuration: .init(maxIterations: 1_000)
            ) { benchmark in
                for _ in benchmark.scaledIterations {
                    try Parsing.parseResponses(dispatchChunks: chunks) { blackHole($0) }
                }
            }
        }

        // ~1.4 KB responses, so at MTU reads nearly every one straddles a boundary. This is the corpus
        // that made read size look expensive on the `ByteBuffer` side (22% more allocations), so it is
        // the one to watch here too.
        for readSize in [ReadSize.mtu, 65_536] {
            let chunks = Parsing.dispatchChunks(bodyStructures.chunks(ofSize: readSize))
            Benchmark(
                "parse.dispatch.responses.bodystructure.\(bodyStructureMessageCount).read-\(readSize)",
                configuration: .init(maxIterations: 1_000)
            ) { benchmark in
                for _ in benchmark.scaledIterations {
                    try Parsing.parseResponses(dispatchChunks: chunks) { blackHole($0) }
                }
            }
        }

        // The literal path, which is where the "extraction always copies" property costs the most: a
        // 1 MB literal is copied out region by region here and handed over by reference in the
        // `parse.literal-1MB.*` cases. `mallocBytesCount` is the number to compare, not wall clock.
        for readSize in ReadSize.sweep {
            let chunks = Parsing.dispatchChunks(
                ResponseCorpus.literalFetchBytes(byteCount: literalSize).chunks(ofSize: readSize)
            )
            Benchmark(
                "parse.dispatch.literal-1MB.read-\(readSize)",
                configuration: .init(maxIterations: 1_000)
            ) { benchmark in
                for _ in benchmark.scaledIterations {
                    try Parsing.parseResponses(dispatchChunks: chunks, options: literalOptions) { blackHole($0) }
                }
            }
        }
    }
}
