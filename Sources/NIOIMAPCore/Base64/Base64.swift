// Courtesy of @fabianfett
// https://github.com/fabianfett/swift-base64-kit

// minor modifications to remove public attributes

struct Base64 {}

// MARK: Encoding

extension Base64 {
     struct EncodingOptions: OptionSet {
         let rawValue: UInt
         init(rawValue: UInt) { self.rawValue = rawValue }

         static let base64URLAlphabet = EncodingOptions(rawValue: UInt(1 << 0))
    }

    /// Base64 encode a collection of UInt8 to a string, without the use of Foundation.
    ///
    /// This function performs the world's most naive Base64 encoding: no attempts to use a larger
    /// lookup table or anything intelligent like that, just shifts and masks. This works fine, for
    /// now: the purpose of this encoding is to avoid round-tripping through Data, and the perf gain
    /// from avoiding that is more than enough to outweigh the silliness of this code.
    @inlinable
     static func encode<Buffer: Collection>(bytes: Buffer, options: EncodingOptions = [])
        -> String where Buffer.Element == UInt8 {
        // In Base64, 3 bytes become 4 output characters, and we pad to the
        // nearest multiple of four.
        let newCapacity = ((bytes.count + 2) / 3) * 4
        let alphabet = options.contains(.base64URLAlphabet)
            ? Base64.encodeBase64URL
            : Base64.encodeBase64

        var outputBytes = [UInt8]()
        outputBytes.reserveCapacity(newCapacity)

        var input = bytes.makeIterator()

        while let firstByte = input.next() {
            let secondByte = input.next()
            let thirdByte = input.next()

            let firstChar = Base64.encode(alphabet: alphabet, firstByte: firstByte)
            let secondChar = Base64.encode(alphabet: alphabet, firstByte: firstByte, secondByte: secondByte)
            let thirdChar = Base64.encode(alphabet: alphabet, secondByte: secondByte, thirdByte: thirdByte)
            let forthChar = Base64.encode(alphabet: alphabet, thirdByte: thirdByte)

            outputBytes.append(firstChar)
            outputBytes.append(secondChar)
            outputBytes.append(thirdChar)
            outputBytes.append(forthChar)
        }

        return String(decoding: outputBytes, as: Unicode.UTF8.self)
    }

    // MARK: Internal

    // The base64 unicode table.
    @usableFromInline
    static let encodeBase64: [UInt8] = [
        UInt8(ascii: "A"), UInt8(ascii: "B"), UInt8(ascii: "C"), UInt8(ascii: "D"),
        UInt8(ascii: "E"), UInt8(ascii: "F"), UInt8(ascii: "G"), UInt8(ascii: "H"),
        UInt8(ascii: "I"), UInt8(ascii: "J"), UInt8(ascii: "K"), UInt8(ascii: "L"),
        UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "O"), UInt8(ascii: "P"),
        UInt8(ascii: "Q"), UInt8(ascii: "R"), UInt8(ascii: "S"), UInt8(ascii: "T"),
        UInt8(ascii: "U"), UInt8(ascii: "V"), UInt8(ascii: "W"), UInt8(ascii: "X"),
        UInt8(ascii: "Y"), UInt8(ascii: "Z"), UInt8(ascii: "a"), UInt8(ascii: "b"),
        UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "e"), UInt8(ascii: "f"),
        UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "i"), UInt8(ascii: "j"),
        UInt8(ascii: "k"), UInt8(ascii: "l"), UInt8(ascii: "m"), UInt8(ascii: "n"),
        UInt8(ascii: "o"), UInt8(ascii: "p"), UInt8(ascii: "q"), UInt8(ascii: "r"),
        UInt8(ascii: "s"), UInt8(ascii: "t"), UInt8(ascii: "u"), UInt8(ascii: "v"),
        UInt8(ascii: "w"), UInt8(ascii: "x"), UInt8(ascii: "y"), UInt8(ascii: "z"),
        UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"),
        UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "7"),
        UInt8(ascii: "8"), UInt8(ascii: "9"), UInt8(ascii: "+"), UInt8(ascii: "/"),
    ]

    @usableFromInline
    static let encodeBase64URL: [UInt8] = [
        UInt8(ascii: "A"), UInt8(ascii: "B"), UInt8(ascii: "C"), UInt8(ascii: "D"),
        UInt8(ascii: "E"), UInt8(ascii: "F"), UInt8(ascii: "G"), UInt8(ascii: "H"),
        UInt8(ascii: "I"), UInt8(ascii: "J"), UInt8(ascii: "K"), UInt8(ascii: "L"),
        UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "O"), UInt8(ascii: "P"),
        UInt8(ascii: "Q"), UInt8(ascii: "R"), UInt8(ascii: "S"), UInt8(ascii: "T"),
        UInt8(ascii: "U"), UInt8(ascii: "V"), UInt8(ascii: "W"), UInt8(ascii: "X"),
        UInt8(ascii: "Y"), UInt8(ascii: "Z"), UInt8(ascii: "a"), UInt8(ascii: "b"),
        UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "e"), UInt8(ascii: "f"),
        UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "i"), UInt8(ascii: "j"),
        UInt8(ascii: "k"), UInt8(ascii: "l"), UInt8(ascii: "m"), UInt8(ascii: "n"),
        UInt8(ascii: "o"), UInt8(ascii: "p"), UInt8(ascii: "q"), UInt8(ascii: "r"),
        UInt8(ascii: "s"), UInt8(ascii: "t"), UInt8(ascii: "u"), UInt8(ascii: "v"),
        UInt8(ascii: "w"), UInt8(ascii: "x"), UInt8(ascii: "y"), UInt8(ascii: "z"),
        UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"),
        UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "7"),
        UInt8(ascii: "8"), UInt8(ascii: "9"), UInt8(ascii: "-"), UInt8(ascii: "_"),
    ]

    @usableFromInline
    static let encodePaddingCharacter: UInt8 = 61

    @inlinable
    static func encode(alphabet: [UInt8], firstByte: UInt8) -> UInt8 {
        let index = firstByte >> 2
        return alphabet[Int(index)]
    }

    @inlinable
    static func encode(alphabet: [UInt8], firstByte: UInt8, secondByte: UInt8?) -> UInt8 {
        var index = (firstByte & 0b0000_0011) << 4
        if let secondByte = secondByte {
            index += (secondByte & 0b1111_0000) >> 4
        }
        return alphabet[Int(index)]
    }

    @inlinable
    static func encode(alphabet: [UInt8], secondByte: UInt8?, thirdByte: UInt8?) -> UInt8 {
        guard let secondByte = secondByte else {
            // No second byte means we are just emitting padding.
            return Base64.encodePaddingCharacter
        }
        var index = (secondByte & 0b0000_1111) << 2
        if let thirdByte = thirdByte {
            index += (thirdByte & 0b1100_0000) >> 6
        }
        return alphabet[Int(index)]
    }

    @inlinable
    static func encode(alphabet: [UInt8], thirdByte: UInt8?) -> UInt8 {
        guard let thirdByte = thirdByte else {
            // No third byte means just padding.
            return Base64.encodePaddingCharacter
        }
        let index = thirdByte & 0b0011_1111
        return alphabet[Int(index)]
    }
}

