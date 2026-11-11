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

/// A contiguous run of bytes.
///
/// This is the narrowest thing the library needs in order to read somebody else's bytes: a single
/// scoped accessor. The signature deliberately matches Foundation's `ContiguousBytes`, so Foundation
/// types conform with an empty extension and the core of `NIOIMAPCore` never has to
/// `import Foundation`.
///
/// ## Conforming
///
/// Most conformances are empty, because the type already has a `withUnsafeBytes(_:)` of the right
/// shape — that is true of `Array`, `ArraySlice` and `ContiguousArray` over `UInt8`, all of which
/// conform below, and of `Foundation.Data`.
///
/// ## Immutability
///
/// ``IMAPByteStorage`` keeps a `ByteRegion` alive so that ``IMAPBuffer`` can hand out its bytes
/// without copying them. That only works if the bytes do not move or change underneath it, so a
/// conformer that is used that way carries an extra requirement described on
/// ``IMAPByteStorage``. Conforming on its own does not commit a type to anything beyond yielding
/// its bytes for the duration of the call.
public protocol ByteRegion {
    /// Calls the given closure with a pointer to the region's bytes.
    ///
    /// The pointer is valid only for the duration of the call. Do not let it escape.
    ///
    /// - Parameter body: A closure that receives the region's bytes.
    /// - Returns: Whatever `body` returns.
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
}

// The stdlib byte containers already have the required accessor.
extension Array: ByteRegion where Element == UInt8 {}
extension ArraySlice: ByteRegion where Element == UInt8 {}
extension ContiguousArray: ByteRegion where Element == UInt8 {}

/// A ``ByteRegion`` whose bytes stay at one address, unchanged, for as long as any copy of it is alive.
///
/// ``ByteRegion`` promises only that its bytes exist for the duration of a
/// ``ByteRegion/withUnsafeBytes(_:)`` call. A region that flattens or decodes on demand satisfies that
/// with a temporary buffer, and a pointer into one of those must not outlive the call.
///
/// Conforming promises more: `withUnsafeBytes(_:)` yields the region's actual storage, at a fixed
/// address, and those bytes stay valid and unchanged for as long as any copy of the value is alive.
/// In return, the library keeps a copy of the value where it would otherwise copy the bytes:
/// ``IMAPInputBuffer`` keeps a large region by reference, and ``IMAPBufferList/makeDispatchData()``
/// donates a region of at least ``IMAPBuffer/dispatchDonationThreshold`` bytes to the `DispatchData`.
///
/// This is the extension point for a byte-buffer type of your own; `NIOIMAP` conforms `ByteBuffer`
/// with nothing more. A region that does not conform is copied instead, which is always correct.
/// `DispatchData.Region` does not conform: it does not keep its `DispatchData` alive.
///
/// - Important: The promise cannot be checked. A conformer whose bytes move or change while a copy of
///   it is alive leaves the parser's or a `DispatchData`'s pointer dangling.
public protocol StableAddressByteRegion: ByteRegion {}

// An `Array`'s buffer does not move while the array is alive, and holding a copy of the array is
// enough to keep it alive: any write to another copy goes through copy-on-write.
extension Array: StableAddressByteRegion where Element == UInt8 {}
extension ArraySlice: StableAddressByteRegion where Element == UInt8 {}
extension ContiguousArray: StableAddressByteRegion where Element == UInt8 {}
