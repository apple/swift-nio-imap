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

// The Foundation half of the input side, kept in one file. Like the rest of `NIOIMAPCore`, it never
// needs full Foundation on Linux: `Data` is in `FoundationEssentials`, `DispatchData` in `Dispatch`.
// `ByteRegion`'s single requirement is spelled the same way as `ContiguousBytes`', so most of what
// follows is an empty extension.

import Dispatch

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Data: ByteRegion {}
extension DispatchData.Region: ByteRegion {}

// Not a `StableAddressByteRegion`: a `DispatchData.Region` points into its `DispatchData` without
// keeping it alive, so its bytes are valid only while that `DispatchData` is. `IMAPInputBuffer.append(_:)`
// therefore copies a large one; `append(contentsOf:)` keeps the whole `DispatchData` instead.

// `Data` presents as one region even when the storage behind it is not contiguous: `withUnsafeBytes`
// flattens in that case, and nothing promises the flattened bytes outlive the call. So `Data` is not
// a `StableAddressByteRegion`, and `IMAPInputBuffer` copies a large one rather than keeping it.

extension IMAPInputBuffer {
    /// Adds every region of `data` to the end of the buffer, in order.
    ///
    /// A region of at least ``IMAPBuffer/copyThreshold`` bytes is kept where it is, along with `data`,
    /// which keeps it alive; a smaller one is copied into the tail. The regions are walked with
    /// `enumerateBytes`, which allocates nothing, so a read costs one small object per kept region and
    /// nothing else. Prefer this to appending each of `data.regions`: that builds an array, and copies
    /// every large region, since a `DispatchData.Region` does not keep its bytes alive.
    ///
    /// Appending an empty `DispatchData` does nothing.
    ///
    /// - Parameter data: The bytes to add.
    public mutating func append(contentsOf data: DispatchData) {
        data.enumerateBytes { bytes, _, _ in
            let bytes = UnsafeRawBufferPointer(bytes)
            guard bytes.count >= IMAPBuffer.copyThreshold else {
                appendToTail(bytes)
                return
            }
            let storage = IMAPByteStorage(DispatchDataRegion(data: data, bytes: bytes))
            appendReceived(storage, range: 0..<storage.count)
        }
    }
}

/// One region of a `DispatchData`, kept alive by holding the whole `DispatchData`.
///
/// A `dispatch_data_t` is immutable and keeps its leaf buffers alive, so `bytes` stays put for as long
/// as `data` does. Holding all of `data` costs a retain rather than the allocation that
/// `subdata(in:)` may make, and pins all of `data` — usually one read — while the region is alive.
private struct DispatchDataRegion: StableAddressByteRegion, @unchecked Sendable {  // @unchecked: `bytes` is in `data`.
    let data: DispatchData
    let bytes: UnsafeRawBufferPointer

    /// All of `data`. A lower bound: a leaf may itself be a sub-range of a larger allocation, and
    /// `DispatchData` does not say how large.
    var pinnedByteCount: Int { data.count }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try body(bytes)
    }
}
