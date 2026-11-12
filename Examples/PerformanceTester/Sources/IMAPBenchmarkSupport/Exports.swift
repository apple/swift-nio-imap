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

// The corpora moved to their own target so that the `IMAPDispatchClient` comparison — which builds
// against both the current library and a `main` worktree — can use them without dragging in the
// drivers here, which name post-migration types. Re-exported so that a benchmark importing
// `IMAPBenchmarkSupport` still sees `ResponseCorpus`, `ReadSize` and `ByteBuffer.chunks(ofSize:)`
// where it always did; the split is an assembly detail, not an API change.
@_exported import IMAPCorpus
