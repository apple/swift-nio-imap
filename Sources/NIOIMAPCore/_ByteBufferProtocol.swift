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

// proof that this works

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView
import enum NIO.Endianness

extension ByteBuffer: _ByteBufferAPITemplate {}
extension ByteBufferView: _ByteBufferViewAPITemplate {}

/// `ByteBuffer` stores contiguously allocated raw bytes. It is a random and sequential accessible sequence of zero or
/// more bytes (octets).
///
/// ### Allocation
/// Use `allocator.buffer(capacity: desiredCapacity)` to allocate a new `ByteBuffer`.
///
/// ### Supported types
/// A variety of types can be read/written from/to a `ByteBuffer`. Using Swift's `extension` mechanism you can easily
/// create `ByteBuffer` support for your own data types. Out of the box, `ByteBuffer` supports for example the following
/// types (non-exhaustive list):
///
///  - `String`/`StaticString`
///  - Swift's various (unsigned) integer types
///  - `Foundation`'s `Data`
///  - `[UInt8]` and generally any `Collection` of `UInt8`
///
/// ### Random Access
/// For every supported type `ByteBuffer` usually contains two methods for random access:
///
///  1. `get<Type>(at: Int, length: Int)` where `<type>` is for example `String`, `Data`, `Bytes` (for `[UInt8]`)
///  2. `set<Type>(at: Int)`
///
/// Example:
///
///     var buf = ...
///     buf.setString("Hello World", at: 0)
///     buf.moveWriterIndex(to: 11)
///     let helloWorld = buf.getString(at: 0, length: 11)
///
///     let written = buf.setInteger(17 as Int, at: 11)
///     buf.moveWriterIndex(forwardBy: written)
///     let seventeen: Int? = buf.getInteger(at: 11)
///
/// If needed, `ByteBuffer` will automatically resize its storage to accommodate your `set` request.
///
/// ### Sequential Access
/// `ByteBuffer` provides two properties which are indices into the `ByteBuffer` to support sequential access:
///  - `readerIndex`, the index of the next readable byte
///  - `writerIndex`, the index of the next byte to write
///
/// For every supported type `ByteBuffer` usually contains two methods for sequential access:
///
///  1. `read<Type>(length: Int)` to read `length` bytes from the current `readerIndex` (and then advance the reader
///     index by `length` bytes)
///  2. `write<Type>(Type)` to write, advancing the `writerIndex` by the appropriate amount
///
/// Example:
///
///      var buf = ...
///      buf.writeString("Hello World")
///      buf.writeInteger(17 as Int)
///      let helloWorld = buf.readString(length: 11)
///      let seventeen: Int = buf.readInteger()
///
/// ### Layout
///     +-------------------+------------------+------------------+
///     | discardable bytes |  readable bytes  |  writable bytes  |
///     |                   |     (CONTENT)    |                  |
///     +-------------------+------------------+------------------+
///     |                   |                  |                  |
///     0      <=      readerIndex   <=   writerIndex    <=    capacity
///
/// The 'discardable bytes' are usually bytes that have already been read, they can however still be accessed using
/// the random access methods. 'Readable bytes' are the bytes currently available to be read using the sequential
/// access interface (`read<Type>`/`write<Type>`). Getting `writableBytes` (bytes beyond the writer index) is undefined
/// behaviour and might yield arbitrary bytes (_not_ `0` initialised).
///
/// ### Slicing
/// `ByteBuffer` supports slicing a `ByteBuffer` without copying the underlying storage.
///
/// Example:
///
///     var buf = ...
///     let dataBytes: [UInt8] = [0xca, 0xfe, 0xba, 0xbe]
///     let dataBytesLength = UInt32(dataBytes.count)
///     buf.writeInteger(dataBytesLength) /* the header */
///     buf.writeBytes(dataBytes) /* the data */
///     let bufDataBytesOnly = buf.getSlice(at: 4, length: dataBytes.count)
///     /* `bufDataByteOnly` and `buf` will share their storage */
///
/// ### Notes
/// All `ByteBuffer` methods that don't contain the word 'unsafe' will only allow you to access the 'readable bytes'.
///
// swift-format-ignore: AmbiguousTrailingClosureOverload
protocol _ByteBufferAPITemplate where Self: Hashable, Self: CustomStringConvertible {
    /// The number of bytes writable until `ByteBuffer` will need to grow its underlying storage which will likely
    /// trigger a copy of the bytes.
    var writableBytes: Int { get }

    /// The number of bytes readable (`readableBytes` = `writerIndex` - `readerIndex`).
    var readableBytes: Int { get }

