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

extension String {
    public init?<T: Sequence>(validatingUTF8Bytes bytes: T) where T.Element == UInt8 {
        var bytesIterator = bytes.makeIterator()
        var scalars: [Unicode.Scalar] = []
        scalars.reserveCapacity(bytes.underestimatedCount)
        var utf8Decoder = UTF8()
        while true {
            switch utf8Decoder.decode(&bytesIterator) {
            case .scalarValue(let v):
                scalars.append(v)
            case .emptyInput:
                self = String(String.UnicodeScalarView(scalars))
                return
            case .error:
                return nil
            }
        }
        preconditionFailure("This should never happen")
    }
}
