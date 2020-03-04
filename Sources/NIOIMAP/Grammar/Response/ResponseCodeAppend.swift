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

    /// IMAPv4 `response-code-apnd`
    public struct ResponseCodeAppend: Equatable {
        public var num: NZNumber
        public var uid: AppendUID
        
        public static func num(_ num: NZNumber, uid: AppendUID) -> Self {
            return Self(num: num, uid: uid)
        }
    }

}