    /// The current capacity of the storage of this `ByteBuffer`, this is not constant and does _not_ signify the number
    /// of bytes that have been written to this `ByteBuffer`.
    var capacity: Int { get }

    /// Reserves enough space to store the specified number of bytes.
    ///
    /// This method will ensure that the buffer has space for at least as many bytes as requested.
    /// This includes any bytes already stored, and completely disregards the reader/writer indices.
    /// If the buffer already has space to store the requested number of bytes, this method will be
    /// a no-op.
    ///
    /// - parameters:
    ///     - minimumCapacity: The minimum number of bytes this buffer must be able to store.
    mutating func reserveCapacity(_ minimumCapacity: Int)

    /// Reserves enough space to write at least the specified number of bytes.
    ///
    /// This method will ensure that the buffer has enough writable space for at least as many bytes
    /// as requested. If the buffer already has space to write the requested number of bytes, this
    /// method will be a no-op.
    ///
    /// - Parameter minimumWritableBytes: The minimum number of writable bytes this buffer must have.
    mutating func reserveCapacity(minimumWritableBytes: Int)

    /// Yields a mutable buffer pointer containing this `ByteBuffer`'s readable bytes. You may modify those bytes.
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    ///
    /// - parameters:
    ///     - body: The closure that will accept the yielded bytes.
    /// - returns: The value returned by `body`.
    mutating func withUnsafeMutableReadableBytes<T>(_ body: (UnsafeMutableRawBufferPointer) throws -> T) rethrows -> T

    /// Yields the bytes currently writable (`bytesWritable` = `capacity` - `writerIndex`). Before reading those bytes you must first
    /// write to them otherwise you will trigger undefined behaviour. The writer index will remain unchanged.
    ///
    /// - note: In almost all cases you should use `writeWithUnsafeMutableBytes` which will move the write pointer instead of this method
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    ///
    /// - parameters:
    ///     - body: The closure that will accept the yielded bytes and return the number of bytes written.
    /// - returns: The number of bytes written.
    mutating func withUnsafeMutableWritableBytes<T>(_ body: (UnsafeMutableRawBufferPointer) throws -> T) rethrows -> T

    /// This vends a pointer of the `ByteBuffer` at the `writerIndex` after ensuring that the buffer has at least `minimumWritableBytes` of writable bytes available.
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    ///
    /// - parameters:
    ///     - minimumWritableBytes: The number of writable bytes to reserve capacity for before vending the `ByteBuffer` pointer to `body`.
    ///     - body: The closure that will accept the yielded bytes and return the number of bytes written.
    /// - returns: The number of bytes written.
    mutating func writeWithUnsafeMutableBytes(
        minimumWritableBytes: Int,
        _ body: (UnsafeMutableRawBufferPointer) throws -> Int
    ) rethrows -> Int

    /// This vends a pointer to the storage of the `ByteBuffer`. It's marked as _very unsafe_ because it might contain
    /// uninitialised memory and it's undefined behaviour to read it. In most cases you should use `withUnsafeReadableBytes`.
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    func withVeryUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T

    /// This vends a pointer to the storage of the `ByteBuffer`. It's marked as _very unsafe_ because it might contain
    /// uninitialised memory and it's undefined behaviour to read it. In most cases you should use `withUnsafeMutableWritableBytes`.
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    mutating func withVeryUnsafeMutableBytes<T>(_ body: (UnsafeMutableRawBufferPointer) throws -> T) rethrows -> T

    /// Yields a buffer pointer containing this `ByteBuffer`'s readable bytes.
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    ///
    /// - parameters:
    ///     - body: The closure that will accept the yielded bytes.
    /// - returns: The value returned by `body`.
    func withUnsafeReadableBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T

    /// Yields a buffer pointer containing this `ByteBuffer`'s readable bytes. You may hold a pointer to those bytes
    /// even after the closure returned iff you model the lifetime of those bytes correctly using the `Unmanaged`
    /// instance. If you don't require the pointer after the closure returns, use `withUnsafeReadableBytes`.
    ///
    /// If you escape the pointer from the closure, you _must_ call `storageManagement.retain()` to get ownership to
    /// the bytes and you also must call `storageManagement.release()` if you no longer require those bytes. Calls to
    /// `retain` and `release` must be balanced.
    ///
    /// - parameters:
    ///     - body: The closure that will accept the yielded bytes and the `storageManagement`.
    /// - returns: The value returned by `body`.
    func withUnsafeReadableBytesWithStorageManagement<T>(
        _ body: (UnsafeRawBufferPointer, Unmanaged<AnyObject>) throws -> T
    ) rethrows -> T

