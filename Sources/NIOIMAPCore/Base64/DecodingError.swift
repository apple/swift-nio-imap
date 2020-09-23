// Courtesy of @fabianfett
// https://github.com/fabianfett/swift-base64-kit

public enum DecodingError: Error, Equatable {
    case invalidLength
    case invalidCharacter(UInt8)
    case unexpectedPaddingCharacter
    case unexpectedEnd
}
