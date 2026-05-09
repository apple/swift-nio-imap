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

import System
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

// MARK: - Directory walk helpers
//
// Both `DownloadDirectory` (`*.message` parsing) and `Append_Files`
// (regular-file enumeration) need to walk a directory and inspect each
// `dirent` entry. The pointer gymnastics around `d_name` (POSIX gives us a
// fixed-size C array; we want a Swift buffer) and the `opendir`/`readdir`
// iteration live here so the call sites can stay focused on their own logic.

/// Calls `closure` once for each entry in `directory`.
///
/// Iterates the directory with `opendir(3)` / `readdir(3)` / `closedir(3)`,
/// which are available on both Darwin and Glibc. Entries are returned in
/// directory order (unsorted).
///
/// Throws `UnableToScanDirectory` if the directory can't be opened or if
/// reading an entry fails.
func scan(
    directory: FilePath,
    closure: (UnsafePointer<dirent>) -> Void
) throws {
    guard let dir = directory.withPlatformString({ opendir($0) }) else {
        throw UnableToScanDirectory()
    }
    defer { closedir(dir) }
    while true {
        // `readdir` returns `nil` both at end-of-directory and on error. It
        // leaves `errno` untouched at end-of-directory, so reset it first and
        // check afterwards to tell the two apart.
        errno = 0
        guard let entry = readdir(dir) else {
            guard errno == 0 else { throw UnableToScanDirectory() }
            break
        }
        closure(UnsafePointer(entry))
    }
}

struct UnableToScanDirectory: Swift.Error {}

/// If `entry` describes a regular file, invokes `body` with the file name as a
/// UTF-8 buffer (no NUL terminator) and returns its result. Returns `nil` if the
/// entry is not a regular file or if `body` itself returns `nil`.
///
/// The buffer is only valid for the duration of `body` — copy out anything you
/// need to keep.
///
/// - Note: On filesystems that don't report a `d_type` (returning `DT_UNKNOWN`),
///   entries are skipped. That doesn't occur on the local filesystems this tool
///   targets, but a fully general implementation would `stat` such entries.
func withRegularFileName<R>(
    dirent entry: UnsafePointer<dirent>,
    _ body: (UnsafeBufferPointer<Unicode.UTF8.CodeUnit>) -> R?
) -> R? {
    guard entry.pointee.d_type == DT_REG else { return nil }
    // `d_name` is a fixed-size C array. Darwin also carries the exact length in
    // `d_namlen`, but Glibc's `dirent` has no such field, so on other platforms
    // we find the NUL terminator within the array ourselves.
    let capacity = MemoryLayout.size(ofValue: entry.pointee.d_name)
    return withUnsafePointer(to: entry.pointee.d_name) { pointer in
        pointer.withMemoryRebound(
            to: Unicode.UTF8.CodeUnit.self,
            capacity: capacity
        ) { rebound in
            #if canImport(Darwin)
            let count = Int(entry.pointee.d_namlen)
            #else
            var count = 0
            while count < capacity, rebound[count] != 0 {
                count += 1
            }
            #endif
            return body(UnsafeBufferPointer(start: rebound, count: count))
        }
    }
}
