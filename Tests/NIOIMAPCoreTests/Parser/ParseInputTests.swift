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

@testable import NIOIMAPCore

import Testing

/// Boundary coverage for the parse cursor.
///
/// Nearly every case here is about a *region boundary*, because that is where this type differs from the
/// single-buffer cursor it replaces, and because the failure mode is silent: a cursor parked on an
/// exhausted region reports end-of-input while bytes are still waiting, so a multi-region extraction
/// stops early and returns the wrong — but perfectly well-formed — answer.
@Suite("ParseInput")
struct ParseInputTests {}

// MARK: - Layout

extension ParseInputTests {
    @Test("The cursor stays a small trivial value")
    func layout() {
        // Backtracking copies this value constantly, so its size and its triviality are the whole reason
        // `composite` is cheap. `lastParsedNewline` shares a word with the region index to keep it here.
        #expect(MemoryLayout<ParseInput>.size == 56)
        #expect(MemoryLayout<ParseInput>.stride == 56)
        #expect(MemoryLayout<RegionEntry>.size == 32)
    }
}

// MARK: - Walking

extension ParseInputTests {
    @Test("A single contiguous region reads back")
    func singleRegion() {
        ParseInputHarness.withSpan("A003 LOGOUT") { input in
            #expect(input.remaining == 11)
            #expect(input.isEmpty == false)
            #expect(input.peek(at: 0) == UInt8(ascii: "A"))
            #expect(input.peek(at: 10) == UInt8(ascii: "T"))
            #expect(input.peek(at: 11) == nil)
            input.advance(by: 5)
            #expect(input.consumed == 5)
            #expect(input.peek(at: 0) == UInt8(ascii: "L"))
            #expect(input.remaining == 6)
        }
    }

    @Test("Peeking crosses region boundaries")
    func peekAcrossRegions() {
        ParseInputHarness.withInput([TestRegion("A00"), TestRegion("3 LOG"), TestRegion("OUT")]) { input in
            #expect(input.remaining == 11)
            #expect(input.peek(at: 2) == UInt8(ascii: "0"))
            #expect(input.peek(at: 3) == UInt8(ascii: "3"))
            #expect(input.peek(at: 8) == UInt8(ascii: "O"))
            #expect(input.peek(at: 10) == UInt8(ascii: "T"))
            #expect(input.peek(at: 11) == nil)
            #expect(input.consumed == 0)
        }
    }

    @Test("Landing exactly on a region boundary refills the head")
    func advanceOntoBoundary() {
        // The bug this pins: guarding the refill with `if headIsEmpty && more > 0` leaves the cursor
        // parked on an exhausted region, and every primitive then reports end-of-input.
        ParseInputHarness.withInput([TestRegion("abc"), TestRegion("def")]) { input in
            input.advance(by: 3)
            #expect(input.isEmpty == false)
            #expect(input.peek(at: 0) == UInt8(ascii: "d"))
            #expect(input.remaining == 3)
            #expect(input.consumed == 3)
        }
    }

    @Test("Leading empty regions are skipped when the cursor is built")
    func leadingEmptyRegions() {
        ParseInputHarness.withInput([TestRegion(""), TestRegion(""), TestRegion("ab")]) { input in
            #expect(input.isEmpty == false)
            #expect(input.peek(at: 0) == UInt8(ascii: "a"))
            #expect(input.remaining == 2)
        }
    }

    @Test("Interior empty regions are skipped while advancing")
    func interiorEmptyRegions() {
        let regions = [TestRegion("ab"), TestRegion(""), TestRegion(""), TestRegion("cd")]
        ParseInputHarness.withInput(regions) { input in
            #expect(input.peek(at: 2) == UInt8(ascii: "c"))
            input.advance(by: 2)
            #expect(input.peek(at: 0) == UInt8(ascii: "c"))
            input.advance(by: 2)
            #expect(input.isEmpty == true)
            #expect(input.consumed == 4)
        }
    }

    @Test("A trailing empty region still reads as exhausted")
    func trailingEmptyRegion() {
        ParseInputHarness.withInput([TestRegion("ab"), TestRegion("")]) { input in
            input.advance(by: 2)
            #expect(input.isEmpty == true)
            #expect(input.peek(at: 0) == nil)
            #expect(input.remaining == 0)
        }
    }

