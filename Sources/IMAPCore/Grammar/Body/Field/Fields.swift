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



extension IMAPCore.Body {

    /// IMAPv4 `body-fields`
    public struct Fields: Equatable {
        public var parameter: [IMAPCore.FieldParameterPair]
        public var id: IMAPCore.NString
        public var description: IMAPCore.NString
        public var encoding: FieldEncoding
        public var octets: Int

        /// Convenience function for a better experience when chaining multiple types.
        public static func parameter(_ parameters: [IMAPCore.FieldParameterPair], id: IMAPCore.NString, description: IMAPCore.NString, encoding: FieldEncoding, octets: Int) -> Self {
            return Self(parameter: parameters, id: id, description: description, encoding: encoding, octets: octets)
        }
    }

}
