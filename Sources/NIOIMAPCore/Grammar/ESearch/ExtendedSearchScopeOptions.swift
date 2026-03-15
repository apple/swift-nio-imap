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

import struct NIO.ByteBuffer
import struct OrderedCollections.OrderedDictionary

/// Optional scope options for extended multi-mailbox search operations (RFC 7377).
///
/// **Requires server capability:** ``Capability/multimailboxSearch``
///
/// Scope options provide a catch-all mechanism for future extensions to the MULTIMAILBOX SEARCH protocol,
/// allowing servers to support additional scope-related parameters beyond those explicitly defined.
/// These options are specified as key-value pairs and are optional in search commands.
/// See [RFC 7377 Section 2.1.1](https://datatracker.ietf.org/doc/html/rfc7377#section-2.1.1) for details.
///
/// ## Related Types
///
/// - See ``ExtendedSearchSourceOptions`` for mailbox selection
/// - See ``ExtendedSearchOptions`` for complete search options
///
/// - SeeAlso: [RFC 7377](https://datatracker.ietf.org/doc/html/rfc7377)
public struct ExtendedSearchScopeOptions: Hashable, Sendable {
    /// An ordered dictionary of scope option key-value pairs.
    ///
    /// The array must contain at least one key-value pair and is never empty. This provides
    /// a flexible mechanism for supporting scope parameters not yet defined in the base specification.
    public let content: OrderedDictionary<String, ParameterValue?>

    /// Creates a new `ExtendedSearchScopeOptions` from one or more scope options.
    ///
    /// - parameter options: One or more key-value scope option pairs. Must not be empty.
    /// - returns: A new `ExtendedSearchScopeOptions` if `options` is non-empty, otherwise `nil`.
    init?(_ options: OrderedDictionary<String, ParameterValue?>) {
        guard options.count >= 1 else {
            return nil
        }
        self.content = options
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeExtendedSearchScopeOptions(_ options: ExtendedSearchScopeOptions) -> Int {
        self.writeOrderedDictionary(options.content, parenthesis: false) { (option, buffer) -> Int in
            buffer.writeParameter(option)
        }
    }
}
