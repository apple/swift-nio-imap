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
import Testing

@Suite("IMAPBufferList")
struct IMAPBufferListTests {
    @Test("an empty list has no regions and no bytes")
    func empty() {
        let list = IMAPBufferList()
        #expect(list.regionCount == 0)
        #expect(list.byteCount == 0)
        #expect(list.copiedBytes() == [])
        #expect(Array(list.regions).isEmpty)
    }

    @Test("byteCount and regionCount count different things")
    func theTwoCountsAreIndependent() {
        // A single zero-length region: one region, no bytes. Neither number is inferable from the
        // other, which is why the type names both and offers neither `count` nor `isEmpty`.
        var list = IMAPBufferList(IMAPBuffer())
        #expect(list.regionCount == 1)
        #expect(list.byteCount == 0)

        list.append(imapBuffer("abc"))
        #expect(list.regionCount == 2)
        #expect(list.byteCount == 3)

        list.append(IMAPBuffer())
        #expect(list.regionCount == 3)
        #expect(list.byteCount == 3)
    }

    @Test("byteCount is the sum over the regions")
    func byteCountSumsTheRegions() {
        let list = IMAPBufferList([imapBuffer("hel"), IMAPBuffer(), imapBuffer("lo wo"), imapBuffer("rld")])
        #expect(list.byteCount == 11)
        #expect(list.byteCount == list.regions.reduce(0) { $0 + $1.count })
        #expect(list.regionCount == 4)
    }

    @Test("regions are a random-access collection, in write order")
    func regionsAreOrdered() {
        let list = IMAPBufferList([imapBuffer("one"), imapBuffer("two"), imapBuffer("three")])
        #expect(list.regions.count == 3)
        #expect(string(list.regions[0]) == "one")
        #expect(string(list.regions[2]) == "three")
        #expect(list.regions.map { string($0) } == ["one", "two", "three"])
        #expect(list.regions.reversed().map { string($0) } == ["three", "two", "one"])
    }

    @Test("a one-region list stays a one-region list")
    func singleRegion() {
        let list = IMAPBufferList(imapBuffer("A1 OK NOOP completed\r\n"))
        #expect(list.regionCount == 1)
        #expect(list.byteCount == 22)
        #expect(String(decoding: list.copiedBytes(), as: UTF8.self) == "A1 OK NOOP completed\r\n")
    }

    @Test("copiedBytes coalesces every region in order")
    func copiedBytesCoalesces() {
        let list = IMAPBufferList([imapBuffer("hel"), IMAPBuffer(), imapBuffer("lo wo"), imapBuffer("rld")])
        #expect(String(decoding: list.copiedBytes(), as: UTF8.self) == "hello world")
    }

    @Test("append does not disturb the regions already there")
    func appendIsAdditive() {
        var list = IMAPBufferList()
        for word in ["a", "bb", "ccc", "dddd"] {
            list.append(imapBuffer(word))
        }
        #expect(list.regionCount == 4)
        #expect(String(decoding: list.copiedBytes(), as: UTF8.self) == "abbcccdddd")
    }

    @Test("equality and hashing ignore segmentation")
    func equalityAcrossSegmentation() {
        let one = IMAPBufferList(imapBuffer("hello world"))
        let four = IMAPBufferList([imapBuffer("hel"), IMAPBuffer(), imapBuffer("lo wo"), imapBuffer("rld")])
        let eleven = IMAPBufferList("hello world".utf8.map { IMAPBuffer([$0]) })

        #expect(one == four)
        #expect(four == eleven)
        #expect(one == eleven)
        #expect(one.hashValue == four.hashValue)
        #expect(one.hashValue == eleven.hashValue)
        #expect(Set([one, four, eleven]).count == 1)

        #expect(one.regionCount == 1)
        #expect(four.regionCount == 4)
        #expect(eleven.regionCount == 11)
    }

    @Test("equality and hashing ignore whether regions are copied or retained")
    func equalityAcrossRepresentation() {
        let copied = IMAPBufferList([imapBuffer("hello "), imapBuffer("world")])

        let storage = IMAPByteStorage(Array("xxhello worldxx".utf8))
        let retained = IMAPBufferList([
            IMAPBuffer(storage, 2..<8),
            IMAPBuffer(storage, 8..<13),
        ])

        #expect(copied == retained)
        #expect(copied.hashValue == retained.hashValue)
    }

    @Test("leading and trailing empty regions do not change equality")
    func emptyRegionsAreTransparentToEquality() {
        let plain = IMAPBufferList(imapBuffer("abc"))
        let padded = IMAPBufferList([IMAPBuffer(), imapBuffer("abc"), IMAPBuffer(), IMAPBuffer()])
        #expect(plain == padded)
        #expect(plain.hashValue == padded.hashValue)
        #expect(plain.regionCount != padded.regionCount)
    }

    @Test("lists over different bytes are not equal")
    func inequality() {
        #expect(IMAPBufferList(imapBuffer("abc")) != IMAPBufferList(imapBuffer("abd")))
        #expect(IMAPBufferList(imapBuffer("abc")) != IMAPBufferList(imapBuffer("ab")))
        #expect(IMAPBufferList(imapBuffer("abc")) != IMAPBufferList())
        // Same byte count, same region count, different bytes — and the difference is in the second
        // region, so a walk that stops early would miss it.
        #expect(
            IMAPBufferList([imapBuffer("ab"), imapBuffer("cd")])
                != IMAPBufferList([imapBuffer("ab"), imapBuffer("ce")])
        )
        // Same bytes overall but differently split *and* differing late.
        #expect(
            IMAPBufferList([imapBuffer("abc"), imapBuffer("d")])
                != IMAPBufferList([imapBuffer("ab"), imapBuffer("ce")])
        )
    }

    @Test("an empty list equals another empty list, however it was built")
    func emptyEquality() {
        #expect(IMAPBufferList() == IMAPBufferList([]))
        #expect(IMAPBufferList() == IMAPBufferList(IMAPBuffer()))
        #expect(IMAPBufferList().hashValue == IMAPBufferList(IMAPBuffer()).hashValue)
    }

    @Test("debugDescription reports both counts")
    func debugDescriptions() {
        #expect(IMAPBufferList().debugDescription == "IMAPBufferList(0 bytes in 0 regions)")
        #expect(IMAPBufferList(imapBuffer("abc")).debugDescription == "IMAPBufferList(3 bytes in 1 region)")
    }
}
