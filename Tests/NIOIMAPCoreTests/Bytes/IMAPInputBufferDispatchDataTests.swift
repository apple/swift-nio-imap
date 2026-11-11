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

// Public API only — no `@testable`, no `@_spi`: a transport that reads into `DispatchData` uses exactly this.
import Dispatch
import Foundation  // `DispatchData.regions`
import NIOIMAPCore
import Testing

/// One `DispatchData` holding `parts` as separate regions: concatenating copies nothing.
private func dispatchData(_ parts: [[UInt8]]) -> DispatchData {
    var data = DispatchData.empty
    for part in parts {
        part.withUnsafeBytes { data.append(DispatchData(bytes: $0)) }
    }
    return data
}

/// The address of each of `data`'s regions.
private func regionAddresses(_ data: DispatchData) -> [UnsafeRawPointer?] {
    var addresses: [UnsafeRawPointer?] = []
    data.enumerateBytes { bytes, _, _ in addresses.append(UnsafeRawPointer(bytes.baseAddress)) }
    return addresses
}

/// Every byte `input` holds, in order.
private func contents(_ input: IMAPInputBuffer) -> [UInt8] {
    input.byteRegions.flatMap { region in region.withUnsafeBytes { Array($0) } }
}

/// Which deallocators have run. Touched only on the deallocator queue, so `@unchecked` is safe.
private final class Deallocations: @unchecked Sendable {
    var freed: Set<String> = []
}

/// `DispatchData` over `byteCount` bytes of `fill`, freed on `queue`, so a drained `queue` has run any
/// deallocator that is due. The deallocator zeroes the bytes first, so a read after it sees no `fill`.
private func trackedData(
    _ name: String,
    byteCount: Int,
    fill: UInt8,
    queue: DispatchQueue,
    deallocations: Deallocations
) -> DispatchData {
    // Only the deallocator touches `bytes` once `DispatchData` owns it.
    nonisolated(unsafe) let bytes = UnsafeMutableRawBufferPointer.allocate(byteCount: byteCount, alignment: 1)
    bytes.initializeMemory(as: UInt8.self, repeating: fill)
    return DispatchData(
        bytesNoCopy: UnsafeRawBufferPointer(bytes),
        deallocator: .custom(queue) {
            bytes.initializeMemory(as: UInt8.self, repeating: 0)
            bytes.deallocate()
            deallocations.freed.insert(name)
        }
    )
}

@Suite("IMAPInputBuffer.append(contentsOf: DispatchData)")
struct IMAPInputBufferDispatchDataTests {
    /// The smallest region kept by reference.
    static let large = IMAPBuffer.copyThreshold
    /// A region copied into the tail.
    static let small = 10

    @Test("keeps large regions where they are and coalesces small ones, bytes in order")
    func mixedRegions() {
        let parts: [[UInt8]] = [
            Array(repeating: UInt8(ascii: "a"), count: Self.small),
            Array(repeating: UInt8(ascii: "b"), count: Self.large),
            Array(repeating: UInt8(ascii: "c"), count: Self.small),
            Array(repeating: UInt8(ascii: "d"), count: Self.small),
            Array(repeating: UInt8(ascii: "e"), count: 2 * Self.large),
        ]
        let data = dispatchData(parts)
        let leaves = regionAddresses(data)
        #expect(leaves.count == parts.count, "precondition: one region per part")

        var input = IMAPInputBuffer()
        input.append(contentsOf: data)

        #expect(contents(input) == parts.flatMap { $0 })
        #expect(input.count == parts.reduce(0) { $0 + $1.count })
        // a | b | c d | e
        #expect(input.regionCount == 4)
        #expect(input.byteRegions[1].withUnsafeBytes { UnsafeRawPointer($0.baseAddress) } == leaves[1])
        #expect(input.byteRegions[3].withUnsafeBytes { UnsafeRawPointer($0.baseAddress) } == leaves[4])
    }

    @Test("copies only-small regions into one tail")
    func smallRegionsOnly() {
        let parts: [[UInt8]] = [Array("A1 ".utf8), Array("NOOP".utf8), Array("\r\n".utf8)]
        let data = dispatchData(parts)
        #expect(regionAddresses(data).count == parts.count, "precondition: one region per part")

        var input = IMAPInputBuffer()
        input.append(contentsOf: data)

        #expect(contents(input) == Array("A1 NOOP\r\n".utf8))
        #expect(input.regionCount == 1)
    }

    @Test("appending an empty DispatchData does nothing")
    func empty() {
        var input = IMAPInputBuffer()
        input.append(contentsOf: .empty)
        #expect(input.isEmpty)
        #expect(input.regionCount == 0)

        input.append(contentsOf: dispatchData([Array("A1".utf8)]))
        input.append(contentsOf: .empty)
        #expect(contents(input) == Array("A1".utf8))
        #expect(input.regionCount == 1)
    }

