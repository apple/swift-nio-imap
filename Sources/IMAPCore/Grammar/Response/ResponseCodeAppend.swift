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



extension IMAPCore {

    /// IMAPv4 `response-code-apnd`
    public struct ResponseCodeAppend: Equatable {
        public var num: Int
        public var uid: Int
        
        public static func num(_ num: Int, uid: Int) -> Self {
            return Self(num: num, uid: uid)
        }
    }

}
