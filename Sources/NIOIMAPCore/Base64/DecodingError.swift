// Courtesy of @fabianfett
// https://github.com/fabianfett/swift-base64-kit

// minor modifications to remove public attributes

enum DecodingError: Error, Equatable {
    case invalidLength
    case invalidCharacter(UInt8)
    case unexpectedPaddingCharacter
    case unexpectedEnd
}
