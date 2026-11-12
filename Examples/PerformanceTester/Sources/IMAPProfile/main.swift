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
import IMAPBenchmarkSupport
import NIO
import NIOIMAP

// A plain executable that runs one benchmark corpus a chosen number of times, for profiling under
// Instruments.
//
// The benchmark runners are profileable too, but they decide their own iteration count from a time
// budget, and they run inside a malloc interposer that both attributes every allocation to itself
// and changes what the Allocations template sees. Under `Allocations` a 3-second budget is also the
// wrong budget: the body-structure case allocates ~414,000 times per iteration, so the runner's ~116
// iterations record ~48 million events. This takes the count as an argument instead.
//
//     swift build -c release --disable-sandbox
//     xcrun xctrace record --template Allocations \
//       --launch -- .build/release/IMAPProfile bodystructure 3
//
// The corpora and drivers are the same ones the benchmarks use, so a hotspot found here is a hotspot
// there.

let scenarios: [String: (Int) -> Void] = [
    // The heavy FETCH: ENVELOPE plus a nested BODYSTRUCTURE, 200 messages, contiguous.
    // `parse.responses.bodystructure.200`.
    "bodystructure": { iterations in
        let bytes = ResponseCorpus.bodyStructureBytes(messageCount: 200)
        for _ in 0..<iterations {
            try! Parsing.parseResponses(chunks: [bytes]) { consume($0) }
        }
    },

    // The light FETCH: UID, size, flags, 1,000 messages, contiguous.
    // `parse.responses.1000.contiguous`.
    "sweep": { iterations in
        let bytes = ResponseCorpus.sweepBytes()
        for _ in 0..<iterations {
            try! Parsing.parseResponses(chunks: [bytes]) { consume($0) }
        }
    },

    // The same heavy FETCH at socket-read size, which is what a client actually sees.
    // `parse.responses.bodystructure.200.read-1448`.
    "bodystructure-mtu": { iterations in
        let chunks = ResponseCorpus.bodyStructureBytes(messageCount: 200).chunks(ofSize: ReadSize.mtu)
        for _ in 0..<iterations {
            try! Parsing.parseResponses(chunks: chunks) { consume($0) }
        }
    },

    // Wide rather than deep: most of the distinct response grammar a client handles.
    // `parse.responses.session`.
    "session": { iterations in
        let bytes = ResponseCorpus.sessionBytes()
        for _ in 0..<iterations {
            try! Parsing.parseResponses(chunks: [bytes]) { consume($0) }
        }
    },

    // The client-command corpus, i.e. the parse side of what a server does.
    // `parse.commands.all`.
    "commands": { iterations in
        let encoded = CommandCorpus.encodedAll
        for _ in 0..<iterations {
            for (_, bytes) in encoded {
                try! Parsing.parseCommand(bytes: bytes) { consume($0) }
            }
        }
    },

    // A 1 MB literal streamed at socket-read size. `parse.literal-1MB.read-1448`.
    "literal": { iterations in
        let chunks = ResponseCorpus.literalFetchBytes(byteCount: 1_024 * 1_024).chunks(ofSize: ReadSize.mtu)
        let options = Parsing.streamingOptions()
        for _ in 0..<iterations {
            try! Parsing.parseResponses(chunks: chunks, options: options) { consume($0) }
        }
    },

    // The command corpus, encoded rather than parsed. `encode.commands.all`.
    "encode-commands": { iterations in
        let commands = CommandCorpus.all
        for _ in 0..<iterations {
            var output = ByteBuffer()
            for (index, entry) in commands.enumerated() {
                CommandEncoding.encode(entry.command, tag: CommandCorpus.tags[index], into: &output)
            }
            consume(output)
        }
    },
]

/// Keeps a parsed value alive past the point the optimizer could delete the work that produced it.
///
/// The benchmarks use `Benchmark.blackHole`, which this executable deliberately cannot reach. A
/// `@inline(never)` function whose argument is stored to a global is the same guarantee without the
/// dependency.
@inline(never)
func consume<T>(_ value: T) {
    withExtendedLifetime(value) {}
}

let arguments = CommandLine.arguments.dropFirst()
guard let name = arguments.first, let scenario = scenarios[name] else {
    let names = scenarios.keys.sorted().joined(separator: ", ")
    print("usage: IMAPProfile <scenario> [iterations]\n  scenarios: \(names)")
    exit(arguments.isEmpty ? 1 : 2)
}
let iterations = arguments.dropFirst().first.flatMap(Int.init) ?? 1

let start = DispatchTime.now()
scenario(iterations)
let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
print("\(name): \(iterations) iteration(s) in \(String(format: "%.1f", elapsed)) ms")
