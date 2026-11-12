//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

import Dispatch
import Foundation
import Testing

/// Coverage for the input seam: the gather, the two paths through it, and the trimming contract.
///
/// Two of these tests exist because of failures that every *other* test in the suite passes with. Which
/// gather path a call takes is invisible from the outside — the answer is the same either way, only
/// copied instead of referenced — so it has to be asserted directly, for every call form, because the
/// forms differ. And an extraction taken after a partial consume is the only case where a missing offset
/// term shows up at all.
@Suite("ParserInputBuffer")
struct ParserInputBufferTests {}

// MARK: - Helpers

/// A payload big enough that the parser refers to it rather than copying it.
private let payload = Array(repeating: UInt8(ascii: "p"), count: 2048)

/// Extracts `count` bytes and reports whether they came out as a reference to the input.
private func extractsWithoutCopying(_ input: inout ParseInput, count: Int = payload.count) throws -> Bool {
    let head = input.withCurrentChunk { chunk in
        chunk.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress!) }
    }
    let buffer = try input.extractBuffer(upTo: count)
    guard buffer.retainedRegion != nil else { return false }
    return buffer.withUnsafeBytes { $0.baseAddress! } == head
}

/// The call form that binds a witness from a generic context, with no limit — the one that a default
/// argument in the wrong place silently sends down the generic path.
private func extractThroughGenericContext<Buffer: ParserInputBuffer>(_ buffer: Buffer) throws -> Bool {
    try buffer.withParseInput { try extractsWithoutCopying(&$0) }
}

private func extractThroughGenericParse<Buffer: ConsumableParserInputBuffer>(_ buffer: inout Buffer) throws -> Bool {
    try buffer.parse { try extractsWithoutCopying(&$0) }
}

private func makeInputBuffer(_ regions: [[UInt8]]) -> IMAPInputBuffer {
    var buffer = IMAPInputBuffer()
    for region in regions { buffer.append(region) }
    return buffer
}

private func makeDispatchData(_ pieces: [[UInt8]]) -> DispatchData {
    var data = DispatchData.empty
    for piece in pieces {
        piece.withUnsafeBufferPointer { data.append($0) }
    }
    return data
}

/// A conformer with no fast path at all: several regions, no owners, so it takes the recursive gather.
private struct ManyRegions: ParserInputBuffer {
    var byteRegions: [[UInt8]]
    var count: Int { byteRegions.reduce(0) { $0 + $1.count } }
}

/// A conformer whose `regionCount` is wrong on the low side, which is the one way a conformer can push
/// the gather past the end of the table it sized.
private struct UnderReportingRegionCount: ParserInputBuffer {
    var byteRegions: [[UInt8]]
    var count: Int { byteRegions.reduce(0) { $0 + $1.count } }
    var regionCount: Int { 1 }
}

// MARK: - Which gather ran

extension ParserInputBufferTests {
    @Test("A payload stays uncopied through every call form")
    func onePassGatherThroughEveryCallForm() throws {
        // A one-pass conformer has to win witness resolution from all of these. It did not, at one point,
        // from the two that leave the limit out — which is most calls — and nothing failed as a result:
        // the payload was simply copied every time.
        var buffer = makeInputBuffer([payload])
        #expect(try buffer.withParseInput(limit: .max) { try extractsWithoutCopying(&$0) })
        #expect(try buffer.withParseInput { try extractsWithoutCopying(&$0) })
        #expect(try extractThroughGenericContext(buffer))

        buffer = makeInputBuffer([payload])
        #expect(try buffer.parse(limit: .max) { try extractsWithoutCopying(&$0) })
        #expect(buffer.isEmpty == true)

        buffer = makeInputBuffer([payload])
        #expect(try buffer.parse { try extractsWithoutCopying(&$0) })

        buffer = makeInputBuffer([payload])
        #expect(try extractThroughGenericParse(&buffer))
    }

    @Test("A conformer that cannot vouch for its bytes gets a copy")
    func genericGatherCopies() throws {
        // Not a defect: nobody is keeping these bytes alive past the call, so a payload that outlives it
        // has to be copied. This is the honest answer for `Data`, `Array` and third-party conformers.
        #expect(try payload.withParseInput { try extractsWithoutCopying(&$0) } == false)
        #expect(try Data(payload).withParseInput { try extractsWithoutCopying(&$0) } == false)
        #expect(try makeDispatchData([payload]).withParseInput { try extractsWithoutCopying(&$0) } == false)
    }

