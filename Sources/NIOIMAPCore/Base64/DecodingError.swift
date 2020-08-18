
public enum DecodingError: Error, Equatable {
    case invalidLength
    case invalidCharacter(UInt8)
    case unexpectedPaddingCharacter
    case unexpectedEnd
}