    /// See `withUnsafeReadableBytesWithStorageManagement` and `withVeryUnsafeBytes`.
    func withVeryUnsafeBytesWithStorageManagement<T>(
        _ body: (UnsafeRawBufferPointer, Unmanaged<AnyObject>) throws -> T
    ) rethrows -> T

    /// Returns a slice of size `length` bytes, starting at `index`. The `ByteBuffer` this is invoked on and the
    /// `ByteBuffer` returned will share the same underlying storage. However, the byte at `index` in this `ByteBuffer`
    /// will correspond to index `0` in the returned `ByteBuffer`.
    /// The `readerIndex` of the returned `ByteBuffer` will be `0`, the `writerIndex` will be `length`.
    ///
    /// The selected bytes must be readable or else `nil` will be returned.
    ///
    /// - parameters:
    ///     - index: The index the requested slice starts at.
    ///     - length: The length of the requested slice.
    /// - returns: A `ByteBuffer` containing the selected bytes as readable bytes or `nil` if the selected bytes were
    ///            not readable in the initial `ByteBuffer`.
    func getSlice(at index: Int, length: Int) -> Self?

    /// Discard the bytes before the reader index. The byte at index `readerIndex` before calling this method will be
    /// at index `0` after the call returns.
    ///
    /// - returns: `true` if one or more bytes have been discarded, `false` if there are no bytes to discard.
    mutating func discardReadBytes() -> Bool

    /// The reader index or the number of bytes previously read from this `ByteBuffer`. `readerIndex` is `0` for a
    /// newly allocated `ByteBuffer`.
    var readerIndex: Int { get }

    /// The write index or the number of bytes previously written to this `ByteBuffer`. `writerIndex` is `0` for a
    /// newly allocated `ByteBuffer`.
    var writerIndex: Int { get }

    /// Set both reader index and writer index to `0`. This will reset the state of this `ByteBuffer` to the state
    /// of a freshly allocated one, if possible without allocations. This is the cheapest way to recycle a `ByteBuffer`
    /// for a new use-case.
    ///
    /// - note: This method will allocate if the underlying storage is referenced by another `ByteBuffer`. Even if an
    ///         allocation is necessary this will be cheaper as the copy of the storage is elided.
    mutating func clear()

    /// Set both reader index and writer index to `0`. This will reset the state of this `ByteBuffer` to the state
    /// of a freshly allocated one, if possible without allocations. This is the cheapest way to recycle a `ByteBuffer`
    /// for a new use-case.
    ///
    /// - note: This method will allocate if the underlying storage is referenced by another `ByteBuffer`. Even if an
    ///         allocation is necessary this will be cheaper as the copy of the storage is elided.
    ///
    /// - parameters:
    ///     - minimumCapacity: The minimum capacity that will be (re)allocated for this buffer
    mutating func clear(minimumCapacity: UInt32)

    /// Copy the collection of `bytes` into the `ByteBuffer` at `index`. Does not move the writer index.
    mutating func setBytes<Bytes>(_ bytes: Bytes, at index: Int) -> Int where Bytes: Sequence, Bytes.Element == UInt8

    /// Copy `bytes` into the `ByteBuffer` at `index`. Does not move the writer index.
    mutating func setBytes(_ bytes: UnsafeRawBufferPointer, at index: Int) -> Int

    /// Move the reader index forward by `offset` bytes.
    ///
    /// - warning: By contract the bytes between (including) `readerIndex` and (excluding) `writerIndex` must be
    ///            initialised, ie. have been written before. Also the `readerIndex` must always be less than or equal
    ///            to the `writerIndex`. Failing to meet either of these requirements leads to undefined behaviour.
    /// - parameters:
    ///   - offset: The number of bytes to move the reader index forward by.
    mutating func moveReaderIndex(forwardBy offset: Int)

    /// Set the reader index to `offset`.
    ///
    /// - warning: By contract the bytes between (including) `readerIndex` and (excluding) `writerIndex` must be
    ///            initialised, ie. have been written before. Also the `readerIndex` must always be less than or equal
    ///            to the `writerIndex`. Failing to meet either of these requirements leads to undefined behaviour.
    /// - parameters:
    ///   - offset: The offset in bytes to set the reader index to.
    mutating func moveReaderIndex(to offset: Int)

