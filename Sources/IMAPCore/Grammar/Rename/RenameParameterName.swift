//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors

// MARK: - Encoding
extension ByteBufferProtocol {
    
    @discardableResult mutating func writeRenameParameterName(_ name: String) -> Int {
        return self.writeTaggedExtensionLabel(name)
    }
    
}
