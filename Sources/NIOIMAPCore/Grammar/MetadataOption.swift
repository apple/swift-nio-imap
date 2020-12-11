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

/// Metadata options use in a `.getMetadata` command.
public enum MetadataOption: Equatable {
    /// Only entry values that are less than or equal in octet size to the specified
    /// MAXSIZE limit are returned.
    case maxSize(Int)

    /// Specifies the maximum depth.
    case scope(ScopeOption)

    /// Implemented as a catch-all to support additions in future extensions.
    case other(Parameter)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMetadataOption(_ option: MetadataOption) -> Int {
        switch option {
        case .maxSize(let num):
            return self.writeString("MAXSIZE \(num)")
        case .scope(let opt):
            return self.writeScopeOption(opt)
        case .other(let param):
            return self.writeParameter(param)
        }
    }

    @discardableResult mutating func writeMetadataOptions(_ array: [MetadataOption]) -> Int {
        self.writeArray(array) { element, buffer in
            buffer.writeMetadataOption(element)
        }
    }
}