    @Test("Advancing past the end clamps, and advancing again is a no-op")
    func advancePastTheEnd() {
        ParseInputHarness.withInput([TestRegion("ab"), TestRegion("cd")]) { input in
            input.advance(by: 999)
            #expect(input.consumed == 4)
            #expect(input.isEmpty == true)
            input.advance(by: 999)
            #expect(input.consumed == 4)
        }
    }

    @Test("Advancing by zero leaves the invariant true")
    func advanceByZero() {
        ParseInputHarness.withInput([TestRegion(""), TestRegion("ab")]) { input in
            input.advance(by: 0)
            #expect(input.consumed == 0)
            #expect(input.peek(at: 0) == UInt8(ascii: "a"))
        }
    }

    @Test("Empty and all-empty inputs terminate")
    func emptyInputs() {
        ParseInputHarness.withInput([]) { input in
            #expect(input.isEmpty == true)
            #expect(input.remaining == 0)
            #expect(input.peek(at: 0) == nil)
            input.advance(by: 4)
            #expect(input.consumed == 0)
        }
        ParseInputHarness.withInput([TestRegion(""), TestRegion(""), TestRegion("")]) { input in
            #expect(input.isEmpty == true)
            input.advance(by: 4)
            #expect(input.consumed == 0)
        }
    }

    @Test("peek2 spans a boundary and reports the end")
    func peek2() {
        ParseInputHarness.withInput([TestRegion("a"), TestRegion("bc")]) { input in
            #expect(input.peek2().map { [$0.0, $0.1] } == [UInt8(ascii: "a"), UInt8(ascii: "b")])
            input.advance(by: 1)
            #expect(input.peek2().map { [$0.0, $0.1] } == [UInt8(ascii: "b"), UInt8(ascii: "c")])
            input.advance(by: 1)
            #expect(input.peek2() == nil)
        }
    }

    @Test("withCurrentChunk hands out the current region only")
    func currentChunk() {
        ParseInputHarness.withInput([TestRegion("abc"), TestRegion("de")]) { input in
            #expect(input.withCurrentChunk { $0.count } == 3)
            input.advance(by: 3)
            #expect(input.withCurrentChunk { $0.count } == 2)
            input.advance(by: 2)
            #expect(input.withCurrentChunk { $0.isEmpty } == true)
        }
    }
}

// MARK: - The limit

extension ParseInputTests {
    @Test("The limit hides bytes from every primitive")
    func limitHidesBytes() {
        ParseInputHarness.withInput([TestRegion("abcd"), TestRegion("efgh")], limit: 6) { input in
            #expect(input.remaining == 6)
            #expect(input.peek(at: 5) == UInt8(ascii: "f"))
            #expect(input.peek(at: 6) == nil)
            #expect(input.withCurrentChunk { $0.count } == 4)
            input.advance(by: 4)
            #expect(input.withCurrentChunk { $0.count } == 2)
            input.advance(by: 999)
            #expect(input.consumed == 6)
            #expect(input.isEmpty == true)
        }
    }

    @Test("A limit falling mid-region truncates the head")
    func limitMidRegion() {
        ParseInputHarness.withSpan("abcdef", limit: 3) { input in
            #expect(input.remaining == 3)
            #expect(input.withCurrentChunk { $0.count } == 3)
            #expect(input.scanUntil(byte: UInt8(ascii: "e")) == nil)
            #expect(errorThrown(by: { try input.extractBytes(length: 4) }) is IncompleteMessage)
            #expect(try! input.extractBytes(length: 3) == Array("abc".utf8))
            #expect(errorThrown(by: { try input.extractBuffer(upTo: 1) }) is IncompleteMessage)
        }
    }
}

// MARK: - Scans

extension ParseInputTests {
    @Test("scanUntil finds a byte in the current region")
    func scanUntilInHead() {
        ParseInputHarness.withSpan("abc def") { input in
            #expect(input.scanUntil(byte: UInt8(ascii: " ")) == 3)
            #expect(input.consumed == 0)
        }
    }

    @Test("scanUntil crosses regions")
    func scanUntilAcrossRegions() {
        ParseInputHarness.withInput([TestRegion("abc"), TestRegion(""), TestRegion("de f")]) { input in
            #expect(input.scanUntil(byte: UInt8(ascii: " ")) == 5)
            #expect(input.scanUntil(byte: UInt8(ascii: "f")) == 6)
            #expect(input.scanUntil(byte: UInt8(ascii: "z")) == nil)
            #expect(input.consumed == 0)
        }
    }

