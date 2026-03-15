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

/// Parameters that modify the behavior of the `CREATE` command.
///
/// The `CreateParameter` enum allows clients to attach special attributes or other
/// metadata when creating a new mailbox. Currently, the primary use is the `USE` option
/// (RFC 6154) to assign special-use attributes (like `\All`, `\Drafts`, `\Trash`) to
/// newly created mailboxes. The `labelled` case provides extensibility for future
/// CREATE parameters.
///
/// ### Example
///
/// ```
/// C: A001 CREATE DraftsFolder USE (\Drafts)
/// S: A001 OK CREATE completed
/// ```
///
/// The `USE (\Drafts)` portion is represented as `CreateParameter.attributes([.drafts])`.
///
/// - SeeAlso: [RFC 3501 Section 6.3.3](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.3) (CREATE Command)
/// - SeeAlso: [RFC 6154 Section 2](https://datatracker.ietf.org/doc/html/rfc6154#section-2) (USE Attribute)
/// - SeeAlso: ``Command/create(_:_:)``
public enum CreateParameter: Hashable, Sendable {
    /// A generic CREATE parameter (catch-all for extensions).
    ///
    /// Used for parameters not specifically handled by other cases, enabling future
    /// extensions to add new CREATE parameters without requiring code changes.
    ///
    /// - parameter KeyValue: A key-value pair representing the parameter
    case labelled(KeyValue<String, ParameterValue?>)

    /// Special-use attributes for the newly-created mailbox (RFC 6154).
    ///
    /// Assigns one or more special-use attributes to the mailbox, such as `\All`,
    /// `\Archive`, `\Drafts`, `\Flagged`, `\Important`, `\Junk`, `\Sent`, or `\Trash`.
    /// These attributes inform mail clients how to treat the mailbox in their UI.
    ///
    /// **Requires server capability:** ``Capability/specialUse``
    ///
    /// - parameter [UseAttribute]: One or more special-use attributes
    ///
    /// - SeeAlso: [RFC 6154](https://datatracker.ietf.org/doc/html/rfc6154) (Special-Use Mailbox Attributes)
    /// - SeeAlso: ``UseAttribute``
    case attributes([UseAttribute])
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeCreateParameter(_ parameter: CreateParameter) -> Int {
        switch parameter {
        case .attributes(let attributes):
            return self.writeString("USE ")
                + self.writeArray(attributes) { (att, buffer) -> Int in
                    buffer.writeUseAttribute(att)
                }
        case .labelled(let parameter):
            return self.writeParameter(parameter)
        }
    }
}
