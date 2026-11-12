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

import Dispatch

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#elseif os(Windows)
import ucrt
#endif

// `DispatchData` is the second backing the encoder is designed to feed, and the one that motivated
// the sink being abstract at all. Unlike a `ByteBuffer`, it wraps *immutable, foreign* storage: it
// cannot be filled in place, but it can adopt memory somebody else allocated. So where the NIO path
// needs the encoder's bytes to land in a `ByteBuffer` from the first byte written, this path needs the
// opposite — the encoder allocates, then donates. `IMAPOutputBuffer` is built for exactly that.
//
// ## The unsafe assertion, and how it is contained
//
// `DispatchData(bytesNoCopy:deallocator:)` takes ownership of a pointer, so the pointer has to
// outlive the `withUnsafeBytes(_:)` call it came from. `ByteRegion` does not promise that — a region
// is free to yield a temporary buffer — so this file only escapes a pointer that
// `IMAPBuffer.withUnsafeBytesAndOwner(_:)` hands out: bytes this library owns, or storage with a fixed
// address — a `StableAddressByteRegion` (the stdlib arrays, a region `IMAPInputBuffer.append(contentsOf:)`
// kept with its `DispatchData`; `ByteBuffer`, in `NIOIMAP`) or an `IMAPBuffer` over one. It copies
// from any other, `DispatchData.Region` included. A third-party `ByteRegion` is
// therefore correct by default and merely pays a copy, unless it conforms too. That method is public,
// so a conversion to another adopting type can be written outside the library the same way.
//
// The deallocator closure holds the owner, which is what keeps the memory alive for as long as the
// `DispatchData` refers to it. This file goes through the internal `withUnsafeBytesAndStableOwner(_:)`:
// the same rule, with the owner's concrete type, so capturing it needs no existential box.
//
// Regions shorter than `IMAPBuffer.dispatchDonationThreshold` are copied instead, each run of them into
// one `malloc` that the `DispatchData` frees with `.free`.

extension IMAPBuffer {
    /// Regions shorter than this are copied into a `DispatchData` rather than donated.
    ///
    /// Below it, donating (allocations plus a deallocator block run asynchronously) costs more than
    /// copying into an allocation shared with neighbouring short regions.
    ///
    /// At most ``copyThreshold``, so a region the encoder kept by reference is never copied for being
    /// short. It is a tuning value and may change between releases.
    public static let dispatchDonationThreshold = 512
}

extension IMAPBufferList {
    /// Converts to a `DispatchData`, without copying where it pays.
    ///
    /// A region of at least ``IMAPBuffer/dispatchDonationThreshold`` bytes is donated rather than
    /// copied when its address is fixed: bytes this library owns, or a region whose owner is a
    /// ``StableAddressByteRegion``. The `DispatchData` adopts the memory and keeps its owner alive.
    /// Each run of the other regions — shorter, or without a fixed address — is copied into one
    /// allocation, which becomes one `DispatchData` region.
    ///
    /// - Note: Each `DispatchData` region costs allocations, and a donated one also a deallocator
    ///   block run asynchronously. That is why short regions are joined up rather than donated.
    ///
    /// - Returns: The bytes, in order.
    public func makeDispatchData() -> DispatchData {
        switch storage {
        case .empty:
            return DispatchData.empty
        case .one(let region):
            return region.makeDispatchData()
        case .many(let regions):
            var result = DispatchData.empty
            // The regions not yet added to `result`, all to be copied.
            var runStart = regions.startIndex
            var runByteCount = 0
            for index in regions.indices {
                let region = regions[index]
                guard let donated = region.donatedDispatchData() else {
                    runByteCount += region.count
                    continue
                }
                Self.appendCopy(of: regions[runStart..<index], byteCount: runByteCount, to: &result)
                result.append(donated)
                runStart = index + 1
                runByteCount = 0
            }
            Self.appendCopy(of: regions[runStart...], byteCount: runByteCount, to: &result)
            return result
        }
    }

    /// Copies `run` into one exact-size allocation and appends it to `data` as one region.
    ///
    /// The allocation is handed over with `.free`, which `libdispatch` runs inline: no block, no queue.
    ///
    /// - Parameters:
    ///   - run: The regions to copy.
    ///   - byteCount: Their total size.
    ///   - data: The `DispatchData` to append to.
    private static func appendCopy(
        of run: ArraySlice<IMAPBuffer>,
        byteCount: Int,
        to data: inout DispatchData
    ) {
        guard byteCount > 0 else { return }
        guard let base = malloc(byteCount) else { fatalError("malloc(\(byteCount)) failed") }
        let copy = UnsafeMutableRawBufferPointer(start: base, count: byteCount)
        var offset = 0
        for region in run where !region.isEmpty {
            region.withUnsafeBytes { UnsafeMutableRawBufferPointer(rebasing: copy[offset...]).copyMemory(from: $0) }
            offset += region.count
        }
        assert(offset == byteCount)
        data.append(DispatchData(bytesNoCopy: UnsafeRawBufferPointer(copy), deallocator: .free))
    }
}

extension IMAPBuffer {
    /// Converts to a `DispatchData`, without copying where it pays.
    ///
    /// See ``IMAPBufferList/makeDispatchData()`` for when this copies and when it does not.
    ///
    /// - Returns: The bytes.
    public func makeDispatchData() -> DispatchData {
        guard !isEmpty else { return DispatchData.empty }

        return donatedDispatchData() ?? withUnsafeBytes { DispatchData(bytes: $0) }
    }

    /// These bytes, donated to a `DispatchData`; `nil` if they should be copied instead: shorter than
    /// ``dispatchDonationThreshold``, or without a fixed address.
    fileprivate func donatedDispatchData() -> DispatchData? {
        guard count >= Self.dispatchDonationThreshold else { return nil }

        return withUnsafeBytesAndStableOwner { bytes, owner in
            // One call per concrete owner type, so the deallocator captures it unboxed.
            switch owner {
            case .array(let array): return Self.adopting(bytes, keeping: array)
            case .storage(let storage): return Self.adopting(bytes, keeping: storage)
            case .segment(let segment): return Self.adopting(bytes, keeping: segment)
            }
        }
    }

    /// Wraps bytes without copying them, keeping `owner` alive for as long as the result lives.
    ///
    /// - Note: The memory is released **asynchronously**. `libdispatch` runs a custom destructor block
    ///   on a queue, and passing `nil` selects the default global queue rather than running it inline,
    ///   so a segment is reclaimed shortly after the last `DispatchData` referring to it goes away
    ///   rather than at that moment. Correctness does not depend on when it happens — the segment is
    ///   held until then — but peak memory does lag, which is worth knowing when measuring footprint.
    ///
    /// - Parameters:
    ///   - bytes: The bytes to adopt. Must stay valid for as long as `owner` is alive.
    ///   - owner: The value that keeps `bytes` alive.
    /// - Returns: A `DispatchData` over `bytes`.
    private static func adopting<Owner: Sendable>(
        _ bytes: UnsafeRawBufferPointer,
        keeping owner: Owner
    ) -> DispatchData {
        // `.custom(nil, …)`: the `nil` is the queue, and it is worth spelling out because it hides
        // behind a defaulted argument. Handing over a queue of one's own is much slower to
        // release, because the destructors queue up behind each other; `nil`
        // means the default global queue instead. `.free` is not an option here either: these bytes
        // are usually a sub-range of a larger allocation, so there is nothing for `free()` to take.
        DispatchData(
            bytesNoCopy: bytes,
            deallocator: .custom(nil) {
                _ = owner
            }
        )
    }
}