    @Test("scanWhile stops at the first byte that fails, in whichever region it is")
    func scanWhileAcrossRegions() {
        let isDigit: (UInt8) -> Bool = { $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }
        ParseInputHarness.withInput([TestRegion("12"), TestRegion("34"), TestRegion(" x")]) { input in
            #expect(input.scanWhile(isDigit) == 4)
            #expect(input.consumed == 0)
        }
        ParseInputHarness.withSpan("x123") { input in
            #expect(input.scanWhile(isDigit) == 0)
        }
    }

    @Test("scanWhile reports nil when every visible byte matches")
    func scanWhileRunsOut() {
        let isDigit: (UInt8) -> Bool = { $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }
        // nil means "this run might continue in bytes that have not arrived", which is what both
        // character-class parsers turn into `IncompleteMessage`.
        ParseInputHarness.withInput([TestRegion("12"), TestRegion("34")]) { input in
            #expect(input.scanWhile(isDigit) == nil)
        }
        // The same answer when the limit is what cut the run short, not the end of the input.
        ParseInputHarness.withSpan("12 x", limit: 2) { input in
            #expect(input.scanWhile(isDigit) == nil)
        }
        ParseInputHarness.withInput([]) { input in
            #expect(input.scanWhile(isDigit) == nil)
        }
    }
}

// MARK: - Extracting bytes

extension ParseInputTests {
    @Test("extractBytes copies across three regions")
    func extractBytesAcrossRegions() throws {
        let bytes = try ParseInputHarness.withInput([TestRegion("A0"), TestRegion("03 LO"), TestRegion("GOUT")]) {
            input in
            let bytes = try input.extractBytes(length: 11)
            #expect(input.consumed == 11)
            #expect(input.isEmpty == true)
            return bytes
        }
        #expect(bytes == Array("A003 LOGOUT".utf8))
    }

    @Test("extractBytes asking for more than is there consumes nothing")
    func extractBytesTooLong() {
        ParseInputHarness.withInput([TestRegion("ab"), TestRegion("cd")]) { input in
            #expect(errorThrown(by: { try input.extractBytes(length: 5) }) is IncompleteMessage)
            #expect(input.consumed == 0)
            #expect(try! input.extractBytes(length: 4) == Array("abcd".utf8))
        }
    }

    @Test("extractBytes of nothing is nothing")
    func extractNoBytes() {
        ParseInputHarness.withInput([]) { input in
            #expect(try! input.extractBytes(length: 0) == [])
        }
    }

    @Test("readByte consumes one byte, and reports the end")
    func readByte() {
        ParseInputHarness.withInput([TestRegion("a"), TestRegion("b")]) { input in
            #expect(try! input.readByte() == UInt8(ascii: "a"))
            #expect(try! input.readByte() == UInt8(ascii: "b"))
            #expect(errorThrown(by: { try input.readByte() }) is IncompleteMessage)
        }
    }
}

// MARK: - Extracting payloads

extension ParseInputTests {
    /// A payload big enough to be worth referring to rather than copying.
    private static let payload = Array(repeating: UInt8(ascii: "p"), count: 2048)

