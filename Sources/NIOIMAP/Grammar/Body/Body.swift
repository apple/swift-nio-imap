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
        
        case singlepart(Singlepart)
        case multipart(Multipart)
        
        /// IMAPv4 `body-fld-lines`
        typealias FieldLines = Number
        
        /// IMAPv4 `body-fld-octets`
        typealias FieldOctets = Number
        
        /// IMAPv4 `body-fld-id`
        typealias FieldID = NString
        
        /// IMAPv4 `body-fld-loc`
        typealias FieldLocation = NString
        
        /// IMAPv4 `body-fld-md`5
        typealias FieldMD5 = NString
        
        /// IMAPv4 `body-fld-desc`
        typealias FieldDescription = NString
    }
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBody(_ body: NIOIMAP.Body) -> Int {
        var size = 0
        size += self.writeString("(")
        switch body {
        case .singlepart(let part):
            size += self.writeBodySinglepart(part)
        case .multipart(let part):
            size += self.writeBodyMultipart(part)
        }
        size += self.writeString(")")
        return size
    }

}
