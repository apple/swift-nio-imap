// https://github.com/swift-extras/swift-extras-base64

// minor modifications to remove public attributes

extension Base64 {
    @usableFromInline
    enum DecodingError: Error, Equatable {
        case invalidLength
        case invalidCharacter(UInt8)
        case unexpectedPaddingCharacter
        case unexpectedEnd
    }
}