    @Test("A large payload is handed out as a reference to the input")
    func extractBufferRetains() throws {
        let (isSameMemory, bytes) = try ParseInputHarness.withInput([TestRegion(owned: Self.payload)]) { input in
            let head = input.withCurrentChunk { chunk in
                chunk.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress!) }
            }
            let buffer = try input.extractBuffer(upTo: 2048)
            let extracted = buffer.withUnsafeBytes { $0.baseAddress! }
            #expect(input.consumed == 2048)
            return (head == extracted, buffer.copiedBytes())
        }
        #expect(isSameMemory, "a payload at or above the copy threshold must not be copied")
        #expect(bytes == Self.payload)
    }

    @Test("A small payload is copied")
    func extractBufferCopiesBelowThreshold() throws {
        let small = Array("small".utf8)
        let isSameMemory = try ParseInputHarness.withInput([TestRegion(owned: small)]) { input in
            let head = input.withCurrentChunk { chunk in
                chunk.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress!) }
            }
            let buffer = try input.extractBuffer(upTo: small.count)
            #expect(buffer.copiedBytes() == small)
            return head == buffer.withUnsafeBytes { $0.baseAddress! }
        }
        #expect(isSameMemory == false, "below the threshold, pinning the whole region is not worth it")
    }

    @Test("A payload with no owner is copied, however large")
    func extractBufferCopiesWithoutAnOwner() throws {
        // Two ways to have no owner: a region the gather could not vouch for, and the single-span entry
        // point, which has no table at all.
        for vouching in [TestRegion.Vouching.unvouched] {
            let isSameMemory = try ParseInputHarness.withInput([
                TestRegion(owned: Self.payload, vouching: vouching)
            ]) { input in
                let head = input.withCurrentChunk { chunk in
                    chunk.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress!) }
                }
                let buffer = try input.extractBuffer(upTo: 2048)
                return head == buffer.withUnsafeBytes { $0.baseAddress! }
            }
            #expect(isSameMemory == false)
        }
        let isSameMemory = try ParseInputHarness.withSpan(Self.payload) { input in
            let head = input.withCurrentChunk { chunk in
                chunk.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress!) }
            }
            let buffer = try input.extractBuffer(upTo: 2048)
            #expect(buffer.copiedBytes() == Self.payload)
            return head == buffer.withUnsafeBytes { $0.baseAddress! }
        }
        #expect(isSameMemory == false)
    }

    @Test("A payload extracted from a partially consumed, head-sliced region is the right payload")
    func extractBufferAfterPartialConsume() throws {
        // The case that catches an offset bug, and the only case that does: the owner box spans a whole
        // network read, the region is the tail of it after an earlier parse, and this parse has already
        // consumed some of that tail. Both offsets have to be added, and a test where either one is zero
        // passes with the wrong arithmetic.
        let prefix = "A003 LOGOUT\r\n"
        let payload = Array(repeating: UInt8(ascii: "z"), count: 2048)
        let owned = Array(prefix.utf8) + payload
        let region = TestRegion(owned: owned, visible: prefix.utf8.count..<owned.count)
        let bytes = try ParseInputHarness.withInput([region]) { input in
            input.advance(by: 5)
            let buffer = try input.extractBuffer(upTo: 4096)
            #expect(buffer.count == payload.count - 5)
            return buffer.copiedBytes()
        }
        #expect(bytes == Array(payload.dropFirst(5)))
    }

    @Test("A payload never crosses a region boundary")
    func extractBufferStopsAtRegionEnd() throws {
        let first = Array(repeating: UInt8(ascii: "1"), count: 2048)
        let second = Array(repeating: UInt8(ascii: "2"), count: 2048)
        try ParseInputHarness.withInput([TestRegion(owned: first), TestRegion(owned: second)]) { input in
            let head = try input.extractBuffer(upTo: 4096)
            #expect(head.count == 2048)
            #expect(head.copiedBytes() == first)
            let tail = try input.extractBuffer(upTo: 4096)
            #expect(tail.copiedBytes() == second)
            #expect(input.isEmpty == true)
        }
    }

    @Test("Asking for no bytes returns no bytes rather than throwing")
    func extractBufferZeroLength() throws {
        // `APPEND … {0+}` depends on this: the command parser has no zero-remaining special case, and
        // moves on only when it gets an empty payload back. Guarding on the take rather than on the
        // input turns that command into a throw.
        try ParseInputHarness.withSpan("abc") { input in
            let buffer = try input.extractBuffer(upTo: 0)
            #expect(buffer.count == 0)
            #expect(input.consumed == 0)
        }
    }

    @Test("Extracting from an exhausted cursor throws")
    func extractBufferAtEnd() {
        ParseInputHarness.withInput([TestRegion("ab")]) { input in
            input.advance(by: 2)
            #expect(errorThrown(by: { try input.extractBuffer(upTo: 4) }) is IncompleteMessage)
        }
    }

    @Test("An extracted payload outlives the gather")
    func extractedBufferOutlivesTheGather() throws {
        let buffer = try ParseInputHarness.withInput([TestRegion(owned: Self.payload)]) { input in
            try input.extractBuffer(upTo: 2048)
        }
        // The regions' accessor scopes are all closed by now, so this reads through the owner the buffer
        // retained, not through the table.
        #expect(buffer.copiedBytes() == Self.payload)
        #expect(buffer.count == 2048)
    }

    @Test("The limit clamps a payload extraction")
    func extractBufferRespectsLimit() throws {
        try ParseInputHarness.withInput([TestRegion(owned: Self.payload)], limit: 100) { input in
            let buffer = try input.extractBuffer(upTo: 4096)
            #expect(buffer.count == 100)
            #expect(errorThrown(by: { try input.extractBuffer(upTo: 4096) }) is IncompleteMessage)
        }
    }
}

