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

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Returns `true` if standard input connects to an interactive terminal session.
var standardInputIsTTY: Bool {
    isatty(FileHandle.standardInput.fileDescriptor) == 1
}