    /// Move the writer index forward by `offset` bytes.
    ///
    /// - warning: By contract the bytes between (including) `readerIndex` and (excluding) `writerIndex` must be
    ///            initialised, ie. have been written before. Also the `readerIndex` must always be less than or equal
    ///            to the `writerIndex`. Failing to meet either of these requirements leads to undefined behaviour.
    /// - parameters:
    ///   - offset: The number of bytes to move the writer index forward by.
    mutating func moveWriterIndex(forwardBy offset: Int)

    /// Set the writer index to `offset`.
    ///
    /// - warning: By contract the bytes between (including) `readerIndex` and (excluding) `writerIndex` must be
    ///            initialised, ie. have been written before. Also the `readerIndex` must always be less than or equal
    ///            to the `writerIndex`. Failing to meet either of these requirements leads to undefined behaviour.
    /// - parameters:
    ///   - offset: The offset in bytes to set the reader index to.
    mutating func moveWriterIndex(to offset: Int)

    /// Copies `length` `bytes` starting at the `fromIndex` to `toIndex`. Does not move the writer index.
    ///
    /// - Note: Overlapping ranges, for example `copyBytes(at: 1, to: 2, length: 5)` are allowed.
    /// - Precondition: The range represented by `fromIndex` and `length` must be readable bytes,
    ///     that is: `fromIndex >= readerIndex` and `fromIndex + length <= writerIndex`.
    /// - Parameter fromIndex: The index of the first byte to copy.
    /// - Parameter toIndex: The index into to which the first byte will be copied.
    /// - Parameter length: The number of bytes which should be copied.
    mutating func copyBytes(at fromIndex: Int, to toIndex: Int, length: Int) throws -> Int

    /// Modify this `ByteBuffer` if this `ByteBuffer` is known to uniquely own its storage.
    ///
    /// In some cases it is possible that code is holding a `ByteBuffer` that has been shared with other
    /// parts of the code, and may want to mutate that `ByteBuffer`. In some cases it may be worth modifying
    /// a `ByteBuffer` only if that `ByteBuffer` is guaranteed to not perform a copy-on-write operation to do
    /// so, for example when a different buffer could be used or more cheaply allocated instead.
    ///
    /// This function will execute the provided block only if it is guaranteed to be able to avoid a copy-on-write
    /// operation. If it cannot execute the block the returned value will be `nil`.
    ///
    /// - parameters:
    ///     - body: The modification operation to execute, with this `ByteBuffer` passed `inout` as an argument.
    /// - returns: The return value of `body`.
    mutating func modifyIfUniquelyOwned<T>(_ body: (inout Self) throws -> T) rethrows -> T?

    /// Get `length` bytes starting at `index` and return the result as `[UInt8]`. This will not change the reader index.
    /// The selected bytes must be readable or else `nil` will be returned.
    ///
    /// - parameters:
    ///     - index: The starting index of the bytes of interest into the `ByteBuffer`.
    ///     - length: The number of bytes of interest.
    /// - returns: A `[UInt8]` value containing the bytes of interest or `nil` if the bytes `ByteBuffer` are not readable.
    func getBytes(at index: Int, length: Int) -> [UInt8]?

    /// Read `length` bytes off this `ByteBuffer`, move the reader index forward by `length` bytes and return the result
    /// as `[UInt8]`.
    ///
    /// - parameters:
    ///     - length: The number of bytes to be read from this `ByteBuffer`.
    /// - returns: A `[UInt8]` value containing `length` bytes or `nil` if there aren't at least `length` bytes readable.
    mutating func readBytes(length: Int) -> [UInt8]?

    /// Write the static `string` into this `ByteBuffer` using UTF-8 encoding, moving the writer index forward appropriately.
    ///
    /// - parameters:
    ///     - string: The string to write.
    /// - returns: The number of bytes written.
    mutating func writeStaticString(_ string: StaticString) -> Int

    /// Write the static `string` into this `ByteBuffer` at `index` using UTF-8 encoding, moving the writer index forward appropriately.
    ///
    /// - parameters:
    ///     - string: The string to write.
    ///     - index: The index for the first serialized byte.
    /// - returns: The number of bytes written.
    mutating func setStaticString(_ string: StaticString, at index: Int) -> Int

    /// Write `string` into this `ByteBuffer` using UTF-8 encoding, moving the writer index forward appropriately.
    ///
    /// - parameters:
    ///     - string: The string to write.
    /// - returns: The number of bytes written.
    mutating func writeString(_ string: String) -> Int

    /// Write `string` into this `ByteBuffer` at `index` using UTF-8 encoding. Does not move the writer index.
    ///
    /// - parameters:
    ///     - string: The string to write.
    ///     - index: The index for the first serialized byte.
    /// - returns: The number of bytes written.
    mutating func setString(_ string: String, at index: Int) -> Int