// MARK: - Matching

extension ParseInputTests {
    @Test("matchFixed consumes a match, case-insensitively by default")
    func matchFixed() {
        ParseInputHarness.withSpan("SELECT INBOX") { input in
            try! input.matchFixed("select ")
            #expect(input.consumed == 7)
            #expect(input.peek(at: 0) == UInt8(ascii: "I"))
        }
    }

    @Test("matchFixed matches across a region boundary")
    func matchFixedAcrossRegions() {
        ParseInputHarness.withInput([TestRegion("SEL"), TestRegion(""), TestRegion("ECT x")]) { input in
            try! input.matchFixed("SELECT")
            #expect(input.consumed == 6)
            #expect(input.peek(at: 0) == UInt8(ascii: " "))
        }
    }

    @Test("matchFixed consumes nothing when a byte disagrees")
    func matchFixedMismatch() {
        ParseInputHarness.withInput([TestRegion("SEL"), TestRegion("XCT")]) { input in
            #expect(errorThrown(by: { try input.matchFixed("SELECT") }) is ParserError)
            #expect(input.consumed == 0)
            #expect(input.peek(at: 0) == UInt8(ascii: "S"))
        }
    }

    @Test("matchFixed is case-sensitive when asked")
    func matchFixedCaseSensitive() {
        ParseInputHarness.withSpan("select") { input in
            #expect(errorThrown(by: { try input.matchFixed("SELECT", caseSensitivity: .caseSensitive) }) is ParserError)
            #expect(input.consumed == 0)
            try! input.matchFixed("select", caseSensitivity: .caseSensitive)
            #expect(input.consumed == 6)
        }
    }

    @Test("matchFixed waits for more bytes when what arrived is a prefix")
    func matchFixedShortPrefix() {
        // The distinction matters: a prefix may still be completed by the next read, a mismatch never
        // can. Getting it the wrong way round either stalls a connection or rejects a valid command.
        ParseInputHarness.withInput([TestRegion("SE"), TestRegion("L")]) { input in
            #expect(errorThrown(by: { try input.matchFixed("SELECT") }) is IncompleteMessage)
            #expect(input.consumed == 0)
        }
    }

    @Test("matchNewline recognises each line ending and records it")
    func matchNewline() {
        ParseInputHarness.withSpan("\r\nx") { input in
            #expect(try! input.matchNewline() == .crlf)
            #expect(input.consumed == 2)
            #expect(input.lastParsedNewline == .crlf)
        }
        ParseInputHarness.withSpan("\nx") { input in
            #expect(try! input.matchNewline() == .lf)
            #expect(input.consumed == 1)
        }
        // A bare CR: the LF may be in the next read, which is what `skipLF` is for.
        ParseInputHarness.withSpan("\r") { input in
            #expect(try! input.matchNewline() == .cr)
            #expect(input.consumed == 1)
            #expect(input.lastParsedNewline == .cr)
        }
        ParseInputHarness.withSpan("\rx") { input in
            #expect(try! input.matchNewline() == .cr)
        }
    }

    @Test("matchNewline skips the stray spaces some servers send")
    func matchNewlineSkipsSpaces() {
        ParseInputHarness.withSpan("  \r\nx") { input in
            #expect(try! input.matchNewline() == .crlf)
            #expect(input.consumed == 4)
        }
    }

    @Test("matchNewline tolerates a modest run of stray spaces")
    func matchNewlineToleratesModestSpaces() {
        let spaces = ParseInput.maximumStraySpaces
        ParseInputHarness.withSpan(String(repeating: " ", count: spaces) + "\r\n") { input in
            #expect(try! input.matchNewline() == .crlf)
        }
    }

    @Test("matchNewline rejects an excessive run of stray spaces")
    func matchNewlineRejectsExcessiveSpaces() {
        let spaces = ParseInput.maximumStraySpaces + 1
        ParseInputHarness.withSpan(String(repeating: " ", count: spaces) + "\r\n") { input in
            #expect(errorThrown(by: { try input.matchNewline() }) is ParserError)
            #expect(input.consumed == 0)
        }
    }

