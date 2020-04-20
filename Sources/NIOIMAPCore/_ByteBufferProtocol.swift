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

// proof that this works
import NIO
extension ByteBuffer: ByteBufferProtocol {
    
}

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
protocol ByteBufferProtocol where Self: Hashable, Self: CustomStringConvertible {
    
    typealias _Capacity = UInt32
    
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
    mutating func writeWithUnsafeMutableBytes(minimumWritableBytes: Int, _ body: (UnsafeMutableRawBufferPointer) throws -> Int) rethrows -> Int

    @available(*, deprecated, message: "please use writeWithUnsafeMutableBytes(minimumWritableBytes:_:) instead to ensure sufficient write capacity.")
    mutating func writeWithUnsafeMutableBytes(_ body: (UnsafeMutableRawBufferPointer) throws -> Int) rethrows -> Int

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
    func withUnsafeReadableBytesWithStorageManagement<T>(_ body: (UnsafeRawBufferPointer, Unmanaged<AnyObject>) throws -> T) rethrows -> T

    /// See `withUnsafeReadableBytesWithStorageManagement` and `withVeryUnsafeBytes`.
    func withVeryUnsafeBytesWithStorageManagement<T>(_ body: (UnsafeRawBufferPointer, Unmanaged<AnyObject>) throws -> T) rethrows -> T

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
    mutating func clear(minimumCapacity: _Capacity)

    /// Copy the collection of `bytes` into the `ByteBuffer` at `index`. Does not move the writer index.
    mutating func setBytes<Bytes>(_ bytes: Bytes, at index: Int) -> Int where Bytes : Sequence, Bytes.Element == UInt8

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
}