    @Test("A payload extracted after an earlier parse is the right payload")
    func extractionAfterPartialConsume() throws {
        // The bytes handed out come from an owner that spans the whole appended run, while the region is
        // the tail of that run — so the range has to account for what earlier parses consumed as well as
        // for what this one has. Getting it wrong returns well-formed bytes from the wrong place.
        var buffer = makeInputBuffer([Array("A003 LOGOUT\r\n".utf8) + payload])
        buffer.parse { $0.advance(by: 13) }
        #expect(buffer.count == payload.count)

        let extracted = try buffer.parse { try $0.extractBuffer(upTo: 4096) }
        #expect(extracted.retainedRegion != nil, "the payload should still be a reference to the input")
        #expect(extracted.copiedBytes() == payload)
        #expect(buffer.isEmpty == true)
    }
}

// MARK: - Trimming

extension ParserInputBufferTests {
    @Test("Parsing discards exactly what the parser consumed")
    func parseTrims() throws {
        var buffer = makeInputBuffer([Array("A001 NOOP\r\nA002 NOOP\r\n".utf8)])
        let first = try buffer.parse { try $0.extractBytes(length: 11) }
        #expect(String(decoding: first, as: UTF8.self) == "A001 NOOP\r\n")
        #expect(buffer.count == 11)
        let second = try buffer.parse { try $0.extractBytes(length: 11) }
        #expect(String(decoding: second, as: UTF8.self) == "A002 NOOP\r\n")
        #expect(buffer.isEmpty == true)
    }

    @Test("A buffer that slices its head region trims by the right amount")
    func headSlicingConformerTrims() throws {
        // The failure this pins produced `03 LOGOUT` from `A003 LOGOUT`: a buffer whose read head is an
        // offset must present its regions from that head, so that what the parser reports having consumed
        // means the same thing to both sides.
        var buffer = TestInputBuffer([TestRegion("A003 LOGOUT\r\nHELLOWORLD")])
        let tag = try buffer.parse { try $0.extractBytes(length: 4) }
        #expect(String(decoding: tag, as: UTF8.self) == "A003")
        #expect(buffer.count == 19)
        let rest = try buffer.parse { try $0.extractBytes(length: 19) }
        #expect(String(decoding: rest, as: UTF8.self) == " LOGOUT\r\nHELLOWORLD")
    }

    @Test("What the parser consumed is discarded even when it throws")
    func parseTrimsOnThrow() {
        // The streaming literal modes make progress and *then* report that they need more bytes, and a
        // response parser skips a stray LF outside any backtracking frame. Both would re-parse bytes if
        // trimming only happened on the way out of a successful parse.
        var buffer = makeInputBuffer([Array("A003 LOGOUT\r\n".utf8)])
        let error = errorThrown {
            try buffer.parse { input in
                input.advance(by: 4)
                throw IncompleteMessage()
            }
        }
        #expect(error is IncompleteMessage)
        #expect(buffer.count == 9)
    }

    @Test("A parse that consumes nothing discards nothing")
    func parseTrimsNothing() throws {
        var buffer = makeInputBuffer([Array("A003 LOGOUT\r\n".utf8)])
        let peeked = buffer.parse { $0.peek(at: 0) }
        #expect(peeked == UInt8(ascii: "A"))
        #expect(buffer.count == 13)
    }

    @Test("A limit hides the bytes past it, and they are not trimmed")
    func parseWithLimit() throws {
        var buffer = makeInputBuffer([Array("A003 LOGOUT\r\n".utf8)])
        let bytes = try buffer.parse(limit: 4) { input in
            #expect(input.remaining == 4)
            return try input.extractBytes(length: 4)
        }
        #expect(String(decoding: bytes, as: UTF8.self) == "A003")
        #expect(buffer.count == 9)
    }
}

// MARK: - Region counts

extension ParserInputBufferTests {
    @Test("A DispatchData parses across its regions", arguments: [1, 2, 25, 5000])
    func dispatchDataRegions(pieceCount: Int) throws {
        let pieces = (0..<pieceCount).map { [UInt8($0 % 251)] }
        var data = makeDispatchData(pieces)
        #expect(data.count == pieceCount)
        #expect(data.regionCount == data.regions.count)
        let bytes = try data.parse { try $0.extractBytes(length: pieceCount) }
        #expect(bytes == pieces.flatMap { $0 })
        #expect(data.count == 0)
    }

