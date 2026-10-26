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

// Encoder benchmarks.
//
// Three groups. The plain `encode.*` cases coalesce their output into one contiguous buffer, which is
// what a caller whose transport needs contiguous bytes has to do; `encode.handler.*` and
// `encode.dispatch.*` model the two transports the library is actually built for, each paired over the
// two shipped sinks. `mallocBytesCount` stands in for "bytes copied": there is no bytes-copied metric,
// but a copying implementation's allocated bytes scale with payload size and a zero-copy one's do not,
// which is what the paired 1 MB / 4 MB APPEND cases are for — read the `handler` and `dispatch` ones for
// that question, since the plain ones copy at the driver's request.
let benchmarks: @Sendable () -> Void = {
    // Threshold tolerances. Same rationale as the parsing target: the allocation and ARC counters are
    // deterministic and are what a regression should trip, while wall clock, throughput and resident
    // memory are sampled and machine-dependent, so they are recorded but not gated.
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

    // Bound to locals so the corpora are built at registration time, not inside the first
    // measured iteration.
    let commands = CommandCorpus.all
    let hotCommands = CommandCorpus.hot

    // The response corpora are defined as wire bytes and parsed here, at registration time, to get
    // the model values the encoder needs. One definition for both directions, so the parse and encode
    // sides cannot drift apart — and no hand-written `BodyStructure` literal to keep in sync with the
    // text it is meant to represent.
    let sweepResponses = ResponseCorpus.responses(parsing: ResponseCorpus.sweepBytes())
    let sessionResponses = ResponseCorpus.responses(parsing: ResponseCorpus.sessionBytes())
    let bodyStructureMessageCount = 200
    let bodyStructureResponses = ResponseCorpus.responses(
        parsing: ResponseCorpus.bodyStructureBytes(messageCount: bodyStructureMessageCount)
    )

    // MARK: Commands

    Benchmark("encode.commands.all") { benchmark in
        for _ in benchmark.scaledIterations {
            var output = ByteBuffer()
            for (index, entry) in commands.enumerated() {
                CommandEncoding.encode(entry.command, tag: CommandCorpus.tags[index], into: &output)
            }
            blackHole(output)
        }
    }

    for (name, command) in hotCommands {
        Benchmark("encode.command.\(name)") { benchmark in
            for _ in benchmark.scaledIterations {
                var output = ByteBuffer()
                CommandEncoding.encode(command, tag: "A1", into: &output)
                blackHole(output)
            }
        }
    }

    // MARK: Synchronizing literals

    // The chunking path. Turning quoted strings off forces every string to be written as a
    // synchronizing literal, and because bytes follow each stop point, `nextChunk()` hands out
    // several chunks that await `+` — the sequence a client has to interleave with
    // the server's continuation requests. This is the path where an off-by-one in the stop-point
    // bookkeeping deadlocks the protocol rather than producing wrong bytes, so it gets its own case
    // even though the command is tiny.
    let synchronizingLiteralOptions = CommandEncodingOptions(
        useQuotedString: false,
        useSynchronizingLiteral: true
    )
    let literalPlusOptions = CommandEncodingOptions(
        useQuotedString: false,
        useSynchronizingLiteral: false,
        useNonSynchronizingLiteralPlus: true
    )
    let literalCommand = Command.login(username: "benchmark-user", password: "benchmark-password")

    // Checked here, at registration time, rather than inside the measured region: if the encoding
    // options ever stop producing a continuation the benchmark is measuring the wrong thing.
    do {
        var probe = ByteBuffer()
        let result = CommandEncoding.encode(
            literalCommand,
            tag: "A1",
            options: synchronizingLiteralOptions,
            into: &probe
        )
        precondition(result.chunkCount > 1, "expected synchronizing literals to produce several chunks")
    }

    Benchmark("encode.login.sync-literal") { benchmark in
        for _ in benchmark.scaledIterations {
            var output = ByteBuffer()
            CommandEncoding.encode(literalCommand, tag: "A1", options: synchronizingLiteralOptions, into: &output)
            blackHole(output)
        }
    }

    // The same command as a LITERAL+, which needs no continuation at all. The pair isolates the
    // cost of the chunking machinery from the cost of the encoding.
    Benchmark("encode.login.literal-plus") { benchmark in
        for _ in benchmark.scaledIterations {
            var output = ByteBuffer()
            CommandEncoding.encode(literalCommand, tag: "A1", options: literalPlusOptions, into: &output)
            blackHole(output)
        }
    }

    // MARK: Quoted strings

    // `writeQuotedIMAPString` used to issue one primitive write per byte, so a 60-byte mailbox name cost
    // 60 writes; it now stages into a temporary buffer and emits one. This pair — the same mailbox name
    // as a quoted string and as a literal — is what measured that, and it stays as the regression net.
    let longMailbox = MailboxName(Array("A mailbox name of some sixty-four bytes, give or take a few.".utf8))
    let quotedCommand = Command.create(longMailbox, [])
    Benchmark("encode.create.quoted-string") { benchmark in
        for _ in benchmark.scaledIterations {
            var output = ByteBuffer()
            CommandEncoding.encode(quotedCommand, tag: "A1", into: &output)
            blackHole(output)
        }
    }

    Benchmark("encode.create.literal") { benchmark in
        for _ in benchmark.scaledIterations {
            var output = ByteBuffer()
            CommandEncoding.encode(quotedCommand, tag: "A1", options: literalPlusOptions, into: &output)
            blackHole(output)
        }
    }

    let smallPayload = IMAPBuffer(ByteBuffer(repeating: UInt8(ascii: "x"), count: 128))
    let smallAppend = CommandEncoding.appendParts(tag: "A1", payload: smallPayload)
    Benchmark("encode.append.128B") { benchmark in
        for _ in benchmark.scaledIterations {
            var output = ByteBuffer()
            CommandEncoding.encode(parts: smallAppend, into: &output)
            blackHole(output)
        }
    }

    // MARK: Large APPEND

    // A 1 MB `AppendCommand.messageBytes`. The encoder appends the payload by reference, but this
    // driver coalesces every chunk into one contiguous buffer, so the baseline here is one full
    // copy. The `encode.handler.append.*` and `encode.dispatch.append.*` cases below measure the
    // paths that do not copy.
    //
    // The 4 MB case exists only as the second point on that line. If the two ever report the same
    // allocated bytes, the payload is no longer being copied.
    for payloadSize in [1_024 * 1_024, 4 * 1_024 * 1_024] {
        let payload = IMAPBuffer(ByteBuffer(repeating: UInt8(ascii: "x"), count: payloadSize))
        let parts = CommandEncoding.appendParts(tag: "A1", payload: payload)
        let label = payloadSize / (1_024 * 1_024)
        Benchmark(
            "encode.append.\(label)MB",
            configuration: .init(maxIterations: 1_000)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                var output = ByteBuffer()
                CommandEncoding.encode(parts: parts, into: &output)
                blackHole(output)
            }
        }
    }

    // MARK: Server responses

    // The session preamble: capabilities, the mailbox tree, STATUS, the SELECT response codes,
    // search results, BYE. Wide rather than deep, and the shape a server writes on every connect.
    Benchmark("encode.responses.session") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(ResponseEncoding.encodeReusingBuffer(sessionResponses) { blackHole($0) })
        }
    }

    // ENVELOPE plus a nested BODYSTRUCTURE per message — the heaviest per-message response a server
    // writes, and the one with the most string building in it.
    Benchmark(
        "encode.responses.bodystructure.\(bodyStructureMessageCount)",
        configuration: .init(maxIterations: 1_000)
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(ResponseEncoding.encodeReusingBuffer(bodyStructureResponses) { blackHole($0) })
        }
    }

    // One `ResponseEncodeBuffer` for the whole sweep, drained per response — what
    // `IMAPServerHandler` does for the lifetime of a connection.
    Benchmark(
        "encode.responses.\(ResponseCorpus.defaultMessageCount).reused-buffer",
        configuration: .init(maxIterations: 1_000)
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(ResponseEncoding.encodeReusingBuffer(sweepResponses) { blackHole($0) })
        }
    }

    Benchmark(
        "encode.responses.\(ResponseCorpus.defaultMessageCount).fresh-buffer",
        configuration: .init(maxIterations: 1_000)
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(ResponseEncoding.encodeWithFreshBuffer(sweepResponses) { blackHole($0) })
        }
    }

    // The server side of the streaming path: a 1 MB body written as `streamingBytes` events at
    // MTU size, each of which `writeBuffer`s into the encode buffer today.
    let streamedLiteral = ResponseCorpus.literalFetchResponses(
        byteCount: 1_024 * 1_024,
        chunkSize: ReadSize.mtu
    )
    Benchmark(
        "encode.literal-1MB.streamed",
        configuration: .init(maxIterations: 1_000)
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(ResponseEncoding.encodeReusingBuffer(streamedLiteral) { blackHole($0) })
        }
    }

    // MARK: The handler's shape, per sink

    // Everything above measures encoding plus a copy of the result into one contiguous buffer. These
    // cases measure what a NIO handler actually does instead — one `ByteBuffer` per region, no
    // coalescing — and they come in pairs, one per shipped sink, because that is the only way to see
    // what the hand-out costs. `IMAPOutputBuffer` copies every region into a fresh `ByteBuffer` on the
    // way out; `ByteBufferOutput` hands out slices of the buffer it encoded into, and pays for that by
    // starting a fresh buffer once bytes have gone out of the old one.
    //
    // Read each pair against the other, not against the cases above: the work either side of the
    // encoder is different.
    for output in OutputBufferKind.allCases {
        Benchmark("encode.handler.commands.all.\(output.rawValue)") { benchmark in
            for _ in benchmark.scaledIterations {
                for (index, entry) in commands.enumerated() {
                    CommandEncoding.encodeAsHandler(
                        entry.command,
                        tag: CommandCorpus.tags[index],
                        output: output
                    ) { blackHole($0) }
                }
            }
        }

        Benchmark("encode.handler.command.noop.\(output.rawValue)") { benchmark in
            for _ in benchmark.scaledIterations {
                CommandEncoding.encodeAsHandler(.noop, tag: "A1", output: output) { blackHole($0) }
            }
        }

        // Three chunks for one short command: the shape that pays the per-hand-out cost most often.
        Benchmark("encode.handler.login.sync-literal.\(output.rawValue)") { benchmark in
            for _ in benchmark.scaledIterations {
                CommandEncoding.encodeAsHandler(
                    literalCommand,
                    tag: "A1",
                    options: synchronizingLiteralOptions,
                    output: output
                ) { blackHole($0) }
            }
        }

        // Zero-copy APPEND, as an allocation figure rather than an assertion: the payload is
        // appended by reference and written on its own, so neither sink copies it. The pair of sizes is
        // the point — if the allocated bytes stop scaling with the payload, nothing is copying it.
        // (The `encode.append.*` cases above still scale, because their driver coalesces every chunk
        // into one contiguous buffer, which is a copy the driver asks for.)
        for payloadSize in [1_024 * 1_024, 4 * 1_024 * 1_024] {
            let payload = IMAPBuffer(ByteBuffer(repeating: UInt8(ascii: "x"), count: payloadSize))
            let parts = CommandEncoding.appendParts(tag: "A1", payload: payload)
            Benchmark(
                "encode.handler.append.\(payloadSize / (1_024 * 1_024))MB.\(output.rawValue)",
                configuration: .init(maxIterations: 1_000)
            ) { benchmark in
                for _ in benchmark.scaledIterations {
                    CommandEncoding.encodeAsHandler(parts: parts, output: output) { blackHole($0) }
                }
            }
        }

        Benchmark(
            "encode.handler.responses.\(ResponseCorpus.defaultMessageCount).\(output.rawValue)",
            configuration: .init(maxIterations: 1_000)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(ResponseEncoding.encodeAsHandler(sweepResponses, output: output) { blackHole($0) })
            }
        }

        Benchmark(
            "encode.handler.responses.\(ResponseCorpus.defaultMessageCount).in-flight.\(output.rawValue)",
            configuration: .init(maxIterations: 1_000)
        ) { benchmark in
            // The same sweep, with every buffer held until the end of it. This is the pessimistic half
            // of the `ByteBufferOutput` trade and it has to be measured, not assumed: that sink can
            // only reuse the buffer it encoded into once the bytes handed out of it have been released,
            // and a server that writes a burst of responses and flushes once at the end never releases
            // one in time. Against the case above, the pair says how much of its allocation win
            // survives a channel that holds on to what it is given.
            var inFlight: [ByteBuffer] = []
            inFlight.reserveCapacity(4_096)
            for _ in benchmark.scaledIterations {
                inFlight.removeAll(keepingCapacity: true)
                blackHole(ResponseEncoding.encodeAsHandler(sweepResponses, output: output) { inFlight.append($0) })
                blackHole(inFlight.count)
            }
        }

        Benchmark(
            "encode.handler.responses.bodystructure.\(bodyStructureMessageCount).\(output.rawValue)",
            configuration: .init(maxIterations: 1_000)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(ResponseEncoding.encodeAsHandler(bodyStructureResponses, output: output) { blackHole($0) })
            }
        }

        Benchmark(
            "encode.handler.literal-1MB.streamed.\(output.rawValue)",
            configuration: .init(maxIterations: 1_000)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(ResponseEncoding.encodeAsHandler(streamedLiteral, output: output) { blackHole($0) })
            }
        }
    }

    // MARK: The DispatchData hand-out, per sink

    // These cases deliberately measure **no ARC metric**, which is both a correctness fix and an honesty
    // fix, and the reason is the same in each direction: a donated region carries a custom deallocator
    // block, and libdispatch runs a custom destructor on the default global queue when the queue is
    // `nil` rather than inline, so this is the only path in the suite that does reference counting on a
    // thread the benchmark does not own.
    //
    // *Honesty:* how many of a chunk's releases land inside the measured region depends on how far the
    // background queue has got. Over successive runs of the same binary `encode.dispatch.regions.64`
    // reported retain/release deltas of 61, 128 and 212 while its allocation counters were identical to
    // the byte, so gating them would gate noise.
    //
    // *Correctness:* asking for an ARC metric makes the harness install a `swift_retain` hook for the
    // duration of the benchmark, and its teardown (`swift_runtime_set_retain_hook(nil, nil)`) restores
    // the original function pointer and only *then* clears the hook data it still dereferences. A thread
    // already inside the hook therefore calls through a NULL pointer. Requesting ARC metrics here
    // segfaulted roughly one run in three, always on `com.apple.root.default-qos` inside the deallocator
    // block; not requesting them means the hook is never installed, because the harness installs it only
    // when a metric needs it. This is an upstream race (ordo-one/benchmark 1.36.2) that any benchmark
    // doing ARC work off-thread can hit — the second upstream issue this suite has had to work around.
    //
    // The allocation counters stay gated, and they are the ones the zero-copy claims are written in terms
    // of anyway: an asynchronous `free` cannot change how many times something was allocated, which is
    // exactly why they are exact here while the ARC counters are not.
    let dispatchMetrics: [BenchmarkMetric] = [
        .wallClock,
        .throughput,
        .mallocCountTotal,
        .mallocBytesCount,
        .peakMemoryResidentDelta,
    ]
    let dispatchThresholds: [BenchmarkMetric: BenchmarkThresholds] = [
        .wallClock: .relaxed,
        .throughput: .relaxed,
        .peakMemoryResidentDelta: .relaxed,
        .mallocCountTotal: BenchmarkThresholds(relative: [.p90: 1.0]),
        .mallocBytesCount: BenchmarkThresholds(relative: [.p90: 1.0]),
    ]

    // The other transport. `IMAPOutputBuffer` exists *because* of this path — a `ByteBuffer` can only be
    // filled in place, so the only way to hand a Dispatch caller bytes without copying them is for the
    // encoder to fill memory it allocated itself and then donate it — and yet until these cases the path
    // had correctness tests and no measurement at all. Every performance number about it came from a
    // scratch probe under `/tmp` that no longer exists.
    //
    // Read these against the `encode.handler.*` cases above, which are the same drivers converting to
    // `ByteBuffer` instead. The segment sink donates here and copies there; `ByteBufferOutput` slices
    // there and, because `ByteBuffer` is a `StableAddressByteRegion`, donates here too. Here either sink
    // copies regions shorter than `IMAPBuffer.dispatchDonationThreshold`, one allocation per run, so
    // these cases copy no payload, and what they measure is the dispatch objects and the short copies.
    for output in OutputBufferKind.allCases {
        Benchmark(
            "encode.dispatch.commands.all.\(output.rawValue)",
            configuration: .init(metrics: dispatchMetrics, thresholds: dispatchThresholds)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                for (index, entry) in commands.enumerated() {
                    CommandEncoding.encodeAsDispatchHandler(
                        entry.command,
                        tag: CommandCorpus.tags[index],
                        output: output
                    ) { blackHole($0) }
                }
            }
        }

        // Encoding and converting to `DispatchData` copies zero bytes, for a chunk spanning several
        // regions. Same construction as the `encode.handler.append.*` pair: if
        // the allocated bytes stop scaling with the payload, nothing is copying it. Expect that of both
        // sinks: the payload and `bytebuffer-sink`'s own regions are `ByteBuffer`-backed, and a
        // `ByteBuffer` promises a stable address, so they are donated.
        for payloadSize in [1_024 * 1_024, 4 * 1_024 * 1_024] {
            let payload = IMAPBuffer(ByteBuffer(repeating: UInt8(ascii: "x"), count: payloadSize))
            let parts = CommandEncoding.appendParts(tag: "A1", payload: payload)
            Benchmark(
                "encode.dispatch.append.\(payloadSize / (1_024 * 1_024))MB.\(output.rawValue)",
                configuration: .init(metrics: dispatchMetrics, maxIterations: 1_000, thresholds: dispatchThresholds)
            ) { benchmark in
                for _ in benchmark.scaledIterations {
                    CommandEncoding.encodeAsDispatchHandler(parts: parts, output: output) { blackHole($0) }
                }
            }
        }

        // A thousand small responses, i.e. a thousand dispatch objects. At a flat ~150 ns each this is
        // where the fixed per-conversion cost shows up as a per-message tax, which is the thing a
        // `ByteBuffer` transport does not pay.
        Benchmark(
            "encode.dispatch.responses.\(ResponseCorpus.defaultMessageCount).\(output.rawValue)",
            configuration: .init(metrics: dispatchMetrics, maxIterations: 1_000, thresholds: dispatchThresholds)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(
                    ResponseEncoding.encodeAsDispatchHandler(sweepResponses, output: output) { blackHole($0) }
                )
            }
        }

        Benchmark(
            "encode.dispatch.literal-1MB.streamed.\(output.rawValue)",
            configuration: .init(metrics: dispatchMetrics, maxIterations: 1_000, thresholds: dispatchThresholds)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(
                    ResponseEncoding.encodeAsDispatchHandler(streamedLiteral, output: output) { blackHole($0) }
                )
            }
        }
    }

    // The other half of the zero-copy `DispatchData` case: the same payload array-backed instead of
    // `ByteBuffer`-backed. Both are `StableAddressByteRegion`s — `bytesNoCopy` needs a pointer that
    // outlives its accessor, and either backing keeps its bytes in place while a copy of it is held — so
    // the allocated bytes should scale with the payload in none of the cases. A backing that does not
    // conform, such as `Data`, would be copied.
    for payloadSize in [1_024 * 1_024, 4 * 1_024 * 1_024] {
        let payload = IMAPBuffer([UInt8](repeating: UInt8(ascii: "x"), count: payloadSize))
        let parts = CommandEncoding.appendParts(tag: "A1", payload: payload)
        Benchmark(
            "encode.dispatch.append.\(payloadSize / (1_024 * 1_024))MB.array-payload",
            configuration: .init(metrics: dispatchMetrics, maxIterations: 1_000, thresholds: dispatchThresholds)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                CommandEncoding.encodeAsDispatchHandler(parts: parts, output: .segments) { blackHole($0) }
            }
        }
    }

    // MARK: The DispatchData conversion on its own

    // The measurement three design decisions rest on: the 64 KB segment cap, the refusal to split
    // eagerly, and the 64-region cap all come from "a `DispatchData` costs a flat ~150 ns regardless of
    // size, plus ~40 ns per additional region, so minimise regions per chunk". That was measured in a
    // scratch directory that is gone, so it is re-derived here — the slope across this sweep is the
    // per-region cost and the intercept is the flat one.
    //
    // `maxIterations` is deliberately low. A donated region's deallocator is a custom block with a `nil`
    // queue, which libdispatch dispatches to the default global queue rather than running inline, so the
    // segments come back asynchronously and a long run queues far more destruction work than it retires.
    for regionCount in DispatchConversion.regionCountSweep {
        let list = DispatchConversion.makeRegionList(regionCount: regionCount, regionSize: 4_096)
        Benchmark(
            "encode.dispatch.regions.\(regionCount)",
            configuration: .init(metrics: dispatchMetrics, maxIterations: 1_000, thresholds: dispatchThresholds)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(list.makeDispatchData())
            }
        }
    }
}
