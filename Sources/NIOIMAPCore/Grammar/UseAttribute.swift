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

public struct UseAttribute: Equatable, RawRepresentable {
    
    public typealias RawValue = String
    
    public static var all = Self(rawValue: "\\All")
    public static var archive = Self(rawValue: "\\Archive")
    public static var drafts = Self(rawValue: "\\Drafts")
    public static var flagged = Self(rawValue: "\\Flagged")
    public static var junk = Self(rawValue: "\\Junk")
    public static var sent = Self(rawValue: "\\Sent")
    public static var trash = Self(rawValue: "\\Trash")
    
    public var rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUseAttribute(_ att: UseAttribute) -> Int {
        self.writeString(att.rawValue)
    }
}
