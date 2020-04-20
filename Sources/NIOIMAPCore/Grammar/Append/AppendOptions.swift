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

extension NIOIMAP {

    public struct AppendOptions: Equatable {
        public var flagList: [Flag]
        public var dateTime: Date.DateTime?
        public var extensions: [AppendExtension]
        
        public static func flagList(_ flagList: [Flag], dateTime: Date.DateTime?, extensions: [AppendExtension]) -> Self {
            return Self(flagList: flagList, dateTime: dateTime, extensions: extensions)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeAppendOptions(_ options: NIOIMAP.AppendOptions) -> Int {
        self.writeIfArrayHasMinimumSize(array: options.flagList) { (array, self) -> Int in
            self.writeSpace() +
            self.writeFlags(array)
        } +
        self.writeIfExists(options.dateTime) { (dateTime) -> Int in
            self.writeSpace() +
            self.writeDateTime(dateTime)
        } +
        self.writeArray(options.extensions, separator: "", parenthesis: false) { (ext, self) -> Int in
            self.writeSpace() +
            self.writeAppendExtension(ext)
        }
    }
    
}
