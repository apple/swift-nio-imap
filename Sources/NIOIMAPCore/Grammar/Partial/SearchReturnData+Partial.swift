//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct NIO.ByteBuffer

extension SearchReturnData {
    public struct Partial: Hashable {
        /// The requested range.
        public var range: PartialRange
        /// The matching messages.
        ///
        /// `nil` indicates no results correspond to the requested range.
        public var messageNumbers: MessageIdentifierSet<UnknownMessageIdentifier>?
    }
}
