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

import NIO

extension NIOIMAP {
    
    public enum ParsingError: Error {
        case lineTooLong
        case incompleteMessage
    }

    public enum GrammarParser {

    }
}

// MARK: - Grammar Parsers
extension NIOIMAP.GrammarParser {

    // address         = "(" addr-name SP addr-adl SP addr-mailbox SP
    //                   addr-host ")"
    static func parseAddress(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Address {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Address in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let name = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let adl = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let host = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return NIOIMAP.Address(name: name, adl: adl, mailbox: mailbox, host: host)
        }
    }

    // append          = "APPEND" SP mailbox 1*append-message
    static func parseAppend(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("APPEND ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let firstMessage = try self.parseAppendMessage(buffer: &buffer, tracker: tracker)
            return .append(to: mailbox, firstMessageMetadata: firstMessage)
        }
    }
    
    // append-data = literal / literal8 / append-data-ext
    static func parseAppendData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.AppendData {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.AppendData in
            let needs8BitCleanTransport = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString("~", buffer: &buffer, tracker: tracker)
            }.map { () in true } ?? false
            try ParserLibrary.parseFixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            let synchronising = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString("+", buffer: &buffer, tracker: tracker)
            }.map { () in false } ?? true
            try ParserLibrary.parseFixedString("}\r\n", buffer: &buffer, tracker: tracker)
            return .init(byteCount: length, needs8BitCleanTransport: needs8BitCleanTransport, synchronizing: synchronising)
        }
    }
    
    // append-data-ext = tagged-ext
    static func parseAppendDataExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtension {
        return try self.parseTaggedExtension(buffer: &buffer, tracker: tracker)
    }
    
    // append-ext = append-ext-name SP append-ext-value
    static func parseAppendExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.AppendExtension {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseAppendExtensionName(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let value = try self.parseAppendExtensionValue(buffer: &buffer, tracker: tracker)
            return .name(name, value: value)
        }
    }
    
    // append-ext-name = tagged-ext-label
    static func parseAppendExtensionName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
    }
    
    // append-ext-value = tagged-ext-value
    static func parseAppendExtensionValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionValue {
        return try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }
    
    // append-message = appents-opts SP append-data
    static func parseAppendMessage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.AppendMessage {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.AppendMessage in
            let options = try self.parseAppendOptions(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let data = try self.parseAppendData(buffer: &buffer, tracker: tracker)
            return .options(options, data: data)
        }
    }
    
    // append-options = [SP flag-list] [SP date-time] *(SP append-ext)
    static func parseAppendOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.AppendOptions {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let flagList = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [NIOIMAP.Flag] in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseFlagList(buffer: &buffer, tracker: tracker)
            }
            let dateTime = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Date.DateTime in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseDateTime(buffer: &buffer, tracker: tracker)
            }
            let array = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.AppendExtension in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseAppendExtension(buffer: &buffer, tracker: tracker)
            }
            return .flagList(flagList, dateTime: dateTime, extensions: array)
        }
    }

    // append-uid      = uniqueid
    static func parseAppendUid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        return try self.parseUniqueID(buffer: &buffer, tracker: tracker)
    }

    // astring         = 1*ASTRING-CHAR / string
    static func parseAString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        func parseOneOrMoreASTRINGCHAR(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
            return try ParserLibrary.parseOneOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char -> Bool in
                return char.isAStringChar
            }
        }
        return try ParserLibrary.parseOneOf([
            Self.parseString,
            parseOneOrMoreASTRINGCHAR
        ], buffer: &buffer, tracker: tracker)
    }

    // atom            = 1*ATOM-CHAR
    static func parseAtom(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            return char.isAtomChar
        }
    }

    // authenticate    = "AUTHENTICATE" SP auth-type [SP initial-resp] *(CRLF base64)
    static func parseAuthenticate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("AUTHENTICATE ", buffer: &buffer, tracker: tracker)
            let authType = try self.parseAuthType(buffer: &buffer, tracker: tracker)

            let initial = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.InitialResponse in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseInitialResp(buffer: &buffer, tracker: tracker)
            }

            // NOTE: Spec is super unclear, so we're ignoring the possibility of multiple base 64 chunks right now
            //            let data = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Base64 in
            //                try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
            //                return try self.parseBase64(buffer: &buffer, tracker: tracker)
            //            }