    @Test("More regions than the recursion can descend are coalesced rather than crashing")
    func recursionIsCapped() throws {
        // Uncapped, this is a stack overflow at somewhere around 1,520 regions — and a stack overflow
        // cannot be caught, so "the caller passed a lot of regions" would be a killed process. The tail
        // beyond the cap is copied into one region instead: bounded stack, unbounded input, nothing lost.
        let bytes = (0..<5000).map { UInt8($0 % 251) }
        let buffer = ManyRegions(byteRegions: bytes.map { [$0] })
        #expect(buffer.regionCount > ManyRegions.maximumGatherDepth)
        let parsed = try buffer.withParseInput { input in
            let head = try input.extractBytes(length: 3000)
            let tail = try input.extractBytes(length: 2000)
            #expect(input.isEmpty == true)
            return head + tail
        }
        #expect(parsed == bytes, "the coalesced tail has to keep its order and its place")
    }

    @Test("A conformer that under-reports its region count still parses")
    func underReportedRegionCount() throws {
        // The table is sized from `regionCount`, so this is the one conformance mistake that could write
        // past it. The gather coalesces when the table is full for the same reason it coalesces at the
        // depth cap, so the mistake costs a copy rather than memory corruption.
        let buffer = UnderReportingRegionCount(byteRegions: [[1, 2], [3, 4], [5], [6, 7]])
        let parsed = try buffer.withParseInput { try $0.extractBytes(length: 7) }
        #expect(parsed == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test("An empty buffer hands over an exhausted cursor")
    func emptyInput() throws {
        var buffer = IMAPInputBuffer()
        buffer.parse { input in
            #expect(input.isEmpty == true)
            #expect(input.remaining == 0)
        }
        ManyRegions(byteRegions: []).withParseInput { #expect($0.isEmpty == true) }
        ManyRegions(byteRegions: [[], []]).withParseInput { #expect($0.isEmpty == true) }
        [UInt8]().withParseInput { #expect($0.isEmpty == true) }
    }
}

// MARK: - Stdlib and Foundation conformers

extension ParserInputBufferTests {
    @Test("The stdlib byte containers and Foundation's can all be parsed from")
    func shippedConformers() throws {
        let text = "A001 NOOP\r\n"
        let bytes = Array(text.utf8)

        let fromArray = try bytes.withParseInput { try $0.extractBytes(length: bytes.count) }
        let fromSlice = try bytes[0...].withParseInput { try $0.extractBytes(length: bytes.count) }
        let fromContiguous = try ContiguousArray(bytes).withParseInput {
            try $0.extractBytes(length: bytes.count)
        }
        let fromData = try Data(bytes).withParseInput { try $0.extractBytes(length: bytes.count) }
        let fromDispatch = try makeDispatchData([bytes]).withParseInput {
            try $0.extractBytes(length: bytes.count)
        }

        #expect(fromArray == bytes)
        #expect(fromSlice == bytes)
        #expect(fromContiguous == bytes)
        #expect(fromData == bytes)
        #expect(fromDispatch == bytes)
    }

    @Test("A parsed prefix is discarded from a DispatchData without copying the rest")
    func dispatchDataDiscardFirst() throws {
        var data = makeDispatchData([Array("A001 NOOP\r\n".utf8), Array("A002 NOOP\r\n".utf8)])
        for tag in ["A001", "A002"] {
            let line = try data.parse { try $0.extractBytes(length: 11) }
            #expect(String(decoding: line, as: UTF8.self) == "\(tag) NOOP\r\n")
        }
        #expect(data.count == 0)
    }

    @Test("Trimming a DispatchData repeatedly does not pile up wrappers")
    func dispatchDataTrimmingStaysFlat() throws {
        // `subdata(in:)` is the cheap way to consume a prefix, but a chain of subranges that the gather
        // then had to walk would make each parse a little more expensive than the last. It does not: the
        // region count only ever goes down, whether the trim lands on a boundary or inside a region.
        var data = makeDispatchData((0..<20).map { Array(repeating: UInt8($0), count: 10) })
        #expect(data.regionCount == 20)
        for step in 1...20 {
            _ = try data.parse { try $0.extractBytes(length: 10) }
            #expect(data.regionCount == 20 - step)
        }
        #expect(data.count == 0)

        var uneven = makeDispatchData((0..<4).map { Array(repeating: UInt8($0), count: 10) })
        _ = try uneven.parse { try $0.extractBytes(length: 5) }
        #expect(uneven.regionCount == 4, "a trim inside a region leaves that region, shortened")
        _ = try uneven.parse { try $0.extractBytes(length: 5) }
        #expect(uneven.regionCount == 3)
    }
}