    /// Get the string at `index` from this `ByteBuffer` decoding using the UTF-8 encoding. Does not move the reader index.
    /// The selected bytes must be readable or else `nil` will be returned.
    ///
    /// - parameters:
    ///     - index: The starting index into `ByteBuffer` containing the string of interest.
    ///     - length: The number of bytes making up the string.
    /// - returns: A `String` value containing the UTF-8 decoded selected bytes from this `ByteBuffer` or `nil` if
    ///            the requested bytes are not readable.
    func getString(at index: Int, length: Int) -> String?

    /// Read `length` bytes off this `ByteBuffer`, decoding it as `String` using the UTF-8 encoding. Move the reader index forward by `length`.
    ///
    /// - parameters:
    ///     - length: The number of bytes making up the string.
    /// - returns: A `String` value deserialized from this `ByteBuffer` or `nil` if there aren't at least `length` bytes readable.
    mutating func readString(length: Int) -> String?

    /// Write `substring` into this `ByteBuffer` using UTF-8 encoding, moving the writer index forward appropriately.
    ///
    /// - parameters:
    ///     - substring: The substring to write.
    /// - returns: The number of bytes written.
    mutating func writeSubstring(_ substring: Substring) -> Int

    /// Write `substring` into this `ByteBuffer` at `index` using UTF-8 encoding. Does not move the writer index.
    ///
    /// - parameters:
    ///     - substring: The substring to write.
    ///     - index: The index for the first serilized byte.
    /// - returns: The number of bytes written
    mutating func setSubstring(_ substring: Substring, at index: Int) -> Int

    /// Write `dispatchData` into this `ByteBuffer`, moving the writer index forward appropriately.
    ///
    /// - parameters:
    ///     - dispatchData: The `DispatchData` instance to write to the `ByteBuffer`.
    /// - returns: The number of bytes written.
    mutating func writeDispatchData(_ dispatchData: DispatchData) -> Int

    /// Write `dispatchData` into this `ByteBuffer` at `index`. Does not move the writer index.
    ///
    /// - parameters:
    ///     - dispatchData: The `DispatchData` to write.
    ///     - index: The index for the first serialized byte.
    /// - returns: The number of bytes written.
    mutating func setDispatchData(_ dispatchData: DispatchData, at index: Int) -> Int

    /// Get the bytes at `index` from this `ByteBuffer` as a `DispatchData`. Does not move the reader index.
    /// The selected bytes must be readable or else `nil` will be returned.
    ///
    /// - parameters:
    ///     - index: The starting index into `ByteBuffer` containing the string of interest.
    ///     - length: The number of bytes.
    /// - returns: A `DispatchData` value deserialized from this `ByteBuffer` or `nil` if the requested bytes
    ///            are not readable.
    func getDispatchData(at index: Int, length: Int) -> DispatchData?

    /// Read `length` bytes off this `ByteBuffer` and return them as a `DispatchData`. Move the reader index forward by `length`.
    ///
    /// - parameters:
    ///     - length: The number of bytes.
    /// - returns: A `DispatchData` value containing the bytes from this `ByteBuffer` or `nil` if there aren't at least `length` bytes readable.
    mutating func readDispatchData(length: Int) -> DispatchData?

    /// Yields an immutable buffer pointer containing this `ByteBuffer`'s readable bytes. Will move the reader index
    /// by the number of bytes returned by `body`.
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    ///
    /// - parameters:
    ///     - body: The closure that will accept the yielded bytes and returns the number of bytes it processed.
    /// - returns: The number of bytes read.
    // swift-format-ignore: AmbiguousTrailingClosureOverload
    mutating func readWithUnsafeReadableBytes(_ body: (UnsafeRawBufferPointer) throws -> Int) rethrows -> Int

