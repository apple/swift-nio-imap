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

// MARK: - ByteBuffer
public extension NIOIMAP {
    
    /// IMAPv4 `base`64
    typealias Base64 = ByteBuffer
    
    /// IMAPv4 `astring`
    typealias AString = ByteBuffer
    
    /// IMAPv4 `text`
    typealias Text = ByteBuffer
    
    /// IMAPv4 `quoted`
    typealias Quoted = ByteBuffer
    
    /// IMAPv4 `string`
    typealias IMAPString = ByteBuffer
    
}

// MARK: - AString
public extension NIOIMAP {
    
    /// IMAPv4 `header-fld-name`
    typealias HeaderFieldName = AString
    
    /// IMAPv4 `password`
    typealias Password = AString

}