    @Test("matchNewline skips stray spaces split across one-byte regions")
    func matchNewlineSpacesAcrossRegions() {
        let regions = Array(repeating: TestRegion(" "), count: ParseInput.maximumStraySpaces) + [TestRegion("\r\n")]
        ParseInputHarness.withInput(regions) { input in
            #expect(try! input.matchNewline() == .crlf)
            #expect(input.consumed == ParseInput.maximumStraySpaces + 2)
        }
        let tooMany = Array(repeating: TestRegion(" "), count: ParseInput.maximumStraySpaces + 1)
        ParseInputHarness.withInput(tooMany) { input in
            #expect(errorThrown(by: { try input.matchNewline() }) is ParserError)
            #expect(input.consumed == 0)
        }
    }

    @Test("matchNewline on spaces without a line ending: incomplete under the cap, an error over it")
    func matchNewlineSpacesWithoutLineEnding() {
        let cap = ParseInput.maximumStraySpaces
        ParseInputHarness.withSpan(String(repeating: " ", count: cap)) { input in
            #expect(errorThrown(by: { try input.matchNewline() }) is IncompleteMessage)
        }
        ParseInputHarness.withSpan(String(repeating: " ", count: cap + 1)) { input in
            #expect(errorThrown(by: { try input.matchNewline() }) is ParserError)
        }
    }

    @Test("matchNewline joins a CRLF split across two regions")
    func matchNewlineAcrossRegions() {
        ParseInputHarness.withInput([TestRegion("a\r"), TestRegion("\nb")]) { input in
            input.advance(by: 1)
            #expect(try! input.matchNewline() == .crlf)
            #expect(input.consumed == 3)
            #expect(input.peek(at: 0) == UInt8(ascii: "b"))
        }
    }

    @Test("matchNewline consumes nothing when there is no line ending")
    func matchNewlineFailure() {
        ParseInputHarness.withSpan(" x") { input in
            #expect(errorThrown(by: { try input.matchNewline() }) is ParserError)
            #expect(input.consumed == 0)
            #expect(input.lastParsedNewline == nil)
        }
        ParseInputHarness.withInput([]) { input in
            #expect(errorThrown(by: { try input.matchNewline() }) is IncompleteMessage)
        }
    }

    @Test("skipLF skips one LF and says whether it did")
    func skipLF() {
        ParseInputHarness.withInput([TestRegion("\n"), TestRegion("OK")]) { input in
            #expect(input.skipLF() == true)
            #expect(input.consumed == 1)
            #expect(input.skipLF() == false)
            #expect(input.consumed == 1)
        }
    }
}

// MARK: - Backtracking

extension ParseInputTests {
    @Test("composite rewinds the read position and the newline on a throw")
    func compositeRewinds() {
        ParseInputHarness.withInput([TestRegion("a\r"), TestRegion("\nbcd")]) { input in
            let error = errorThrown {
                try input.composite(tracker: .makeNewDefault) { input, _ in
                    input.advance(by: 1)
                    try input.matchNewline()
                    _ = try input.extractBytes(length: 3)
                    throw ParserError(hint: "nope")
                }
            }
            #expect(error is ParserError)
            #expect(input.consumed == 0)
            #expect(input.lastParsedNewline == nil)
            #expect(input.peek(at: 0) == UInt8(ascii: "a"))
        }
    }

    @Test("composite keeps what it parsed when it returns")
    func compositeKeepsProgress() {
        ParseInputHarness.withSpan("abcdef") { input in
            let bytes = try! input.composite(tracker: .makeNewDefault) { input, _ in
                try input.extractBytes(length: 3)
            }
            #expect(bytes == Array("abc".utf8))
            #expect(input.consumed == 3)
        }
    }

    @Test("composite counts stack frames")
    func compositeTracksRecursion() {
        ParseInputHarness.withSpan("abc") { input in
            let error = errorThrown {
                try input.composite(tracker: StackTracker(maximumParserStackDepth: 2)) { input, tracker in
                    try input.composite(tracker: tracker) { input, tracker in
                        try input.composite(tracker: tracker) { _, _ in }
                    }
                }
            }
            #expect(error is TooMuchRecursion)
            #expect(input.consumed == 0)
        }
    }
}
