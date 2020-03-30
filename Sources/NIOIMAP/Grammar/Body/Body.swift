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

import NIO

extension NIOIMAP {

    /// IMAOv4 body
    public enum Body: Equatable {
        
        case singlepart(TypeSinglepart)
        case multipart(TypeMultipart)
        
        /// IMAPv4 `body-fld-lines`
        public typealias FieldLines = Int
        
        /// IMAPv4 `body-fld-octets`
        public typealias FieldOctets = Int
    }
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBody(_ body: NIOIMAP.Body) -> Int {
        var size = 0
        size += self.writeString("(")
        switch body {
        case .singlepart(let part):
            size += self.writeBodyTypeSinglepart(part)
        case .multipart(let part):
            size += self.writeBodyTypeMultipart(part)
        }
        size += self.writeString(")")
        return size
    }

}
