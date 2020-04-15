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



extension IMAPCore.Date {
    
    /// IMAPv4 `time`
    public struct Time: Equatable {
        public var hour: Int
        public var minute: Int
        public var second: Int
        
        public static func hour(_ hour: Int, minute: Int, second: Int) -> Self {
            return Self(hour: hour, minute: minute, second: second)
        }
    }
    
}
