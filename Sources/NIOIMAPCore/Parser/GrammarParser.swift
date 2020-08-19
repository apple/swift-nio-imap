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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
#elseif os(Linux) || os(FreeBSD) || os(Android)
import Glibc
#else
let badOS = { fatalError("unsupported OS") }()
#endif

import struct NIO.ByteBuffer

public enum ParsingError: Error {
    case lineTooLong
}

struct _IncompleteMessage: Error {}

public enum GrammarParser {}

// MARK: - Grammar Parsers

extension GrammarParser {
    // address         = "(" addr-name SP addr-adl SP addr-mailbox SP
    //                   addr-host ")"
    static func parseAddress(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Address {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Address in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let name = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let adl = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let host = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return Address(name: name, adl: adl, mailbox: mailbox, host: host)
        }
    }

    // append          = "APPEND" SP mailbox 1*append-message
    static func parseAppend(buffer: inout ByteBuffer, tracker: StackTracker) throws -> CommandStream {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> CommandStream in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" APPEND ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .append(.start(tag: tag, appendingTo: mailbox))
        }
    }

    // append-data = literal / literal8 / append-data-ext
    static func parseAppendData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendData {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AppendData in
            let withoutContentTransferEncoding = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString("~", buffer: &buffer, tracker: tracker)
            }.map { () in true } ?? false
            try ParserLibrary.parseFixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            _ = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString("+", buffer: &buffer, tracker: tracker)
            }.map { () in false } ?? true
            try ParserLibrary.parseFixedString("}", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseNewline(buffer: &buffer, tracker: tracker)
            return .init(byteCount: length, withoutContentTransferEncoding: withoutContentTransferEncoding)
        }
    }

    // append-message = appents-opts SP append-data
    static func parseAppendMessage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendMessage {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> AppendMessage in
            let options = try self.parseAppendOptions(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let data = try self.parseAppendData(buffer: &buffer, tracker: tracker)
            return .init(options: options, data: data)
        }
    }

    // append-options = [SP flag-list] [SP date-time] *(SP append-ext)
    static func parseAppendOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendOptions {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let flagList = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [Flag] in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseFlagList(buffer: &buffer, tracker: tracker)
            } ?? []
            let internalDate = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> InternalDate in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseInternalDate(buffer: &buffer, tracker: tracker)
            }
            let array = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> TaggedExtension in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseTaggedExtension(buffer: &buffer, tracker: tracker)
            }
            return .init(flagList: flagList, internalDate: internalDate, extensions: array)
        }
    }

    // astring         = 1*ASTRING-CHAR / string
    static func parseAString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        func parseOneOrMoreASTRINGCHAR(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try ParserLibrary.parseOneOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isAStringChar
            }
        }
        return try ParserLibrary.parseOneOf([
            Self.parseString,
            parseOneOrMoreASTRINGCHAR,
        ], buffer: &buffer, tracker: tracker)
    }

    // atom            = 1*ATOM-CHAR
    static func parseAtom(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAtomChar
        }
    }

    // authenticate    = "AUTHENTICATE" SP auth-type *(CRLF base64)
    static func parseAuthenticate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("AUTHENTICATE ", buffer: &buffer, tracker: tracker)
            let authMethod = try self.parseAtom(buffer: &buffer, tracker: tracker)

            // NOTE: Spec is super unclear, so we're ignoring the possibility of multiple base 64 chunks right now
