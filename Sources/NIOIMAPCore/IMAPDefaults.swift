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

public struct IMAPDefaults {
    /// A line should be no more than 8192 bytes according to RFC 7162 section 4.
    public static let lineLengthLimit: Int = 8_192

    /// Allow 4KB literals by default.
    public static let literalSizeLimit: Int = 4_096
    
    /// Allow any size bodies by default.
    public static let bodySizeLimit: Int = .max

    private init() {}
}