//            let data = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [NIOIMAP.Base64] in
//                try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
//                return [try self.parseBase64(buffer: &buffer, tracker: tracker)]
//            } ?? []
            return .authenticate(authType, initial, [])
        }
    }

    // auth-type       = atom
    static func parseAuthType(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try self.parseAtom(buffer: &buffer, tracker: tracker)
    }

    // base64          = *(4base64-char) [base64-terminal]
    static func parseBase64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            let bytes = try ParserLibrary.parseZeroOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { $0.isBase64Char || $0 == UInt8(ascii: "=") }
            let readableBytesView = bytes.readableBytesView
            if let firstEq = readableBytesView.firstIndex(of: UInt8(ascii: "=")) {
                for index in firstEq..<readableBytesView.endIndex {
                    guard readableBytesView[index] == UInt8(ascii: "=") else {
                        throw ParserError(hint: "Found invalid character (expecting =) \(String(decoding: readableBytesView, as: Unicode.UTF8.self))")
                    }
                }
            }
            guard bytes.readableBytes % 4 == 0 else {
                throw ParserError(hint: "Base64 not divisible by 4 \(readableBytesView)")
            }
            return bytes
        }
    }

    // body            = "(" (body-type-1part / body-type-mpart) ")"
    static func parseBody(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body {

        func parseBody_singlePart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let part = try self.parseBodyTypeSinglePart(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .singlepart(part)
        }

        func parseBody_multiPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let part = try self.parseBodyTypeMultipart(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .multipart(part)
        }

        return try ParserLibrary.parseOneOf([
            parseBody_singlePart,
            parseBody_multiPart
        ], buffer: &buffer, tracker: tracker)
    }

    // body-extension  = nstring / number /
    //                    "(" body-extension *(SP body-extension) ")"
    static func parseBodyExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.BodyExtensionType] {

        func parseBodyExtensionType_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.BodyExtensionType {
            return .string(try self.parseNString(buffer: &buffer, tracker: tracker))
        }

        func parseBodyExtensionType_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.BodyExtensionType {
            return .number(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }
        
        func parseBodyExtensionType(buffer: inout ByteBuffer, tracker: StackTracker, into array: inout [NIOIMAP.BodyExtensionType]) throws {
            let element = try ParserLibrary.parseOneOf([
                parseBodyExtensionType_string,
                parseBodyExtensionType_number
            ], buffer: &buffer, tracker: tracker)
            array.append(element)
        }

        func parseBodyExtension_array(buffer: inout ByteBuffer, tracker: StackTracker, into array: inout [NIOIMAP.BodyExtensionType]) throws {
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
        
        func parseBodyExtension_arrayOrStatic(buffer: inout ByteBuffer, tracker: StackTracker, into array: inout [NIOIMAP.BodyExtensionType]) throws {
            let save = buffer
            do {
                try parseBodyExtensionType(buffer: &buffer, tracker: tracker, into: &array)
            } catch is ParserError {
                buffer = save
                try parseBodyExtension_array(buffer: &buffer, tracker: tracker, into: &array)
            }
        }

        var array = [NIOIMAP.BodyExtensionType]()
        try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
        return array
    }

    // body-ext-1part  = body-fld-md5 [SP body-fld-dsp [SP body-fld-lang [SP body-fld-loc *(SP body-extension)]]]
    static func parseBodyExtSinglePart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.ExtensionSinglepart {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Body.ExtensionSinglepart in
            let md5 = try self.parseNString(buffer: &buffer, tracker: tracker)
            let dsp = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Body.FieldDSPLanguage in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try parseBodyDescriptionLanguage(buffer: &buffer, tracker: tracker)
            }
            return NIOIMAP.Body.ExtensionSinglepart(fieldMD5: md5, dspLanguage: dsp)
        }
    }

    // body-ext-mpart  = body-fld-param [SP body-fld-dsp [SP body-fld-lang [SP body-fld-loc *(SP body-extension)]]]
    static func parseBodyExtMpart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.ExtensionMultipart {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Body.ExtensionMultipart in
            let param = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            let dsp = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Body.FieldDSPLanguage in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try parseBodyDescriptionLanguage(buffer: &buffer, tracker: tracker)
            }
            return NIOIMAP.Body.ExtensionMultipart(parameter: param, dspLanguage: dsp)
        }
    }

    // body-fields     = body-fld-param SP body-fld-id SP body-fld-desc SP
    //                   body-fld-enc SP body-fld-octets
    static func parseBodyFields(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.Fields {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Body.Fields in
            let fieldParam = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldID = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldDescription = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldEncoding = try self.parseBodyFieldEncoding(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldOctets = try self.parseBodyFieldOctets(buffer: &buffer, tracker: tracker)
            return NIOIMAP.Body.Fields(
                parameter: fieldParam,
                id: fieldID,
                description: fieldDescription,
                encoding: fieldEncoding,
                octets: fieldOctets
            )
        }
    }

    // body-fld-dsp    = "(" string SP body-fld-param ")" / nil
    static func parseBodyFieldDsp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldDSPData? {

        func parseBodyFieldDsp_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldDSPData? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseBodyFieldDsp_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldDSPData? {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let string = try self.parseString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let param = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return NIOIMAP.Body.FieldDSPData(string: string, parameter: param)
        }

        return try ParserLibrary.parseOneOf([
            parseBodyFieldDsp_nil,
            parseBodyFieldDsp_some
        ], buffer: &buffer, tracker: tracker)
    }

    // body-fld-enc    = (DQUOTE ("7BIT" / "8BIT" / "BINARY" / "BASE64"/
    //                   "QUOTED-PRINTABLE") DQUOTE) / string
    static func parseBodyFieldEncoding(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldEncoding {

        func parseBodyFieldEncoding_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldEncoding {
            return .string(try self.parseString(buffer: &buffer, tracker: tracker))
        }

        func parseBodyFieldEncoding_option(_ option: String, result: NIOIMAP.Body.FieldEncoding, buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldEncoding {
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(option, buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return result
        }

        func parseBodyFieldEncoding_7bit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldEncoding {
            return try parseBodyFieldEncoding_option("7BIT", result: .bit7, buffer: &buffer, tracker: tracker)
        }

        func parseBodyFieldEncoding_8bit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldEncoding {
            return try parseBodyFieldEncoding_option("8BIT", result: .bit8, buffer: &buffer, tracker: tracker)
        }

        func parseBodyFieldEncoding_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldEncoding {
            return try parseBodyFieldEncoding_option("BINARY", result: .binary, buffer: &buffer, tracker: tracker)
        }

        func parseBodyFieldEncoding_base64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldEncoding {
            return try parseBodyFieldEncoding_option("BASE64", result: .base64, buffer: &buffer, tracker: tracker)
        }

        func parseBodyFieldEncoding_quotePrintable(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldEncoding {
            return try parseBodyFieldEncoding_option("QUOTED-PRINTABLE", result: .quotedPrintable, buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseOneOf([
            parseBodyFieldEncoding_7bit,
            parseBodyFieldEncoding_8bit,
            parseBodyFieldEncoding_binary,
            parseBodyFieldEncoding_base64,
            parseBodyFieldEncoding_quotePrintable,
            parseBodyFieldEncoding_string
        ], buffer: &buffer, tracker: tracker)
    }

    // body-fld-lang   = nstring / "(" string *(SP string) ")"
    static func parseBodyFieldLanguage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldLanguage {

        func parseBodyFieldLanguage_single(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldLanguage {
            return .single(try self.parseNString(buffer: &buffer, tracker: tracker))
        }

        func parseBodyFieldLanguage_multiple(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldLanguage {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseString(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseString(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .multiple(array)
        }

        return try ParserLibrary.parseOneOf([
            parseBodyFieldLanguage_multiple,
            parseBodyFieldLanguage_single
        ], buffer: &buffer, tracker: tracker)
    }

    // body-fld-lines  = number
    static func parseBodyFieldLines(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        return try self.parseNumber(buffer: &buffer, tracker: tracker)
    }

    // body-fld-octets = number
    static func parseBodyFieldOctets(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        return try self.parseNumber(buffer: &buffer, tracker: tracker)
    }

    // body-fld-param  = "(" string SP string *(SP string SP string) ")" / nil
    static func parseBodyFieldParam(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer]? {

        func parseBodyFieldParam_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer]? {
            try parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseBodyFieldParam_pairs(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer]? {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try parseString(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseString(buffer: &buffer, tracker: tracker)
            }

            guard array.count % 2 == 0 else {
                throw ParserError(hint: "Field parameteres expected in pairs")
            }

            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try ParserLibrary.parseOneOf([
            parseBodyFieldParam_pairs,
            parseBodyFieldParam_nil
        ], buffer: &buffer, tracker: tracker)
    }

    // body-type-1part = (body-type-basic / body-type-msg / body-type-text)
    //                   [SP body-ext-1part]
    static func parseBodyTypeSinglePart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.TypeSinglepart {

        func parseBodyTypeSinglePart_basic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.TypeSinglepartType {
            return .basic(try self.parseBodyTypeBasic(buffer: &buffer, tracker: tracker))
        }

        func parseBodyTypeSinglePart_message(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.TypeSinglepartType {
            return .message(try self.parseBodyTypeMessage(buffer: &buffer, tracker: tracker))
        }

        func parseBodyTypeSinglePart_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.TypeSinglepartType {
            return .text(try self.parseBodyTypeText(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Body.TypeSinglepart in
            let type = try ParserLibrary.parseOneOf([
                parseBodyTypeSinglePart_basic,
                parseBodyTypeSinglePart_message,
                parseBodyTypeSinglePart_text
            ], buffer: &buffer, tracker: tracker)
            let ext = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Body.ExtensionSinglepart in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseBodyExtSinglePart(buffer: &buffer, tracker: tracker)
            }
            return NIOIMAP.Body.TypeSinglepart(type: type, extension: ext)
        }
    }

    // body-type-basic = media-basic SP body-fields
    static func parseBodyTypeBasic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.TypeBasic {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Body.TypeBasic in
            let media = try self.parseMediaBasic(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            return NIOIMAP.Body.TypeBasic(media: media, fields: fields)
        }
    }

    // body-type-mpart = 1*body SP media-subtype
    //                   [SP body-ext-mpart]
    static func parseBodyTypeMultipart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.TypeMultipart {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Body.TypeMultipart in
            let bodies = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try self.parseBody(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let media = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            let ext = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Body.ExtensionMultipart in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseBodyExtMpart(buffer: &buffer, tracker: tracker)
            }
            return NIOIMAP.Body.TypeMultipart(bodies: bodies, mediaSubtype: media, multipartExtension: ext)
        }
    }

    // body-type-msg   = media-message SP body-fields SP envelope
    //                   SP body SP body-fld-lines
    static func parseBodyTypeMessage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.TypeMessage {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Body.TypeMessage in
            let message = try self.parseMediaMessage(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let bodyFields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let envelope = try self.parseEnvelope(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let body = try self.parseBody(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldLines = try self.parseBodyFieldLines(buffer: &buffer, tracker: tracker)
            return NIOIMAP.Body.TypeMessage(message: message, fields: bodyFields, envelope: envelope, body: body, fieldLines: fieldLines)
        }
    }

    // body-type-text  = media-text SP body-fields SP body-fld-lines
    static func parseBodyTypeText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.TypeText {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Body.TypeText in
            let media = try self.parseMediaText(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let bodyFields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldLines = try self.parseBodyFieldLines(buffer: &buffer, tracker: tracker)
            return NIOIMAP.Body.TypeText(mediaText: media, fields: bodyFields, lines: fieldLines)
        }
    }

    // capability      = ("AUTH=" auth-type) / atom / "MOVE" / "ENABLE" / "FILTERS"
    static func parseCapability(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Capability {

        func parseCapability_auth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Capability {
            try ParserLibrary.parseFixedString("AUTH=", buffer: &buffer, tracker: tracker)
            let authType = try parseAuthType(buffer: &buffer, tracker: tracker)
            return .auth(authType)
        }

        func parseCapability_atom(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Capability {
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .other(atom)
        }

        func parseCapability_condStore(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Capability {
            try ParserLibrary.parseFixedString("CONDSTORE", buffer: &buffer, tracker: tracker)
            return .condStore
        }

        func parseCapability_enable(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Capability {
            try ParserLibrary.parseFixedString("ENABLE", buffer: &buffer, tracker: tracker)
            return .enable
        }

        func parseCapability_move(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Capability {
            try ParserLibrary.parseFixedString("MOVE", buffer: &buffer, tracker: tracker)
            return .move
        }

        func parseCapability_filters(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Capability {
            try ParserLibrary.parseFixedString("FILTERS", buffer: &buffer, tracker: tracker)
            return .filters
        }

        return try ParserLibrary.parseOneOf([
            parseCapability_move,
            parseCapability_enable,
            parseCapability_condStore,
            parseCapability_auth,
            parseCapability_filters,
            parseCapability_atom,
        ], buffer: &buffer, tracker: tracker)
    }

    // capability-data = "CAPABILITY" *(SP capability) SP "IMAP4rev1"
    //                   *(SP capability)
    static func parseCapabilityData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.Capability] {

        func parseCapabilityData_constant(buffer: inout ByteBuffer, tracker: StackTracker) throws {

            func parseCapabilityData_constant_1(buffer: inout ByteBuffer, tracker: StackTracker) throws {
                try ParserLibrary.parseFixedString(" IMAP4rev1", buffer: &buffer, tracker: tracker)
            }

            func parseCapabilityData_constant_2(buffer: inout ByteBuffer, tracker: StackTracker) throws {
                try ParserLibrary.parseFixedString(" IMAP4", buffer: &buffer, tracker: tracker)
            }

            try ParserLibrary.parseOneOf([
                parseCapabilityData_constant_1,
                parseCapabilityData_constant_2
            ], buffer: &buffer, tracker: tracker)
        }

        func parseCapabilityData_single(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Capability {
            return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }

        func parseCapabilityData_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.Capability] {
            var array = [NIOIMAP.Capability]()
            var shouldContinue = true
            while shouldContinue {
                do {
                    try parseCapabilityData_constant(buffer: &buffer, tracker: tracker)
                } catch {
                    do {
                        array.append(try parseCapabilityData_single(buffer: &buffer, tracker: tracker))
                    } catch {
                        shouldContinue = false
                    }
                }
            }
            return array
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [NIOIMAP.Capability] in
            try ParserLibrary.parseFixedString("CAPABILITY", buffer: &buffer, tracker: tracker)
            return try parseCapabilityData_array(buffer: &buffer, tracker: tracker)
        }
    }

    // charset          = atom / quoted
    static func parseCharset(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {

        func parseCharset_atom(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            return try parseAtom(buffer: &buffer, tracker: tracker)
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
            parseCharset_quoted
        ], buffer: &buffer, tracker: tracker)
    }

    // childinfo-extended-item =  "CHILDINFO" SP "("
    //             list-select-base-opt-quoted
    //             *(SP list-select-base-opt-quoted) ")"
    static func parseChildinfoExtendedItem(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ChildInfoExtendedItem {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.ChildInfoExtendedItem in
            try ParserLibrary.parseFixedString("CHILDINFO (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.ListSelectBaseOptionQuoted in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // child-mbox-flag =  "\HasChildren" / "\HasNoChildren"
    static func parseChildMailboxFlag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ChildMailboxFlag {

        func parseChildMailboxFlag_children(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ChildMailboxFlag {
            try ParserLibrary.parseFixedString(#"\HasChildren"#, buffer: &buffer, tracker: tracker)
            return .HasChildren
        }

        func parseChildMailboxFlag_noChildren(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ChildMailboxFlag {
            try ParserLibrary.parseFixedString(#"\HasNoChildren"#, buffer: &buffer, tracker: tracker)
            return .HasNoChildren
        }

        return try ParserLibrary.parseOneOf([
            parseChildMailboxFlag_children,
            parseChildMailboxFlag_noChildren
        ], buffer: &buffer, tracker: tracker)
    }

    // command         = tag SP (command-any / command-auth / command-nonauth /
    //                   command-select) CRLF
    static func parseCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Command {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Command in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let type = try ParserLibrary.parseOneOf([
                self.parseCommandAny,
                self.parseCommandAuth,
                self.parseCommandNonauth,
                self.parseCommandSelect
            ], buffer: &buffer, tracker: tracker)
            return NIOIMAP.Command(tag, type)
        }
    }
    
    static func parseCommandEnd(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
    }

    // command-any     = "CAPABILITY" / "LOGOUT" / "NOOP" / enable / x-command / id
    static func parseCommandAny(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {

        func parseCommandAny_capability(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
            try ParserLibrary.parseFixedString("CAPABILITY", buffer: &buffer, tracker: tracker)
            return .capability
        }

        func parseCommandAny_logout(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
            try ParserLibrary.parseFixedString("LOGOUT", buffer: &buffer, tracker: tracker)
            return .logout
        }

        func parseCommandAny_noop(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
            try ParserLibrary.parseFixedString("NOOP", buffer: &buffer, tracker: tracker)
            return .noop
        }

        func parseCommandAny_xcommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
            let command = try self.parseXCommand(buffer: &buffer, tracker: tracker)
            return .xcommand(command)
        }

        func parseCommandAny_id(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
            let id = try self.parseID(buffer: &buffer, tracker: tracker)
            return .id(id)
        }

        func parseCommandAny_enable(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
            let enable = try self.parseEnable(buffer: &buffer, tracker: tracker)
            return enable
        }

        return try ParserLibrary.parseOneOf([
            parseCommandAny_xcommand,
            parseCommandAny_noop,
            parseCommandAny_logout,
            parseCommandAny_capability,
            parseCommandAny_id,
            parseCommandAny_enable
        ], buffer: &buffer, tracker: tracker)
    }

    // command-auth    = append / create / delete / examine / list / lsub /
    //                   Namespace-Command /
    //                   rename / select / status / subscribe / unsubscribe /
    //                   idle
    static func parseCommandAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseOneOf([
            self.parseAppend,
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
            self.parseNamespaceCommand
        ], buffer: &buffer, tracker: tracker)
    }

    // command-nonauth = login / authenticate / "STARTTLS"
    static func parseCommandNonauth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {

        func parseCommandNonauth_starttls(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
            try ParserLibrary.parseFixedString("STARTTLS", buffer: &buffer, tracker: tracker)
            return .starttls
        }

        return try ParserLibrary.parseOneOf([
            self.parseLogin,
            self.parseAuthenticate,
            parseCommandNonauth_starttls
        ], buffer: &buffer, tracker: tracker)
    }

    // command-select  = "CHECK" / "CLOSE" / "UNSELECT" / "EXPUNGE" / copy / fetch / store /
    //                   uid / search / move
    static func parseCommandSelect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {

        func parseCommandSelect_check(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
            try ParserLibrary.parseFixedString("CHECK", buffer: &buffer, tracker: tracker)
            return .check
        }

        func parseCommandSelect_close(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
            try ParserLibrary.parseFixedString("CLOSE", buffer: &buffer, tracker: tracker)
            return .close
        }

        func parseCommandSelect_expunge(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
            try ParserLibrary.parseFixedString("EXPUNGE", buffer: &buffer, tracker: tracker)
            return .expunge
        }

        func parseCommandSelect_unselect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
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
            self.parseMove
        ], buffer: &buffer, tracker: tracker)
    }

    // condstore-param = "CONDSTORE"
    static func parseConditionalStoreParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseFixedString("CONDSTORE", buffer: &buffer, tracker: tracker)
    }

    // continue-req    = "+" SP (resp-text / base64) CRLF
    static func parseContinueRequest(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ContinueRequest {

        func parseContinueReq_responseText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ContinueRequest {
            return .responseText(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseContinueReq_base64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ContinueRequest {
            return .base64(try self.parseBase64(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.ContinueRequest in
            try ParserLibrary.parseFixedString("+ ", buffer: &buffer, tracker: tracker)
            let continueReq = try ParserLibrary.parseOneOf([
                parseContinueReq_base64,
                parseContinueReq_responseText,
            ], buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
            return continueReq
        }
    }

    // copy            = "COPY" SP sequence-set SP mailbox
    static func parseCopy(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("COPY ", buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .copy(sequence, mailbox)
        }
    }

    // create          = "CREATE" SP mailbox [create-params]
    static func parseCreate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("CREATE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseCreateParameters)
            return .create(mailbox, params)
        }
    }
    
    // create-param = create-param-name [SP create-param-value]
    static func parseCreateParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CreateParameter {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseCreateParameterName(buffer: &buffer, tracker: tracker)
            let value = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.TaggedExtensionValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseCreateParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .name(name, value: value)
        }
    }

    // create-params = SP "(" create-param *(SP create-param-value) ")"
    static func parseCreateParameters(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.CreateParameter] {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseCreateParameter(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.CreateParameter in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseCreateParameter(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }
    
    // create-param-name = tagged-ext-label
    static func parseCreateParameterName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
    }
    
    // create-param-value = tagged-ext-val
    static func parseCreateParameterValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionValue {
        return try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }

    // date            = date-text / DQUOTE date-text DQUOTE
    static func parseDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Date {

        func parseDateText_quoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Date {
            return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
                let date = try self.parseDateText(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
                return date
            }
        }

        return try ParserLibrary.parseOneOf([
            parseDateText,
            parseDateText_quoted
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
            parse2Digit
        ], buffer: &buffer, tracker: tracker)
    }

    // date-month      = "Jan" / "Feb" / "Mar" / "Apr" / "May" / "Jun" /
    //                   "Jul" / "Aug" / "Sep" / "Oct" / "Nov" / "Dec"
    static func parseDateMonth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Date.Month {
        let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            isalnum(Int32(char)) != 0
        }
        guard let month = NIOIMAP.Date.Month(rawValue: string.lowercased()) else {
            throw ParserError(hint: "No date-month match for \(string)")
        }
        return month
    }

    // date-text       = date-day "-" date-month "-" date-year
    static func parseDateText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Date {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let day = try self.parseDateDay(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let month = try self.parseDateMonth(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let year = try self.parseDateYear(buffer: &buffer, tracker: tracker)
            return NIOIMAP.Date(day: day, month: month, year: year)
        }
    }

    // date-year       = 4DIGIT
    static func parseDateYear(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        return try self.parse4Digit(buffer: &buffer, tracker: tracker)
    }

    // date-time       = DQUOTE date-day-fixed "-" date-month "-" date-year
    //                   SP time SP zone DQUOTE
    static func parseDateTime(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Date.DateTime {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            let day = try self.parseDateDayFixed(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let month = try self.parseDateMonth(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let year = try self.parseDateYear(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let time = try self.parseTime(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let zone = try self.parseZone(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return NIOIMAP.Date.DateTime(date: NIOIMAP.Date(day: day, month: month, year: year), time: time, zone: zone)
        }
    }

    // delete          = "DELETE" SP mailbox
    static func parseDelete(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("DELETE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .delete(mailbox)
        }
    }

    // eitem-standard-tag =  atom
    static func parseEitemStandardTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try self.parseAtom(buffer: &buffer, tracker: tracker)
    }

    // eitem-vendor-tag =  vendor-token "-" atom
    static func parseEitemVendorTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.EItemVendorTag {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.EItemVendorTag in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return NIOIMAP.EItemVendorTag(token: token, atom: atom)
        }
    }

    // enable          = "ENABLE" 1*(SP capability)
    static func parseEnable(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("ENABLE", buffer: &buffer, tracker: tracker)
            let capabilities = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Capability in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
            return .enable(capabilities)
        }
    }

    // enable-data     = "ENABLED" *(SP capability)
    static func parseEnableData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.Capability] {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [NIOIMAP.Capability] in
            try ParserLibrary.parseFixedString("ENABLED", buffer: &buffer, tracker: tracker)
            return try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Capability in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }
    }

    // envelope        = "(" env-date SP env-subject SP env-from SP
    //                   env-sender SP env-reply-to SP env-to SP env-cc SP
    //                   env-bcc SP env-in-reply-to SP env-message-id ")"
    static func parseEnvelope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Envelope {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Envelope in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let date = try self.parseNString(buffer: &buffer, tracker: tracker)
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
            let messageID = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return NIOIMAP.Envelope(
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
    static func parseEntryTypeRequest(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.EntryTypeRequest {

        func parseEntryTypeRequest_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.EntryTypeRequest {
            try ParserLibrary.parseFixedString("all", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseEntryTypeRequest_response(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.EntryTypeRequest {
            return .response(try self.parseEntryTypeResponse(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseEntryTypeRequest_all,
            parseEntryTypeRequest_response
        ], buffer: &buffer, tracker: tracker)
    }

    // entry-type-resp = "priv" / "shared"
    static func parseEntryTypeResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.EntryTypeResponse {

        func parseEntryTypeResponse_private(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.EntryTypeResponse {
            try ParserLibrary.parseFixedString("priv", buffer: &buffer, tracker: tracker)
            return .private
        }

        func parseEntryTypeResponse_shared(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.EntryTypeResponse {
            try ParserLibrary.parseFixedString("shared", buffer: &buffer, tracker: tracker)
            return .shared
        }

        return try ParserLibrary.parseOneOf([
            parseEntryTypeResponse_private,
            parseEntryTypeResponse_shared
        ], buffer: &buffer, tracker: tracker)
    }

    // esearch-response  = "ESEARCH" [search-correlator] [SP "UID"]
    //                     *(SP search-return-data)
    static func parseEsearchResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ESearchResponse {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("ESEARCH", buffer: &buffer, tracker: tracker)
            let correlator = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSearchCorrelator)
            let uid = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString(" UID", buffer: &buffer, tracker: tracker)
                return true
                } ?? false
            let searchReturnData = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.SearchReturnData in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSearchReturnData(buffer: &buffer, tracker: tracker)
            }
            return NIOIMAP.ESearchResponse(correlator: correlator, uid: uid, returnData: searchReturnData)
        }
    }

    // examine         = "EXAMINE" SP mailbox [select-params
    static func parseExamine(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("EXAMINE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSelectParameters)
            return .examine(mailbox, params)
        }
    }

    // fetch           = "FETCH" SP sequence-set SP ("ALL" / "FULL" / "FAST" /
    //                   fetch-att / "(" fetch-att *(SP fetch-att) ")") [fetch-modifiers]
    static func parseFetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {

        func parseFetch_type_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchType {
            try ParserLibrary.parseFixedString("ALL", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseFetch_type_full(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchType {
            try ParserLibrary.parseFixedString("FULL", buffer: &buffer, tracker: tracker)
            return .full
        }

        func parseFetch_type_fast(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchType {
            try ParserLibrary.parseFixedString("FAST", buffer: &buffer, tracker: tracker)
            return .fast
        }

        func parseFetch_type_singleAtt(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchType {
            return .attributes([try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)])
        }

        func parseFetch_type_multiAtt(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchType {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.FetchAttribute in
                try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
                return try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .attributes(array)
        }

        func parseFetch_type(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchType {
            return try ParserLibrary.parseOneOf([
                parseFetch_type_all,
                parseFetch_type_full,
                parseFetch_type_fast,
                parseFetch_type_singleAtt,
                parseFetch_type_multiAtt
            ], buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("FETCH ", buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let att = try parseFetch_type(buffer: &buffer, tracker: tracker)
            let modifiers = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseFetchModifiers)
            return .fetch(sequence, att, modifiers)
        }
    }

    // fetch-att       = "ENVELOPE" / "FLAGS" / "INTERNALDATE" /
    //                   "RFC822.SIZE" /
    //                   "BODY" ["STRUCTURE"] / "UID" /
    //                   "BODY" section [partial] /
    //                   "BODY.PEEK" section [partial] /
    //                   "BINARY" [".PEEK"] section-binary [partial] /
    //                   "BINARY.SIZE" section-binary
    // TODO: rev2
    static func parseFetchAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchAttribute {

        func parseFetchAttribute_envelope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchAttribute {
            try ParserLibrary.parseFixedString("ENVELOPE", buffer: &buffer, tracker: tracker)
            return .envelope
        }

        func parseFetchAttribute_flags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchAttribute {
            try ParserLibrary.parseFixedString("FLAGS", buffer: &buffer, tracker: tracker)
            return .flags
        }

        func parseFetchAttribute_internalDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchAttribute {
            try ParserLibrary.parseFixedString("INTERNALDATE", buffer: &buffer, tracker: tracker)
            return .internaldate
        }

        func parseFetchAttribute_UID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchAttribute {
            try ParserLibrary.parseFixedString("UID", buffer: &buffer, tracker: tracker)
            return .uid
        }

        func parseFetchAttribute_rfc822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchAttribute {
            try ParserLibrary.parseFixedString("RFC822", buffer: &buffer, tracker: tracker)
            let rfc = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.RFC822 in
                try self.parseRFC822(buffer: &buffer, tracker: tracker)
            }
            return .rfc822(rfc)
        }

        func parseFetchAttribute_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchAttribute {
            try ParserLibrary.parseFixedString("BODY", buffer: &buffer, tracker: tracker)
            let structure: Bool = {
                do {
                    try ParserLibrary.parseFixedString("STRUCTURE", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    return false
                }
            }()
            return .body(structure: structure)
        }

        func parseFetchAttribute_bodySection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchAttribute {
            try ParserLibrary.parseFixedString("BODY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let chevronNumber = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Partial in
                try self.parsePartial(buffer: &buffer, tracker: tracker)
            }
            return .bodySection(section, chevronNumber)
        }

        func parseFetchAttribute_bodyPeekSection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchAttribute {
            try ParserLibrary.parseFixedString("BODY.PEEK", buffer: &buffer, tracker: tracker)
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let chevronNumber = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Partial in
                try self.parsePartial(buffer: &buffer, tracker: tracker)
            }
            return .bodyPeekSection(section, chevronNumber)
        }

        func parseFetchAttribute_modSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchAttribute {
            return .modSequence(try self.parseModifierSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseFetchAttribute_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchAttribute {
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

        func parseFetchAttribute_binarySize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchAttribute {
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
            parseFetchAttribute_binarySize
        ], buffer: &buffer, tracker: tracker)
    }
    
    // fetch-modifier = fetch-modifier-name [SP fetch-modifier-params]
    static func parseFetchModifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.FetchModifier {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseFetchModifierName(buffer: &buffer, tracker: tracker)
            let value = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.TaggedExtensionValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseFetchModifierParameter(buffer: &buffer, tracker: tracker)
            }
            return .name(name, value: value)
        }
    }

    // fetch-modifiers = SP "(" fetch-modifier *(SP fetch-modifier) ")"
    static func parseFetchModifiers(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.FetchModifier] {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseFetchModifier(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.FetchModifier in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseFetchModifier(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }
    
    // fetch-modifier-name = tagged-ext-label
    static func parseFetchModifierName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
    }
    
    // fetch-modifier-params = tagged-ext-val
    static func parseFetchModifierParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionValue {
        return try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }

    // filter-name = 1*<any ATOM-CHAR except "/">
    static func parseFilterName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            return char.isAtomChar && char != UInt8(ascii: "/")
        }
    }

    // flag            = "\Answered" / "\Flagged" / "\Deleted" /
    //                   "\Seen" / "\Draft" / flag-keyword / flag-extension
    static func parseFlag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Flag {

        func parseFlag_answered(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Flag {
            try ParserLibrary.parseFixedString("\\Answered", buffer: &buffer, tracker: tracker)
            return .answered
        }

        func parseFlag_flagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Flag {
            try ParserLibrary.parseFixedString("\\Flagged", buffer: &buffer, tracker: tracker)
            return .flagged
        }

        func parseFlag_deleted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Flag {
            try ParserLibrary.parseFixedString("\\Deleted", buffer: &buffer, tracker: tracker)
            return .deleted
        }

        func parseFlag_seen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Flag {
            try ParserLibrary.parseFixedString("\\Seen", buffer: &buffer, tracker: tracker)
            return .seen
        }

        func parseFlag_draft(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Flag {
            try ParserLibrary.parseFixedString("\\Draft", buffer: &buffer, tracker: tracker)
            return .draft
        }

        func parseFlag_keyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Flag {
            let word = try self.parseFlagKeyword(buffer: &buffer, tracker: tracker)
            return .keyword(word)
        }

        func parseFlag_extension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Flag {
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
            parseFlag_extension
        ], buffer: &buffer, tracker: tracker)
    }

    // flag-extension  = "\" atom
    static func parseFlagExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in
            try ParserLibrary.parseFixedString("\\", buffer: &buffer, tracker: tracker)
            return try self.parseAtom(buffer: &buffer, tracker: tracker )
        }
    }

    // flag-fetch      = flag
    static func parseFlagFetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Flag {
        return try self.parseFlag(buffer: &buffer, tracker: tracker)
    }

    // flag-keyword    = "$MDNSent" / "$Forwarded" / atom
    static func parseFlagKeyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Flag.Keyword {

        func parseFlag_keyword_sent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Flag.Keyword {
            try ParserLibrary.parseFixedString("$MDNSent", buffer: &buffer, tracker: tracker)
            return .mdnSent
        }

        func parseFlag_keyword_forwarded(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Flag.Keyword {
            try ParserLibrary.parseFixedString("$Forwarded", buffer: &buffer, tracker: tracker)
            return .forwarded
        }

        func parseFlag_keyword_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Flag.Keyword {
            return .other(try self.parseAtom(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseFlag_keyword_sent,
            parseFlag_keyword_forwarded,
            parseFlag_keyword_other
        ], buffer: &buffer, tracker: tracker)
    }

    // flag-list       = "(" [flag *(SP flag)] ")"
    static func parseFlagList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.Flag] {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let flags = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, track) -> [NIOIMAP.Flag] in
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
    static func parseFlagPerm(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.PermanentFlag {
        func parseFlagPerm_wildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.PermanentFlag {
            try ParserLibrary.parseFixedString("\\*", buffer: &buffer, tracker: tracker)
            return .wildcard
        }

        func parseFlagPerm_flag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.PermanentFlag {
            return .flag(try self.parseFlag(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseFlagPerm_wildcard,
            parseFlagPerm_flag
        ], buffer: &buffer, tracker: tracker)
    }

    // greeting        = "*" SP (resp-cond-auth / resp-cond-bye) CRLF
    static func parseGreeting(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Greeting {

        func parseGreeting_auth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Greeting {
            return .auth(try self.parseResponseConditionalAuth(buffer: &buffer, tracker: tracker))
        }

        func parseGreeting_bye(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Greeting {
            return .bye(try self.parseResponseConditionalBye(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Greeting in
            try ParserLibrary.parseFixedString("* ", buffer: &buffer, tracker: tracker)
            let greeting = try ParserLibrary.parseOneOf([
                parseGreeting_auth,
                parseGreeting_bye
            ], buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
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
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [String] in
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
    static func parseID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ID {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("ID ", buffer: &buffer, tracker: tracker)
            return try parseIDParamsList(buffer: &buffer, tracker: tracker)
        }
    }

    // id-response = "ID" SP id-params-list
    static func parseIDResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.IDResponse {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("ID ", buffer: &buffer, tracker: tracker)
            return try parseIDParamsList(buffer: &buffer, tracker: tracker)
        }
    }

    // id-params-list = "(" *(string SP nstring) ")" / nil
    static func parseIDParamsList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.IDParamsList {

        func parseIDParamsList_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.IDParamsList {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseIDParamsList_element(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.IDParamsListElement {
            let key = try self.parseString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let value = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .key(key, value: value)
        }

        func parseIDParamsList_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.IDParamsList {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try parseIDParamsList_element(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.IDParamsListElement in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try parseIDParamsList_element(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try ParserLibrary.parseOneOf([
            parseIDParamsList_nil,
            parseIDParamsList_some
        ], buffer: &buffer, tracker: tracker)
    }

    // idle            = "IDLE" CRLF "DONE"
    static func parseIdleStart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        try ParserLibrary.parseFixedString("IDLE", buffer: &buffer, tracker: tracker)
        return .idleStart
    }

    static func parseIdleDone(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseFixedString("DONE\r\n", buffer: &buffer, tracker: tracker)
    }

    // initial-resp    =  (base64 / "=")
    static func parseInitialResp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.InitialResponse {

        func parseInitialResp_equals(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.InitialResponse {
            try ParserLibrary.parseFixedString("=", buffer: &buffer, tracker: tracker)
            return .equals
        }

        func parseInitialResp_base64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.InitialResponse {
            return .base64(try self.parseBase64(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseInitialResp_equals,
            parseInitialResp_base64
        ], buffer: &buffer, tracker: tracker)
    }

    // list            = "LIST" [SP list-select-opts] SP mailbox SP mbox-or-pat [SP list-return-opts]
    static func parseList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("LIST", buffer: &buffer, tracker: tracker)
            let selectOptions = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.ListSelectOptions in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectOptions(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let mailboxPatterns = try self.parseMailboxPatterns(buffer: &buffer, tracker: tracker)
            let returnOptions = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [NIOIMAP.ReturnOption] in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseListReturnOptions(buffer: &buffer, tracker: tracker)
            } ?? []
            return .list(selectOptions, mailbox, mailboxPatterns, returnOptions)
        }
    }

    // list-select-base-opt =  "SUBSCRIBED" / option-extension
    static func parseListSelectBaseOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectBaseOption {

        func parseListSelectBaseOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectBaseOption {
            try ParserLibrary.parseFixedString("SUBSCRIBED", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseListSelectBaseOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectBaseOption {
            return .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseListSelectBaseOption_subscribed,
            parseListSelectBaseOption_optionExtension
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-base-opt-quoted =  DQUOTE list-select-base-opt DQUOTE
    static func parseListSelectBaseOptionQuoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectBaseOptionQuoted {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.ListSelectBaseOptionQuoted in
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            let option = try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return option
        }
    }

    // list-select-independent-opt =  "REMOTE" / option-extension
    static func parseListSelectIndependentOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectIndependentOption {

        func parseListSelectIndependentOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectIndependentOption {
            try ParserLibrary.parseFixedString("REMOTE", buffer: &buffer, tracker: tracker)
            return .remote
        }

        func parseListSelectIndependentOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectIndependentOption {
            return .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseListSelectIndependentOption_subscribed,
            parseListSelectIndependentOption_optionExtension
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-mod-opt =  "RECURSIVEMATCH" / option-extension
    static func parseListSelectModOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectModOption {

        func parseListSelectModOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectModOption {
            try ParserLibrary.parseFixedString("RECURSIVEMATCH", buffer: &buffer, tracker: tracker)
            return .recursiveMatch
        }

        func parseListSelectModOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectModOption {
            return .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseListSelectModOption_subscribed,
            parseListSelectModOption_optionExtension
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-opt =  list-select-base-opt / list-select-independent-opt
    //                    / list-select-mod-opt
    static func parseListSelectOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectOption {

        func parseListSelectOption_base(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectOption {
            return .base(try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker))
        }

        func parseListSelectOption_independent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectOption {
            return .independent(try self.parseListSelectIndependentOption(buffer: &buffer, tracker: tracker))
        }

        func parseListSelectOption_mod(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectOption {
            return .mod(try self.parseListSelectModOption(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseListSelectOption_base,
            parseListSelectOption_independent,
            parseListSelectOption_mod
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-opts =  "(" [
    //                    (*(list-select-opt SP) list-select-base-opt
    //                    *(SP list-select-opt))
    //                   / (list-select-independent-opt
    //                    *(SP list-select-independent-opt))
    //                      ] ")"
    static func parseListSelectOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectOptions {

        func parseListSelectOptions_mixed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectionOptionsData {
            var selectOptions = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.ListSelectOption in
                let option = try self.parseListSelectOption(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return option
            }
            let baseOption = try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &selectOptions, tracker: tracker) { (buffer, tracker) -> NIOIMAP.ListSelectOption in
                let option = try self.parseListSelectOption(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return option
            }

            return .select(selectOptions, baseOption)
        }

        func parseListSelectOptions_independent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ListSelectionOptionsData {
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
                return try ParserLibrary.parseOneOf([
                    parseListSelectOptions_mixed,
                    parseListSelectOptions_independent
                ], buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return options
        }
    }

    static func parseLiteralSize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Int in
            try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString("~", buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("}\r\n", buffer: &buffer, tracker: tracker)
            return length
        }
    }

    // mbox-or-pat  = list-mailbox / patterns
    static func parseMailboxPatterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MailboxPatterns {

        func parseMailboxPatterns_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MailboxPatterns {
            return .mailbox(try self.parseListMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxPatterns_patterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MailboxPatterns {
            return .pattern(try self.parsePatterns(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseMailboxPatterns_list,
            parseMailboxPatterns_patterns
        ], buffer: &buffer, tracker: tracker)
    }

    // list-return-opt = "RETURN" SP "(" [return-option *(SP return-option)] ")"
    static func parseListReturnOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.ReturnOption] {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("RETURN (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseReturnOption(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.ReturnOption in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseReturnOption(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // list-mailbox    = 1*list-char / string
    static func parseListMailbox(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.ListMailbox {

        func parseListMailbox_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.ListMailbox {
            try self.parseString(buffer: &buffer, tracker: tracker)
        }

        func parseListMailbox_chars(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.ListMailbox {
            try ParserLibrary.parseOneOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isListChar
            }
        }

        return try ParserLibrary.parseOneOf([
            parseListMailbox_string,
            parseListMailbox_chars
        ], buffer: &buffer, tracker: tracker)
    }

    // list-wildcards  = "%" / "*"
    static func parseListWildcards(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        guard let char = buffer.readInteger(as: UInt8.self) else {
            throw NIOIMAP.ParsingError.incompleteMessage
        }
        guard char.isListWildcard else {
            throw ParserError()
        }
        return String(decoding: CollectionOfOne(char), as: Unicode.UTF8.self)
    }

    // literal         = "{" number ["+"] "}" CRLF *CHAR8
    static func parseLiteral(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
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
                throw NIOIMAP.ParsingError.incompleteMessage
            }
        }
    }

    // login           = "LOGIN" SP userid SP password
    static func parseLogin(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("LOGIN ", buffer: &buffer, tracker: tracker)
            let userid = try Self.parseUserId(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let password = try Self.parsePassword(buffer: &buffer, tracker: tracker)
            return .login(userid, password)
        }
    }

    // lsub = "LSUB" SP mailbox SP list-mailbox
    static func parseLSUB(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("LSUB ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let listMailbox = try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            return .lsub(mailbox, listMailbox)
        }
    }

    // mailbox         = "INBOX" / astring
    static func parseMailbox(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox {
        func parseInbox(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox {
            try ParserLibrary.parseFixedString("INBOX", caseSensitive: false, buffer: &buffer, tracker: tracker)
            return .inbox
        }
        func parseOther(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox {
            let bufferedString = try self.parseAString(buffer: &buffer, tracker: tracker)
            let string = String(decoding: bufferedString.readableBytesView, as: Unicode.UTF8.self)
            return NIOIMAP.Mailbox(string)
        }
        return try ParserLibrary.parseOneOf([
            parseInbox,
            parseOther
        ], buffer: &buffer, tracker: tracker)
    }

    // mailbox-data    =  "FLAGS" SP flag-list / "LIST" SP mailbox-list /
    //                    esearch-response /
    //                    "STATUS" SP mailbox SP "(" [status-att-list] ")" /
    //                    number SP "EXISTS" / Namespace-Response
    static func parseMailboxData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.Data {

        func parseMailboxData_flags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.Data {
            try ParserLibrary.parseFixedString("FLAGS ", buffer: &buffer, tracker: tracker)
            return .flags(try self.parseFlagList(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxData_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.Data {
            try ParserLibrary.parseFixedString("LIST ", buffer: &buffer, tracker: tracker)
            return .list(try self.parseMailboxList(buffer: &buffer, tracker: tracker))
        }
        
        func parseMailboxData_lsub(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.Data {
            try ParserLibrary.parseFixedString("LSUB ", buffer: &buffer, tracker: tracker)
            return .lsub(try self.parseMailboxList(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxData_search(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.Data {
            let response = try self.parseEsearchResponse(buffer: &buffer, tracker: tracker)
            return .search(response)
        }

        func parseMailboxData_status(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.Data {
            try ParserLibrary.parseFixedString("STATUS ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let list = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try self.parseStatusAttributeList(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .status(mailbox, list)
        }

        func parseMailboxData_exists(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.Data {
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" EXISTS", buffer: &buffer, tracker: tracker)
            return .exists(number)
        }

        func parseMailboxData_recent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.Data {
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" RECENT", buffer: &buffer, tracker: tracker)
            return .exists(number)
        }

        return try ParserLibrary.parseOneOf([
            parseMailboxData_flags,
            parseMailboxData_list,
            parseMailboxData_lsub,
            parseMailboxData_search,
            parseMailboxData_status,
            parseMailboxData_exists,
            parseMailboxData_recent
        ], buffer: &buffer, tracker: tracker)
    }

    // mailbox-list    = "(" [mbx-list-flags] ")" SP
    //                    (DQUOTE QUOTED-CHAR DQUOTE / nil) SP mailbox
    //                    [SP mbox-list-extended]
    static func parseMailboxList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.List {

        func parseMailboxList_quotedChar_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Character? in
                try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)

                guard let character = buffer.readSlice(length: 1)?.readableBytesView.first else {
                    throw NIOIMAP.ParsingError.incompleteMessage
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

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Mailbox.List in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let flags = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Mailbox.List.Flags in
                return try self.parseMailboxListFlags(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let character = try ParserLibrary.parseOneOf([
                parseMailboxList_quotedChar_some,
                parseMailboxList_quotedChar_nil
            ], buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return NIOIMAP.Mailbox.List(flags: flags, char: character, mailbox: mailbox)
        }
    }

    // mbox-list-extended =  "(" [mbox-list-extended-item
    //                       *(SP mbox-list-extended-item)] ")"
    static func parseMailboxListExtended(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.ListExtended {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Mailbox.ListExtended in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let data = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [NIOIMAP.Mailbox.ListExtendedItem] in
                var array = [try self.parseMailboxListExtendedItem(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Mailbox.ListExtendedItem in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseMailboxListExtendedItem(buffer: &buffer, tracker: tracker)
                }
                return array
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return data
        }
    }

    // mbox-list-extended-item =  mbox-list-extended-item-tag SP
    //                            tagged-ext-val
    static func parseMailboxListExtendedItem(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.ListExtendedItem {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Mailbox.ListExtendedItem in
            let tag = try self.parseMailboxListExtendedItemTag(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let val = try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
            return NIOIMAP.Mailbox.ListExtendedItem(tag: tag, extensionValue: val)
        }
    }

    // mbox-list-extended-item-tag =  astring
    static func parseMailboxListExtendedItemTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.ListExtendedItemTag {
        return try self.parseAString(buffer: &buffer, tracker: tracker)
    }

    // mbox-or-pat =  list-mailbox / patterns
    static func parseMailboxOrPat(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MailboxPatterns {

        func parseMailboxOrPat_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MailboxPatterns {
            return .mailbox(try self.parseListMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxOrPat_patterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MailboxPatterns {
            return .pattern(try self.parsePatterns(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseMailboxOrPat_list,
            parseMailboxOrPat_patterns
        ], buffer: &buffer, tracker: tracker)
    }

    // mbx-list-flags  = *(mbx-list-oflag SP) mbx-list-sflag
    //                   *(SP mbx-list-oflag) /
    //                   mbx-list-oflag *(SP mbx-list-oflag)
    static func parseMailboxListFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.List.Flags {

        func parseMailboxListFlags_mixedArray(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.List.Flags {
            var oFlags = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Mailbox.List.OFlag in
                let flag = try self.parseMailboxListOflag(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return flag
            }
            let sFlag = try self.parseMailboxListSflag(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &oFlags, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Mailbox.List.OFlag in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseMailboxListOflag(buffer: &buffer, tracker: tracker)
            }
            return NIOIMAP.Mailbox.List.Flags(oFlags: oFlags, sFlag: sFlag)
        }

        func parseMailboxListFlags_OFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.List.Flags {
            var output = [try self.parseMailboxListOflag(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Mailbox.List.OFlag in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseMailboxListOflag(buffer: &buffer, tracker: tracker)
            }
            return NIOIMAP.Mailbox.List.Flags(oFlags: output, sFlag: nil)
        }

        return try ParserLibrary.parseOneOf([
            parseMailboxListFlags_mixedArray,
            parseMailboxListFlags_OFlags
        ], buffer: &buffer, tracker: tracker)
    }

    // mbx-list-oflag  = "\Noinferiors" / child-mbox-flag /
    //                   "\Subscribed" / "\Remote" / flag-extension
    static func parseMailboxListOflag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.List.OFlag {

        // protect against parsing an sflag
        let saved = buffer
        if let sFlag = try? self.parseMailboxListSflag(buffer: &buffer, tracker: tracker) {
            throw ParserError(hint: "\(sFlag) is an sFlag, so can't treat as oFlag")
        }
        buffer = saved

        func parseMailboxListOflag_inferiors(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.List.OFlag {
            try ParserLibrary.parseFixedString("\\Noinferiors", buffer: &buffer, tracker: tracker)
            return .noInferiors
        }

        func parseMailboxListOflag_flagExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.List.OFlag {
            return .other(try self.parseFlagExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseMailboxListOflag_inferiors,
            parseMailboxListOflag_flagExtension
        ], buffer: &buffer, tracker: tracker)
    }

    // mbx-list-sflag  = "\NonExistent" / "\Noselect" / "\Marked" / "\Unmarked"
    static func parseMailboxListSflag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Mailbox.List.SFlag {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { c -> Bool in
                return isalpha(Int32(c)) != 0 || c == UInt8(ascii: "\\")
            }
            guard let flag = NIOIMAP.Mailbox.List.SFlag(rawValue: string) else {
                throw ParserError(hint: "Found \(string) which was not an sflag")
            }
            return flag
        }
    }

    // media-basic     = ((DQUOTE ("APPLICATION" / "AUDIO" / "IMAGE" /
    //                   "MESSAGE" / "VIDEO") DQUOTE) / string) SP
    //                   media-subtype
    static func parseMediaBasic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Media.Basic {

        func parseMediaBasic_Type_defined(_ option: String, result: NIOIMAP.Media.BasicType, buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Media.BasicType {
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(option, buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return result
        }

        func parseMediaBasic_Type_application(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Media.BasicType {
            return try parseMediaBasic_Type_defined("APPLICATION", result: .application, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Type_audio(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Media.BasicType {
            return try parseMediaBasic_Type_defined("AUDIO", result: .audio, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Type_image(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Media.BasicType {
            return try parseMediaBasic_Type_defined("IMAGE", result: .image, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Type_message(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Media.BasicType {
            return try parseMediaBasic_Type_defined("MESSAGE", result: .message, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Type_video(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Media.BasicType {
            return try parseMediaBasic_Type_defined("VIDEO", result: .video, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Type_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Media.BasicType {
            return .other(try self.parseString(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Media.Basic in
            let basicType = try ParserLibrary.parseOneOf([
                parseMediaBasic_Type_application,
                parseMediaBasic_Type_audio,
                parseMediaBasic_Type_image,
                parseMediaBasic_Type_message,
                parseMediaBasic_Type_video,
                parseMediaBasic_Type_other
            ], buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let subtype = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            return NIOIMAP.Media.Basic(type: basicType, subtype: subtype)
        }
    }


    // media-message   = DQUOTE "MESSAGE" DQUOTE SP
    //                   DQUOTE ("RFC822" / "GLOBAL") DQUOTE
    static func parseMediaMessage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Media.Message {

        func parseMediaMessage_rfc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Media.Message {
            try ParserLibrary.parseFixedString("RFC822", buffer: &buffer, tracker: tracker)
            return .rfc822
        }

        func parseMediaMessage_global(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Media.Message {
            try ParserLibrary.parseFixedString("GLOBAL", buffer: &buffer, tracker: tracker)
            return .global
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Media.Message in
            try ParserLibrary.parseFixedString("\"MESSAGE\" \"", buffer: &buffer, tracker: tracker)
            let message = try ParserLibrary.parseOneOf([
                parseMediaMessage_rfc,
                parseMediaMessage_global
            ], buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return message
        }
    }

    // media-subtype   = string
    static func parseMediaSubtype(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        var buffer = try self.parseString(buffer: &buffer, tracker: tracker)
        return buffer.readString(length: buffer.readableBytes)!
    }

    // media-text      = DQUOTE "TEXT" DQUOTE SP media-subtype
    static func parseMediaText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in
            try ParserLibrary.parseFixedString("\"TEXT\" ", buffer: &buffer, tracker: tracker)
            let subtype = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            return subtype
        }
    }

    // message-data    = nz-number SP ("EXPUNGE" / ("FETCH" SP msg-att))
    static func parseMessageData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageData {

        func parseMessageData_expunge(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageData {
            let number = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" EXPUNGE", buffer: &buffer, tracker: tracker)
            return .expunge(number)
        }

        func parseMessageData_fetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageData {
            let number = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" FETCH ", buffer: &buffer, tracker: tracker)
            return .fetch(number)
        }

        return try ParserLibrary.parseOneOf([
            parseMessageData_expunge,
            parseMessageData_fetch
        ], buffer: &buffer, tracker: tracker)
    }

    // mod-sequence-valzer = "0" / mod-sequence-value
    static func parseModifierSequenceValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ModifierSequenceValue {
        let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
        guard let value = NIOIMAP.ModifierSequenceValue(number) else {
            throw ParserError(hint: "Unable to create ModifiersSequenceValueZero")
        }
        return value
    }

    // move            = "MOVE" SP sequence-set SP mailbox
    static func parseMove(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("MOVE ", buffer: &buffer, tracker: tracker)
            let set = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .move(set, mailbox)
        }
    }

    // msg-att         = "(" (msg-att-dynamic / msg-att-static)
    //                    *(SP (msg-att-dynamic / msg-att-static)) ")"
    static func parseMessageAttributeStart(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
    }
    
    static func parseMessageAttributeMiddle(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
    }
    
    static func parseMessageAttributeEnd(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseFixedString(")\r\n", buffer: &buffer, tracker: tracker)
    }
    
    static func parseMessageAttribute_dynamicOrStatic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageAttributeType {
        
        func parseMessageAttribute_static(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageAttributeType {
            return .static(try self.parseMessageAttributeStatic(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_dynamic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageAttributeType {
            return .dynamic(try self.parseMessageAttributeDynamic(buffer: &buffer, tracker: tracker))
        }
        
        return try ParserLibrary.parseOneOf([
            parseMessageAttribute_static,
            parseMessageAttribute_dynamic
        ], buffer: &buffer, tracker: tracker)
    }

    // msg-att-dynamic = "FLAGS" SP "(" [flag-fetch *(SP flag-fetch)] ")"
    static func parseMessageAttributeDynamic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageAttributesDynamic {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.MessageAttributesDynamic in
            try ParserLibrary.parseFixedString("FLAGS (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseFlagFetch(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Flag in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseFlagFetch(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // msg-att-static  = "ENVELOPE" SP envelope / "INTERNALDATE" SP date-time /
    //                   "RFC822.SIZE" SP number /
    //                   "BODY" ["STRUCTURE"] SP body /
    //                   "BODY" section ["<" number ">"] SP nstring /
    //                   "BINARY" section-binary SP (nstring / literal8) /
    //                   "BINARY.SIZE" section-binary SP number /
    //                   "UID" SP uniqueid
    static func parseMessageAttributeStatic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageAttributesStatic {

        func parseMessageAttributeStatic_envelope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageAttributesStatic {
            try ParserLibrary.parseFixedString("ENVELOPE ", buffer: &buffer, tracker: tracker)
            return .envelope(try self.parseEnvelope(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttributeStatic_internalDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageAttributesStatic {
            try ParserLibrary.parseFixedString("INTERNALDATE ", buffer: &buffer, tracker: tracker)
            return .internalDate(try self.parseDateTime(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttributeStatic_rfc822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageAttributesStatic {
            try ParserLibrary.parseFixedString("RFC822", buffer: &buffer, tracker: tracker)
            let rfc = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.RFC822Reduced in
                try self.parseRFC822Reduced(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .rfc822(rfc, string)
        }

        func parseMessageAttributeStatic_rfc822Size(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageAttributesStatic {
            try ParserLibrary.parseFixedString("RFC822.SIZE ", buffer: &buffer, tracker: tracker)
            return .rfc822Size(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttributeStatic_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageAttributesStatic {
            try ParserLibrary.parseFixedString("BODY", buffer: &buffer, tracker: tracker)
            let structure: Bool = {
                do {
                    try ParserLibrary.parseFixedString("STRUCTURE", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    return false
                }
            }()
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let body = try self.parseBody(buffer: &buffer, tracker: tracker)
            return .body(body, structure: structure)
        }

        func parseMessageAttributeStatic_bodySection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageAttributesStatic {
            try ParserLibrary.parseFixedString("BODY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let number = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try ParserLibrary.parseFixedString("<", buffer: &buffer, tracker: tracker)
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString(">", buffer: &buffer, tracker: tracker)
                return num
            }
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)

            // stream if body text
            if section == .text(.text) {
                let literalSize = try self.parseLiteralSize(buffer: &buffer, tracker: tracker)
                return .bodySectionText(number, literalSize)
            } else {
                let string = try self.parseNString(buffer: &buffer, tracker: tracker)
                return .bodySection(section, number, string)
            }
        }

        func parseMessageAttributeStatic_uid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageAttributesStatic {
            try ParserLibrary.parseFixedString("UID ", buffer: &buffer, tracker: tracker)
            return .uid(try self.parseUniqueID(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttributeStatic_binarySize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageAttributesStatic {
            try ParserLibrary.parseFixedString("BINARY.SIZE", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return .binarySize(section: section, number: number)
        }

        func parseMessageAttributeStatic_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.MessageAttributesStatic {
            try ParserLibrary.parseFixedString("BINARY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let size = try self.parseLiteralSize(buffer: &buffer, tracker: tracker)
            return .binaryLiteral(section: section, size: size)
        }

        return try ParserLibrary.parseOneOf([
            parseMessageAttributeStatic_envelope,
            parseMessageAttributeStatic_internalDate,
            parseMessageAttributeStatic_rfc822,
            parseMessageAttributeStatic_rfc822Size,
            parseMessageAttributeStatic_body,
            parseMessageAttributeStatic_bodySection,
            parseMessageAttributeStatic_uid,
            parseMessageAttributeStatic_binarySize,
            // we currently deliberately don't parse BINARY representations in the quoted string form.
            parseMessageAttributeStatic_binary
        ], buffer: &buffer, tracker: tracker)
    }

    // Namespace         = nil / "(" 1*Namespace-Descr ")"
    static func parseNamespace(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Namespace {

        func parseNamespace_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Namespace {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseNamespace_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Namespace {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let descriptions = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseNamespaceDescription)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return descriptions
        }

        return try ParserLibrary.parseOneOf([
            parseNamespace_nil,
            parseNamespace_some
        ], buffer: &buffer, tracker: tracker)
    }

    // Namespace-Command = "NAMESPACE"
    static func parseNamespaceCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        try ParserLibrary.parseFixedString("NAMESPACE", buffer: &buffer, tracker: tracker)
        return .namespace
    }

    // Namespace-Descr   = "(" string SP
    //                        (DQUOTE QUOTED-CHAR DQUOTE / nil)
    //                         [Namespace-Response-Extensions] ")"
    static func parseNamespaceDescription(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.NamespaceDescription {

        func parseNamespaceDescr_quotedChar(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            guard let char = buffer.readBytes(length: 1)?.first else {
                throw NIOIMAP.ParsingError.incompleteMessage
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

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.NamespaceDescription in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let string = try self.parseString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let char = try ParserLibrary.parseOneOf([
                parseNamespaceDescr_quotedChar,
                parseNamespaceDescr_nil
            ], buffer: &buffer, tracker: tracker)
            let extensions = try self.parseNamespaceResponseExtensions(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .string(string, char: char, responseExtensions: extensions)
        }
    }

    // Namespace-Response-Extensions = *(Namespace-Response-Extension)
    static func parseNamespaceResponseExtensions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.NamespaceResponseExtensions {
        return try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.NamespaceResponseExtension in
            return try self.parseNamespaceResponseExtension(buffer: &buffer, tracker: tracker)
        }
    }

    // Namespace-Response-Extension = SP string SP
    //                   "(" string *(SP string) ")"
    static func parseNamespaceResponseExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.NamespaceResponseExtension {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.NamespaceResponseExtension in
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
            return NIOIMAP.NamespaceResponseExtension(str1: s1, strs: array)
        }
    }

    // Namespace-Response = "*" SP "NAMESPACE" SP Namespace
    //                       SP Namespace SP Namespace
    static func parseNamespaceResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.NamespaceResponse {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.NamespaceResponse in
            try ParserLibrary.parseFixedString("NAMESPACE ", buffer: &buffer, tracker: tracker)
            let n1 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let n2 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let n3 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            return NIOIMAP.NamespaceResponse(userNamespace: n1, otherUserNamespace: n2, sharedNamespace: n3)
        }
    }

    // nil             = "NIL"
    static func parseNil(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseFixedString("nil", buffer: &buffer, tracker: tracker)
    }

    // nstring         = string / nil
    static func parseNString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.NString {

        func parseNString_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.NString {
            try ParserLibrary.parseFixedString("NIL", buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseNString_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.NString {
            return try self.parseString(buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseOneOf([
            parseNString_nil,
            parseNString_some
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
    static func parseOptionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.OptionExtension {

        func parseOptionExtensionType_standard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.OptionExtensionType {
            return .standard(try self.parseOptionStandardTag(buffer: &buffer, tracker: tracker))
        }

        func parseOptionExtensionType_vendor(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.OptionExtensionType {
            return .vendor(try self.parseOptionVendorTag(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.OptionExtension in
            let type = try ParserLibrary.parseOneOf([
                parseOptionExtensionType_standard,
                parseOptionExtensionType_vendor
            ], buffer: &buffer, tracker: tracker)
            let value = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.OptionValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseOptionValue(buffer: &buffer, tracker: tracker)
            }
            return NIOIMAP.OptionExtension(type: type, value: value)
        }
    }

    // option-standard-tag =  atom
    static func parseOptionStandardTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try self.parseAtom(buffer: &buffer, tracker: tracker)
    }

    // option-val-comp =  astring /
    //                    option-val-comp *(SP option-val-comp) /
    //                    "(" option-val-comp ")"
    static func parseOptionValueComp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.OptionValueComp {

        func parseOptionValueComp_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.OptionValueComp {
            return .string(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseOptionValueComp_single(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.OptionValueComp {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .array([comp])
        }

        func parseOptionValueComp_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.OptionValueComp {
            var array = [try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.OptionValueComp in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            }
            return .array(array)
        }

        return try ParserLibrary.parseOneOf([
            parseOptionValueComp_string,
            parseOptionValueComp_single,
            parseOptionValueComp_array
        ], buffer: &buffer, tracker: tracker)
    }

    // option-value =  "(" option-val-comp ")"
    static func parseOptionValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.OptionValue {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.OptionValue in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return comp
        }
    }

    // option-vendor-tag =  vendor-token "-" atom
    static func parseOptionVendorTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.OptionVendorTag {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.OptionVendorTag in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return NIOIMAP.OptionVendorTag(token: token, atom: atom)
        }
    }

    // partial-range    = number ["." nz-number]
    static func parsePartialRange(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Partial.Range {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Partial.Range in
            let num1 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let num2 = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try ParserLibrary.parseFixedString(".", buffer: &buffer, tracker: tracker)
                return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            }
            return NIOIMAP.Partial.Range(num1: num1, num2: num2)
        }
    }

    // partial         = "<" number "." nz-number ">"
    static func parsePartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Partial {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Partial in
            try ParserLibrary.parseFixedString("<", buffer: &buffer, tracker: tracker)
            let num1 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(".", buffer: &buffer, tracker: tracker)
            let num2 = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(">", buffer: &buffer, tracker: tracker)
            return NIOIMAP.Partial(left: num1, right: num2)
        }
    }

    // password        = astring
    static func parsePassword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        var buffer = try Self.parseAString(buffer: &buffer, tracker: tracker)
        return buffer.readString(length: buffer.readableBytes)!
    }

    // patterns        = "(" list-mailbox *(SP list-mailbox) ")"
    static func parsePatterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Patterns {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Patterns in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseListMailbox(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Mailbox.ListMailbox in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // quoted          = DQUOTE *QUOTED-CHAR DQUOTE
    static func parseQuoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            let data = try ParserLibrary.parseZeroOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char in
                return char.isQuotedChar
            }
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return data
        }
    }

    // rename          = "RENAME" SP mailbox SP mailbox [rename-params]
    static func parseRename(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("RENAME ", buffer: &buffer, tracker: tracker)
            let from = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", caseSensitive: false, buffer: &buffer, tracker: tracker)
            let to = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseRenameParameters)
            return .rename(from: from, to: to, params: params)
        }
    }
    
    // rename-param = rename-param-name [SP rename-param-value]
    static func parseRenameParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.RenameParameter {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseRenameParameterName(buffer: &buffer, tracker: tracker)
            let value = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.TaggedExtensionValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseCreateParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .name(name, value: value)
        }
    }

    // rename-params = SP "(" rename-param *(SP rename-param-value) ")"
    static func parseRenameParameters(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.RenameParameter] {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseRenameParameter(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.RenameParameter in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseRenameParameter(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }
    
    // rename-param-name = tagged-ext-label
    static func parseRenameParameterName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
    }
    
    // rename-param-value = tagged-ext-val
    static func parseRenameParameterValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionValue {
        return try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }

    // response        = response-done
    static func parseResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Response {
        return try self.parseResponseDone(buffer: &buffer, tracker: tracker)
    }

    // response-data   = "*" SP response-payload CRLF
    static func parseResponseData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseData {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("* ", buffer: &buffer, tracker: tracker)
            let payload = try self.parseResponsePayload(buffer: &buffer, tracker: tracker)
            
            if case NIOIMAP.ResponseData.messageData(NIOIMAP.MessageData.fetch(_)) = payload {
                return payload
            }
            
            try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
            return payload
        }
    }

    // response-done   = response-tagged / response-fatal
    static func parseResponseDone(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseDone {
        func parseResponseDone_tagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseDone {
            return .tagged(try self.parseResponseTagged(buffer: &buffer, tracker: tracker))
        }
        func parseResponseDone_fatal(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseDone {
            return .fatal(try self.parseResponseFatal(buffer: &buffer, tracker: tracker))
        }
        return try ParserLibrary.parseOneOf([
            parseResponseDone_tagged,
            parseResponseDone_fatal
        ], buffer: &buffer, tracker: tracker)
    }

    // response-fatal  = "*" SP resp-cond-bye CRLF
    static func parseResponseFatal(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseFatal {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.ResponseFatal in
            try ParserLibrary.parseFixedString("* ", buffer: &buffer, tracker: tracker)
            let bye = try self.parseResponseConditionalBye(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
            return bye
        }
    }

    // response-tagged = tag SP resp-cond-state CRLF
    static func parseResponseTagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTagged {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.ResponseTagged in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let state = try self.parseResponseConditionalState(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
            return NIOIMAP.ResponseTagged(tag: tag, state: state)
        }
    }

    // resp-code-apnd  = "APPENDUID" SP nz-number SP append-uid
    static func parseResponseCodeAppend(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseCodeAppend {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.ResponseCodeAppend in
            try ParserLibrary.parseFixedString("APPENDUID ", buffer: &buffer, tracker: tracker)
            let number = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let uid = try self.parseAppendUid(buffer: &buffer, tracker: tracker)
            return NIOIMAP.ResponseCodeAppend(num: number, uid: uid)
        }
    }

    // resp-code-copy  = "COPYUID" SP nz-number SP uid-set SP uid-set
    static func parseResponseCodeCopy(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseCodeCopy {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.ResponseCodeCopy in
            try ParserLibrary.parseFixedString("COPYUID ", buffer: &buffer, tracker: tracker)
            let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let set1 = try self.parseUidSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let set2 = try self.parseUidSet(buffer: &buffer, tracker: tracker)
            return NIOIMAP.ResponseCodeCopy(num: num, set1: set1, set2: set2)
        }
    }

    // resp-cond-auth  = ("OK" / "PREAUTH") SP resp-text
    static func parseResponseConditionalAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseConditionalAuth {

        func parseResponseConditionalAuth_ok(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseConditionalAuth {
            try ParserLibrary.parseFixedString("OK ", buffer: &buffer, tracker: tracker)
            return .ok(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseResponseConditionalAuth_preauth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseConditionalAuth {
            try ParserLibrary.parseFixedString("PREAUTH ", buffer: &buffer, tracker: tracker)
            return .preauth(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseResponseConditionalAuth_ok,
            parseResponseConditionalAuth_preauth
        ], buffer: &buffer, tracker: tracker)
    }

    // resp-cond-bye   = "BYE" SP resp-text
    static func parseResponseConditionalBye(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseConditionalBye {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.ResponseConditionalBye in
            try ParserLibrary.parseFixedString("BYE ", buffer: &buffer, tracker: tracker)
            return try self.parseResponseText(buffer: &buffer, tracker: tracker)
        }
    }

    // resp-cond-state = ("OK" / "NO" / "BAD") SP resp-text
    static func parseResponseConditionalState(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseConditionalState {

        func parseResponseConditionalState_ok(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseConditionalState {
            try ParserLibrary.parseFixedString("OK ", buffer: &buffer, tracker: tracker)
            return .ok(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseResponseConditionalState_no(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseConditionalState {
            try ParserLibrary.parseFixedString("NO ", buffer: &buffer, tracker: tracker)
            return .no(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseResponseConditionalState_bad(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseConditionalState {
            try ParserLibrary.parseFixedString("BAD ", buffer: &buffer, tracker: tracker)
            return .bad(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseResponseConditionalState_ok,
            parseResponseConditionalState_no,
            parseResponseConditionalState_bad
        ], buffer: &buffer, tracker: tracker)
    }

    // response-payload = resp-cond-state / resp-cond-bye / mailbox-data / message-data / capability-data / id-response / enable-data
    static func parseResponsePayload(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponsePayload {
        
        func parseResponsePayload_conditionalState(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponsePayload {
            return .conditionalState(try self.parseResponseConditionalState(buffer: &buffer, tracker: tracker))
        }
        
        func parseResponsePayload_conditionalBye(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponsePayload {
            return .conditionalBye(try self.parseResponseConditionalBye(buffer: &buffer, tracker: tracker))
        }
        
        func parseResponsePayload_mailboxData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponsePayload {
            return .mailboxData(try self.parseMailboxData(buffer: &buffer, tracker: tracker))
        }
        
        func parseResponsePayload_messageData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponsePayload {
            return .messageData(try self.parseMessageData(buffer: &buffer, tracker: tracker))
        }
        
        func parseResponsePayload_capabilityData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponsePayload {
            return .capabilityData(try self.parseCapabilityData(buffer: &buffer, tracker: tracker))
        }
        
        func parseResponsePayload_idResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponsePayload {
            return .id(try self.parseIDResponse(buffer: &buffer, tracker: tracker))
        }
        
        func parseResponsePayload_enableData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponsePayload {
            return .enableData(try self.parseEnableData(buffer: &buffer, tracker: tracker))
        }
        
        return try ParserLibrary.parseOneOf([
            parseResponsePayload_conditionalState,
            parseResponsePayload_conditionalBye,
            parseResponsePayload_mailboxData,
            parseResponsePayload_messageData,
            parseResponsePayload_capabilityData,
            parseResponsePayload_idResponse,
            parseResponsePayload_enableData
        ], buffer: &buffer, tracker: tracker)
    }
    
    // resp-text       = ["[" resp-text-code "]" SP] text
    static func parseResponseText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseText {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.ResponseText in
            let code = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.ResponseTextCode in
                try ParserLibrary.parseFixedString("[", buffer: &buffer, tracker: tracker)
                let code = try self.parseResponseTextCode(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString("] ", buffer: &buffer, tracker: tracker)
                return code
            }
            let text = try self.parseText(buffer: &buffer, tracker: tracker)
            return NIOIMAP.ResponseText(code: code, text: text)
        }
    }
    
    static func parseResponseType(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseType {
        
        func parseResponseType_continue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseType {
            return .continueRequest(try self.parseContinueRequest(buffer: &buffer, tracker: tracker))
        }
        
        func parseResponseType_data(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseType {
            return .responseData(try self.parseResponseData(buffer: &buffer, tracker: tracker))
        }
        
        return try ParserLibrary.parseOneOf([
            parseResponseType_continue,
            parseResponseType_data
        ], buffer: &buffer, tracker: tracker)
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
    static func parseResponseTextCode(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTextCode {

        func parseResponseTextCode_alert(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTextCode {
            try ParserLibrary.parseFixedString("ALERT", buffer: &buffer, tracker: tracker)
            return .alert
        }
        
        func parseResponseTextCode_badCharset(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTextCode {
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
            }
            return .badCharset(charsets)
        }

        func parseResponseTextCode_capabilityData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTextCode {
            return .capability(try self.parseCapabilityData(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_parse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTextCode {
            try ParserLibrary.parseFixedString("PARSE", buffer: &buffer, tracker: tracker)
            return .parse
        }

        func parseResponseTextCode_permanentFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTextCode {
            try ParserLibrary.parseFixedString("PERMANENTFLAGS (", buffer: &buffer, tracker: tracker)
            let array = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [NIOIMAP.PermanentFlag] in
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

        func parseResponseTextCode_readOnly(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTextCode {
            try ParserLibrary.parseFixedString("READ-ONLY", buffer: &buffer, tracker: tracker)
            return .readOnly
        }

        func parseResponseTextCode_readWrite(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTextCode {
            try ParserLibrary.parseFixedString("READ-WRITE", buffer: &buffer, tracker: tracker)
            return .readWrite
        }

        func parseResponseTextCode_tryCreate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTextCode {
            try ParserLibrary.parseFixedString("TRYCREATE", buffer: &buffer, tracker: tracker)
            return .tryCreate
        }

        func parseResponseTextCode_uidNext(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTextCode {
            try ParserLibrary.parseFixedString("UIDNEXT ", buffer: &buffer, tracker: tracker)
            return .uidNext(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_uidValidity(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTextCode {
            try ParserLibrary.parseFixedString("UIDVALIDITY ", buffer: &buffer, tracker: tracker)
            return .uidValidity(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_unseen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTextCode {
            try ParserLibrary.parseFixedString("UNSEEN ", buffer: &buffer, tracker: tracker)
            return .unseen(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }
        
        func parseResponseTextCode_namespace(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTextCode {
            return .namespace(try self.parseNamespaceResponse(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_atom(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseTextCode {
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
            parseResponseTextCode_atom
        ], buffer: &buffer, tracker: tracker)
    }

    // return-option   =  "SUBSCRIBED" / "CHILDREN" / status-option /
    //                    option-extension
    static func parseReturnOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ReturnOption {

        func parseReturnOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ReturnOption {
            try ParserLibrary.parseFixedString("SUBSCRIBED", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseReturnOption_children(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ReturnOption {
            try ParserLibrary.parseFixedString("CHILDREN", buffer: &buffer, tracker: tracker)
            return .children
        }

        func parseReturnOption_statusOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ReturnOption {
            return .statusOption(try self.parseStatusOption(buffer: &buffer, tracker: tracker))
        }

        func parseReturnOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ReturnOption {
            return .optionExtension(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseReturnOption_subscribed,
            parseReturnOption_children,
            parseReturnOption_statusOption,
            parseReturnOption_optionExtension
        ], buffer: &buffer, tracker: tracker)
    }

    // search          = "SEARCH" [search-return-opts] SP search-program
    static func parseSearch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("SEARCH", buffer: &buffer, tracker: tracker)
            let returnOpts = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSearchReturnOptions)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let program = try self.parseSearchProgram(buffer: &buffer, tracker: tracker)
            return .search(returnOptions: returnOpts, program: program)
        }
    }

    // search-correlator    = SP "(" "TAG" SP tag-string ")"
    static func parseSearchCorrelator(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchCorrelator {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString(" (TAG ", buffer: &buffer, tracker: tracker)
            let tag = try self.parseTagString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return tag
        }
    }

    // search-critera = search-key *(search-key)
    static func parseSearchCriteria(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchCriteria {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
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
    static func parseSearchKey(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {

        func parseSearchKey_fixed(string: String, result: NIOIMAP.SearchKey, buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString(string, buffer: &buffer, tracker: tracker)
            return result
        }

        func parseSearchKey_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return try parseSearchKey_fixed(string: "ALL", result: .all, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_answered(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return try parseSearchKey_fixed(string: "ANSWERED", result: .answered, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_bcc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("BCC ", buffer: &buffer, tracker: tracker)
            return .bcc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_before(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("BEFORE ", buffer: &buffer, tracker: tracker)
            return .before(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("BODY ", buffer: &buffer, tracker: tracker)
            return .body(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_cc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("CC ", buffer: &buffer, tracker: tracker)
            return .cc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_deleted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return try parseSearchKey_fixed(string: "DELETED", result: .deleted, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_flagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return try parseSearchKey_fixed(string: "FLAGGED", result: .flagged, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_from(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("FROM ", buffer: &buffer, tracker: tracker)
            return .from(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_keyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("KEYWORD ", buffer: &buffer, tracker: tracker)
            return .keyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_new(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return try parseSearchKey_fixed(string: "NEW", result: .new, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_old(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return try parseSearchKey_fixed(string: "OLD", result: .old, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_recent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return try parseSearchKey_fixed(string: "RECENT", result: .recent, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_seen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return try parseSearchKey_fixed(string: "SEEN", result: .seen, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_unseen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return try parseSearchKey_fixed(string: "UNSEEN", result: .unseen, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_unanswered(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return try parseSearchKey_fixed(string: "UNANSWERED", result: .unanswered, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_undeleted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return try parseSearchKey_fixed(string: "UNDELETED", result: .undeleted, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_unflagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return try parseSearchKey_fixed(string: "UNFLAGGED", result: .unflagged, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_draft(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return try parseSearchKey_fixed(string: "DRAFT", result: .draft, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_undraft(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return try parseSearchKey_fixed(string: "UNDRAFT", result: .undraft, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_on(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("ON ", buffer: &buffer, tracker: tracker)
            return .on(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_since(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("SINCE ", buffer: &buffer, tracker: tracker)
            return .since(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_subject(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("SUBJECT ", buffer: &buffer, tracker: tracker)
            return .subject(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("TEXT ", buffer: &buffer, tracker: tracker)
            return .text(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_to(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("TO ", buffer: &buffer, tracker: tracker)
            return .to(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_unkeyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("UNKEYWORD ", buffer: &buffer, tracker: tracker)
            return .unkeyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_filter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("FILTER ", buffer: &buffer, tracker: tracker)
            return .filter(try self.parseFilterName(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("HEADER ", buffer: &buffer, tracker: tracker)
            let header = try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let string = try self.parseAString(buffer: &buffer, tracker: tracker)
            return .header(header, string)
        }

        func parseSearchKey_larger(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("LARGER ", buffer: &buffer, tracker: tracker)
            return .larger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_smaller(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("SMALLER ", buffer: &buffer, tracker: tracker)
            return .smaller(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_not(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("NOT ", buffer: &buffer, tracker: tracker)
            return .not(try self.parseSearchKey(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_or(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("OR ", buffer: &buffer, tracker: tracker)
            let key1 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let key2 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            return .or(key1, key2)
        }

        func parseSearchKey_sentBefore(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("SENTBEFORE ", buffer: &buffer, tracker: tracker)
            return .sent(.before(try self.parseDate(buffer: &buffer, tracker: tracker)))
        }

        func parseSearchKey_sentOn(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("SENTON ", buffer: &buffer, tracker: tracker)
            return .sent(.on(try self.parseDate(buffer: &buffer, tracker: tracker)))
        }

        func parseSearchKey_sentSince(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("SENTSINCE ", buffer: &buffer, tracker: tracker)
            return .sent(.since(try self.parseDate(buffer: &buffer, tracker: tracker)))
        }

        func parseSearchKey_uid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("UID ", buffer: &buffer, tracker: tracker)
            return .uid(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sequenceSet(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            return .sequenceSet(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.SearchKey in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .array(array)
        }

        func parseSearchKey_older(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("OLDER ", buffer: &buffer, tracker: tracker)
            return .older(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_younger(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchKey {
            try ParserLibrary.parseFixedString("YOUNGER ", buffer: &buffer, tracker: tracker)
            return .younger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseSearchKey_older,
            parseSearchKey_younger,
            parseSearchKey_all,
            parseSearchKey_answered,
            parseSearchKey_bcc,
            parseSearchKey_before,
            parseSearchKey_body,
            parseSearchKey_cc,
            parseSearchKey_deleted,
            parseSearchKey_flagged,
            parseSearchKey_from,
            parseSearchKey_keyword,
            parseSearchKey_new,
            parseSearchKey_old,
            parseSearchKey_recent,
            parseSearchKey_seen,
            parseSearchKey_unseen,
            parseSearchKey_unanswered,
            parseSearchKey_undeleted,
            parseSearchKey_unflagged,
            parseSearchKey_draft,
            parseSearchKey_undraft,
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
            parseSearchKey_filter
        ], buffer: &buffer, tracker: tracker)
    }


    // search-modifier-name = tagged-ext-label
    static func parseSearchModifierName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
    }

    // search-mod-params = tagged-ext-val
    static func parseSearchModifierParams(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionValue {
        return try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }

    // search-program       = ["CHARSET" SP charset SP] search-key *(SP search-key)
    static func parseSearchProgram(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchProgram {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let charset = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> String in
                try ParserLibrary.parseFixedString("CHARSET ", buffer: &buffer, tracker: tracker)
                let charset = try self.parseCharset(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return charset
            }
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.SearchKey in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }
            return NIOIMAP.SearchProgram(charset: charset, keys: array)
        }
    }

    // search-ret-data-ext = search-modifier-name SP search-return-value
    static func parseSearchReturnDataExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnDataExtension {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.SearchReturnDataExtension in
            let modifier = try self.parseSearchModifierName(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let value = try self.parseSearchReturnValue(buffer: &buffer, tracker: tracker)
            return NIOIMAP.SearchReturnDataExtension(modifier: modifier, returnValue: value)
        }
    }

    // search-return-data = "MIN" SP nz-number /
    //                     "MAX" SP nz-number /
    //                     "ALL" SP sequence-set /
    //                     "COUNT" SP number /
    //                     search-ret-data-ext
    static func parseSearchReturnData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnData {

        func parseSearchReturnData_min(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnData {
            try ParserLibrary.parseFixedString("MIN ", buffer: &buffer, tracker: tracker)
            return .min(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_max(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnData {
            try ParserLibrary.parseFixedString("MAX ", buffer: &buffer, tracker: tracker)
            return .max(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnData {
            try ParserLibrary.parseFixedString("ALL ", buffer: &buffer, tracker: tracker)
            return .all(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_count(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnData {
            try ParserLibrary.parseFixedString("COUNT ", buffer: &buffer, tracker: tracker)
            return .count(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_dataExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnData {
            return .dataExtension(try self.parseSearchReturnDataExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseSearchReturnData_min,
            parseSearchReturnData_max,
            parseSearchReturnData_all,
            parseSearchReturnData_count,
            parseSearchReturnData_dataExtension
        ], buffer: &buffer, tracker: tracker)
    }

    // search-return-opts   = SP "RETURN" SP "(" [search-return-opt *(SP search-return-opt)] ")"
    static func parseSearchReturnOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.SearchReturnOption] {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString(" RETURN (", buffer: &buffer, tracker: tracker)
            let array = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [NIOIMAP.SearchReturnOption] in
                var array = [try self.parseSearchReturnOption(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.SearchReturnOption in
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
    static func parseSearchReturnOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnOption {

        func parseSearchReturnOption_min(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnOption {
            try ParserLibrary.parseFixedString("MIN", buffer: &buffer, tracker: tracker)
            return .min
        }

        func parseSearchReturnOption_max(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnOption {
            try ParserLibrary.parseFixedString("MAX", buffer: &buffer, tracker: tracker)
            return .max
        }

        func parseSearchReturnOption_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnOption {
            try ParserLibrary.parseFixedString("ALL", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseSearchReturnOption_count(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnOption {
            try ParserLibrary.parseFixedString("COUNT", buffer: &buffer, tracker: tracker)
            return .count
        }

        func parseSearchReturnOption_save(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnOption {
            try ParserLibrary.parseFixedString("SAVE", buffer: &buffer, tracker: tracker)
            return .save
        }

        func parseSearchReturnOption_extension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnOption {
            let optionExtension = try self.parseSearchReturnOptionExtension(buffer: &buffer, tracker: tracker)
            return .optionExtension(optionExtension)
        }

        return try ParserLibrary.parseOneOf([
            parseSearchReturnOption_min,
            parseSearchReturnOption_max,
            parseSearchReturnOption_all,
            parseSearchReturnOption_count,
            parseSearchReturnOption_save,
            parseSearchReturnOption_extension
        ], buffer: &buffer, tracker: tracker)
    }

    // search-ret-opt-ext = search-modifier-name [SP search-mod-params]
    static func parseSearchReturnOptionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SearchReturnOptionExtension {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.SearchReturnOptionExtension in
            let name = try self.parseSearchModifierName(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.TaggedExtensionValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSearchModifierParams(buffer: &buffer, tracker: tracker)
            }
            return NIOIMAP.SearchReturnOptionExtension(modifierName: name, params: params)
        }
    }

    // search-return-value = tagged-ext-val
    static func parseSearchReturnValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionValue {
        return try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }

    // section         = "[" [section-spec] "]"
    static func parseSection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SectionSpec? {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.SectionSpec? in
            try ParserLibrary.parseFixedString("[", buffer: &buffer, tracker: tracker)
            let spec = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.SectionSpec in
                try self.parseSectionSpec(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString("]", buffer: &buffer, tracker: tracker)
            return spec
        }
    }

    // section-binary  = "[" [section-part] "]"
    static func parseSectionBinary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Int]? {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Int]? in
            try ParserLibrary.parseFixedString("[", buffer: &buffer, tracker: tracker)
            let part = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                return try self.parseSectionPart(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString("]", buffer: &buffer, tracker: tracker)
            return part
        }
    }

    // section-msgtext = "HEADER" / "HEADER.FIELDS" [".NOT"] SP header-list /
    //                   "TEXT"
    static func parseSectionMessageText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SectionMessageText {

        func parseSectionMessageText_header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SectionMessageText {
            try ParserLibrary.parseFixedString("HEADER", buffer: &buffer, tracker: tracker)
            return .header
        }

        func parseSectionMessageText_headerFields(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SectionMessageText {
            try ParserLibrary.parseFixedString("HEADER.FIELDS ", buffer: &buffer, tracker: tracker)
            return .headerFields(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionMessageText_notHeaderFields(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SectionMessageText {
            try ParserLibrary.parseFixedString("HEADER.FIELDS.NOT ", buffer: &buffer, tracker: tracker)
            return .notHeaderFields(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionMessageText_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SectionMessageText {
            try ParserLibrary.parseFixedString("TEXT", buffer: &buffer, tracker: tracker)
            return .text
        }

        return try ParserLibrary.parseOneOf([
            parseSectionMessageText_headerFields,
            parseSectionMessageText_notHeaderFields,
            parseSectionMessageText_header,
            parseSectionMessageText_text
        ], buffer: &buffer, tracker: tracker)
    }

    // section-part    = nz-number *("." nz-number)
    static func parseSectionPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Int] {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Int] in
            var output = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> Int in
                return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                    try ParserLibrary.parseFixedString(".", buffer: &buffer, tracker: tracker)
                    return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                }
            }
            return output
        }
    }

    // section-spec    = section-msgtext / (section-part ["." section-text])
    static func parseSectionSpec(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SectionSpec {

        func parseSectionSpec_messageText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SectionSpec {
            return .text(try self.parseSectionMessageText(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpec_part(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SectionSpec {
            let part = try self.parseSectionPart(buffer: &buffer, tracker: tracker)
            let text = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.SectionText in
                try ParserLibrary.parseFixedString(".", buffer: &buffer, tracker: tracker)
                return .message(try self.parseSectionMessageText(buffer: &buffer, tracker: tracker))
            }
            return .part(part, text: text)
        }

        return try ParserLibrary.parseOneOf([
            parseSectionSpec_messageText,
            parseSectionSpec_part
        ], buffer: &buffer, tracker: tracker)
    }

    // section-text    = section-msgtext / "MIME"
    static func parseSectionText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SectionText {

        func parseSectionText_mime(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SectionText {
            try ParserLibrary.parseFixedString("MIME", buffer: &buffer, tracker: tracker)
            return .mime
        }

        func parseSectionText_messageText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SectionText {
            return .message(try self.parseSectionMessageText(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseSectionText_mime,
            parseSectionText_messageText
        ], buffer: &buffer, tracker: tracker)
    }

    // select          = "SELECT" SP mailbox [select-params]
    static func parseSelect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("SELECT ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSelectParameters)
            return .select(mailbox, params)
        }
    }

    // select-params = SP "(" select-param *(SP select-param ")"
    static func parseSelectParameters(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.SelectParameter] {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [NIOIMAP.SelectParameter] in
            try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseSelectParameter(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.SelectParameter in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSelectParameter(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // select-param = select-param-name [SP select-param-value]
    static func parseSelectParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SelectParameter {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.SelectParameter in
            let name = try self.parseSelectParameterName(buffer: &buffer, tracker: tracker)
            let value = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.TaggedExtensionValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSelectParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .name(name, value: value)
        }
    }

    // select-param-name = tagged-ext-name
    static func parseSelectParameterName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
    }

    // select-param-value = tagged-ext-value
    static func parseSelectParameterValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionValue {
        return try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }

    // seq-number      = nz-number / "*"
    static func parseSequenceNumber(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SequenceNumber {

        func parseSequenceNumber_wildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SequenceNumber {
            try ParserLibrary.parseFixedString("*", buffer: &buffer, tracker: tracker)
            return .last
        }

        func parseSequenceNumber_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SequenceNumber {
            let num = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            return .number(num)
        }

        return try ParserLibrary.parseOneOf([
            parseSequenceNumber_wildcard,
            parseSequenceNumber_number
        ], buffer: &buffer, tracker: tracker)
    }

    // seq-range       = seq-number ":" seq-number
    static func parseSequenceRange(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SequenceRange {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.SequenceRange in
            let num1 = try self.parseSequenceNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(":", buffer: &buffer, tracker: tracker)
            let num2 = try self.parseSequenceNumber(buffer: &buffer, tracker: tracker)
            return NIOIMAP.SequenceRange(num1 ... num2)
        }
    }

    // sequence-set    = (seq-number / seq-range) ["," sequence-set]
    static func parseSequenceSet(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.SequenceRange] {

        func parseSequenceSet_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SequenceRange {
            let num = try self.parseSequenceNumber(buffer: &buffer, tracker: tracker)
            return NIOIMAP.SequenceRange(from: num, to: num)
        }

        func parseSequenceSet_element(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.SequenceRange {
            return try ParserLibrary.parseOneOf([
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
            return output
        }
    }

    // status          = "STATUS" SP mailbox SP
    //                   "(" status-att *(SP status-att) ")"
    static func parseStatus(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("STATUS ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var atts = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &atts, tracker: tracker) { buffer, tracker -> NIOIMAP.StatusAttribute in
                try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .status(mailbox, atts)
        }
    }

    // status-att      = "MESSAGES" / "UIDNEXT" / "UIDVALIDITY" /
    //                   "UNSEEN" / "DELETED" / "SIZE"
    static func parseStatusAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.StatusAttribute {
        let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { c -> Bool in
            return isalpha(Int32(c)) != 0
        }
        guard let att = NIOIMAP.StatusAttribute(rawValue: string.uppercased()) else {
            throw ParserError(hint: "Found \(string) which was not a status attribute")
        }
        return att
    }

    // status-att-val   = ("MESSAGES" SP number) /
    //                    ("UIDNEXT" SP nz-number) /
    //                    ("UIDVALIDITY" SP nz-number) /
    //                    ("UNSEEN" SP number) /
    //                    ("DELETED" SP number) /
    //                    ("SIZE" SP number64)
    //
    static func parseStatusAttributeValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.StatusAttributeValue {

        func parseStatusAttributeValue_messages(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.StatusAttributeValue {
            try ParserLibrary.parseFixedString("MESSAGES ", buffer: &buffer, tracker: tracker)
            return .messages(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_uidnext(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.StatusAttributeValue {
            try ParserLibrary.parseFixedString("UIDNEXT ", buffer: &buffer, tracker: tracker)
            return .uidNext(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_uidvalidity(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.StatusAttributeValue {
            try ParserLibrary.parseFixedString("UIDVALIDITY ", buffer: &buffer, tracker: tracker)
            return .uidValidity(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_unseen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.StatusAttributeValue {
            try ParserLibrary.parseFixedString("UNSEEN ", buffer: &buffer, tracker: tracker)
            return .unseen(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_deleted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.StatusAttributeValue {
            try ParserLibrary.parseFixedString("DELETED ", buffer: &buffer, tracker: tracker)
            return .deleted(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_size(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.StatusAttributeValue {
            try ParserLibrary.parseFixedString("SIZE ", buffer: &buffer, tracker: tracker)
            return .size(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_modSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.StatusAttributeValue {
            try ParserLibrary.parseFixedString("HIGHESTMODSEQ ", buffer: &buffer, tracker: tracker)
            return .modSequence(try self.parseModifierSequenceValue(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseStatusAttributeValue_messages,
            parseStatusAttributeValue_uidnext,
            parseStatusAttributeValue_uidvalidity,
            parseStatusAttributeValue_unseen,
            parseStatusAttributeValue_deleted,
            parseStatusAttributeValue_size,
            parseStatusAttributeValue_modSequence
        ], buffer: &buffer, tracker: tracker)
    }

    // status-att-list  = status-att-val *(SP status-att-val)
    static func parseStatusAttributeList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.StatusAttributeList {

        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.StatusAttributeList in
            var array = [try parseStatusAttributeValue(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.StatusAttributeValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try parseStatusAttributeValue(buffer: &buffer, tracker: tracker)
            }
            return array
        }
    }

    // status-option = "STATUS" SP "(" status-att *(SP status-att) ")"
    static func parseStatusOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.StatusOption {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.StatusOption in
            try ParserLibrary.parseFixedString("STATUS (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.StatusAttribute in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // store           = "STORE" SP sequence-set SP store-att-flags
    static func parseStore(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("STORE ", buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            let modifiers = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseStoreModifiers)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let flags = try self.parseStoreAttributeFlags(buffer: &buffer, tracker: tracker)
            return .store(sequence, modifiers, flags)
        }
    }

    // store-att-flags = (["+" / "-"] "FLAGS" [".SILENT"]) SP
    //                   (flag-list / (flag *(SP flag)))
    static func parseStoreAttributeFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.StoreAttributeFlags {

        func parseStoreAttributeFlags_silent(buffer: inout ByteBuffer, tracker: StackTracker)-> Bool {
            do {
                try ParserLibrary.parseFixedString(".SILENT", buffer: &buffer, tracker: tracker)
                return true
            } catch {
                return false
            }
        }

        func parseStoreAttributeFlags_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.Flag] {
            return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [NIOIMAP.Flag] in
                var output = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Flag in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                return output
            }
        }

        func parseStoreAttributeFlags_type(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.StoreAttributeFlagsType {
            return try ParserLibrary.parseOneOf([
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> NIOIMAP.StoreAttributeFlagsType in
                    try ParserLibrary.parseFixedString("+FLAGS", buffer: &buffer, tracker: tracker)
                    return .add
                },
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> NIOIMAP.StoreAttributeFlagsType in
                    try ParserLibrary.parseFixedString("-FLAGS", buffer: &buffer, tracker: tracker)
                    return .remove
                },
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> NIOIMAP.StoreAttributeFlagsType in
                    try ParserLibrary.parseFixedString("FLAGS", buffer: &buffer, tracker: tracker)
                    return .other
                }
            ], buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.StoreAttributeFlags in
            let type = try parseStoreAttributeFlags_type(buffer: &buffer, tracker: tracker)
            let silent = parseStoreAttributeFlags_silent(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let flags = try ParserLibrary.parseOneOf([
                parseStoreAttributeFlags_array,
                parseFlagList
            ], buffer: &buffer, tracker: tracker)
            return NIOIMAP.StoreAttributeFlags(type: type, silent: silent, flags: flags)
        }
    }
    
    // store-modifier = store-modifier-name [SP store-modif-params]
    static func parseStoreModifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.StoreModifier {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseStoreModifierName(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.TaggedExtensionValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseStoreModifierParameters(buffer: &buffer, tracker: tracker)
            }
            return .name(name, parameters: params)
        }
    }
    
    // store-modifiers = SP "(" store-modifier *(SP store-modifier ")"
    static func parseStoreModifiers(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.StoreModifier] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseStoreModifier(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.StoreModifier in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseStoreModifier(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }
    
    // store-modifier-name = tagged-ext-label
    static func parseStoreModifierName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
    }
    
    // store-modifier-params = tagged-ext-val
    static func parseStoreModifierParameters(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionValue {
        return try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }

    // string          = quoted / literal
    static func parseString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        return try ParserLibrary.parseOneOf([
            Self.parseQuoted,
            Self.parseLiteral
        ], buffer: &buffer, tracker: tracker)
    }

    // subscribe       = "SUBSCRIBE" SP mailbox
    static func parseSubscribe(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("SUBSCRIBE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .subscribe(mailbox)
        }
    }

    // tag             = 1*<any ASTRING-CHAR except "+">
    static func parseTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            return char.isAStringChar && char != UInt8(ascii: "+")
        }
    }

    // tag-string       = string
    static func parseTagString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TagString {
        return try self.parseString(buffer: &buffer, tracker: tracker)
    }

    // tagged-ext = tagged-ext-label SP tagged-ext-val
    static func parseTaggedExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtension {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let label = try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let value = try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
            return .label(label, value: value)
        }
    }
    
    // tagged-ext-label    = tagged-label-fchar *tagged-label-char
    static func parseTaggedExtensionLabel(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in

            guard let fchar = buffer.readBytes(length: 1)?.first else {
                throw NIOIMAP.ParsingError.incompleteMessage
            }
            guard fchar.isTaggedLabelFchar else {
                throw ParserError(hint: "\(fchar) is not a valid fchar’")
            }

            let trailing = try ParserLibrary.parseZeroOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
                return char.isTaggedLabelChar
            }

            return String(decoding: [fchar], as: Unicode.UTF8.self) + trailing
        }
    }

    // astring
    // continuation = ( SP tagged-ext-comp )*
    // tagged-ext-comp = astring continuation | '(' tagged-ext-comp ')' continuation
    static func parseTaggedExtensionComplex_continuation(
        into: inout NIOIMAP.TaggedExtensionComplex,
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
        into: inout NIOIMAP.TaggedExtensionComplex,
        buffer: inout ByteBuffer,
        tracker: StackTracker
    ) throws {

        func parseTaggedExtensionComplex_string(
            into: inout NIOIMAP.TaggedExtensionComplex,
            buffer: inout ByteBuffer,
            tracker: StackTracker
        ) throws {
            into.append(try self.parseAString(buffer: &buffer, tracker: tracker))
            try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
        }

        func parseTaggedExtensionComplex_bracketed(
            into: inout NIOIMAP.TaggedExtensionComplex,
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
    static func parseTaggedExtensionComplex(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionComplex {
        var result = NIOIMAP.TaggedExtensionComplex()
        try self.parseTaggedExtensionComplex_helper(into: &result, buffer: &buffer, tracker: tracker)
        return result
    }

    // tagged-ext-simple   = sequence-set / number / number64
    static func parseTaggedExtensionSimple(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionSimple {

        func parseTaggedExtensionSimple_set(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionSimple {
            return .sequence(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionSimple_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionSimple {
            return .number(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionSimple_number64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionSimple {
            return .number64(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseTaggedExtensionSimple_set,
            parseTaggedExtensionSimple_number,
            parseTaggedExtensionSimple_number64
        ], buffer: &buffer, tracker: tracker)
    }

    // tagged-ext-val      = tagged-ext-simple /
    //                       "(" [tagged-ext-comp] ")"
    static func parseTaggedExtensionValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionValue {

        func parseTaggedExtensionVal_simple(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionValue {
            return .simple(try self.parseTaggedExtensionSimple(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionVal_comp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.TaggedExtensionValue {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseTaggedExtensionComplex)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .comp(comp)
        }

        return try ParserLibrary.parseOneOf([
            parseTaggedExtensionVal_simple,
            parseTaggedExtensionVal_comp
        ], buffer: &buffer, tracker: tracker)
    }

    // text            = 1*TEXT-CHAR
    static func parseText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        return try ParserLibrary.parseOneOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char -> Bool in
            return char.isTextChar
        }
    }

    // time            = 2DIGIT ":" 2DIGIT ":" 2DIGIT
    static func parseTime(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Date.Time {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.Date.Time in
            let hour = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(":", buffer: &buffer, tracker: tracker)
            let minute = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(":", buffer: &buffer, tracker: tracker)
            let second = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            return NIOIMAP.Date.Time(hour: hour, minute: minute, second: second)
        }
    }

    // uid             = "UID" SP
    //                   (copy / move / fetch / search / store / uid-expunge)
    static func parseUid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {

        func parseUid_subcommand_command(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.UIDCommandType {
            let type = try ParserLibrary.parseOneOf([
                self.parseCommandAny,
                self.parseCommandAuth,
                self.parseCommandNonauth,
                self.parseCommandSelect
            ], buffer: &buffer, tracker: tracker)
            guard let uidCommand = NIOIMAP.UIDCommandType(commandType: type) else {
                throw ParserError(hint: "Invalid UID command")
            }
            return uidCommand
        }

        func parseUid_subcommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.UIDCommandType {
            return try ParserLibrary.parseOneOf([
                parseUidExpunge,
                parseUid_subcommand_command
            ], buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
            try ParserLibrary.parseFixedString("UID ", buffer: &buffer, tracker: tracker)
            return .uid(try parseUid_subcommand(buffer: &buffer, tracker: tracker))
        }
    }

    // uid-expunge    = "EXPUNGE" SP sequence-set
    static func parseUidExpunge(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.UIDCommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("EXPUNGE ", buffer: &buffer, tracker: tracker)
            let set = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            return .uidExpunge(set)
        }
    }

    // uid-set         = (uniqueid / uid-range) *("," uid-set)
    static func parseUidSet(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.UIDSetType] {

        func parseUidSetType_id(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.UIDSetType {
            return .uniqueID(try self.parseUniqueID(buffer: &buffer, tracker: tracker))
        }

        func parseUidSetType_range(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.UIDSetType {
            return .range(try self.parseUidRange(buffer: &buffer, tracker: tracker))
        }

        func parseUidSetType(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.UIDSetType {
            return try ParserLibrary.parseOneOf([
                parseUidSetType_range,
                parseUidSetType_id,
            ], buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [NIOIMAP.UIDSetType] in
            var array = [try parseUidSetType(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> NIOIMAP.UIDSetType in
                try ParserLibrary.parseFixedString(",", buffer: &buffer, tracker: tracker)
                return try parseUidSetType(buffer: &buffer, tracker: tracker)
            }
            return array
        }
    }

    // uid-range       = (uniqueid ":" uniqueid)
    static func parseUidRange(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.UIDRange {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.UIDRange in
            let id1 = try self.parseUniqueID(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(":", buffer: &buffer, tracker: tracker)
            let id2 = try self.parseUniqueID(buffer: &buffer, tracker: tracker)
            return NIOIMAP.UIDRange(left: id1, right: id2)
        }
    }

    // uniqueid        = nz-number
    static func parseUniqueID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
    }

    // unsubscribe     = "UNSUBSCRIBE" SP mailbox
    static func parseUnsubscribe(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.CommandType {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NIOIMAP.CommandType in
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
        return try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            return char.isAlpha
        }
    }

    // x-command       = "X" atom <experimental command arguments>
    static func parseXCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try ParserLibrary.parseFixedString("X", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return atom
        }
    }

    // zone            = ("+" / "-") 4DIGIT
    static func parseZone(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Date.TimeZone {

        func parseZonePositive(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Date.TimeZone {
            try ParserLibrary.parseFixedString("+", buffer: &buffer, tracker: tracker)
            let num = try self.parse4Digit(buffer: &buffer, tracker: tracker)
            guard let zone = NIOIMAP.Date.TimeZone(num) else {
                throw ParserError(hint: "Building TimeZone from \(num) failed")
            }
            return zone
        }

        func parseZoneNegative(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Date.TimeZone {
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let num = try self.parse4Digit(buffer: &buffer, tracker: tracker)
            guard let zone = NIOIMAP.Date.TimeZone(-num) else {
                throw ParserError(hint: "Building TimeZone from \(num) failed")
            }
            return zone
        }

        return try ParserLibrary.parseOneOf([
            parseZonePositive,
            parseZoneNegative
        ], buffer: &buffer, tracker: tracker)
    }

}

// MARK: - Helper Parsers
extension NIOIMAP.GrammarParser {

    static func parseBodyLocationExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldLocationExtension {
        let fieldLocation = try self.parseNString(buffer: &buffer, tracker: tracker)
        let extensions = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [NIOIMAP.BodyExtensionType] in
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            return try self.parseBodyExtension(buffer: &buffer, tracker: tracker)
        }
        return NIOIMAP.Body.FieldLocationExtension(location: fieldLocation, extensions: extensions)
    }

    static func parseBodyLanguageLocation(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldLanguageLocation {
        let fieldLanguage = try self.parseBodyFieldLanguage(buffer: &buffer, tracker: tracker)
        try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
        let locationExtension = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            return try parseBodyLocationExtension(buffer: &buffer, tracker: tracker)
        }
        return NIOIMAP.Body.FieldLanguageLocation(language: fieldLanguage, location: locationExtension)
    }

    static func parseBodyDescriptionLanguage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Body.FieldDSPLanguage {
        let description = try self.parseBodyFieldDsp(buffer: &buffer, tracker: tracker)
        let language = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NIOIMAP.Body.FieldLanguageLocation in
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            return try parseBodyLanguageLocation(buffer: &buffer, tracker: tracker)
        }
        return NIOIMAP.Body.FieldDSPLanguage(fieldDSP: description, fieldLanguage: language)
    }

    static func parse2Digit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        return try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 2)
    }

    static func parse4Digit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        return try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 4)
    }

    static func parseNDigits(buffer: inout ByteBuffer, tracker: StackTracker, bytes: Int) throws -> Int {
        let (num, size) = try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker)
        guard size == bytes else {
            throw ParserError(hint: "Expected \(bytes) digits, got \(size)")
        }
        return num
    }

    // reusable for a lot of the env-* types
    static func parseEnvelopeAddresses(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.Address] {
        try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
        let addresses = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { buffer, tracker in
            return try self.parseAddress(buffer: &buffer, tracker: tracker)
        }
        try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
        return addresses
    }

    static func parseOptionalEnvelopeAddresses(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.Address]? {
        func parseOptionalEnvelopeAddresses_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NIOIMAP.Address]? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }
        return try ParserLibrary.parseOneOf([
            parseEnvelopeAddresses,
            parseOptionalEnvelopeAddresses_nil
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseRFC822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.RFC822 {

        func parseRFC822_header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.RFC822 {
            try ParserLibrary.parseFixedString(".HEADER", buffer: &buffer, tracker: tracker)
            return .header
        }

        func parseRFC822_size(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.RFC822 {
            try ParserLibrary.parseFixedString(".SIZE", buffer: &buffer, tracker: tracker)
            return .size
        }

        func parseRFC822_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.RFC822 {
            try ParserLibrary.parseFixedString(".TEXT", buffer: &buffer, tracker: tracker)
            return .text
        }

        return try ParserLibrary.parseOneOf([
            parseRFC822_header,
            parseRFC822_size,
            parseRFC822_text
        ], buffer: &buffer, tracker: tracker)

    }

    static func parseRFC822Reduced(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.RFC822Reduced {

        func parseRFC822Reduced_header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.RFC822Reduced {
            try ParserLibrary.parseFixedString(".HEADER", buffer: &buffer, tracker: tracker)
            return .header
        }

        func parseRFC822Reduced_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.RFC822Reduced {
            try ParserLibrary.parseFixedString(".TEXT", buffer: &buffer, tracker: tracker)
            return .text
        }

        return try ParserLibrary.parseOneOf([
            parseRFC822Reduced_header,
            parseRFC822Reduced_text
        ], buffer: &buffer, tracker: tracker)
    }

}
