//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// swift-format-ignore: NoBlockComments
// This base64 implementation is heavily inspired by:
// https://github.com/lemire/fastbase64/blob/master/src/chromiumbase64.c ignore-unacceptable-language
/*
 Copyright (c) 2015-2016, Wojciech Muła, Alfred Klomp,  Daniel Lemire
 (Unless otherwise stated in the source code)
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are
 met:

 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// https://github.com/client9/stringencoders/blob/master/src/modp_b64.c ignore-unacceptable-language

/*
 The MIT License (MIT)

 Copyright (c) 2016 Nick Galbreath

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

// https://github.com/swift-extras/swift-extras-base64

// minor modifications to remove public attributes

@usableFromInline
enum Base64 {
    @usableFromInline
    struct EncodingOptions: OptionSet, Sendable {
        @usableFromInline
        let rawValue: UInt

        @usableFromInline
        init(rawValue: UInt) { self.rawValue = rawValue }

        @usableFromInline
        static let base64UrlAlphabet = EncodingOptions(rawValue: UInt(1 << 0))

        @usableFromInline
        static let omitPaddingCharacter = EncodingOptions(rawValue: UInt(1 << 1))
    }

    @usableFromInline
    struct DecodingOptions: OptionSet, Sendable {
        @usableFromInline
        let rawValue: UInt

        @usableFromInline
        init(rawValue: UInt) { self.rawValue = rawValue }

        @usableFromInline
        static let base64UrlAlphabet = DecodingOptions(rawValue: UInt(1 << 0))

        @usableFromInline
        static let omitPaddingCharacter = DecodingOptions(rawValue: UInt(1 << 1))
    }
}

//// MARK: - Extensions -

extension String {
    @usableFromInline
    init<Buffer: Collection>(base64Encoding bytes: Buffer, options: Base64.EncodingOptions = [])
    where Buffer.Element == UInt8 {
        self = Base64.encodeString(bytes: bytes, options: options)
    }

    func base64decoded(options: Base64.DecodingOptions = []) throws -> [UInt8] {
        try Base64.decode(string: self, options: options)
    }
}
