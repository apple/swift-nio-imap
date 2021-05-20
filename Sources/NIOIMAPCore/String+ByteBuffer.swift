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
        
        let allFitInsideInt8 = bytes.allSatisfy { $0 < Int8.max && $0 >= 0 }
        guard allFitInsideInt8 else {
            return nil
        }
        
        let maybeString = bytes.map { CChar($0) }.withUnsafeBytes { body in
            String(validatingUTF8: body.bindMemory(to: CChar.self).baseAddress!)
        }
        guard let string = maybeString else {
            return nil
        }
        self = string
    }
    
}
