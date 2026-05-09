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

import Synchronization
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOIMAP

/// Parses the small set of message headers that `IMAPToolLib` needs when
/// appending messages to a mailbox.
///
/// `IMAPToolLib` ships with a minimal, dependency-free implementation
/// (``MiniMIMEHeaderParser``). An embedding tool can install a richer parser
/// (for example, one backed by a full MIME parser) via
/// ``MessageHeaderParser/current``.
public protocol MessageHeaderParsing: Sendable {
    /// Parses just the `Date` header from the given message data.
    func dateHeader(_ data: Data) -> InternetMessageDate?

    /// Parses the headers needed to append the given message.
    func headersOfInterest(_ data: Data) -> EmailMessage.HeadersOfInterest?
}

/// The minimal header parser used by default. It does not handle header folding
/// (continuation lines) and only understands `Date` and `Message-ID`.
struct MiniMIMEHeaderParser: MessageHeaderParsing {
    init() {}

    func dateHeader(_ data: Data) -> InternetMessageDate? {
        MIMEMessage.data(data).dateHeader()
    }

    func headersOfInterest(_ data: Data) -> EmailMessage.HeadersOfInterest? {
        MIMEMessage.data(data).headersOfInterest()
    }
}

/// The message header parser used throughout `IMAPToolLib`.
///
/// Defaults to ``MiniMIMEHeaderParser``. Embedders can replace it before running
/// any command.
public enum MessageHeaderParser {
    private static let _current = Mutex<any MessageHeaderParsing>(MiniMIMEHeaderParser())

    public static var current: any MessageHeaderParsing {
        get { _current.withLock { $0 } }
        set { _current.withLock { $0 = newValue } }
    }
}
