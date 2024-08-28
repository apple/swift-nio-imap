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

/// Parameters to use when creating a mailbox.
public enum CreateParameter: Hashable, Sendable {
    /// Implemented as a catch-all to provide support for cases defined in future extensions.
    case labelled(KeyValue<String, ParameterValue?>)

    /// Adds special-use attributes to the newly-created Mailbox.
    case attributes([UseAttribute])
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeCreateParameter(_ parameter: CreateParameter) -> Int {
        switch parameter {
        case .attributes(let attributes):
            return self.writeString("USE ") +
                self.writeArray(attributes) { (att, buffer) -> Int in
                    buffer.writeUseAttribute(att)
                }
        case .labelled(let parameter):
            return self.writeParameter(parameter)
        }
    }
}
