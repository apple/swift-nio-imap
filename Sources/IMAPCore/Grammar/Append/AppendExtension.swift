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

    public struct AppendExtension: Equatable {
        public var name: String
        public var value: TaggedExtensionValue
        
        public static func name(_ name: String, value: TaggedExtensionValue) -> Self {
            return Self(name: name, value: value)
        }
    }

}
