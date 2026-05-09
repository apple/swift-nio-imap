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

import NIO

extension MultiThreadedEventLoopGroup {
    /// A shared event loop group with a low thread count for IMAP connections.
    public static var sharedEventLoopGroup: MultiThreadedEventLoopGroup {
        _singleton
    }
}

private let _singleton: MultiThreadedEventLoopGroup = {
    // A dedicated, never-shut-down group for IMAP connections. `_makePerpetualGroup`
    // returns a group whose event loops run for the lifetime of the process, and this
    // global holds the reference to it — so no extra manual `retain()` is needed.
    MultiThreadedEventLoopGroup._makePerpetualGroup(
        threadNamePrefix: "nio-imap-tool-",
        numberOfThreads: 2
    )
}()
