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

#if compiler(>=6.2)
/// A workaround for Swift 6.0 and Swift 6.1, which require the closures of this module’s
/// caller-isolated methods to return a `Sendable` value.
///
/// Those two compilers treat a closure that inherits the caller’s isolation as running
/// _outside_ the callee’s isolation, so a non-`Sendable` result cannot be sent back out of it.
/// This alias is how the module imposes that requirement on them — and only on them: from
/// Swift 6.2 on, `nonisolated(nonsending)` makes it demonstrable that the closure runs in the
/// caller’s isolation domain, its result never leaves that domain, and so the alias is an
/// unconstrained `Any` that requires nothing.
///
/// - Note: Delete this alias, and the `_IMAPClosureResult` constraint on every generic result
///   type in this module, once Swift 6.2 is the oldest supported compiler.
public typealias _IMAPClosureResult = Any
#else
/// A workaround for Swift 6.0 and Swift 6.1, which require the closures of this module’s
/// caller-isolated methods to return a `Sendable` value.
///
/// Those two compilers treat a closure that inherits the caller’s isolation as running
/// _outside_ the callee’s isolation, so a non-`Sendable` result cannot be sent back out of it.
/// This alias is `Sendable` here to impose that requirement. From Swift 6.2 on it is an
/// unconstrained `Any`, and any result is allowed.
///
/// - Note: Delete this alias, and the `_IMAPClosureResult` constraint on every generic result
///   type in this module, once Swift 6.2 is the oldest supported compiler.
public typealias _IMAPClosureResult = Sendable
#endif