//            let data = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [ByteBuffer] in
//                try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
//                return [try self.parseBase64(buffer: &buffer, tracker: tracker)]
//            } ?? []
            return .authenticate(method: authMethod, [])
        }
    }

    // base64          = *(4base64-char) [base64-terminal]
    static func parseBase64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            let bytes = try ParserLibrary.parseZeroOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { $0.isBase64Char || $0 == UInt8(ascii: "=") }
            let readableBytesView = bytes.readableBytesView
            if let firstEq = readableBytesView.firstIndex(of: UInt8(ascii: "=")) {
                for index in firstEq ..< readableBytesView.endIndex {
                    guard readableBytesView[index] == UInt8(ascii: "=") else {
                        throw ParserError(hint: "Found invalid character (expecting =) \(String(decoding: readableBytesView, as: Unicode.UTF8.self))")
                    }
                }
            }
            return ByteBuffer(bytes: try Base64.decode(encoded: String(buffer: buffer)))
        }
    }

    // body            = "(" (body-type-1part / body-type-mpart) ")"
    static func parseBody(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure {
        func parseBody_singlePart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let part = try self.parseBodyKindSinglePart(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .singlepart(part)
        }

        func parseBody_multiPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let part = try self.parseBodyKindMultipart(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .multipart(part)
        }

        return try ParserLibrary.parseOneOf([
            parseBody_singlePart,
            parseBody_multiPart,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-extension  = nstring / number /
    //                    "(" body-extension *(SP body-extension) ")"
    static func parseBodyExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [BodyExtension] {
        func parseBodyExtensionKind_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyExtension {
            .string(try self.parseNString(buffer: &buffer, tracker: tracker))
        }

        func parseBodyExtensionKind_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyExtension {
            .number(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseBodyExtensionKind(buffer: inout ByteBuffer, tracker: StackTracker, into array: inout [BodyExtension]) throws {
            let element = try ParserLibrary.parseOneOf([
                parseBodyExtensionKind_string,
                parseBodyExtensionKind_number,
            ], buffer: &buffer, tracker: tracker)
            array.append(element)
        }

        func parseBodyExtension_array(buffer: inout ByteBuffer, tracker: StackTracker, into array: inout [BodyExtension]) throws {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
            var save = buffer
            do {
                while true {
                    save = buffer
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
                }
            } catch is ParserError {
                buffer = save
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
        }

        func parseBodyExtension_arrayOrStatic(buffer: inout ByteBuffer, tracker: StackTracker, into array: inout [BodyExtension]) throws {
            let save = buffer
            do {
                try parseBodyExtensionKind(buffer: &buffer, tracker: tracker, into: &array)
            } catch is ParserError {
                buffer = save
                try parseBodyExtension_array(buffer: &buffer, tracker: tracker, into: &array)
            }
        }

        var array = [BodyExtension]()
        try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
        return array
    }

    // body-ext-1part  = body-fld-md5 [SP body-fld-dsp [SP body-fld-lang [SP body-fld-loc *(SP body-extension)]]]
    static func parseBodyExtSinglePart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart.Extension {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Singlepart.Extension in
            let md5 = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { String(buffer: $0) }
            let dsp = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.DispositionAndLanguage in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try parseBodyDescriptionLanguage(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Singlepart.Extension(fieldMD5: md5, dispositionAndLanguage: dsp)
        }
    }

    // body-ext-mpart  = body-fld-param [SP body-fld-dsp [SP body-fld-lang [SP body-fld-loc *(SP body-extension)]]]
    static func parseBodyExtMpart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Multipart.Extension {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Multipart.Extension in
            let param = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            let dsp = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.DispositionAndLanguage in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try parseBodyDescriptionLanguage(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Multipart.Extension(parameters: param, dispositionAndLanguage: dsp)
        }
    }

    // body-fields     = body-fld-param SP body-fld-id SP body-fld-desc SP
    //                   body-fld-enc SP body-fld-octets
    static func parseBodyFields(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Fields {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Fields in
            let fieldParam = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldID = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { String(buffer: $0) }
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldDescription = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { String(buffer: $0) }
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let Encoding = try self.parseBodyEncoding(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldOctets = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return BodyStructure.Fields(
                parameter: fieldParam,
                id: fieldID,
                description: fieldDescription,
                encoding: Encoding,
                octetCount: fieldOctets
            )
        }
    }

    // body-fld-dsp    = "(" string SP body-fld-param ")" / nil
    static func parseBodyFieldDsp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Disposition? {
        func parseBodyFieldDsp_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Disposition? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseBodyFieldDsp_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Disposition? {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let string = String(buffer: try self.parseString(buffer: &buffer, tracker: tracker))
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let param = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return BodyStructure.Disposition(kind: string, parameter: param)
        }

        return try ParserLibrary.parseOneOf([
            parseBodyFieldDsp_nil,
            parseBodyFieldDsp_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-fld-enc    = (DQUOTE ("7BIT" / "8BIT" / "BINARY" / "BASE64"/
    //                   "QUOTED-PRINTABLE") DQUOTE) / string
    static func parseBodyEncoding(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
        func parseBodyEncoding_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            let parsedBuffer = try self.parseString(buffer: &buffer, tracker: tracker)
            return .init(String(buffer: parsedBuffer))
        }

        func parseBodyEncoding_option(_ option: String, result: BodyStructure.Encoding, buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(option, buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return result
        }

        func parseBodyEncoding_7bit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("7BIT", result: .sevenBit, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_8bit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("8BIT", result: .eightBit, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("BINARY", result: .binary, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_base64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("BASE64", result: .base64, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_quotePrintable(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("QUOTED-PRINTABLE", result: .quotedPrintable, buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseOneOf([
            parseBodyEncoding_7bit,
            parseBodyEncoding_8bit,
            parseBodyEncoding_binary,
            parseBodyEncoding_base64,
            parseBodyEncoding_quotePrintable,
            parseBodyEncoding_string,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-fld-lang   = nstring / "(" string *(SP string) ")"
    static func parseBodyFieldLanguage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [String] {
        func parseBodyFieldLanguage_single(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [String] {
            guard let language = try self.parseNString(buffer: &buffer, tracker: tracker) else {
                return []
            }
            return [String(buffer: language)]
        }

        func parseBodyFieldLanguage_multiple(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [String] {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [String(buffer: try self.parseString(buffer: &buffer, tracker: tracker))]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> String in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return String(buffer: try self.parseString(buffer: &buffer, tracker: tracker))
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try ParserLibrary.parseOneOf([
            parseBodyFieldLanguage_multiple,
            parseBodyFieldLanguage_single,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-fld-param  = "(" string SP string *(SP string SP string) ")" / nil
    static func parseBodyFieldParam(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [BodyStructure.ParameterPair] {
        func parseBodyFieldParam_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [BodyStructure.ParameterPair] {
            try parseNil(buffer: &buffer, tracker: tracker)
            return []
        }

        func parseBodyFieldParam_singlePair(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.ParameterPair {
            let field = String(buffer: try parseString(buffer: &buffer, tracker: tracker))
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let value = String(buffer: try parseString(buffer: &buffer, tracker: tracker))
            return .init(field: field, value: value)
        }

        func parseBodyFieldParam_pairs(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [BodyStructure.ParameterPair] {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try parseBodyFieldParam_singlePair(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> BodyStructure.ParameterPair in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try parseBodyFieldParam_singlePair(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try ParserLibrary.parseOneOf([
            parseBodyFieldParam_pairs,
            parseBodyFieldParam_nil,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-type-1part = (body-type-basic / body-type-msg / body-type-text)
    //                   [SP body-ext-1part]
    static func parseBodyKindSinglePart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
        func parseBodyKindSinglePart_extension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart.Extension? {
            try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseBodyExtSinglePart(buffer: &buffer, tracker: tracker)
            }
        }

        func parseBodyKindSinglePart_basic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
            let media = try self.parseMediaBasic(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            let ext = try parseBodyKindSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(type: .basic(media), fields: fields, extension: ext)
        }

        func parseBodyKindSinglePart_message(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
            let mediaMessage = try self.parseMediaMessage(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let envelope = try self.parseEnvelope(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let body = try self.parseBody(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldLines = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let message = BodyStructure.Singlepart.Message(message: mediaMessage, envelope: envelope, body: body, fieldLines: fieldLines)
            let ext = try parseBodyKindSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(type: .message(message), fields: fields, extension: ext)
        }

        func parseBodyKindSinglePart_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
            let media = try self.parseMediaText(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldLines = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let text = BodyStructure.Singlepart.Text(mediaText: media, lineCount: fieldLines)
            let ext = try parseBodyKindSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(type: .text(text), fields: fields, extension: ext)
        }

        return try ParserLibrary.parseOneOf([
            parseBodyKindSinglePart_message,
            parseBodyKindSinglePart_text,
            parseBodyKindSinglePart_basic,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-type-mpart = 1*body SP media-subtype
    //                   [SP body-ext-mpart]
    static func parseBodyKindMultipart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Multipart {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Multipart in
            let parts = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure in
                try? ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseBody(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let media = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            let ext = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.Multipart.Extension in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseBodyExtMpart(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Multipart(parts: parts, mediaSubtype: media, extension: ext)
        }
    }

    // capability      = ("AUTH=" auth-type) / atom / "MOVE" / "ENABLE" / "FILTERS"
    static func parseCapability(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Capability {
        let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
        return Capability(string)
    }

    // capability-data = "CAPABILITY" *(SP capability) SP "IMAP4rev1"
    //                   *(SP capability)
    static func parseCapabilityData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Capability] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Capability] in
            try ParserLibrary.parseFixedString("CAPABILITY", buffer: &buffer, tracker: tracker)
            return try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }
    }

    // charset          = atom / quoted
    static func parseCharset(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        func parseCharset_atom(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            try parseAtom(buffer: &buffer, tracker: tracker)
        }

        func parseCharset_quoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            var buffer = try parseQuoted(buffer: &buffer, tracker: tracker)
            guard let string = buffer.readString(length: buffer.readableBytes) else {
                throw ParserError(hint: "Couldn't read string from buffer")
            }
            return string
        }

        return try ParserLibrary.parseOneOf([
            parseCharset_atom,
            parseCharset_quoted,
        ], buffer: &buffer, tracker: tracker)
    }

    // childinfo-extended-item =  "CHILDINFO" SP "("
    //             list-select-base-opt-quoted
    //             *(SP list-select-base-opt-quoted) ")"
    static func parseChildinfoExtendedItem(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ListSelectBaseOption] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ListSelectBaseOption] in
            try ParserLibrary.parseFixedString("CHILDINFO (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ListSelectBaseOption in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // child-mbox-flag =  "\hasChildren" / "\hasNoChildren"
    static func parseChildMailboxFlag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ChildMailboxFlag {
        func parseChildMailboxFlag_children(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ChildMailboxFlag {
            try ParserLibrary.parseFixedString(#"\hasChildren"#, buffer: &buffer, tracker: tracker)
            return .hasChildren
        }

        func parseChildMailboxFlag_noChildren(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ChildMailboxFlag {
            try ParserLibrary.parseFixedString(#"\hasNoChildren"#, buffer: &buffer, tracker: tracker)
            return .hasNoChildren
        }

        return try ParserLibrary.parseOneOf([
            parseChildMailboxFlag_children,
            parseChildMailboxFlag_noChildren,
        ], buffer: &buffer, tracker: tracker)
    }

    // command         = tag SP (command-any / command-auth / command-nonauth /
    //                   command-select) CRLF
    static func parseCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedCommand {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let type = try ParserLibrary.parseOneOf([
                self.parseCommandAny,
                self.parseCommandAuth,
                self.parseCommandNonauth,
                self.parseCommandSelect,
            ], buffer: &buffer, tracker: tracker)
            return TaggedCommand(tag: tag, command: type)
        }
    }

    // command-any     = "CAPABILITY" / "LOGOUT" / "NOOP" / enable / x-command / id
    static func parseCommandAny(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseCommandAny_capability(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("CAPABILITY", buffer: &buffer, tracker: tracker)
            return .capability
        }

        func parseCommandAny_logout(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("LOGOUT", buffer: &buffer, tracker: tracker)
            return .logout
        }

        func parseCommandAny_noop(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("NOOP", buffer: &buffer, tracker: tracker)
            return .noop
        }

        func parseCommandAny_id(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            let id = try self.parseID(buffer: &buffer, tracker: tracker)
            return .id(id)
        }

        func parseCommandAny_enable(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            let enable = try self.parseEnable(buffer: &buffer, tracker: tracker)
            return enable
        }

        return try ParserLibrary.parseOneOf([
            parseCommandAny_noop,
            parseCommandAny_logout,
            parseCommandAny_capability,
            parseCommandAny_id,
            parseCommandAny_enable,
        ], buffer: &buffer, tracker: tracker)
    }

    // command-auth    = append / create / delete / examine / list / lsub /
    //                   Namespace-Command /
    //                   rename / select / status / subscribe / unsubscribe /
    //                   idle
    static func parseCommandAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseOneOf([
            self.parseCreate,
            self.parseDelete,
            self.parseExamine,
            self.parseList,
            self.parseLSUB,
            self.parseRename,
            self.parseSelect,
            self.parseStatus,
            self.parseSubscribe,
            self.parseUnsubscribe,
            self.parseIdleStart,
            self.parseNamespaceCommand,
        ], buffer: &buffer, tracker: tracker)
    }

    // command-nonauth = login / authenticate / "STARTTLS"
    static func parseCommandNonauth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseCommandNonauth_starttls(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("STARTTLS", buffer: &buffer, tracker: tracker)
            return .starttls
        }

        return try ParserLibrary.parseOneOf([
            self.parseLogin,
            self.parseAuthenticate,
            parseCommandNonauth_starttls,
        ], buffer: &buffer, tracker: tracker)
    }

    // command-select  = "CHECK" / "CLOSE" / "UNSELECT" / "EXPUNGE" / copy / fetch / store /
    //                   uid / search / move
    static func parseCommandSelect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseCommandSelect_check(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("CHECK", buffer: &buffer, tracker: tracker)
            return .check
        }

        func parseCommandSelect_close(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("CLOSE", buffer: &buffer, tracker: tracker)
            return .close
        }

        func parseCommandSelect_expunge(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("EXPUNGE", buffer: &buffer, tracker: tracker)
            return .expunge
        }

        func parseCommandSelect_unselect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("UNSELECT", buffer: &buffer, tracker: tracker)
            return .unselect
        }

        return try ParserLibrary.parseOneOf([
            parseCommandSelect_check,
            parseCommandSelect_close,
            parseCommandSelect_expunge,
            parseCommandSelect_unselect,
            self.parseCopy,
            self.parseFetch,
            self.parseStore,
            self.parseUid,
            self.parseSearch,
            self.parseMove,
        ], buffer: &buffer, tracker: tracker)
    }

    // condstore-param = "CONDSTORE"
    static func parseConditionalStoreParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseFixedString("CONDSTORE", buffer: &buffer, tracker: tracker)
    }

    // continue-req    = "+" SP (resp-text / base64) CRLF
    static func parseContinueRequest(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ContinueRequest {
        func parseContinueReq_responseText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ContinueRequest {
            .responseText(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseContinueReq_base64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ContinueRequest {
            .base64(try self.parseBase64(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ContinueRequest in
            try ParserLibrary.parseFixedString("+", buffer: &buffer, tracker: tracker)
            // Allow no space and no additional text after "+":
            let continueReq: ContinueRequest
            if try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: ParserLibrary.parseSpace(buffer:tracker:)) != nil {
                continueReq = try ParserLibrary.parseOneOf([
                    parseContinueReq_base64,
                    parseContinueReq_responseText,
                ], buffer: &buffer, tracker: tracker)
            } else {
                continueReq = .responseText(ResponseText(code: nil, text: ""))
            }
            try ParserLibrary.parseNewline(buffer: &buffer, tracker: tracker)
            return continueReq
        }
    }

    // copy            = "COPY" SP sequence-set SP mailbox
    static func parseCopy(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("COPY ", buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .copy(sequence, mailbox)
        }
    }

    // create          = "CREATE" SP mailbox [create-params]
    static func parseCreate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("CREATE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
            return .create(mailbox, params)
        }
    }

    // create-param = create-param-name [SP create-param-value]
    static func parseParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Parameter {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            let value = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ParameterValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .init(name: name, value: value)
        }
    }

    // date            = date-text / DQUOTE date-text DQUOTE
    static func parseDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date {
        func parseDateText_quoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date {
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
                let date = try self.parseDateText(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
                return date
            }
        }

        return try ParserLibrary.parseOneOf([
            parseDateText,
            parseDateText_quoted,
        ], buffer: &buffer, tracker: tracker)
    }

    // date-day        = 1*2DIGIT
    static func parseDateDay(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        let (num, size) = try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker)
        guard size <= 2 else {
            throw ParserError(hint: "Expected 1 or 2 bytes, got \(size)")
        }
        return num
    }

    // date-day-fixed  = (SP DIGIT) / 2DIGIT
    static func parseDateDayFixed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        func parseDateDayFixed_spaced(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            return try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 1)
        }

        return try ParserLibrary.parseOneOf([
            parseDateDayFixed_spaced,
            parse2Digit,
        ], buffer: &buffer, tracker: tracker)
    }

    // date-month      = "Jan" / "Feb" / "Mar" / "Apr" / "May" / "Jun" /
    //                   "Jul" / "Aug" / "Sep" / "Oct" / "Nov" / "Dec"
    static func parseDateMonth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            isalnum(Int32(char)) != 0
        }
        guard let month = Date.month(text: string.lowercased()) else {
            throw ParserError(hint: "No month match for \(string)")
        }
        return month
    }

    // date-text       = date-day "-" date-month "-" date-year
    static func parseDateText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let day = try self.parseDateDay(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let month = try self.parseDateMonth(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let year = try self.parse4Digit(buffer: &buffer, tracker: tracker)
            guard let date = Date(year: year, month: month, day: day) else {
                throw ParserError(hint: "Invalid date components \(year) \(month) \(day)")
            }
            return date
        }
    }

    // date-time       = DQUOTE date-day-fixed "-" date-month "-" date-year
    //                   SP time SP zone DQUOTE
    static func parseInternalDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> InternalDate {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            let day = try self.parseDateDayFixed(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let month = try self.parseDateMonth(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let year = try self.parse4Digit(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)

            // time            = 2DIGIT ":" 2DIGIT ":" 2DIGIT
            let hour = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(":", buffer: &buffer, tracker: tracker)
            let minute = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(":", buffer: &buffer, tracker: tracker)
            let second = try self.parse2Digit(buffer: &buffer, tracker: tracker)

            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)

            func splitZoneMinutes(_ raw: Int) -> Int? {
                guard raw >= 0 else { return nil }
                let minutes = raw % 100
                let hours = (raw - minutes) / 100
                guard minutes <= 60, hour <= 24 else { return nil }
                return hours * 60 + minutes
            }

            // zone            = ("+" / "-") 4DIGIT
            func parseZonePositive(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
                try ParserLibrary.parseFixedString("+", buffer: &buffer, tracker: tracker)
                let num = try self.parse4Digit(buffer: &buffer, tracker: tracker)
                guard let zone = splitZoneMinutes(num) else {
                    throw ParserError(hint: "Building TimeZone from \(num) failed")
                }
                return zone
            }

            func parseZoneNegative(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
                try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
                let num = try self.parse4Digit(buffer: &buffer, tracker: tracker)
                guard let zone = splitZoneMinutes(num) else {
                    throw ParserError(hint: "Building TimeZone from \(num) failed")
                }
                return -zone
            }

            let zone = try ParserLibrary.parseOneOf([
                parseZonePositive,
                parseZoneNegative,
            ], buffer: &buffer, tracker: tracker)

            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            guard let d = InternalDate(year: year, month: month, day: day, hour: hour, minute: minute, second: second, zoneMinutes: zone) else {
                throw ParserError(hint: "Invalid internal date.")
            }
            return d
        }
    }

    // delete          = "DELETE" SP mailbox
    static func parseDelete(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("DELETE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .delete(mailbox)
        }
    }

    // eitem-vendor-tag =  vendor-token "-" atom
    static func parseEitemVendorTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EItemVendorTag {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EItemVendorTag in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return EItemVendorTag(token: token, atom: atom)
        }
    }

    // enable          = "ENABLE" 1*(SP capability)
    static func parseEnable(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("ENABLE", buffer: &buffer, tracker: tracker)
            let capabilities = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Capability in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
            return .enable(capabilities)
        }
    }

    // enable-data     = "ENABLED" *(SP capability)
    static func parseEnableData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Capability] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Capability] in
            try ParserLibrary.parseFixedString("ENABLED", buffer: &buffer, tracker: tracker)
            return try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Capability in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }
    }

    // envelope        = "(" env-date SP env-subject SP env-from SP
    //                   env-sender SP env-reply-to SP env-to SP env-cc SP
    //                   env-bcc SP env-in-reply-to SP env-message-id ")"
    static func parseEnvelope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Envelope {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Envelope in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let date = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { String(buffer: $0) }
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let subject = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let from = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let sender = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let replyTo = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let to = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let cc = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let bcc = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let inReplyTo = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let messageID = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { String(buffer: $0) }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return Envelope(
                date: date,
                subject: subject,
                from: from,
                sender: sender,
                reply: replyTo,
                to: to,
                cc: cc,
                bcc: bcc,
                inReplyTo: inReplyTo,
                messageID: messageID
            )
        }
    }

    // entry-type-req = entry-type-resp / all
    static func parseEntryKindRequest(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindRequest {
        func parseEntryKindRequest_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindRequest {
            try ParserLibrary.parseFixedString("all", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseEntryKindRequest_response(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindRequest {
            .response(try self.parseEntryKindResponse(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseEntryKindRequest_all,
            parseEntryKindRequest_response,
        ], buffer: &buffer, tracker: tracker)
    }

    // entry-type-resp = "priv" / "shared"
    static func parseEntryKindResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindResponse {
        func parseEntryKindResponse_private(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindResponse {
            try ParserLibrary.parseFixedString("priv", buffer: &buffer, tracker: tracker)
            return .private
        }

        func parseEntryKindResponse_shared(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindResponse {
            try ParserLibrary.parseFixedString("shared", buffer: &buffer, tracker: tracker)
            return .shared
        }

        return try ParserLibrary.parseOneOf([
            parseEntryKindResponse_private,
            parseEntryKindResponse_shared,
        ], buffer: &buffer, tracker: tracker)
    }

    // esearch-response  = "ESEARCH" [search-correlator] [SP "UID"]
    //                     *(SP search-return-data)
    static func parseEsearchResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ESearchResponse {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("ESEARCH", buffer: &buffer, tracker: tracker)
            let correlator = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSearchCorrelator)
            let uid = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString(" UID", buffer: &buffer, tracker: tracker)
                return true
            } ?? false
            let searchReturnData = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SearchReturnData in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSearchReturnData(buffer: &buffer, tracker: tracker)
            }
            return ESearchResponse(correlator: correlator, uid: uid, returnData: searchReturnData)
        }
    }

    // examine         = "EXAMINE" SP mailbox [select-params
    static func parseExamine(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("EXAMINE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
            return .examine(mailbox, params)
        }
    }

    // fetch           = "FETCH" SP sequence-set SP ("ALL" / "FULL" / "FAST" /
    //                   fetch-att / "(" fetch-att *(SP fetch-att) ")") [fetch-modifiers]
    static func parseFetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("FETCH ", buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let att = try parseFetch_type(buffer: &buffer, tracker: tracker)
            let modifiers = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
            return .fetch(sequence, att, modifiers)
        }
    }

    fileprivate static func parseFetch_type(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
        func parseFetch_type_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try ParserLibrary.parseFixedString("ALL", buffer: &buffer, tracker: tracker)
            return [.flags, .internalDate, .rfc822Size, .envelope]
        }

        func parseFetch_type_fast(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try ParserLibrary.parseFixedString("FAST", buffer: &buffer, tracker: tracker)
            return [.flags, .internalDate, .rfc822Size]
        }

        func parseFetch_type_full(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try ParserLibrary.parseFixedString("FULL", buffer: &buffer, tracker: tracker)
            return [.flags, .internalDate, .rfc822Size, .envelope, .bodyStructure(extensions: false)]
        }

        func parseFetch_type_singleAtt(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            [try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)]
        }

        func parseFetch_type_multiAtt(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> FetchAttribute in
                try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
                return try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try ParserLibrary.parseOneOf([
            parseFetch_type_all,
            parseFetch_type_full,
            parseFetch_type_fast,
            parseFetch_type_singleAtt,
            parseFetch_type_multiAtt,
        ], buffer: &buffer, tracker: tracker)
    }

    // fetch-att       = "ENVELOPE" / "FLAGS" / "INTERNALDATE" /
    //                   "RFC822.SIZE" /
    //                   "BODY" ["STRUCTURE"] / "UID" /
    //                   "BODY" section [partial] /
    //                   "BODY.PEEK" section [partial] /
    //                   "BINARY" [".PEEK"] section-binary [partial] /
    //                   "BINARY.SIZE" section-binary
    // TODO: rev2
    static func parseFetchAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
        func parseFetchAttribute_envelope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("ENVELOPE", buffer: &buffer, tracker: tracker)
            return .envelope
        }

        func parseFetchAttribute_flags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("FLAGS", buffer: &buffer, tracker: tracker)
            return .flags
        }

        func parseFetchAttribute_internalDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("INTERNALDATE", buffer: &buffer, tracker: tracker)
            return .internalDate
        }

        func parseFetchAttribute_UID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("UID", buffer: &buffer, tracker: tracker)
            return .uid
        }

        func parseFetchAttribute_rfc822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            func parseFetchAttribute_rfc822Size(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
                try ParserLibrary.parseFixedString("RFC822.SIZE", buffer: &buffer, tracker: tracker)
                return .rfc822Size
            }

            func parseFetchAttribute_rfc822Header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
                try ParserLibrary.parseFixedString("RFC822.HEADER", buffer: &buffer, tracker: tracker)
                return .rfc822Header
            }

            func parseFetchAttribute_rfc822Text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
                try ParserLibrary.parseFixedString("RFC822.TEXT", buffer: &buffer, tracker: tracker)
                return .rfc822Text
            }

            func parseFetchAttribute_rfc822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
                try ParserLibrary.parseFixedString("RFC822", buffer: &buffer, tracker: tracker)
                return .rfc822
            }

            return try ParserLibrary.parseOneOf([
                parseFetchAttribute_rfc822Size,
                parseFetchAttribute_rfc822Header,
                parseFetchAttribute_rfc822Text,
                parseFetchAttribute_rfc822,
            ], buffer: &buffer, tracker: tracker)
        }

        func parseFetchAttribute_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("BODY", buffer: &buffer, tracker: tracker)
            let extensions: Bool = {
                do {
                    try ParserLibrary.parseFixedString("STRUCTURE", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    return false
                }
            }()
            return .bodyStructure(extensions: extensions)
        }

        func parseFetchAttribute_bodySection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("BODY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let chevronNumber = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ClosedRange<Int> in
                try self.parsePartial(buffer: &buffer, tracker: tracker)
            }
            return .bodySection(peek: false, section, chevronNumber)
        }

        func parseFetchAttribute_bodyPeekSection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("BODY.PEEK", buffer: &buffer, tracker: tracker)
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let chevronNumber = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ClosedRange<Int> in
                try self.parsePartial(buffer: &buffer, tracker: tracker)
            }
            return .bodySection(peek: true, section, chevronNumber)
        }

        func parseFetchAttribute_modSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            .modifierSequenceValue(try self.parseModifierSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseFetchAttribute_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            func parsePeek(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Bool {
                let save = buffer
                do {
                    try ParserLibrary.parseFixedString(".PEEK", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    buffer = save
                    return false
                }
            }

            try ParserLibrary.parseFixedString("BINARY", buffer: &buffer, tracker: tracker)
            let peek = try parsePeek(buffer: &buffer, tracker: tracker)
            let sectionBinary = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            let partial = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parsePartial)
            return .binary(peek: peek, section: sectionBinary, partial: partial)
        }

        func parseFetchAttribute_binarySize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("BINARY.SIZE", buffer: &buffer, tracker: tracker)
            let sectionBinary = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            return .binarySize(section: sectionBinary)
        }

        return try ParserLibrary.parseOneOf([
            parseFetchAttribute_envelope,
            parseFetchAttribute_flags,
            parseFetchAttribute_internalDate,
            parseFetchAttribute_UID,
            parseFetchAttribute_rfc822,
            parseFetchAttribute_bodySection,
            parseFetchAttribute_bodyPeekSection,
            parseFetchAttribute_body,
            parseFetchAttribute_modSequence,
            parseFetchAttribute_binary,
            parseFetchAttribute_binarySize,
        ], buffer: &buffer, tracker: tracker)
    }

    // filter-name = 1*<any ATOM-CHAR except "/">
    static func parseFilterName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAtomChar && char != UInt8(ascii: "/")
        }
    }

    // flag            = "\Answered" / "\Flagged" / "\Deleted" /
    //                   "\Seen" / "\Draft" / flag-keyword / flag-extension
    static func parseFlag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
        func parseFlag_answered(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try ParserLibrary.parseFixedString("\\Answered", buffer: &buffer, tracker: tracker)
            return .answered
        }

        func parseFlag_flagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try ParserLibrary.parseFixedString("\\Flagged", buffer: &buffer, tracker: tracker)
            return .flagged
        }

        func parseFlag_deleted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try ParserLibrary.parseFixedString("\\Deleted", buffer: &buffer, tracker: tracker)
            return .deleted
        }

        func parseFlag_seen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try ParserLibrary.parseFixedString("\\Seen", buffer: &buffer, tracker: tracker)
            return .seen
        }

        func parseFlag_draft(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try ParserLibrary.parseFixedString("\\Draft", buffer: &buffer, tracker: tracker)
            return .draft
        }

        func parseFlag_keyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            let word = try self.parseFlagKeyword(buffer: &buffer, tracker: tracker)
            return .keyword(word)
        }

        func parseFlag_extension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            let word = try self.parseFlagExtension(buffer: &buffer, tracker: tracker)
            return .extension(word)
        }

        return try ParserLibrary.parseOneOf([
            parseFlag_seen,
            parseFlag_draft,
            parseFlag_answered,
            parseFlag_flagged,
            parseFlag_deleted,
            parseFlag_keyword,
            parseFlag_extension,
        ], buffer: &buffer, tracker: tracker)
    }

    // flag-extension  = "\" atom
    static func parseFlagExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in
            try ParserLibrary.parseFixedString("\\", buffer: &buffer, tracker: tracker)
            let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return "\\\(string)"
        }
    }

    // flag-keyword    = "$MDNSent" / "$Forwarded" / atom
    static func parseFlagKeyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag.Keyword {
        let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
        return Flag.Keyword(string)
    }

    // flag-list       = "(" [flag *(SP flag)] ")"
    static func parseFlagList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Flag] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let flags = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, _) -> [Flag] in
                var output = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                    try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                return output
            } ?? []
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return flags
        }
    }

    // flag-perm       = flag / "\*"
    static func parseFlagPerm(buffer: inout ByteBuffer, tracker: StackTracker) throws -> PermanentFlag {
        func parseFlagPerm_wildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> PermanentFlag {
            try ParserLibrary.parseFixedString("\\*", buffer: &buffer, tracker: tracker)
            return .wildcard
        }

        func parseFlagPerm_flag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> PermanentFlag {
            .flag(try self.parseFlag(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseFlagPerm_wildcard,
            parseFlagPerm_flag,
        ], buffer: &buffer, tracker: tracker)
    }

    // greeting        = "*" SP (resp-cond-auth / resp-cond-bye) CRLF
    static func parseGreeting(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Greeting {
        func parseGreeting_auth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Greeting {
            .auth(try self.parseResponseConditionalAuth(buffer: &buffer, tracker: tracker))
        }

        func parseGreeting_bye(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Greeting {
            .bye(try self.parseResponseConditionalBye(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Greeting in
            try ParserLibrary.parseFixedString("* ", buffer: &buffer, tracker: tracker)
            let greeting = try ParserLibrary.parseOneOf([
                parseGreeting_auth,
                parseGreeting_bye,
            ], buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseNewline(buffer: &buffer, tracker: tracker)
            return greeting
        }
    }

    // header-fld-name = astring
    static func parseHeaderFieldName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        var buffer = try self.parseAString(buffer: &buffer, tracker: tracker)
        return buffer.readString(length: buffer.readableBytes)!
    }

    // header-list     = "(" header-fld-name *(SP header-fld-name) ")"
    static func parseHeaderList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [String] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [String] in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var output = [try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> String in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return output
        }
    }

    // id = "ID" SP id-params-list
    static func parseID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [IDParameter] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("ID ", buffer: &buffer, tracker: tracker)
            return try parseIDParamsList(buffer: &buffer, tracker: tracker)
        }
    }

    // id-response = "ID" SP id-params-list
    static func parseIDResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [IDParameter] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("ID ", buffer: &buffer, tracker: tracker)
            return try parseIDParamsList(buffer: &buffer, tracker: tracker)
        }
    }

    // id-params-list = "(" *(string SP nstring) ")" / nil
    static func parseIDParamsList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [IDParameter] {
        func parseIDParamsList_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [IDParameter] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }

        func parseIDParamsList_element(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IDParameter {
            let key = String(buffer: try self.parseString(buffer: &buffer, tracker: tracker))
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let value = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .init(key: key, value: value)
        }

        func parseIDParamsList_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [IDParameter] {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try parseIDParamsList_element(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> IDParameter in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try parseIDParamsList_element(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try ParserLibrary.parseOneOf([
            parseIDParamsList_nil,
            parseIDParamsList_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // idle            = "IDLE" CRLF "DONE"
    static func parseIdleStart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseFixedString("IDLE", buffer: &buffer, tracker: tracker)
        return .idleStart
    }

    static func parseIdleDone(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseFixedString("DONE", buffer: &buffer, tracker: tracker)
        try ParserLibrary.parseNewline(buffer: &buffer, tracker: tracker)
    }

    // list            = "LIST" [SP list-select-opts] SP mailbox SP mbox-or-pat [SP list-return-opts]
    static func parseList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("LIST", buffer: &buffer, tracker: tracker)
            let selectOptions = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ListSelectOptions in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectOptions(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let mailboxPatterns = try self.parseMailboxPatterns(buffer: &buffer, tracker: tracker)
            let returnOptions = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [ReturnOption] in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseListReturnOptions(buffer: &buffer, tracker: tracker)
            } ?? []
            return .list(selectOptions, reference: mailbox, mailboxPatterns, returnOptions)
        }
    }

    // list-select-base-opt =  "SUBSCRIBED" / option-extension
    static func parseListSelectBaseOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
        func parseListSelectBaseOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
            try ParserLibrary.parseFixedString("SUBSCRIBED", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseListSelectBaseOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseListSelectBaseOption_subscribed,
            parseListSelectBaseOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-base-opt-quoted =  DQUOTE list-select-base-opt DQUOTE
    static func parseListSelectBaseOptionQuoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ListSelectBaseOption in
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            let option = try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return option
        }
    }

    // list-select-independent-opt =  "REMOTE" / option-extension
    static func parseListSelectIndependentOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectIndependentOption {
        func parseListSelectIndependentOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectIndependentOption {
            try ParserLibrary.parseFixedString("REMOTE", buffer: &buffer, tracker: tracker)
            return .remote
        }

        func parseListSelectIndependentOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectIndependentOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseListSelectIndependentOption_subscribed,
            parseListSelectIndependentOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-mod-opt =  "RECURSIVEMATCH" / option-extension
    static func parseListSelectModOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectModOption {
        func parseListSelectModOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectModOption {
            try ParserLibrary.parseFixedString("RECURSIVEMATCH", buffer: &buffer, tracker: tracker)
            return .recursiveMatch
        }

        func parseListSelectModOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectModOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseListSelectModOption_subscribed,
            parseListSelectModOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-opt =  list-select-base-opt / list-select-independent-opt
    //                    / list-select-mod-opt
    static func parseListSelectOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOption {
        func parseListSelectOption_base(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOption {
            .base(try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker))
        }

        func parseListSelectOption_independent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOption {
            .independent(try self.parseListSelectIndependentOption(buffer: &buffer, tracker: tracker))
        }

        func parseListSelectOption_mod(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOption {
            .mod(try self.parseListSelectModOption(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseListSelectOption_base,
            parseListSelectOption_independent,
            parseListSelectOption_mod,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-opts =  "(" [
    //                    (*(list-select-opt SP) list-select-base-opt
    //                    *(SP list-select-opt))
    //                   / (list-select-independent-opt
    //                    *(SP list-select-independent-opt))
    //                      ] ")"
    static func parseListSelectOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOptions {
        func parseListSelectOptions_mixed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectionOptionsData {
            var selectOptions = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ListSelectOption in
                let option = try self.parseListSelectOption(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return option
            }
            let baseOption = try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &selectOptions, tracker: tracker) { (buffer, tracker) -> ListSelectOption in
                let option = try self.parseListSelectOption(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return option
            }

            return .select(selectOptions, baseOption)
        }

        func parseListSelectOptions_independent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectionOptionsData {
            var array = [try self.parseListSelectIndependentOption(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectIndependentOption(buffer: &buffer, tracker: tracker)
            }
            return .selectIndependent(array)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let options = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseOneOf([
                    parseListSelectOptions_mixed,
                    parseListSelectOptions_independent,
                ], buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return options
        }
    }

    static func parseLiteralSize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Int in
            try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString("~", buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("}", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseNewline(buffer: &buffer, tracker: tracker)
            return length
        }
    }

    // mbox-or-pat  = list-mailbox / patterns
    static func parseMailboxPatterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
        func parseMailboxPatterns_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
            .mailbox(try self.parseListMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxPatterns_patterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
            .pattern(try self.parsePatterns(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseMailboxPatterns_list,
            parseMailboxPatterns_patterns,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-return-opt = "RETURN" SP "(" [return-option *(SP return-option)] ")"
    static func parseListReturnOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ReturnOption] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("RETURN (", buffer: &buffer, tracker: tracker)
            let options = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [ReturnOption] in
                var array = [try self.parseReturnOption(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ReturnOption in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseReturnOption(buffer: &buffer, tracker: tracker)
                }
                return array
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return options ?? []
        }
    }

    // list-mailbox    = 1*list-char / string
    static func parseListMailbox(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        func parseListMailbox_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try self.parseString(buffer: &buffer, tracker: tracker)
        }

        func parseListMailbox_chars(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try ParserLibrary.parseOneOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isListChar
            }
        }

        return try ParserLibrary.parseOneOf([
            parseListMailbox_string,
            parseListMailbox_chars,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-wildcards  = "%" / "*"
    static func parseListWildcards(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        guard let char = buffer.readInteger(as: UInt8.self) else {
            throw _IncompleteMessage()
        }
        guard char.isListWildcard else {
            throw ParserError()
        }
        return String(decoding: CollectionOfOne(char), as: Unicode.UTF8.self)
    }

    // literal         = "{" number ["+"] "}" CRLF *CHAR8
    static func parseLiteral(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try ParserLibrary.parseFixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString("+", buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString("}", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseNewline(buffer: &buffer, tracker: tracker)
            if let bytes = buffer.readSlice(length: length) {
                if bytes.readableBytesView.contains(0) {
                    throw ParserError(hint: "Found NUL byte in literal")
                }
                return bytes
            } else {
                throw _IncompleteMessage()
            }
        }
    }

    // login           = "LOGIN" SP userid SP password
    static func parseLogin(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("LOGIN ", buffer: &buffer, tracker: tracker)
            let userid = try Self.parseUserId(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let password = try Self.parsePassword(buffer: &buffer, tracker: tracker)
            return .login(username: userid, password: password)
        }
    }

    // lsub = "LSUB" SP mailbox SP list-mailbox
    static func parseLSUB(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Command in
            try ParserLibrary.parseFixedString("LSUB ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let listMailbox = try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            return .lsub(reference: mailbox, pattern: listMailbox)
        }
    }

    // mailbox         = "INBOX" / astring
    static func parseMailbox(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName {
        let string = try self.parseAString(buffer: &buffer, tracker: tracker)
        return MailboxName(string)
    }

    // mailbox-data    =  "FLAGS" SP flag-list / "LIST" SP mailbox-list /
    //                    esearch-response /
    //                    "STATUS" SP mailbox SP "(" [status-att-list] ")" /
    //                    number SP "EXISTS" / Namespace-Response
    static func parseMailboxData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
        func parseMailboxData_flags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try ParserLibrary.parseFixedString("FLAGS ", buffer: &buffer, tracker: tracker)
            return .flags(try self.parseFlagList(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxData_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try ParserLibrary.parseFixedString("LIST ", buffer: &buffer, tracker: tracker)
            return .list(try self.parseMailboxList(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxData_lsub(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try ParserLibrary.parseFixedString("LSUB ", buffer: &buffer, tracker: tracker)
            return .lsub(try self.parseMailboxList(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxData_esearch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            let response = try self.parseEsearchResponse(buffer: &buffer, tracker: tracker)
            return .esearch(response)
        }

        func parseMailboxData_search(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try ParserLibrary.parseFixedString("SEARCH", buffer: &buffer, tracker: tracker)
            let nums = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            }
            return .search(nums)
        }

        func parseMailboxData_status(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try ParserLibrary.parseFixedString("STATUS ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let status = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseMailboxStatus)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .status(mailbox, status ?? .init())
        }

        func parseMailboxData_exists(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" EXISTS", buffer: &buffer, tracker: tracker)
            return .exists(number)
        }

        func parseMailboxData_recent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" RECENT", buffer: &buffer, tracker: tracker)
            return .recent(number)
        }

        func parseMailboxData_namespace(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            .namespace(try self.parseNamespaceResponse(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseMailboxData_flags,
            parseMailboxData_list,
            parseMailboxData_lsub,
            parseMailboxData_esearch,
            parseMailboxData_status,
            parseMailboxData_exists,
            parseMailboxData_recent,
            parseMailboxData_search,
            parseMailboxData_namespace,
        ], buffer: &buffer, tracker: tracker)
    }

    // mailbox-list    = "(" [mbx-list-flags] ")" SP
    //                    (DQUOTE QUOTED-CHAR DQUOTE / nil) SP mailbox
    //                    [SP mbox-list-extended]
    static func parseMailboxList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxInfo {
        func parseMailboxList_quotedChar_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Character? in
                try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)

                guard let character = buffer.readSlice(length: 1)?.readableBytesView.first else {
                    throw _IncompleteMessage()
                }
                guard character.isQuotedChar else {
                    throw ParserError(hint: "Expected quoted char found \(String(decoding: [character], as: Unicode.UTF8.self))")
                }

                try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
                return Character(UnicodeScalar(character))
            }
        }

        func parseMailboxList_quotedChar_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MailboxInfo in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let flags = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseMailboxListFlags) ?? []
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let character = try ParserLibrary.parseOneOf([
                parseMailboxList_quotedChar_some,
                parseMailboxList_quotedChar_nil,
            ], buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let listExtended = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: { (buffer, tracker) -> [ListExtendedItem] in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseMailboxListExtended(buffer: &buffer, tracker: tracker)
            }) ?? []
            return MailboxInfo(attributes: flags, pathSeparator: character, mailbox: mailbox, extensions: listExtended)
        }
    }

    // mbox-list-extended =  "(" [mbox-list-extended-item
    //                       *(SP mbox-list-extended-item)] ")"
    static func parseMailboxListExtended(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ListExtendedItem] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ListExtendedItem] in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let data = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [ListExtendedItem] in
                var array = [try self.parseMailboxListExtendedItem(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ListExtendedItem in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseMailboxListExtendedItem(buffer: &buffer, tracker: tracker)
                }
                return array
            } ?? []
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return data
        }
    }

    // mbox-list-extended-item =  mbox-list-extended-item-tag SP
    //                            tagged-ext-val
    static func parseMailboxListExtendedItem(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListExtendedItem {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ListExtendedItem in
            let tag = try self.parseAString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let val = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return ListExtendedItem(tag: tag, extensionValue: val)
        }
    }

    // mbox-or-pat =  list-mailbox / patterns
    static func parseMailboxOrPat(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
        func parseMailboxOrPat_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
            .mailbox(try self.parseListMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxOrPat_patterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
            .pattern(try self.parsePatterns(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseMailboxOrPat_list,
            parseMailboxOrPat_patterns,
        ], buffer: &buffer, tracker: tracker)
    }

    // mbx-list-flags  = *(mbx-list-oflag SP) mbx-list-sflag
    //                   *(SP mbx-list-oflag) /
    //                   mbx-list-oflag *(SP mbx-list-oflag)
    static func parseMailboxListFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [MailboxInfo.Attribute] {
        var results = [MailboxInfo.Attribute(try self.parseFlagExtension(buffer: &buffer, tracker: tracker))]
        do {
            while true {
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                let att = try self.parseFlagExtension(buffer: &buffer, tracker: tracker)
                results.append(.init(att))
            }
        } catch {
            // do nothing
        }
        return results
    }

    // media-basic     = ((DQUOTE ("APPLICATION" / "AUDIO" / "IMAGE" /
    //                   "MESSAGE" / "VIDEO") DQUOTE) / string) SP
    //                   media-subtype
    static func parseMediaBasic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Basic {
        func parseMediaBasic_Kind_defined(_ option: String, result: Media.BasicKind, buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(option, buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return result
        }

        func parseMediaBasic_Kind_application(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("APPLICATION", result: .application, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_audio(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("AUDIO", result: .audio, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_image(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("IMAGE", result: .image, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_message(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("MESSAGE", result: .message, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_video(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("VIDEO", result: .video, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            let buffer = try self.parseString(buffer: &buffer, tracker: tracker)
            return .other(String(buffer: buffer))
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Media.Basic in
            let basicType = try ParserLibrary.parseOneOf([
                parseMediaBasic_Kind_application,
                parseMediaBasic_Kind_audio,
                parseMediaBasic_Kind_image,
                parseMediaBasic_Kind_message,
                parseMediaBasic_Kind_video,
                parseMediaBasic_Kind_other,
            ], buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let subtype = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            return Media.Basic(kind: basicType, subtype: subtype)
        }
    }

    // media-message   = DQUOTE "MESSAGE" DQUOTE SP
    //                   DQUOTE ("RFC822" / "GLOBAL") DQUOTE
    static func parseMediaMessage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Message {
        func parseMediaMessage_rfc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Message {
            try ParserLibrary.parseFixedString("RFC822", buffer: &buffer, tracker: tracker)
            return .rfc822
        }

        func parseMediaMessage_global(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Message {
            try ParserLibrary.parseFixedString("GLOBAL", buffer: &buffer, tracker: tracker)
            return .global
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Media.Message in
            try ParserLibrary.parseFixedString("\"MESSAGE\" \"", buffer: &buffer, tracker: tracker)
            let message = try ParserLibrary.parseOneOf([
                parseMediaMessage_rfc,
                parseMediaMessage_global,
            ], buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return message
        }
    }

    // media-subtype   = string
    static func parseMediaSubtype(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.MediaSubtype {
        let buffer = try self.parseString(buffer: &buffer, tracker: tracker)
        let string = String(buffer: buffer)
        return .init(string)
    }

    // media-text      = DQUOTE "TEXT" DQUOTE SP media-subtype
    static func parseMediaText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in
            try ParserLibrary.parseFixedString("\"TEXT\" ", buffer: &buffer, tracker: tracker)
            let subtype = try self.parseString(buffer: &buffer, tracker: tracker)
            return String(buffer: subtype)
        }
    }

    // message-data    = nz-number SP ("EXPUNGE" / ("FETCH" SP msg-att))
    static func parseMessageData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageData {
        func parseMessageData_expunge(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageData {
            let number = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" EXPUNGE", buffer: &buffer, tracker: tracker)
            return .expunge(number)
        }

        return try ParserLibrary.parseOneOf([
            parseMessageData_expunge,
        ], buffer: &buffer, tracker: tracker)
    }

    // mod-sequence-valzer = "0" / mod-sequence-value
    static func parseModifierSequenceValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ModifierSequenceValue {
        let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
        guard let value = ModifierSequenceValue(number) else {
            throw ParserError(hint: "Unable to create ModifiersSequenceValueZero")
        }
        return value
    }

    // move            = "MOVE" SP sequence-set SP mailbox
    static func parseMove(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("MOVE ", buffer: &buffer, tracker: tracker)
            let set = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .move(set, mailbox)
        }
    }

    static func parseFetchStreamingResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StreamingKind {
        func parseFetchStreamingResponse_rfc822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StreamingKind {
            try ParserLibrary.parseFixedString("RFC822.TEXT", buffer: &buffer, tracker: tracker)
            return .rfc822
        }

        func parseFetchStreamingResponse_bodySectionText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StreamingKind {
            try ParserLibrary.parseFixedString("BODY[TEXT]", buffer: &buffer, tracker: tracker)
            let number = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try ParserLibrary.parseFixedString("<", buffer: &buffer, tracker: tracker)
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString(">", buffer: &buffer, tracker: tracker)
                return num
            }
            return .body(partial: number)
        }

        func parseFetchStreamingResponse_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StreamingKind {
            try ParserLibrary.parseFixedString("BINARY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            return .binary(section: section)
        }

        return try ParserLibrary.parseOneOf([
            parseFetchStreamingResponse_rfc822,
            parseFetchStreamingResponse_bodySectionText,
            parseFetchStreamingResponse_binary,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseFetchResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
        func parseFetchResponse_start(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
            try ParserLibrary.parseFixedString("* ", buffer: &buffer, tracker: tracker)
            let number = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" FETCH (", buffer: &buffer, tracker: tracker)
            return .start(number)
        }

        func parseFetchResponse_simpleAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
            let attribute = try self.parseMessageAttribute(buffer: &buffer, tracker: tracker)
            return .simpleAttribute(attribute)
        }

        func parseFetchResponse_streamingBegin(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
            let type = try self.parseFetchStreamingResponse(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let literalSize = try self.parseLiteralSize(buffer: &buffer, tracker: tracker)
            return .streamingBegin(kind: type, byteCount: literalSize)
        }

        func parseFetchResponse_finish(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseNewline(buffer: &buffer, tracker: tracker)
            return .finish
        }

        return try ParserLibrary.parseOneOf([
            parseFetchResponse_start,
            parseFetchResponse_streamingBegin,
            parseFetchResponse_simpleAttribute,
            parseFetchResponse_finish,
        ], buffer: &buffer, tracker: tracker)
    }

    // msg-att-static  = "ENVELOPE" SP envelope / "INTERNALDATE" SP date-time /
    //                   "RFC822.SIZE" SP number /
    //                   "BODY" ["STRUCTURE"] SP body /
    //                   "BODY" section ["<" number ">"] SP nstring /
    //                   "BINARY" section-binary SP (nstring / literal8) /
    //                   "BINARY.SIZE" section-binary SP number /
    //                   "UID" SP uniqueid
    // msg-att-dynamic = "FLAGS" SP "(" [flag-fetch *(SP flag-fetch)] ")"
    // ---- This function combines static and dynamic
    static func parseMessageAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
        func parseMessageAttribute_flags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MessageAttribute in
                try ParserLibrary.parseFixedString("FLAGS (", buffer: &buffer, tracker: tracker)
                var array = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> Flag in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
                return .flags(array)
            }
        }

        func parseMessageAttribute_envelope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("ENVELOPE ", buffer: &buffer, tracker: tracker)
            return .envelope(try self.parseEnvelope(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_internalDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("INTERNALDATE ", buffer: &buffer, tracker: tracker)
            return .internalDate(try self.parseInternalDate(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_rfc822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("RFC822 ", buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .rfc822(string)
        }

        func parseMessageAttribute_rfc822Header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("RFC822.HEADER ", buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .rfc822Header(string)
        }

        func parseMessageAttribute_rfc822Text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("RFC822.TEXT ", buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .rfc822Text(string)
        }

        func parseMessageAttribute_rfc822Size(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("RFC822.SIZE ", buffer: &buffer, tracker: tracker)
            return .rfc822Size(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("BODY", buffer: &buffer, tracker: tracker)
            let hasExtensionData: Bool = {
                do {
                    try ParserLibrary.parseFixedString("STRUCTURE", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    return false
                }
            }()
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let body = try self.parseBody(buffer: &buffer, tracker: tracker)
            return .body(body, hasExtensionData: hasExtensionData)
        }

        func parseMessageAttribute_bodySection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("BODY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let offset = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try ParserLibrary.parseFixedString("<", buffer: &buffer, tracker: tracker)
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString(">", buffer: &buffer, tracker: tracker)
                return num
            }
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .bodySection(section ?? SectionSpecifier(kind: .complete), offset: offset, data: string)
        }

        func parseMessageAttribute_uid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("UID ", buffer: &buffer, tracker: tracker)
            return .uid(try self.parseUID(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_binarySize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("BINARY.SIZE", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return .binarySize(section: section, size: number)
        }

        func parseMessageAttribute_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("BINARY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .binary(section: section, data: string)
        }

        return try ParserLibrary.parseOneOf([
            parseMessageAttribute_envelope,
            parseMessageAttribute_internalDate,
            parseMessageAttribute_rfc822,
            parseMessageAttribute_rfc822Size,
            parseMessageAttribute_rfc822Header,
            parseMessageAttribute_rfc822Text,
            parseMessageAttribute_body,
            parseMessageAttribute_bodySection,
            parseMessageAttribute_uid,
            parseMessageAttribute_binarySize,
            parseMessageAttribute_binary,
            parseMessageAttribute_flags,
        ], buffer: &buffer, tracker: tracker)
    }

    // Namespace         = nil / "(" 1*Namespace-Descr ")"
    static func parseNamespace(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
        func parseNamespace_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }

        func parseNamespace_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let descriptions = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseNamespaceDescription)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return descriptions
        }

        return try ParserLibrary.parseOneOf([
            parseNamespace_nil,
            parseNamespace_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // Namespace-Command = "NAMESPACE"
    static func parseNamespaceCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseFixedString("NAMESPACE", buffer: &buffer, tracker: tracker)
        return .namespace
    }

    // Namespace-Descr   = "(" string SP
    //                        (DQUOTE QUOTED-CHAR DQUOTE / nil)
    //                         [Namespace-Response-Extensions] ")"
    static func parseNamespaceDescription(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NamespaceDescription {
        func parseNamespaceDescr_quotedChar(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            guard let char = buffer.readBytes(length: 1)?.first else {
                throw _IncompleteMessage()
            }
            guard char.isQuotedChar else {
                throw ParserError(hint: "Invalid character")
            }
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return Character(.init(char))
        }

        func parseNamespaceDescr_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceDescription in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let string = try self.parseString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let char = try ParserLibrary.parseOneOf([
                parseNamespaceDescr_quotedChar,
                parseNamespaceDescr_nil,
            ], buffer: &buffer, tracker: tracker)
            let extensions = try self.parseNamespaceResponseExtensions(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .init(string: string, char: char, responseExtensions: extensions)
        }
    }

    // Namespace-Response-Extensions = *(Namespace-Response-Extension)
    static func parseNamespaceResponseExtensions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceResponseExtension] {
        try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NamespaceResponseExtension in
            try self.parseNamespaceResponseExtension(buffer: &buffer, tracker: tracker)
        }
    }

    // Namespace-Response-Extension = SP string SP
    //                   "(" string *(SP string) ")"
    static func parseNamespaceResponseExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NamespaceResponseExtension {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceResponseExtension in
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let s1 = try self.parseString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseString(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseString(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return NamespaceResponseExtension(string: s1, array: array)
        }
    }

    // Namespace-Response = "*" SP "NAMESPACE" SP Namespace
    //                       SP Namespace SP Namespace
    static func parseNamespaceResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NamespaceResponse {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceResponse in
            try ParserLibrary.parseFixedString("NAMESPACE ", buffer: &buffer, tracker: tracker)
            let n1 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let n2 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let n3 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            return NamespaceResponse(userNamespace: n1, otherUserNamespace: n2, sharedNamespace: n3)
        }
    }

    // nil             = "NIL"
    static func parseNil(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseFixedString("nil", buffer: &buffer, tracker: tracker)
    }

    // nstring         = string / nil
    static func parseNString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer? {
        func parseNString_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer? {
            try ParserLibrary.parseFixedString("NIL", buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseNString_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer? {
            try self.parseString(buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseOneOf([
            parseNString_nil,
            parseNString_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // number          = 1*DIGIT
    static func parseNumber(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        let (num, _) = try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker)
        return num
    }

    // nz-number       = digit-nz *DIGIT
    static func parseNZNumber(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        if case .some(UInt8(ascii: "0")) = buffer.readableBytesView.first {
            throw ParserError(hint: "Number began with 0 ")
        }
        let (num, _) = try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker)
        return num
    }

    // option-extension = (option-standard-tag / option-vendor-tag)
    //                    [SP option-value]
    static func parseOptionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionExtension {
        func parseOptionExtensionKind_standard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionExtensionKind {
            .standard(try self.parseAtom(buffer: &buffer, tracker: tracker))
        }

        func parseOptionExtensionKind_vendor(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionExtensionKind {
            .vendor(try self.parseOptionVendorTag(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> OptionExtension in
            let type = try ParserLibrary.parseOneOf([
                parseOptionExtensionKind_standard,
                parseOptionExtensionKind_vendor,
            ], buffer: &buffer, tracker: tracker)
            let value = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> OptionValueComp in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseOptionValue(buffer: &buffer, tracker: tracker)
            }
            return OptionExtension(kind: type, value: value)
        }
    }

    // option-val-comp =  astring /
    //                    option-val-comp *(SP option-val-comp) /
    //                    "(" option-val-comp ")"
    static func parseOptionValueComp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
        func parseOptionValueComp_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
            .string(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseOptionValueComp_single(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .array([comp])
        }

        func parseOptionValueComp_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
            var array = [try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> OptionValueComp in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            }
            return .array(array)
        }

        return try ParserLibrary.parseOneOf([
            parseOptionValueComp_string,
            parseOptionValueComp_single,
            parseOptionValueComp_array,
        ], buffer: &buffer, tracker: tracker)
    }

    // option-value =  "(" option-val-comp ")"
    static func parseOptionValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> OptionValueComp in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return comp
        }
    }

    // option-vendor-tag =  vendor-token "-" atom
    static func parseOptionVendorTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionVendorTag {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> OptionVendorTag in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return OptionVendorTag(token: token, atom: atom)
        }
    }

    // partial         = "<" number "." nz-number ">"
    static func parsePartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ClosedRange<Int> {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ClosedRange<Int> in
            try ParserLibrary.parseFixedString("<", buffer: &buffer, tracker: tracker)
            guard let num1 = UInt32(exactly: try self.parseNumber(buffer: &buffer, tracker: tracker)) else {
                throw ParserError(hint: "Partial range start is invalid.")
            }
            try ParserLibrary.parseFixedString(".", buffer: &buffer, tracker: tracker)
            guard let num2 = UInt32(exactly: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
                throw ParserError(hint: "Partial range count is invalid.")
            }
            guard num2 > 0 else { throw ParserError(hint: "Partial range is invalid: <\(num1).\(num2)>.") }
            try ParserLibrary.parseFixedString(">", buffer: &buffer, tracker: tracker)
            let upper1 = num1.addingReportingOverflow(num2)
            guard !upper1.overflow else { throw ParserError(hint: "Range is invalid: <\(num1).\(num2)>.") }
            let upper2 = upper1.partialValue.subtractingReportingOverflow(1)
            guard !upper2.overflow else { throw ParserError(hint: "Range is invalid: <\(num1).\(num2)>.") }
            return Int(num1) ... Int(upper2.partialValue)
        }
    }

    // password        = astring
    static func parsePassword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        var buffer = try Self.parseAString(buffer: &buffer, tracker: tracker)
        return buffer.readString(length: buffer.readableBytes)!
    }

    // patterns        = "(" list-mailbox *(SP list-mailbox) ")"
    static func parsePatterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ByteBuffer] in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseListMailbox(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // quoted          = DQUOTE *QUOTED-CHAR DQUOTE
    static func parseQuoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            let data = try ParserLibrary.parseZeroOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char in
                char.isQuotedChar
            }
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return data
        }
    }

    // rename          = "RENAME" SP mailbox SP mailbox [rename-params]
    static func parseRename(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("RENAME ", buffer: &buffer, tracker: tracker)
            let from = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", caseSensitive: false, buffer: &buffer, tracker: tracker)
            let to = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
            return .rename(from: from, to: to, params: params)
        }
    }

    // response-data   = "*" SP response-payload CRLF
    static func parseResponseData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("* ", buffer: &buffer, tracker: tracker)
            let payload = try self.parseResponsePayload(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseNewline(buffer: &buffer, tracker: tracker)
            return payload
        }
    }

    // response-fatal  = "*" SP resp-cond-bye CRLF
    static func parseResponseFatal(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseText {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseText in
            try ParserLibrary.parseFixedString("* ", buffer: &buffer, tracker: tracker)
            let bye = try self.parseResponseConditionalBye(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseNewline(buffer: &buffer, tracker: tracker)
            return bye
        }
    }

    // response-tagged = tag SP resp-cond-state CRLF
    static func parseTaggedResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedResponse {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> TaggedResponse in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let state = try self.parseResponseConditionalState(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseNewline(buffer: &buffer, tracker: tracker)
            return TaggedResponse(tag: tag, state: state)
        }
    }

    // resp-code-apnd  = "APPENDUID" SP nz-number SP append-uid
    static func parseResponseCodeAppend(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseCodeAppend {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseCodeAppend in
            try ParserLibrary.parseFixedString("APPENDUID ", buffer: &buffer, tracker: tracker)
            let number = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let uid = try self.parseUID(buffer: &buffer, tracker: tracker)
            return ResponseCodeAppend(num: number, uid: uid)
        }
    }

    // resp-code-copy  = "COPYUID" SP nz-number SP uid-set SP uid-set
    static func parseResponseCodeCopy(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseCodeCopy {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseCodeCopy in
            try ParserLibrary.parseFixedString("COPYUID ", buffer: &buffer, tracker: tracker)
            let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let set1 = try self.parseUIDSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let set2 = try self.parseUIDSet(buffer: &buffer, tracker: tracker)
            return ResponseCodeCopy(num: num, set1: set1, set2: set2)
        }
    }

    // resp-cond-auth  = ("OK" / "PREAUTH") SP resp-text
    static func parseResponseConditionalAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalAuth {
        func parseResponseConditionalAuth_ok(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalAuth {
            try ParserLibrary.parseFixedString("OK ", buffer: &buffer, tracker: tracker)
            return .ok(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseResponseConditionalAuth_preauth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalAuth {
            try ParserLibrary.parseFixedString("PREAUTH ", buffer: &buffer, tracker: tracker)
            return .preauth(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseResponseConditionalAuth_ok,
            parseResponseConditionalAuth_preauth,
        ], buffer: &buffer, tracker: tracker)
    }

    // resp-cond-bye   = "BYE" SP resp-text
    static func parseResponseConditionalBye(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseText {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseText in
            try ParserLibrary.parseFixedString("BYE ", buffer: &buffer, tracker: tracker)
            return try self.parseResponseText(buffer: &buffer, tracker: tracker)
        }
    }

    // resp-cond-state = ("OK" / "NO" / "BAD") SP resp-text
    static func parseResponseConditionalState(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalState {
        func parseResponseConditionalState_ok(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalState {
            try ParserLibrary.parseFixedString("OK ", buffer: &buffer, tracker: tracker)
            return .ok(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseResponseConditionalState_no(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalState {
            try ParserLibrary.parseFixedString("NO ", buffer: &buffer, tracker: tracker)
            return .no(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseResponseConditionalState_bad(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalState {
            try ParserLibrary.parseFixedString("BAD ", buffer: &buffer, tracker: tracker)
            return .bad(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseResponseConditionalState_ok,
            parseResponseConditionalState_no,
            parseResponseConditionalState_bad,
        ], buffer: &buffer, tracker: tracker)
    }

    // response-payload = resp-cond-state / resp-cond-bye / mailbox-data / message-data / capability-data / id-response / enable-data
    static func parseResponsePayload(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
        func parseResponsePayload_conditionalState(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .conditionalState(try self.parseResponseConditionalState(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_conditionalBye(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .conditionalBye(try self.parseResponseConditionalBye(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_mailboxData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .mailboxData(try self.parseMailboxData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_messageData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .messageData(try self.parseMessageData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_capabilityData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .capabilityData(try self.parseCapabilityData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_idResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .id(try self.parseIDResponse(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_enableData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .enableData(try self.parseEnableData(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseResponsePayload_conditionalState,
            parseResponsePayload_conditionalBye,
            parseResponsePayload_mailboxData,
            parseResponsePayload_messageData,
            parseResponsePayload_capabilityData,
            parseResponsePayload_idResponse,
            parseResponsePayload_enableData,
        ], buffer: &buffer, tracker: tracker)
    }

    // resp-text       = ["[" resp-text-code "]" SP] text
    static func parseResponseText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseText {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseText in
            let code = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ResponseTextCode in
                try ParserLibrary.parseFixedString("[", buffer: &buffer, tracker: tracker)
                let code = try self.parseResponseTextCode(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString("] ", buffer: &buffer, tracker: tracker)
                return code
            }
            let text = try self.parseText(buffer: &buffer, tracker: tracker)
            return ResponseText(code: code, text: String(buffer: text))
        }
    }

    // resp-text-code  = "ALERT" /
    //                   "BADCHARSET" [SP "(" charset *(SP charset) ")" ] /
    //                   capability-data / "PARSE" /
    //                   "PERMANENTFLAGS" SP "("
    //                   [flag-perm *(SP flag-perm)] ")" /
    //                   "READ-ONLY" / "READ-WRITE" / "TRYCREATE" /
    //                   "UIDNEXT" SP nz-number / "UIDVALIDITY" SP nz-number /
    //                   "UNSEEN" SP nz-number
    //                   atom [SP 1*<any TEXT-CHAR except "]">]
    static func parseResponseTextCode(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
        func parseResponseTextCode_alert(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("ALERT", buffer: &buffer, tracker: tracker)
            return .alert
        }

        func parseResponseTextCode_badCharset(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("BADCHARSET", buffer: &buffer, tracker: tracker)
            let charsets = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [String] in
                try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
                var array = [try self.parseCharset(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> String in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseCharset(buffer: &buffer, tracker: tracker)
                }
                try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
                return array
            } ?? []
            return .badCharset(charsets)
        }

        func parseResponseTextCode_capabilityData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            .capability(try self.parseCapabilityData(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_parse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("PARSE", buffer: &buffer, tracker: tracker)
            return .parse
        }

        func parseResponseTextCode_permanentFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("PERMANENTFLAGS (", buffer: &buffer, tracker: tracker)
            let array = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [PermanentFlag] in
                var array = [try self.parseFlagPerm(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseFlagPerm(buffer: &buffer, tracker: tracker)
                }
                return array
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .permanentFlags(array ?? [])
        }

        func parseResponseTextCode_readOnly(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("READ-ONLY", buffer: &buffer, tracker: tracker)
            return .readOnly
        }

        func parseResponseTextCode_readWrite(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("READ-WRITE", buffer: &buffer, tracker: tracker)
            return .readWrite
        }

        func parseResponseTextCode_tryCreate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("TRYCREATE", buffer: &buffer, tracker: tracker)
            return .tryCreate
        }

        func parseResponseTextCode_uidNext(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("UIDNEXT ", buffer: &buffer, tracker: tracker)
            return .uidNext(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_uidValidity(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("UIDVALIDITY ", buffer: &buffer, tracker: tracker)
            return .uidValidity(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_unseen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("UNSEEN ", buffer: &buffer, tracker: tracker)
            return .unseen(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_namespace(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            .namespace(try self.parseNamespaceResponse(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_atom(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            let string = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> String in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { (char) -> Bool in
                    char.isTextChar && char != UInt8(ascii: "]")
                }
            }
            return .other(atom, string)
        }

        return try ParserLibrary.parseOneOf([
            parseResponseTextCode_alert,
            parseResponseTextCode_badCharset,
            parseResponseTextCode_capabilityData,
            parseResponseTextCode_parse,
            parseResponseTextCode_permanentFlags,
            parseResponseTextCode_readOnly,
            parseResponseTextCode_readWrite,
            parseResponseTextCode_tryCreate,
            parseResponseTextCode_uidNext,
            parseResponseTextCode_uidValidity,
            parseResponseTextCode_unseen,
            parseResponseTextCode_namespace,
            parseResponseTextCode_atom,
        ], buffer: &buffer, tracker: tracker)
    }

    // return-option   =  "SUBSCRIBED" / "CHILDREN" / status-option /
    //                    option-extension
    static func parseReturnOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
        func parseReturnOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            try ParserLibrary.parseFixedString("SUBSCRIBED", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseReturnOption_children(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            try ParserLibrary.parseFixedString("CHILDREN", buffer: &buffer, tracker: tracker)
            return .children
        }

        func parseReturnOption_statusOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            .statusOption(try self.parseStatusOption(buffer: &buffer, tracker: tracker))
        }

        func parseReturnOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            .optionExtension(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseReturnOption_subscribed,
            parseReturnOption_children,
            parseReturnOption_statusOption,
            parseReturnOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // search          = "SEARCH" [search-return-opts] SP search-program
    static func parseSearch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("SEARCH", buffer: &buffer, tracker: tracker)
            let returnOpts = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSearchReturnOptions) ?? []
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let charset = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> String in
                try ParserLibrary.parseFixedString("CHARSET ", buffer: &buffer, tracker: tracker)
                let charset = try self.parseCharset(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return charset
            }
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchKey in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }

            if case .and = array.first!, array.count == 1 {
                return .search(key: array.first!, charset: charset, returnOptions: returnOpts)
            } else if array.count == 1 {
                return .search(key: array.first!, charset: charset, returnOptions: returnOpts)
            } else {
                return .search(key: .and(array), charset: charset, returnOptions: returnOpts)
            }
        }
    }

    // search-correlator    = SP "(" "TAG" SP tag-string ")"
    static func parseSearchCorrelator(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString(" (TAG ", buffer: &buffer, tracker: tracker)
            let tag = try self.parseString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return tag
        }
    }

    // search-critera = search-key *(search-key)
    static func parseSearchCriteria(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [SearchKey] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }
            return array
        }
    }

    // search-key      = "ALL" / "ANSWERED" / "BCC" SP astring /
    //                   "BEFORE" SP date / "BODY" SP astring /
    //                   "CC" SP astring / "DELETED" / "FLAGGED" /
    //                   "FROM" SP astring / "KEYWORD" SP flag-keyword /
    //                   "NEW" / "OLD" / "ON" SP date / "RECENT" / "SEEN" /
    //                   "SINCE" SP date / "SUBJECT" SP astring /
    //                   "TEXT" SP astring / "TO" SP astring /
    //                   "UNANSWERED" / "UNDELETED" / "UNFLAGGED" /
    //                   "UNKEYWORD" SP flag-keyword / "UNSEEN" /
    //                   "DRAFT" / "HEADER" SP header-fld-name SP astring /
    //                   "LARGER" SP number / "NOT" SP search-key /
    //                   "OR" SP search-key SP search-key /
    //                   "SENTBEFORE" SP date / "SENTON" SP date /
    //                   "SENTSINCE" SP date / "SMALLER" SP number /
    //                   "UID" SP sequence-set / "UNDRAFT" / sequence-set /
    //                   "(" search-key *(SP search-key) ")"
    static func parseSearchKey(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
        func parseSearchKey_fixed(string: String, result: SearchKey, buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString(string, buffer: &buffer, tracker: tracker)
            return result
        }

        func parseSearchKey_fixedOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            let inputs: [(String, SearchKey)] = [
                ("ALL", .all),
                ("ANSWERED", .answered),
                ("DELETED", .deleted),
                ("FLAGGED", .flagged),
                ("NEW", .new),
                ("OLD", .old),
                ("RECENT", .recent),
                ("SEEN", .seen),
                ("UNSEEN", .unseen),
                ("UNANSWERED", .unanswered),
                ("UNDELETED", .undeleted),
                ("UNFLAGGED", .unflagged),
                ("DRAFT", .draft),
                ("UNDRAFT", .undraft),
            ]
            let save = buffer
            for (key, value) in inputs {
                do {
                    return try parseSearchKey_fixed(string: key, result: value, buffer: &buffer, tracker: tracker)
                } catch is ParserError {
                    buffer = save
                }
            }
            throw ParserError()
        }

        func parseSearchKey_bcc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("BCC ", buffer: &buffer, tracker: tracker)
            return .bcc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_before(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("BEFORE ", buffer: &buffer, tracker: tracker)
            return .before(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("BODY ", buffer: &buffer, tracker: tracker)
            return .body(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_cc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("CC ", buffer: &buffer, tracker: tracker)
            return .cc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_from(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("FROM ", buffer: &buffer, tracker: tracker)
            return .from(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_keyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("KEYWORD ", buffer: &buffer, tracker: tracker)
            return .keyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_on(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("ON ", buffer: &buffer, tracker: tracker)
            return .on(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_since(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("SINCE ", buffer: &buffer, tracker: tracker)
            return .since(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_subject(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("SUBJECT ", buffer: &buffer, tracker: tracker)
            return .subject(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("TEXT ", buffer: &buffer, tracker: tracker)
            return .text(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_to(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("TO ", buffer: &buffer, tracker: tracker)
            return .to(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_unkeyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("UNKEYWORD ", buffer: &buffer, tracker: tracker)
            return .unkeyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_filter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("FILTER ", buffer: &buffer, tracker: tracker)
            return .filter(try self.parseFilterName(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("HEADER ", buffer: &buffer, tracker: tracker)
            let header = try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let string = try self.parseAString(buffer: &buffer, tracker: tracker)
            return .header(header, string)
        }

        func parseSearchKey_larger(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("LARGER ", buffer: &buffer, tracker: tracker)
            return .messageSizeLarger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_smaller(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("SMALLER ", buffer: &buffer, tracker: tracker)
            return .messageSizeSmaller(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_not(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("NOT ", buffer: &buffer, tracker: tracker)
            return .not(try self.parseSearchKey(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_or(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("OR ", buffer: &buffer, tracker: tracker)
            let key1 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let key2 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            return .or(key1, key2)
        }

        func parseSearchKey_sentBefore(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("SENTBEFORE ", buffer: &buffer, tracker: tracker)
            return .sentBefore(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sentOn(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("SENTON ", buffer: &buffer, tracker: tracker)
            return .sentOn(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sentSince(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("SENTSINCE ", buffer: &buffer, tracker: tracker)
            return .sentSince(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_uid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("UID ", buffer: &buffer, tracker: tracker)
            return .uid(try self.parseUIDSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sequenceSet(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            .sequenceNumbers(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchKey in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)

            if array.count == 1 {
                return array.first!
            } else {
                return .and(array)
            }
        }

        func parseSearchKey_older(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("OLDER ", buffer: &buffer, tracker: tracker)
            return .older(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_younger(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("YOUNGER ", buffer: &buffer, tracker: tracker)
            return .younger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseSearchKey_older,
            parseSearchKey_fixedOptions,
            parseSearchKey_younger,
            parseSearchKey_bcc,
            parseSearchKey_before,
            parseSearchKey_body,
            parseSearchKey_cc,
            parseSearchKey_from,
            parseSearchKey_keyword,
            parseSearchKey_on,
            parseSearchKey_since,
            parseSearchKey_subject,
            parseSearchKey_text,
            parseSearchKey_to,
            parseSearchKey_unkeyword,
            parseSearchKey_header,
            parseSearchKey_larger,
            parseSearchKey_smaller,
            parseSearchKey_not,
            parseSearchKey_or,
            parseSearchKey_sentBefore,
            parseSearchKey_sentOn,
            parseSearchKey_sentSince,
            parseSearchKey_uid,
            parseSearchKey_sequenceSet,
            parseSearchKey_array,
            parseSearchKey_filter,
        ], buffer: &buffer, tracker: tracker)
    }

    // search-ret-data-ext = search-modifier-name SP search-return-value
    static func parseSearchReturnDataExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnDataExtension {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SearchReturnDataExtension in
            let modifier = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let value = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return SearchReturnDataExtension(modifier: modifier, returnValue: value)
        }
    }

    // search-return-data = "MIN" SP nz-number /
    //                     "MAX" SP nz-number /
    //                     "ALL" SP sequence-set /
    //                     "COUNT" SP number /
    //                     search-ret-data-ext
    static func parseSearchReturnData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
        func parseSearchReturnData_min(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try ParserLibrary.parseFixedString("MIN ", buffer: &buffer, tracker: tracker)
            return .min(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_max(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try ParserLibrary.parseFixedString("MAX ", buffer: &buffer, tracker: tracker)
            return .max(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try ParserLibrary.parseFixedString("ALL ", buffer: &buffer, tracker: tracker)
            return .all(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_count(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try ParserLibrary.parseFixedString("COUNT ", buffer: &buffer, tracker: tracker)
            return .count(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_dataExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            .dataExtension(try self.parseSearchReturnDataExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseSearchReturnData_min,
            parseSearchReturnData_max,
            parseSearchReturnData_all,
            parseSearchReturnData_count,
            parseSearchReturnData_dataExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // search-return-opts   = SP "RETURN" SP "(" [search-return-opt *(SP search-return-opt)] ")"
    static func parseSearchReturnOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [SearchReturnOption] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString(" RETURN (", buffer: &buffer, tracker: tracker)
            let array = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [SearchReturnOption] in
                var array = [try self.parseSearchReturnOption(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchReturnOption in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseSearchReturnOption(buffer: &buffer, tracker: tracker)
                }
                return array
            } ?? []
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // search-return-opt  = "MIN" / "MAX" / "ALL" / "COUNT" /
    //                      "SAVE" /
    //                      search-ret-opt-ext
    static func parseSearchReturnOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
        func parseSearchReturnOption_min(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try ParserLibrary.parseFixedString("MIN", buffer: &buffer, tracker: tracker)
            return .min
        }

        func parseSearchReturnOption_max(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try ParserLibrary.parseFixedString("MAX", buffer: &buffer, tracker: tracker)
            return .max
        }

        func parseSearchReturnOption_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try ParserLibrary.parseFixedString("ALL", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseSearchReturnOption_count(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try ParserLibrary.parseFixedString("COUNT", buffer: &buffer, tracker: tracker)
            return .count
        }

        func parseSearchReturnOption_save(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try ParserLibrary.parseFixedString("SAVE", buffer: &buffer, tracker: tracker)
            return .save
        }

        func parseSearchReturnOption_extension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            let optionExtension = try self.parseSearchReturnOptionExtension(buffer: &buffer, tracker: tracker)
            return .optionExtension(optionExtension)
        }

        return try ParserLibrary.parseOneOf([
            parseSearchReturnOption_min,
            parseSearchReturnOption_max,
            parseSearchReturnOption_all,
            parseSearchReturnOption_count,
            parseSearchReturnOption_save,
            parseSearchReturnOption_extension,
        ], buffer: &buffer, tracker: tracker)
    }

    // search-ret-opt-ext = search-modifier-name [SP search-mod-params]
    static func parseSearchReturnOptionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOptionExtension {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SearchReturnOptionExtension in
            let name = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ParameterValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            }
            return SearchReturnOptionExtension(modifierName: name, params: params)
        }
    }

    // section         = "[" [section-spec] "]"
    static func parseSection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier? {
        func parseSection_none(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier? {
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier? in
                try ParserLibrary.parseFixedString("[]", buffer: &buffer, tracker: tracker)
                return nil
            }
        }

        func parseSection_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier? {
            try ParserLibrary.parseFixedString("[", buffer: &buffer, tracker: tracker)
            let spec = try self.parseSectionSpecifier(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("]", buffer: &buffer, tracker: tracker)
            return spec
        }

        return try ParserLibrary.parseOneOf([
            parseSection_none,
            parseSection_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // section-binary  = "[" [section-part] "]"
    static func parseSectionBinary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Part {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier.Part in
            try ParserLibrary.parseFixedString("[", buffer: &buffer, tracker: tracker)
            let part = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSectionPart)
            try ParserLibrary.parseFixedString("]", buffer: &buffer, tracker: tracker)
            return part ?? .init(rawValue: [])
        }
    }

    // section-part    = nz-number *("." nz-number)
    static func parseSectionPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Part {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier.Part in
            var output = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> Int in
                try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                    try ParserLibrary.parseFixedString(".", buffer: &buffer, tracker: tracker)
                    return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                }
            }
            return .init(rawValue: output)
        }
    }

    // section-spec    = section-msgtext / (section-part ["." section-text])
    static func parseSectionSpecifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier {
        func parseSectionSpecifier_noPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            let kind = try self.parseSectionSpecifierKind(buffer: &buffer, tracker: tracker)
            return .init(kind: kind)
        }

        func parseSectionSpecifier_withPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            let part = try self.parseSectionPart(buffer: &buffer, tracker: tracker)
            let kind = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SectionSpecifier.Kind in
                try ParserLibrary.parseFixedString(".", buffer: &buffer, tracker: tracker)
                return try self.parseSectionSpecifierKind(buffer: &buffer, tracker: tracker)
            } ?? .complete
            return .init(part: part, kind: kind)
        }

        return try ParserLibrary.parseOneOf([
            parseSectionSpecifier_withPart,
            parseSectionSpecifier_noPart,
        ], buffer: &buffer, tracker: tracker)
    }

    // section-text    = section-msgtext / "MIME"
    static func parseSectionSpecifierKind(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
        func parseSectionSpecifierKind_mime(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try ParserLibrary.parseFixedString("MIME", buffer: &buffer, tracker: tracker)
            return .MIMEHeader
        }

        func parseSectionSpecifierKind_header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try ParserLibrary.parseFixedString("HEADER", buffer: &buffer, tracker: tracker)
            return .header
        }

        func parseSectionSpecifierKind_headerFields(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try ParserLibrary.parseFixedString("HEADER.FIELDS ", buffer: &buffer, tracker: tracker)
            return .headerFields(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpecifierKind_notHeaderFields(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try ParserLibrary.parseFixedString("HEADER.FIELDS.NOT ", buffer: &buffer, tracker: tracker)
            return .headerFieldsNot(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpecifierKind_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try ParserLibrary.parseFixedString("TEXT", buffer: &buffer, tracker: tracker)
            return .text
        }

        func parseSectionSpecifierKind_complete(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            .complete
        }

        return try ParserLibrary.parseOneOf([
            parseSectionSpecifierKind_mime,
            parseSectionSpecifierKind_headerFields,
            parseSectionSpecifierKind_notHeaderFields,
            parseSectionSpecifierKind_header,
            parseSectionSpecifierKind_text,
            parseSectionSpecifierKind_complete,
        ], buffer: &buffer, tracker: tracker)
    }

    // select          = "SELECT" SP mailbox [select-params]
    static func parseSelect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("SELECT ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
            return .select(mailbox, params)
        }
    }

    // select-params = SP "(" select-param *(SP select-param ")"
    static func parseParameters(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Parameter] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [Parameter] in
            try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseParameter(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> Parameter in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseParameter(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // Sequence Range
    static func parseSequenceRange(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceRange {
        func parse_wildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceNumber {
            try ParserLibrary.parseFixedString("*", buffer: &buffer, tracker: tracker)
            return .max
        }

        func parse_SequenceOrWildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceNumber {
            try ParserLibrary.parseOneOf([
                parse_wildcard,
                GrammarParser.parseSequenceNumber,
            ], buffer: &buffer, tracker: tracker)
        }

        func parse_colonAndSequenceOrWildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceNumber {
            try ParserLibrary.parseFixedString(":", buffer: &buffer, tracker: tracker)
            return try parse_SequenceOrWildcard(buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SequenceRange in
            let id1 = try parse_SequenceOrWildcard(buffer: &buffer, tracker: tracker)
            let id2 = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: parse_colonAndSequenceOrWildcard)
            if let id = id2 {
                return SequenceRange(left: id1, right: id)
            } else if id1 == .max {
                return .all
            } else {
                return SequenceRange(id1)
            }
        }
    }

    // SequenceNumber
    // Note: the formal syntax is bogus here.
    // "*" is a sequence range, but not a sequence number.
    static func parseSequenceNumber(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceNumber {
        guard let seq = SequenceNumber(rawValue: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
            throw ParserError(hint: "Sequence number out of range.")
        }
        return seq
    }

    // sequence-set    = (seq-number / seq-range) ["," sequence-set]
    static func parseSequenceSet(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceSet {
        func parseSequenceSet_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceRange {
            let num = try self.parseSequenceNumber(buffer: &buffer, tracker: tracker)
            return SequenceRange(num)
        }

        func parseSequenceSet_element(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceRange {
            try ParserLibrary.parseOneOf([
                self.parseSequenceRange,
                parseSequenceSet_number,
            ], buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            var output = [try parseSequenceSet_element(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                try ParserLibrary.parseFixedString(",", buffer: &buffer, tracker: tracker)
                return try parseSequenceSet_element(buffer: &buffer, tracker: tracker)
            }
            guard let s = SequenceSet(output) else {
                throw ParserError(hint: "Sequence set is empty.")
            }
            return s
        }
    }

    // uid-set
    static func parseUIDSet(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UIDSet {
        func parseUIDSet_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UIDRange {
            let num = try self.parseUID(buffer: &buffer, tracker: tracker)
            return UIDRange(num)
        }

        func parseUIDSet_element(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UIDRange {
            try ParserLibrary.parseOneOf([
                self.parseUIDRange,
                parseUIDSet_number,
            ], buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            var output = [try parseUIDSet_element(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                try ParserLibrary.parseFixedString(",", buffer: &buffer, tracker: tracker)
                return try parseUIDSet_element(buffer: &buffer, tracker: tracker)
            }
            guard let s = UIDSet(output) else {
                throw ParserError(hint: "UID set is empty.")
            }
            return s
        }
    }

    // status          = "STATUS" SP mailbox SP
    //                   "(" status-att *(SP status-att) ")"
    static func parseStatus(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("STATUS ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var atts = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &atts, tracker: tracker) { buffer, tracker -> MailboxAttribute in
                try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .status(mailbox, atts)
        }
    }

    // status-att      = "MESSAGES" / "UIDNEXT" / "UIDVALIDITY" /
    //                   "UNSEEN" / "DELETED" / "SIZE"
    static func parseStatusAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxAttribute {
        let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { c -> Bool in
            isalpha(Int32(c)) != 0
        }
        guard let att = MailboxAttribute(rawValue: string.uppercased()) else {
            throw ParserError(hint: "Found \(string) which was not a status attribute")
        }
        return att
    }

    // status-att-list  = status-att-val *(SP status-att-val)
    static func parseMailboxStatus(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxStatus {
        enum MailboxValue: Equatable {
            case messages(Int)
            case uidNext(Int)
            case uidValidity(Int)
            case unseen(Int)
            case size(Int)
            case recent(Int)
            case modSequence(ModifierSequenceValue)
        }

        func parseStatusAttributeValue_messages(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseFixedString("MESSAGES ", buffer: &buffer, tracker: tracker)
            return .messages(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_uidnext(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseFixedString("UIDNEXT ", buffer: &buffer, tracker: tracker)
            return .uidNext(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_uidvalidity(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseFixedString("UIDVALIDITY ", buffer: &buffer, tracker: tracker)
            return .uidValidity(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_unseen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseFixedString("UNSEEN ", buffer: &buffer, tracker: tracker)
            return .unseen(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_size(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseFixedString("SIZE ", buffer: &buffer, tracker: tracker)
            return .size(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_modSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseFixedString("HIGHESTMODSEQ ", buffer: &buffer, tracker: tracker)
            return .modSequence(try self.parseModifierSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_recent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseFixedString("RECENT ", buffer: &buffer, tracker: tracker)
            return .recent(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseOneOf([
                parseStatusAttributeValue_messages,
                parseStatusAttributeValue_uidnext,
                parseStatusAttributeValue_uidvalidity,
                parseStatusAttributeValue_unseen,
                parseStatusAttributeValue_size,
                parseStatusAttributeValue_modSequence,
                parseStatusAttributeValue_recent,
            ], buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> MailboxStatus in

            var array = [try parseStatusAttributeValue(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> MailboxValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try parseStatusAttributeValue(buffer: &buffer, tracker: tracker)
            }

            var status = MailboxStatus()
            for value in array {
                switch value {
                case .messages(let messages):
                    status.messageCount = messages
                case .modSequence(let modSequence):
                    status.modSequence = modSequence
                case .size(let size):
                    status.size = size
                case .uidNext(let uidNext):
                    status.nextUID = uidNext
                case .uidValidity(let uidValidity):
                    status.uidValidity = uidValidity
                case .unseen(let unseen):
                    status.unseenCount = unseen
                case .recent(let recent):
                    status.recentCount = recent
                }
            }
            return status
        }
    }

    // status-option = "STATUS" SP "(" status-att *(SP status-att) ")"
    static func parseStatusOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [MailboxAttribute] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [MailboxAttribute] in
            try ParserLibrary.parseFixedString("STATUS (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> MailboxAttribute in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // store           = "STORE" SP sequence-set SP store-att-flags
    static func parseStore(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("STORE ", buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            let modifiers = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let flags = try self.parseStoreAttributeFlags(buffer: &buffer, tracker: tracker)
            return .store(sequence, modifiers, flags)
        }
    }

    // store-att-flags = (["+" / "-"] "FLAGS" [".SILENT"]) SP
    //                   (flag-list / (flag *(SP flag)))
    static func parseStoreAttributeFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreFlags {
        func parseStoreAttributeFlags_silent(buffer: inout ByteBuffer, tracker: StackTracker) -> Bool {
            do {
                try ParserLibrary.parseFixedString(".SILENT", buffer: &buffer, tracker: tracker)
                return true
            } catch {
                return false
            }
        }

        func parseStoreAttributeFlags_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Flag] {
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [Flag] in
                var output = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> Flag in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                return output
            }
        }

        func parseStoreAttributeFlags_operation(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreFlags.Operation {
            try ParserLibrary.parseOneOf([
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> StoreFlags.Operation in
                    try ParserLibrary.parseFixedString("+FLAGS", buffer: &buffer, tracker: tracker)
                    return .add
                },
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> StoreFlags.Operation in
                    try ParserLibrary.parseFixedString("-FLAGS", buffer: &buffer, tracker: tracker)
                    return .remove
                },
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> StoreFlags.Operation in
                    try ParserLibrary.parseFixedString("FLAGS", buffer: &buffer, tracker: tracker)
                    return .replace
                },
            ], buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> StoreFlags in
            let operation = try parseStoreAttributeFlags_operation(buffer: &buffer, tracker: tracker)
            let silent = parseStoreAttributeFlags_silent(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let flags = try ParserLibrary.parseOneOf([
                parseStoreAttributeFlags_array,
                parseFlagList,
            ], buffer: &buffer, tracker: tracker)
            return StoreFlags(operation: operation, silent: silent, flags: flags)
        }
    }

    // string          = quoted / literal
    static func parseString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try ParserLibrary.parseOneOf([
            Self.parseQuoted,
            Self.parseLiteral,
        ], buffer: &buffer, tracker: tracker)
    }

    // subscribe       = "SUBSCRIBE" SP mailbox
    static func parseSubscribe(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("SUBSCRIBE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .subscribe(mailbox)
        }
    }

    // tag             = 1*<any ASTRING-CHAR except "+">
    static func parseTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAStringChar && char != UInt8(ascii: "+")
        }
    }

    // tagged-ext = tagged-ext-label SP tagged-ext-val
    static func parseTaggedExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtension {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let label = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let value = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return .init(label: label, value: value)
        }
    }

    // tagged-ext-label    = tagged-label-fchar *tagged-label-char
    static func parseParameterName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in

            guard let fchar = buffer.readBytes(length: 1)?.first else {
                throw _IncompleteMessage()
            }
            guard fchar.isTaggedLabelFchar else {
                throw ParserError(hint: "\(fchar) is not a valid fchar’")
            }

            let trailing = try ParserLibrary.parseZeroOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isTaggedLabelChar
            }

            return String(decoding: [fchar], as: Unicode.UTF8.self) + trailing
        }
    }

    // astring
    // continuation = ( SP tagged-ext-comp )*
    // tagged-ext-comp = astring continuation | '(' tagged-ext-comp ')' continuation
    static func parseTaggedExtensionComplex_continuation(
        into: inout [String],
        buffer: inout ByteBuffer,
        tracker: StackTracker
    ) throws {
        while true {
            do {
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_helper(into: &into, buffer: &buffer, tracker: tracker)
            } catch {
                return
            }
        }
    }

    static func parseTaggedExtensionComplex_helper(
        into: inout [String],
        buffer: inout ByteBuffer,
        tracker: StackTracker
    ) throws {
        func parseTaggedExtensionComplex_string(
            into: inout [String],
            buffer: inout ByteBuffer,
            tracker: StackTracker
        ) throws {
            into.append(String(buffer: try self.parseAString(buffer: &buffer, tracker: tracker)))
            try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
        }

        func parseTaggedExtensionComplex_bracketed(
            into: inout [String],
            buffer: inout ByteBuffer,
            tracker: StackTracker
        ) throws {
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_helper(into: &into, buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
            }
        }

        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let save = buffer
            do {
                try parseTaggedExtensionComplex_string(into: &into, buffer: &buffer, tracker: tracker)
            } catch {
                buffer = save
                try parseTaggedExtensionComplex_bracketed(into: &into, buffer: &buffer, tracker: tracker)
            }
        }
    }

    // NOTE: Left-recursive, modification above, this needs some work
    // tagged-ext-comp     = astring /
    //                       tagged-ext-comp *(SP tagged-ext-comp) /
    //                       "(" tagged-ext-comp ")"
    static func parseTaggedExtensionComplex(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [String] {
        var result = [String]()
        try self.parseTaggedExtensionComplex_helper(into: &result, buffer: &buffer, tracker: tracker)
        return result
    }

    // tagged-ext-val      = tagged-ext-simple /
    //                       "(" [tagged-ext-comp] ")"
    static func parseParameterValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ParameterValue {
        func parseTaggedExtensionSimple_set(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ParameterValue {
            .sequence(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionSimple_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ParameterValue {
            .number(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionSimple_number64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ParameterValue {
            .number64(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionVal_comp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ParameterValue {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseTaggedExtensionComplex) ?? []
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .comp(comp)
        }

        return try ParserLibrary.parseOneOf([
            parseTaggedExtensionSimple_set,
            parseTaggedExtensionSimple_number,
            parseTaggedExtensionSimple_number64,
            parseTaggedExtensionVal_comp,
        ], buffer: &buffer, tracker: tracker)
    }

    // text            = 1*TEXT-CHAR
    static func parseText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try ParserLibrary.parseOneOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isTextChar
        }
    }

    // uid             = "UID" SP
    //                   (copy / move / fetch / search / store / uid-expunge)
    static func parseUid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseUid_copy(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try ParserLibrary.parseFixedString("COPY ", buffer: &buffer, tracker: tracker)
                let set = try self.parseUIDSet(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
                let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
                return .uidCopy(set, mailbox)
            }
        }

        func parseUid_move(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try ParserLibrary.parseFixedString("MOVE ", buffer: &buffer, tracker: tracker)
                let set = try self.parseUIDSet(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
                return .uidMove(set, mailbox)
            }
        }

        func parseUid_fetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try ParserLibrary.parseFixedString("FETCH ", buffer: &buffer, tracker: tracker)
                let set = try self.parseUIDSet(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                let att = try parseFetch_type(buffer: &buffer, tracker: tracker)
                let modifiers = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
                return .uidFetch(set, att, modifiers)
            }
        }

        func parseUid_search(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            guard case .search(let key, let charset, let returnOptions) = try self.parseSearch(buffer: &buffer, tracker: tracker) else {
                fatalError("This should never happen")
            }
            return .uidSearch(key: key, charset: charset, returnOptions: returnOptions)
        }

        func parseUid_store(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try ParserLibrary.parseFixedString("STORE ", buffer: &buffer, tracker: tracker)
                let set = try self.parseUIDSet(buffer: &buffer, tracker: tracker)
                let modifiers = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                let flags = try self.parseStoreAttributeFlags(buffer: &buffer, tracker: tracker)
                return .uidStore(set, modifiers, flags)
            }
        }

        func parseUid_expunge(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("EXPUNGE ", buffer: &buffer, tracker: tracker)
            let set = try self.parseUIDSet(buffer: &buffer, tracker: tracker)
            return .uidExpunge(set)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("UID ", buffer: &buffer, tracker: tracker)
            return try ParserLibrary.parseOneOf([
                parseUid_copy,
                parseUid_move,
                parseUid_fetch,
                parseUid_search,
                parseUid_store,
                parseUid_expunge,
            ], buffer: &buffer, tracker: tracker)
        }
    }

    // uid-range       = (uniqueid ":" uniqueid)
    static func parseUIDRange(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UIDRange {
        func parse_wildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UID {
            try ParserLibrary.parseFixedString("*", buffer: &buffer, tracker: tracker)
            return .max
        }

        func parse_UIDOrWildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UID {
            try ParserLibrary.parseOneOf([
                parse_wildcard,
                GrammarParser.parseUID,
            ], buffer: &buffer, tracker: tracker)
        }

        func parse_colonAndUIDOrWildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UID {
            try ParserLibrary.parseFixedString(":", buffer: &buffer, tracker: tracker)
            return try parse_UIDOrWildcard(buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> UIDRange in
            let id1 = try parse_UIDOrWildcard(buffer: &buffer, tracker: tracker)
            let id2 = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: parse_colonAndUIDOrWildcard)
            if let id = id2 {
                return UIDRange(left: id1, right: id)
            } else if id1 == .max {
                return .all
            } else {
                return UIDRange(id1)
            }
        }
    }

    // uniqueid        = nz-number
    static func parseUID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UID {
        guard let uid = UID(rawValue: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
            throw ParserError(hint: "UID out of range.")
        }
        return uid
    }

    // unsubscribe     = "UNSUBSCRIBE" SP mailbox
    static func parseUnsubscribe(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("UNSUBSCRIBE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .unsubscribe(mailbox)
        }
    }

    // userid          = astring
    static func parseUserId(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        var astring = try Self.parseAString(buffer: &buffer, tracker: tracker)
        return astring.readString(length: astring.readableBytes)! // if this fails, something has gone very, very wrong
    }

    // vendor-token     = atom (maybe?!?!?!)
    static func parseVendorToken(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAlpha
        }
    }
}

// MARK: - Helper Parsers

extension GrammarParser {
    static func parseBodyLocationExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.LocationAndExtensions {
        let fieldLocation = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { String(buffer: $0) }
        let extensions = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [BodyExtension] in
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            return try self.parseBodyExtension(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.LocationAndExtensions(location: fieldLocation, extensions: extensions)
    }

    static func parseBodyLanguageLocation(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.LanguageLocation {
        let fieldLanguage = try self.parseBodyFieldLanguage(buffer: &buffer, tracker: tracker)
        let locationExtension = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.LocationAndExtensions in
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            return try parseBodyLocationExtension(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.LanguageLocation(languages: fieldLanguage, location: locationExtension)
    }

    static func parseBodyDescriptionLanguage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.DispositionAndLanguage {
        let description = try self.parseBodyFieldDsp(buffer: &buffer, tracker: tracker)
        let language = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.LanguageLocation in
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            return try parseBodyLanguageLocation(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.DispositionAndLanguage(disposition: description, language: language)
    }

    static func parse2Digit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 2)
    }

    static func parse4Digit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 4)
    }

    static func parseNDigits(buffer: inout ByteBuffer, tracker: StackTracker, bytes: Int) throws -> Int {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let (num, size) = try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker)
            guard size == bytes else {
                throw ParserError(hint: "Expected \(bytes) digits, got \(size)")
            }
            return num
        }
    }

    // reusable for a lot of the env-* types
    static func parseEnvelopeAddresses(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Address] {
        try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
        let addresses = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try self.parseAddress(buffer: &buffer, tracker: tracker)
        }
        try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
        return addresses
    }

    static func parseOptionalEnvelopeAddresses(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Address] {
        func parseOptionalEnvelopeAddresses_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Address] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }
        return try ParserLibrary.parseOneOf([
            parseEnvelopeAddresses,
            parseOptionalEnvelopeAddresses_nil,
        ], buffer: &buffer, tracker: tracker)
    }
}
