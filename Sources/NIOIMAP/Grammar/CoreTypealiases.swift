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

// MARK: - String
public extension NIOIMAP {
    
    /// IMAPv4 `astring`
    typealias AString = ByteBuffer
    
    /// IMAPv4 `atom`
    typealias Atom = String
    
    /// IMAPv4 `tag`
    typealias Tag = String
    
    // Note: This is probably wrong, the spec didn't define it
    /// IMAPv4 `vendor-token`
    typealias VendorToken = Atom
    
    /// IMAPv4 `charset`
    typealias Charset = String
}

// MARK: - ByteBuffer
public extension NIOIMAP {
    /// IMAPv4 `base`64
    typealias Base64 = ByteBuffer
    
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

// MARK: - Atom
public extension NIOIMAP {
    
    /// IMAPv4 `auth-type`
    typealias AuthType = Atom
    
}

// MARK: - Int
public extension NIOIMAP {
    
    /// IMAPv4 `number`
    typealias Number = Int
    
    /// IMAPv4 `number64`
    typealias Number64 = Int
    
    /// IMAPv4 `nz-number`
    typealias NZNumber = Int
}

// MARK: - Number
public extension NIOIMAP {
    
    /// IMAPv4 `uniqueid`
    typealias UniqueID = Number
    
    /// IMAPv4 `append-uid`
    typealias AppendUID = UniqueID
}
