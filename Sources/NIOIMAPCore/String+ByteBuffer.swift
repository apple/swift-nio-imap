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

extension String {
    
    public init?<T: Sequence>(validatingUTF8Bytes bytes: T) where T.Element == UInt8 {
        
        // CChar is an alias for Int8, so the bytes need to fit inside Int8
        let allFitInsideInt8 = bytes.allSatisfy { $0 <= Int8.max && $0 >= 0 }
        guard allFitInsideInt8 else {
            return nil
        }
        
        // The initialiser we use depends on the string being NULL-terminated
        let chars = bytes.map { CChar($0) } + [0]
        let maybeString = chars.withUnsafeBytes { body in
            String(validatingUTF8: body.bindMemory(to: CChar.self).baseAddress!)
        }
        guard let string = maybeString else {
            return nil
        }
        self = string
    }
    
}
