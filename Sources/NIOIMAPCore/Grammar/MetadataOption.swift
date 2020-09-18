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

public enum MetadataOption: Equatable {
    case maxSize(Int)
    case scope(ScopeOption)
    case `other`(Parameter)
}

// MARK: - Encoding
extension EncodeBuffer {
    
    @discardableResult mutating func writeMetadataOption(_ option: MetadataOption) -> Int {
        switch option {
        case .maxSize(let num):
            return self.writeString("MAXSIZE \(num)")
        case .scope(let opt):
            return self.writeScopeOption(opt)
        case .other(let param):
            return self.writeParameter(param)
        }
    }
    
    @discardableResult mutating func writeMetadataOptions(_ array: [MetadataOption]) -> Int {
        self.writeArray(array) { element, buffer in
            buffer.writeMetadataOption(element)
        }
    }
    
}