// MARK: - Decode -

extension Base64 {
     struct DecodingOptions: OptionSet {
         let rawValue: UInt
         init(rawValue: UInt) { self.rawValue = rawValue }

         static let base64URLAlphabet = DecodingOptions(rawValue: UInt(1 << 0))
    }

    @inlinable
     static func decode<Buffer: Collection>(encoded: Buffer, options: DecodingOptions = [])
        throws -> [UInt8] where Buffer.Element == UInt8 {
        let alphabet = options.contains(.base64URLAlphabet)
            ? Base64.decodeBase64URL
            : Base64.decodeBase64

        // In Base64 4 encoded bytes, become 3 decoded bytes. We pad to the
        // nearest multiple of three.
        let inputLength = encoded.count
        guard inputLength > 0 else { return [] }
        guard inputLength % 4 == 0 else {
            throw DecodingError.invalidLength
        }

        let inputBlocks = (inputLength + 3) / 4
        let fullQualified = inputBlocks - 1
        let outputLength = ((encoded.count + 3) / 4) * 3
        var iterator = encoded.makeIterator()
        var outputBytes = [UInt8]()
        outputBytes.reserveCapacity(outputLength)

        // fast loop. we don't expect any padding in here.
        for _ in 0 ..< fullQualified {
            let firstValue: UInt8 = try iterator.nextValue(alphabet: alphabet)
            let secondValue: UInt8 = try iterator.nextValue(alphabet: alphabet)
            let thirdValue: UInt8 = try iterator.nextValue(alphabet: alphabet)
            let forthValue: UInt8 = try iterator.nextValue(alphabet: alphabet)

            outputBytes.append((firstValue << 2) | (secondValue >> 4))
            outputBytes.append((secondValue << 4) | (thirdValue >> 2))
            outputBytes.append((thirdValue << 6) | forthValue)
        }

        // last 4 bytes. we expect padding characters in three and four
        let firstValue: UInt8 = try iterator.nextValue(alphabet: alphabet)
        let secondValue: UInt8 = try iterator.nextValue(alphabet: alphabet)
        let thirdValue: UInt8? = try iterator.nextValueOrEmpty(alphabet: alphabet)
        let forthValue: UInt8? = try iterator.nextValueOrEmpty(alphabet: alphabet)

        outputBytes.append((firstValue << 2) | (secondValue >> 4))
        if let thirdValue = thirdValue {
            outputBytes.append((secondValue << 4) | (thirdValue >> 2))

            if let forthValue = forthValue {
                outputBytes.append((thirdValue << 6) | forthValue)
            }
        }

        return outputBytes
    }