    @Test("a kept region keeps the DispatchData's storage alive after the DispatchData is gone")
    func keptRegionOutlivesData() {
        let queue = DispatchQueue(label: "IMAPInputBufferDispatchDataTests.deallocator")
        let deallocations = Deallocations()
        let fill = UInt8(ascii: "k")

        var input = IMAPInputBuffer()
        do {
            let kept = trackedData(
                "kept",
                byteCount: Self.large,
                fill: fill,
                queue: queue,
                deallocations: deallocations
            )
            input.append(contentsOf: kept)
            _ = trackedData("dropped", byteCount: Self.large, fill: fill, queue: queue, deallocations: deallocations)
        }
        queue.sync {}

        #expect(queue.sync { deallocations.freed } == ["dropped"])
        #expect(contents(input) == Array(repeating: fill, count: Self.large))
    }

    /// A `DispatchData.Region` is a pointer into its `DispatchData` and does not retain it.
    @Test("a large DispatchData.Region appended on its own is copied, so it outlives the DispatchData")
    func regionIsCopied() throws {
        let queue = DispatchQueue(label: "IMAPInputBufferDispatchDataTests.deallocator")
        let deallocations = Deallocations()
        let fill = UInt8(ascii: "r")

        var input = IMAPInputBuffer()
        do {
            let data = trackedData(
                "region",
                byteCount: Self.large,
                fill: fill,
                queue: queue,
                deallocations: deallocations
            )
            input.append(try #require(data.regions.first))
        }
        queue.sync {}

        #expect(queue.sync { deallocations.freed } == ["region"], "precondition: nothing keeps the data alive")
        #expect(contents(input) == Array(repeating: fill, count: Self.large))
    }

    @Test("makeDispatchData of an IMAPBuffer over a DispatchData.Region outlives the DispatchData")
    func regionBufferConversionOutlivesData() throws {
        let queue = DispatchQueue(label: "IMAPInputBufferDispatchDataTests.deallocator")
        let deallocations = Deallocations()
        let fill = UInt8(ascii: "c")

        let converted: DispatchData
        do {
            let data = trackedData(
                "region",
                byteCount: Self.large,
                fill: fill,
                queue: queue,
                deallocations: deallocations
            )
            converted = IMAPBuffer(IMAPByteStorage(try #require(data.regions.first))).makeDispatchData()
        }
        queue.sync {}

        #expect(queue.sync { deallocations.freed } == ["region"], "precondition: nothing keeps the data alive")
        #expect(Array(converted) == Array(repeating: fill, count: Self.large))
    }

    @Test("withUnsafeBytesAndOwner on an IMAPBuffer over a DispatchData.Region: the owner keeps the bytes")
    func regionBufferOwnerKeepsBytes() throws {
        let queue = DispatchQueue(label: "IMAPInputBufferDispatchDataTests.deallocator")
        let deallocations = Deallocations()
        let fill = UInt8(ascii: "o")

        let escaped: (bytes: UnsafeRawBufferPointer, owner: any Sendable)?
        do {
            let data = trackedData(
                "region",
                byteCount: Self.large,
                fill: fill,
                queue: queue,
                deallocations: deallocations
            )
            let buffer = IMAPBuffer(IMAPByteStorage(try #require(data.regions.first)))
            escaped = buffer.withUnsafeBytesAndOwner { ($0, $1) }
        }
        queue.sync {}

        // No pointer is a valid answer; a pointer must stay valid while its owner is held.
        guard let escaped else { return }
        #expect(
            withExtendedLifetime(escaped.owner) { Array(escaped.bytes) } == Array(repeating: fill, count: Self.large)
        )
    }

    @Test("a kept region is donated to makeDispatchData, and the donation keeps the DispatchData alive")
    func keptRegionIsDonated() throws {
        let queue = DispatchQueue(label: "IMAPInputBufferDispatchDataTests.deallocator")
        let deallocations = Deallocations()
        let fill = UInt8(ascii: "d")

        let converted: DispatchData
        let leaf: UnsafeRawPointer?
        do {
            let data = trackedData(
                "kept",
                byteCount: Self.large,
                fill: fill,
                queue: queue,
                deallocations: deallocations
            )
            leaf = try #require(regionAddresses(data).first)
            var input = IMAPInputBuffer()
            input.append(contentsOf: data)
            converted = input.byteRegions[0].makeDispatchData()
        }
        queue.sync {}

        #expect(queue.sync { deallocations.freed }.isEmpty)
        #expect(regionAddresses(converted) == [leaf], "donated, not copied")
        #expect(Array(converted) == Array(repeating: fill, count: Self.large))
    }
}