    /// Yields an immutable buffer pointer containing this `ByteBuffer`'s readable bytes. Will move the reader index
    /// by the number of bytes `body` returns in the first tuple component.
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    ///
    /// - parameters:
    ///     - body: The closure that will accept the yielded bytes and returns the number of bytes it processed along with some other value.
    /// - returns: The value `body` returned in the second tuple component.
    // swift-format-ignore: AmbiguousTrailingClosureOverload
    mutating func readWithUnsafeReadableBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> (Int, T)) rethrows -> T

    /// Yields a mutable buffer pointer containing this `ByteBuffer`'s readable bytes. You may modify the yielded bytes.
    /// Will move the reader index by the number of bytes returned by `body` but leave writer index as it was.
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    ///
    /// - parameters:
    ///     - body: The closure that will accept the yielded bytes and returns the number of bytes it processed.
    /// - returns: The number of bytes read.
    // swift-format-ignore: AmbiguousTrailingClosureOverload
    mutating func readWithUnsafeMutableReadableBytes(
        _ body: (UnsafeMutableRawBufferPointer) throws -> Int
    ) rethrows -> Int

    /// Yields a mutable buffer pointer containing this `ByteBuffer`'s readable bytes. You may modify the yielded bytes.
    /// Will move the reader index by the number of bytes `body` returns in the first tuple component but leave writer index as it was.
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    ///
    /// - parameters:
    ///     - body: The closure that will accept the yielded bytes and returns the number of bytes it processed along with some other value.
    /// - returns: The value `body` returned in the second tuple component.
    // swift-format-ignore: AmbiguousTrailingClosureOverload
    mutating func readWithUnsafeMutableReadableBytes<T>(
        _ body: (UnsafeMutableRawBufferPointer) throws -> (Int, T)
    ) rethrows -> T

    /// Copy `buffer`'s readable bytes into this `ByteBuffer` starting at `index`. Does not move any of the reader or writer indices.
    ///
    /// - parameters:
    ///     - buffer: The `ByteBuffer` to copy.
    ///     - index: The index for the first byte.
    /// - returns: The number of bytes written.
    mutating func setBuffer(_ buffer: ByteBuffer, at index: Int) -> Int

    /// Write `buffer`'s readable bytes into this `ByteBuffer` starting at `writerIndex`. This will move both this
    /// `ByteBuffer`'s writer index as well as `buffer`'s reader index by the number of bytes readable in `buffer`.
    ///
    /// - parameters:
    ///     - buffer: The `ByteBuffer` to write.
    /// - returns: The number of bytes written to this `ByteBuffer` which is equal to the number of bytes read from `buffer`.
    mutating func writeBuffer(_ buffer: inout ByteBuffer) -> Int

    /// Write `bytes`, a `Sequence` of `UInt8` into this `ByteBuffer`. Moves the writer index forward by the number of bytes written.
    ///
    /// - parameters:
    ///     - bytes: A `Collection` of `UInt8` to be written.
    /// - returns: The number of bytes written or `bytes.count`.
    mutating func writeBytes<Bytes>(_ bytes: Bytes) -> Int where Bytes: Sequence, Bytes.Element == UInt8

    /// Write `bytes` into this `ByteBuffer`. Moves the writer index forward by the number of bytes written.
    ///
    /// - parameters:
    ///     - bytes: An `UnsafeRawBufferPointer`
    /// - returns: The number of bytes written or `bytes.count`.
    mutating func writeBytes(_ bytes: UnsafeRawBufferPointer) -> Int

    /// Slice the readable bytes off this `ByteBuffer` without modifying the reader index. This method will return a
    /// `ByteBuffer` sharing the underlying storage with the `ByteBuffer` the method was invoked on. The returned
    /// `ByteBuffer` will contain the bytes in the range `readerIndex..<writerIndex` of the original `ByteBuffer`.
    ///
    /// - note: Because `ByteBuffer` implements copy-on-write a copy of the storage will be automatically triggered when either of the `ByteBuffer`s sharing storage is written to.
    ///
    /// - returns: A `ByteBuffer` sharing storage containing the readable bytes only.
    func slice() -> ByteBuffer

    /// Slice `length` bytes off this `ByteBuffer` and move the reader index forward by `length`.
    /// If enough bytes are readable the `ByteBuffer` returned by this method will share the underlying storage with
    /// the `ByteBuffer` the method was invoked on.
    /// The returned `ByteBuffer` will contain the bytes in the range `readerIndex..<(readerIndex + length)` of the
    /// original `ByteBuffer`.
    /// The `readerIndex` of the returned `ByteBuffer` will be `0`, the `writerIndex` will be `length`.
    ///
    /// - note: Because `ByteBuffer` implements copy-on-write a copy of the storage will be automatically triggered when either of the `ByteBuffer`s sharing storage is written to.
    ///
    /// - parameters:
    ///     - length: The number of bytes to slice off.
    /// - returns: A `ByteBuffer` sharing storage containing `length` bytes or `nil` if the not enough bytes were readable.
    mutating func readSlice(length: Int) -> Self?

    /// Read an integer off this `ByteBuffer`, move the reader index forward by the integer's byte size and return the result.
    ///
    /// - parameters:
    ///     - endianness: The endianness of the integer in this `ByteBuffer` (defaults to big endian).
    ///     - as: the desired `FixedWidthInteger` type (optional parameter)
    /// - returns: An integer value deserialized from this `ByteBuffer` or `nil` if there aren't enough bytes readable.
    mutating func readInteger<T>(endianness: Endianness, as: T.Type) -> T? where T: FixedWidthInteger

    /// Get the integer at `index` from this `ByteBuffer`. Does not move the reader index.
    /// The selected bytes must be readable or else `nil` will be returned.
    ///
    /// - parameters:
    ///     - index: The starting index of the bytes for the integer into the `ByteBuffer`.
    ///     - endianness: The endianness of the integer in this `ByteBuffer` (defaults to big endian).
    ///     - as: the desired `FixedWidthInteger` type (optional parameter)
    /// - returns: An integer value deserialized from this `ByteBuffer` or `nil` if the bytes of interest are not
    ///            readable.
    func getInteger<T>(at index: Int, endianness: Endianness, as: T.Type) -> T? where T: FixedWidthInteger

    /// Write `integer` into this `ByteBuffer`, moving the writer index forward appropriately.
    ///
    /// - parameters:
    ///     - integer: The integer to serialize.
    ///     - endianness: The endianness to use, defaults to big endian.
    /// - returns: The number of bytes written.
    mutating func writeInteger<T>(_ integer: T, endianness: Endianness, as: T.Type) -> Int where T: FixedWidthInteger

    /// Write `integer` into this `ByteBuffer` starting at `index`. This does not alter the writer index.
    ///
    /// - parameters:
    ///     - integer: The integer to serialize.
    ///     - index: The index of the first byte to write.
    ///     - endianness: The endianness to use, defaults to big endian.
    /// - returns: The number of bytes written.
    mutating func setInteger<T>(_ integer: T, at index: Int, endianness: Endianness, as: T.Type) -> Int
    where T: FixedWidthInteger

    /// A view into the readable bytes of the `ByteBuffer`.
    var readableBytesView: ByteBufferView { get }

    /// Returns a view into some portion of the readable bytes of a `ByteBuffer`.
    ///
    /// - parameters:
    ///   - index: The index the view should start at
    ///   - length: The length of the view (in bytes)
    /// - returns: A view into a portion of a `ByteBuffer` or `nil` if the requested bytes were not readable.
    func viewBytes(at index: Int, length: Int) -> ByteBufferView?

    /// Create a `ByteBuffer` from the given `ByteBufferView`s range.
    ///
    /// - parameter view: The `ByteBufferView` which you want to get a `ByteBuffer` from.
    init(_ view: ByteBufferView)
}

