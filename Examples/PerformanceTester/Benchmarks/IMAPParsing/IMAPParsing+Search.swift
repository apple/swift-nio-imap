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

// SEARCH and ESEARCH results (issue #694).
//
// Large results (5,000 elements) are the target: one line spread over many reads. Every read re-runs
// the parser from the start of the response until the line is complete, so the read-size cases
// measure that rework, and the contiguous case measures parsing alone.
//
// Small results (1–32 elements, 1,000 copies per sample) place the threshold below which a fast path
// should not engage.
//
// Names: `parse.<kind>.d<digits>.n<elements>[.contiguous|.read-<size>]`.
func registerSearchBenchmarks() {
    let largeReadSizes = [ReadSize.mtu, 16_384]

    for kind in SearchCorpus.Kind.allCases {
        for digits in SearchCorpus.Digits.allCases {
            let prefix = "parse.\(kind.rawValue).d\(digits.rawValue)"

            for count in SearchCorpus.smallCounts {
                let repetitions = SearchCorpus.smallRepetitions
                let bytes = SearchCorpus.responseBytes(
                    kind: kind,
                    count: count,
                    digits: digits,
                    repetitions: repetitions
                )
                checkSearchCorpus(kind: kind, count: count, digits: digits, repetitions: repetitions, chunks: [bytes])
                Benchmark("\(prefix).n\(count)", configuration: .init(maxIterations: 1_000)) { benchmark in
                    for _ in benchmark.scaledIterations {
                        try Parsing.parseResponses(chunks: [bytes]) { blackHole($0) }
                    }
                }
            }

            let count = SearchCorpus.largeCount
            let bytes = SearchCorpus.responseBytes(kind: kind, count: count, digits: digits)
            checkSearchCorpus(kind: kind, count: count, digits: digits, repetitions: 1, chunks: [bytes])
            Benchmark("\(prefix).n\(count).contiguous", configuration: .init(maxIterations: 1_000)) { benchmark in
                for _ in benchmark.scaledIterations {
                    try Parsing.parseResponses(chunks: [bytes]) { blackHole($0) }
                }
            }

            for readSize in largeReadSizes {
                let chunks = bytes.chunks(ofSize: readSize)
                checkSearchCorpus(kind: kind, count: count, digits: digits, repetitions: 1, chunks: chunks)
                Benchmark(
                    "\(prefix).n\(count).read-\(readSize)",
                    configuration: .init(maxIterations: 1_000)
                ) { benchmark in
                    for _ in benchmark.scaledIterations {
                        try Parsing.parseResponses(chunks: chunks) { blackHole($0) }
                    }
                }
            }
        }
    }

    // Building the set alone, from already-parsed ranges: what the ESEARCH parser does once it has
    // read every element. Separates set construction from number parsing.
    let ranges = SearchCorpus.elements(kind: .esearch, count: SearchCorpus.largeCount, digits: .five).map {
        MessageIdentifierRange(UID(rawValue: $0.lowerBound)...UID(rawValue: $0.upperBound))
    }
    Benchmark("build.esearch-set.n\(SearchCorpus.largeCount)", configuration: .init(maxIterations: 1_000)) {
        benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(MessageIdentifierSet(ranges))
        }
    }
}

/// Parses `chunks` once and traps unless every result equals the corpus it was generated from.
///
/// A fast path that silently drops or misreads a number would otherwise show up as a speed-up.
private func checkSearchCorpus(
    kind: SearchCorpus.Kind,
    count: Int,
    digits: SearchCorpus.Digits,
    repetitions: Int,
    chunks: [ByteBuffer]
) {
    let expected = SearchCorpus.elements(kind: kind, count: count, digits: digits)
    var results: [[ClosedRange<UInt32>]] = []
    var taggedCount = 0
    try! Parsing.parseResponses(chunks: chunks) { event in
        switch event {
        case .response(.untagged(.mailboxData(.search(let ids, _)))):
            results.append(ids.map { $0.rawValue...$0.rawValue })
        case .response(.untagged(.mailboxData(.extendedSearch(let response)))):
            let ranges = response.matchedUIDs.map { Array($0.ranges) } ?? []
            results.append(ranges.map { $0.range.lowerBound.rawValue...$0.range.upperBound.rawValue })
        case .response(.tagged):
            taggedCount += 1
        default:
            preconditionFailure("unexpected event in \(kind) corpus: \(event)")
        }
    }
    let name = "\(kind.rawValue) d\(digits.rawValue) n\(count), \(chunks.count) chunk(s)"
    precondition(taggedCount == 1, "\(name): \(taggedCount) tagged completions, expected 1")
    precondition(results.count == repetitions, "\(name): \(results.count) results, expected \(repetitions)")
    precondition(results.allSatisfy { $0 == expected }, "\(name): parsed result differs from the corpus")
}