    @inlinable
     static func decode(encoded: String, options: DecodingOptions = []) throws -> [UInt8] {
        // A string can be backed by a contiguous storage (pure swift string)
        // or a nsstring (bridged string from objc). We only get a pointer
        // to the contiguous storage, if the input string is a swift string.
        // Therefore to transform the nsstring backed input into a swift
        // string we concat the input with nothing, causing a copy on write
        // into a swift string.
        let decoded = try encoded.utf8.withContiguousStorageIfAvailable { pointer in
            try self.decode(encoded: pointer, options: options)
        }

        if decoded != nil {
            return decoded!
        }

        return try self.decode(encoded: encoded + "", options: options)
    }

    // MARK: Internal

    // swiftformat:disable consecutiveSpaces
    @usableFromInline
    static let decodeBase64: [UInt8] = [
        //         0    1    2    3    4    5    6    7    8    9
        /*  0 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /*  1 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /*  2 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /*  3 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /*  4 */ 255, 255, 255,  62, 255, 255, 255,  63,  52,  53,
        /*  5 */  54,  55,  56,  57,  58,  59,  60,  61, 255, 255,
        /*  6 */ 255, 254, 255, 255, 255,   0,   1,   2,   3,   4,
        /*  7 */   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,
        /*  8 */  15,  16,  17,  18,  19,  20,  21,  22,  23,  24,
        /*  9 */  25, 255, 255, 255, 255, 255, 255,  26,  27,  28,
        /* 10 */  29,  30,  31,  32,  33,  34,  35,  36,  37,  38,
        /* 11 */  39,  40,  41,  42,  43,  44,  45,  46,  47,  48,
        /* 12 */  49,  50,  51, 255, 255, 255, 255, 255, 255, 255,
        /* 13 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 14 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 15 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 16 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 17 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 18 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 19 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 20 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 21 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 22 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 23 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 24 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 25 */ 255, 255, 255, 255, 255,
    ]

    @usableFromInline
    static let decodeBase64URL: [UInt8] = [
        //         0    1    2    3    4    5    6    7    8    9
        /*  0 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /*  1 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /*  2 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /*  3 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /*  4 */ 255, 255, 255, 255, 255,  62, 255, 255,  52,  53,
        /*  5 */  54,  55,  56,  57,  58,  59,  60,  61, 255, 255,
        /*  6 */ 255, 254, 255, 255, 255,   0,   1,   2,   3,   4,
        /*  7 */   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,
        /*  8 */  15,  16,  17,  18,  19,  20,  21,  22,  23,  24,
        /*  9 */  25, 255, 255, 255, 255,  63, 255,  26,  27,  28,
        /* 10 */  29,  30,  31,  32,  33,  34,  35,  36,  37,  38,
        /* 11 */  39,  40,  41,  42,  43,  44,  45,  46,  47,  48,
        /* 12 */  49,  50,  51, 255, 255, 255, 255, 255, 255, 255,
        /* 13 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 14 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 15 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 16 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 17 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 18 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 19 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 20 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 21 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 22 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 23 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 24 */ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        /* 25 */ 255, 255, 255, 255, 255,
    ]
    // swiftformat:enable consecutiveSpaces

    @usableFromInline
    static let paddingCharacter: UInt8 = 254
}

extension IteratorProtocol where Self.Element == UInt8 {
    mutating func nextValue(alphabet: [UInt8]) throws -> UInt8 {
        let ascii = next()!

        let value = alphabet[Int(ascii)]

        if value < 64 {
            return value
        }

        if value == Base64.paddingCharacter {
            throw DecodingError.unexpectedPaddingCharacter
        }

        throw DecodingError.invalidCharacter(ascii)
    }

    mutating func nextValueOrEmpty(alphabet: [UInt8]) throws -> UInt8? {
        let ascii = next()!

        let value = alphabet[Int(ascii)]

        if value < 64 {
            return value
        }

        if value == Base64.paddingCharacter {
            return nil
        }

        throw DecodingError.invalidCharacter(ascii)
    }
}

// MARK: - Extensions -

extension String {

    init<Buffer: Collection>(base64Encoding bytes: Buffer, options: Base64.EncodingOptions = [])
        where Buffer.Element == UInt8 {
        self = Base64.encode(bytes: bytes, options: options)
    }

     func base64decoded(options: Base64.DecodingOptions = []) throws -> [UInt8] {
        // In Base64, 3 bytes become 4 output characters, and we pad to the nearest multiple
        // of four.
        try Base64.decode(encoded: self, options: options)
    }
}
