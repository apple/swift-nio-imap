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

    public struct AppendOptions: Equatable {
        var flagList: FlagList?
        var dateTime: Date.DateTime?
        var extensions: [AppendExtension]
        
        static func flagList(_ flagList: FlagList?, dateTime: Date.DateTime?, extensions: [AppendExtension]) -> Self {
            return Self(flagList: flagList, dateTime: dateTime, extensions: extensions)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeAppendOptions(_ options: NIOIMAP.AppendOptions) -> Int {
        self.writeIfExists(options.flagList) { (flagList) -> Int in
            self.writeSpace() +
            self.writeFlags(flagList)
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