/// A view into a portion of a `ByteBuffer`.
///
/// A `ByteBufferView` is useful whenever a `Collection where Element == UInt8` representing a portion of a
/// `ByteBuffer` is needed.
protocol _ByteBufferViewAPITemplate
where Self: RandomAccessCollection, Self: MutableCollection, Self: RangeReplaceableCollection {
    /// A type representing the sequence's elements.
    associatedtype Element = UInt8

    /// A type that represents a position in the collection.
    ///
    /// Valid indices consist of the position of every element and a
    /// "past the end" position that's not valid for use as a subscript
    /// argument.
    associatedtype Index = Int

    /// A sequence that represents a contiguous subrange of the collection's
    /// elements.
    ///
    /// This associated type appears as a requirement in the `Sequence`
    /// protocol, but it is restated here with stricter constraints. In a
    /// collection, the subsequence should also conform to `Collection`.
    associatedtype SubSequence = ByteBufferView

    /// Creates a `ByteBufferView` from the readable bytes of the given `buffer`.
    init(_ buffer: ByteBuffer)

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R

    /// The position of the first element in a nonempty collection.
    ///
    /// If the collection is empty, `startIndex` is equal to `endIndex`.
    var startIndex: Index { get }

    /// The collection's "past the end" position---that is, the position one
    /// greater than the last valid subscript argument.
    ///
    /// When you need a range that includes the last element of a collection, use
    /// the half-open range operator (`..<`) with `endIndex`. The `..<` operator
    /// creates a range that doesn't include the upper bound, so it's always
    /// safe to use with `endIndex`. For example:
    ///
    ///     let numbers = [10, 20, 30, 40, 50]
    ///     if let index = numbers.firstIndex(of: 30) {
    ///         print(numbers[index ..< numbers.endIndex])
    ///     }
    ///     // Prints "[30, 40, 50]"
    ///
    /// If the collection is empty, `endIndex` is equal to `startIndex`.
    var endIndex: Index { get }

    /// Returns the position immediately after the given index.
    ///
    /// The successor of an index must be well defined. For an index `i` into a
    /// collection `c`, calling `c.index(after: i)` returns the same index every
    /// time.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be less than
    ///   `endIndex`.
    /// - Returns: The index value immediately after `i`.
    func index(after i: Index) -> Index

    /// Accesses the element at the specified position.
    ///
    /// The following example accesses an element of an array through its
    /// subscript to print its value:
    ///
    ///     var streets = ["Adams", "Bryant", "Channing", "Douglas", "Evarts"]
    ///     print(streets[1])
    ///     // Prints "Bryant"
    ///
    /// You can subscript a collection with any valid index other than the
    /// collection's end index. The end index refers to the position one past
    /// the last element of a collection, so it doesn't correspond with an
    /// element.
    ///
    /// - Parameter position: The position of the element to access. `position`
    ///   must be a valid index of the collection that is not equal to the
    ///   `endIndex` property.
    ///
    /// - Complexity: O(1)
    subscript(position: Index) -> UInt8 { get set }

    /// Accesses a contiguous subrange of the collection's elements.
    ///
    /// The accessed slice uses the same indices for the same elements as the
    /// original collection uses. Always use the slice's `startIndex` property
    /// instead of assuming that its indices start at a particular value.
    ///
    /// This example demonstrates getting a slice of an array of strings, finding
    /// the index of one of the strings in the slice, and then using that index
    /// in the original array.
    ///
    ///     let streets = ["Adams", "Bryant", "Channing", "Douglas", "Evarts"]
    ///     let streetsSlice = streets[2 ..< streets.endIndex]
    ///     print(streetsSlice)
    ///     // Prints "["Channing", "Douglas", "Evarts"]"
    ///
    ///     let index = streetsSlice.firstIndex(of: "Evarts")    // 4
    ///     print(streets[index!])
    ///     // Prints "Evarts"
    ///
    /// - Parameter bounds: A range of the collection's indices. The bounds of
    ///   the range must be valid indices of the collection.
    ///
    /// - Complexity: O(1)
    subscript(range: Range<Index>) -> Self { get set }

    /// Call `body(p)`, where `p` is a pointer to the collection's
    /// contiguous storage.  If no such storage exists, it is
    /// first created.  If the collection does not support an internal
    /// representation in a form of contiguous storage, `body` is not
    /// called and `nil` is returned.
    ///
    /// A `Collection` that provides its own implementation of this method
    /// must also guarantee that an equivalent buffer of its `SubSequence`
    /// can be generated by advancing the pointer by the distance to the
    /// slice's `startIndex`.
    func withContiguousStorageIfAvailable<R>(_ body: (UnsafeBufferPointer<UInt8>) throws -> R) rethrows -> R?

    /// Creates a new, empty collection.
    init()

    /// Replaces the specified subrange of elements with the given collection.
    ///
    /// This method has the effect of removing the specified range of elements
    /// from the collection and inserting the new elements at the same location.
    /// The number of new elements need not match the number of elements being
    /// removed.
    ///
    /// In this example, three elements in the middle of an array of integers are
    /// replaced by the five elements of a `Repeated<Int>` instance.
    ///
    ///      var nums = [10, 20, 30, 40, 50]
    ///      nums.replaceSubrange(1...3, with: repeatElement(1, count: 5))
    ///      print(nums)
    ///      // Prints "[10, 1, 1, 1, 1, 1, 50]"
    ///
    /// If you pass a zero-length range as the `subrange` parameter, this method
    /// inserts the elements of `newElements` at `subrange.startIndex`. Calling
    /// the `insert(contentsOf:at:)` method instead is preferred.
    ///
    /// Likewise, if you pass a zero-length collection as the `newElements`
    /// parameter, this method removes the elements in the given subrange
    /// without replacement. Calling the `removeSubrange(_:)` method instead is
    /// preferred.
    ///
    /// Calling this method may invalidate any existing indices for use with this
    /// collection.
    ///
    /// - Parameters:
    ///   - subrange: The subrange of the collection to replace. The bounds of
    ///     the range must be valid indices of the collection.
    ///   - newElements: The new elements to add to the collection.
    ///
    /// - Complexity: O(*n* + *m*), where *n* is length of this collection and
    ///   *m* is the length of `newElements`. If the call to this method simply
    ///   appends the contents of `newElements` to the collection, this method is
    ///   equivalent to `append(contentsOf:)`.
    mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C)
    where C: Collection, C.Element == ByteBufferView.Element
}
