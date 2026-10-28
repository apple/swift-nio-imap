//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

/// Property tests for folding the flat RFC 3501 §7.4.2 address list into groups (#859).
///
/// Each seed generates `casesPerSeed` lists; the first failing case per seed is reported with
/// seed, case index and input, so it can be rerun alone.
@Suite("Envelope grouping properties")
struct EnvelopeGroupingPropertyTests {
    static let seeds: [UInt64] = (1...20).map { UInt64($0) &* 0x2545_F491_4F6C_DD1D }
    static let casesPerSeed = 50
    static let maximumLength = 64
    /// Wire form affects classification only; idempotence and the oracle are fold-level.
    fileprivate static let endToEndProperties: [GroupingProperty] = [
        .lossless, .noInvention, .noEndMarkerLeaks,
    ]

    @Test("no address lost", arguments: seeds)
    func lossless(seed: UInt64) {
        Self.check(.lossless, seed: seed)
    }

    @Test("no group invented", arguments: seeds)
    func noInvention(seed: UInt64) {
        Self.check(.noInvention, seed: seed)
    }

    @Test("no end marker leaks", arguments: seeds)
    func noEndMarkerLeaks(seed: UInt64) {
        Self.check(.noEndMarkerLeaks, seed: seed)
    }

    @Test("fold is idempotent", arguments: seeds)
    func idempotent(seed: UInt64) {
        Self.check(.idempotent, seed: seed)
    }

    @Test("well-formed input folds as before", arguments: seeds)
    func matchesLegacyOnWellFormedInput(seed: UInt64) {
        Self.check(.matchesLegacy, seed: seed, shapes: .wellFormedOnly)
    }

    /// Properties 1–3 through `parseEnvelope`: classification depends on the wire form.
    @Test("end to end through parseEnvelope", arguments: seeds)
    func endToEnd(seed: UInt64) {
        var generator = AddressListGenerator(seed: seed)
        for index in 0..<Self.casesPerSeed {
            let (shape, input) = generator.next(shapes: .all)
            let wire = generator.wireEnvelope(from: input)
            let parsed: Envelope
            do {
                parsed = try Self.parseEnvelope(wire)
            } catch {
                Issue.record("seed \(seed) case \(index) \(shape): threw \(error)\nwire: \(wire)")
                return
            }
            for property in Self.endToEndProperties {
                guard let failure = property.violation(input: input, output: parsed.from) else { continue }
                Issue.record("seed \(seed) case \(index) \(shape) \(property): \(failure)\nwire: \(wire)")
                return
            }
        }
    }
}

// MARK: - Width

/// Correctness at scale only: no timing assertion.
extension EnvelopeGroupingPropertyTests {
    static let emptyGroupCount = 3_000
    static let addressCount = 6_000

    @Test("many empty groups")
    func manyEmptyGroups() {
        let names = (0..<Self.emptyGroupCount).map { ByteBuffer(string: "g\($0)") }
        let input = names.flatMap { [EmailAddress.groupStart($0), .groupEnd()] }
        let output = GrammarParser().parseEnvelopeEmailAddressGroups(input)
        #expect(output.count == Self.emptyGroupCount)
        #expect(output == names.map { .group(.init(groupName: $0, sourceRoot: nil, children: [])) })
    }

    @Test("many addresses")
    func manyAddresses() {
        let input = (0..<Self.addressCount).map {
            EmailAddress(personName: nil, sourceRoot: nil, mailbox: ByteBuffer(string: "a\($0)"), host: "example.com")
        }
        let output = GrammarParser().parseEnvelopeEmailAddressGroups(input)
        #expect(output.count == Self.addressCount)
        #expect(output == input.map { .singleAddress($0) })
    }

    /// Exercises the append-to-open-group path.
    @Test("many members in one group")
    func manyGroupMembers() {
        let members = (0..<Self.addressCount).map {
            EmailAddress(personName: nil, sourceRoot: nil, mailbox: ByteBuffer(string: "a\($0)"), host: "example.com")
        }
        let input = [EmailAddress.groupStart("g")] + members + [.groupEnd()]
        let output = GrammarParser().parseEnvelopeEmailAddressGroups(input)
        #expect(output == [.group(EmailAddressGroup(groupName: "g", sourceRoot: nil, children: members))])
    }
}

// MARK: - Driver

extension EnvelopeGroupingPropertyTests {
    /// Runs `property` over `casesPerSeed` generated lists; records the first violation only.
    fileprivate static func check(
        _ property: GroupingProperty,
        seed: UInt64,
        shapes: ShapeSelection = .all,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        var generator = AddressListGenerator(seed: seed)
        for index in 0..<casesPerSeed {
            let (shape, input) = generator.next(shapes: shapes)
            let output = GrammarParser().parseEnvelopeEmailAddressGroups(input)
            guard let failure = property.violation(input: input, output: output) else { continue }
            Issue.record(
                "seed \(seed) case \(index) \(shape): \(failure)\ninput: \(describe(input))",
                sourceLocation: sourceLocation
            )
            return
        }
    }

    fileprivate static func parseEnvelope(_ wire: String) throws -> Envelope {
        // Terminator: the envelope must not end the buffer.
        var buffer = ParseBuffer(ByteBuffer(string: wire + "\r"))
        return try GrammarParser().parseEnvelope(buffer: &buffer, tracker: .makeNewDefault)
    }
}

// MARK: - Properties

private enum GroupingProperty: CustomStringConvertible {
    case lossless
    case noInvention
    case noEndMarkerLeaks
    case idempotent
    case matchesLegacy

    var description: String {
        switch self {
        case .lossless: "lossless"
        case .noInvention: "no invention"
        case .noEndMarkerLeaks: "no end marker leaks"
        case .idempotent: "idempotent"
        case .matchesLegacy: "matches legacy"
        }
    }

    /// `nil` if the property holds, else a description of the violation.
    func violation(input: [EmailAddress], output: [EmailAddressListElement]) -> String? {
        switch self {
        case .lossless:
            let expected = input.filter { !$0.isGroupEnd }
            let actual = flatten(output, markers: .startsOnly)
            return actual == expected ? nil : "output \(describe(actual))"
        case .noInvention:
            return firstInventedGroup(input: input, output: output).map { "invented \($0)" }
        case .noEndMarkerLeaks:
            return allAddresses(output).contains(where: \.isGroupEnd) ? "end marker in output" : nil
        case .idempotent:
            let refolded = GrammarParser().parseEnvelopeEmailAddressGroups(flatten(output, markers: .startsAndEnds))
            return refolded == output ? nil : "refolded differs"
        case .matchesLegacy:
            guard let legacy = legacyParseEnvelopeEmailAddressGroups(input) else { return "legacy nested" }
            return output == legacy ? nil : "differs from legacy"
        }
    }
}

// MARK: - List helpers

/// Every `.singleAddress`, top level and group members.
private func allAddresses(_ elements: [EmailAddressListElement]) -> [EmailAddress] {
    elements.flatMap { element -> [EmailAddress] in
        switch element {
        case .singleAddress(let address): [address]
        case .group(let group): group.children
        }
    }
}

private enum MarkerFlattening {
    /// group → start, children. Used to compare against non-end input addresses.
    case startsOnly
    /// group → start, children, end. Matches the encoder (`writeEmailAddressGroup`).
    case startsAndEnds
}

/// Flattens back into the wire sequence.
private func flatten(_ elements: [EmailAddressListElement], markers: MarkerFlattening) -> [EmailAddress] {
    elements.flatMap { element -> [EmailAddress] in
        switch element {
        case .singleAddress(let address):
            return [address]
        case .group(let group):
            let start = EmailAddress.groupStart(group.groupName, sourceRoot: group.sourceRoot)
            let end: [EmailAddress] = markers == .startsAndEnds ? [.groupEnd(sourceRoot: group.sourceRoot)] : []
            return [start] + group.children + end
        }
    }
}

/// First output group not backed by an input run `start, address…, end`.
///
/// Groups are matched in output order against a forward-only input cursor, so each run backs at
/// most one group and groups cannot be reordered. A member that is a marker never matches.
private func firstInventedGroup(input: [EmailAddress], output: [EmailAddressListElement]) -> String? {
    var cursor = input.startIndex
    for case .group(let group) in output {
        guard let runEnd = bracketedRunEnd(for: group, in: input, from: cursor) else {
            return "group \(String(buffer: group.groupName)) with \(group.children.count) children"
        }
        cursor = runEnd
    }
    return nil
}

/// Index just past the first run at or after `cursor` that brackets exactly `group`, or `nil`.
private func bracketedRunEnd(for group: EmailAddressGroup, in input: [EmailAddress], from cursor: Int) -> Int? {
    let members = group.children
    guard !members.contains(where: \.isGroupMarker) else { return nil }
    let runLength = members.count + 2
    guard input.count - cursor >= runLength else { return nil }
    for startIndex in cursor...(input.count - runLength) {
        let start = input[startIndex]
        guard start.isGroupStart, start.mailbox == group.groupName, start.sourceRoot == group.sourceRoot else {
            continue
        }
        let memberRange = (startIndex + 1)..<(startIndex + 1 + members.count)
        guard Array(input[memberRange]) == members, input[memberRange.upperBound].isGroupEnd else { continue }
        return memberRange.upperBound + 1
    }
    return nil
}

private func describe(_ addresses: [EmailAddress]) -> String {
    func field(_ value: ByteBuffer?) -> String {
        value.map { "\"\(String(buffer: $0))\"" } ?? "NIL"
    }
    let items = addresses.map {
        "(\(field($0.personName)) \(field($0.sourceRoot)) \(field($0.mailbox)) \(field($0.host)))"
    }
    return "(\(items.joined()))"
}

// MARK: - Markers

/// RFC 3501 §7.4.2: host NIL marks a group; start has mailbox = group name, end has mailbox NIL.
extension EmailAddress {
    fileprivate var isGroupMarker: Bool { host == nil }
    fileprivate var isGroupStart: Bool { host == nil && mailbox != nil }
    fileprivate var isGroupEnd: Bool { host == nil && mailbox == nil }

    fileprivate static func groupStart(_ name: ByteBuffer, sourceRoot: ByteBuffer? = nil) -> EmailAddress {
        .init(personName: nil, sourceRoot: sourceRoot, mailbox: name, host: nil)
    }

    fileprivate static func groupEnd(sourceRoot: ByteBuffer? = nil) -> EmailAddress {
        .init(personName: nil, sourceRoot: sourceRoot, mailbox: nil, host: nil)
    }
}

// MARK: - Legacy oracle

/// Pre-#859 fold, verbatim except its nestable group type, now private. Correct on well-formed input only.
/// `nil` if it nested, which well-formed input cannot.
private func legacyParseEnvelopeEmailAddressGroups(_ addresses: [EmailAddress]) -> [EmailAddressListElement]? {
    var results: [LegacyElement] = []
    var stack: [LegacyGroup] = []

    for address in addresses {
        // RFC 2822 Syntaxt: If the host is nil then the group has started
        // if the mailbox is also nil, then the group has finished.
        if address.host == nil, let name = address.mailbox {  // start of group
            stack.append(LegacyGroup(groupName: name, sourceRoot: address.sourceRoot, children: []))
        } else if address.host == nil, let group = stack.popLast() {  // end of group
            if stack.last == nil {
                results.append(.group(group))
            } else {
                stack[stack.count - 1].children.append(.group(group))
            }
        } else {  // normal address
            if stack.last == nil {
                results.append(.singleAddress(address))
            } else {
                stack[stack.count - 1].children.append(.singleAddress(address))
            }
        }
    }

    let flattened = results.compactMap(\.flattened)
    return flattened.count == results.count ? flattened : nil
}

/// Pre-#859 `EmailAddressGroup`: children could be groups.
private struct LegacyGroup {
    var groupName: ByteBuffer
    var sourceRoot: ByteBuffer?
    var children: [LegacyElement]
}

/// Pre-#859 `EmailAddressListElement`.
private indirect enum LegacyElement {
    case singleAddress(EmailAddress)
    case group(LegacyGroup)

    /// The current type, or `nil` if the group nests.
    var flattened: EmailAddressListElement? {
        switch self {
        case .singleAddress(let address):
            return .singleAddress(address)
        case .group(let group):
            let members = group.children.compactMap { child -> EmailAddress? in
                guard case .singleAddress(let address) = child else { return nil }
                return address
            }
            guard members.count == group.children.count else { return nil }
            return .group(.init(groupName: group.groupName, sourceRoot: group.sourceRoot, children: members))
        }
    }
}

// MARK: - Generator

/// Deterministic, platform-independent PRNG (Steele, Lea, Flood 2014).
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        self.state &+= 0x9E37_79B9_7F4A_7C15
        var z = self.state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private enum ShapeSelection {
    case all
    case wellFormedOnly
}

/// Input shapes, weighted towards the malformed sequences that matter.
private enum Shape: CaseIterable, CustomStringConvertible {
    case longStartRun
    case markersOnly
    case alternating
    case endBeforeStart
    case empty
    case uniform
    case wellFormed

    var weight: Int {
        switch self {
        case .longStartRun: 2
        case .markersOnly: 2
        case .alternating: 2
        case .endBeforeStart: 2
        case .empty: 1
        case .uniform: 4
        case .wellFormed: 4
        }
    }

    var description: String {
        switch self {
        case .longStartRun: "long start run"
        case .markersOnly: "markers only"
        case .alternating: "alternating"
        case .endBeforeStart: "end before start"
        case .empty: "empty"
        case .uniform: "uniform"
        case .wellFormed: "well-formed"
        }
    }
}

private struct AddressListGenerator {
    private static let groupNames: [ByteBuffer] = ["Team", "A", "B", "", "undisclosed-recipients"]
    private static let personNames: [ByteBuffer?] = [nil, "", "Alice"]
    private static let mailboxes: [ByteBuffer?] = [nil, "", "alice", "bob"]
    /// Never NIL: a NIL host is a marker.
    private static let hosts: [ByteBuffer] = ["example.com", ""]
    private static let sourceRoots: [ByteBuffer?] = [nil, nil, nil, "@relay"]
    private static let maximumGroupMembers = 5

    private var rng: SplitMix64

    init(seed: UInt64) {
        self.rng = SplitMix64(seed: seed)
    }

    mutating func next(shapes: ShapeSelection) -> (Shape, [EmailAddress]) {
        let shape = self.pickShape(shapes)
        return (shape, self.generate(shape))
    }

    private mutating func pickShape(_ selection: ShapeSelection) -> Shape {
        guard selection == .all else { return .wellFormed }
        let total = Shape.allCases.map(\.weight).reduce(0, +)
        var roll = Int.random(in: 0..<total, using: &self.rng)
        for shape in Shape.allCases {
            if roll < shape.weight { return shape }
            roll -= shape.weight
        }
        return .uniform
    }

    private mutating func generate(_ shape: Shape) -> [EmailAddress] {
        let limit = EnvelopeGroupingPropertyTests.maximumLength
        var result: [EmailAddress] = []
        switch shape {
        case .empty:
            break
        case .longStartRun:
            result += (0..<self.int(0...8)).map { _ in self.anyElement() }
            result += (0..<self.int(2...40)).map { _ in self.start() }
            result += (0..<self.int(0...16)).map { _ in self.anyElement() }
        case .markersOnly:
            result = (0..<self.int(1...limit)).map { _ in self.bool() ? self.start() : self.end() }
        case .alternating:
            for _ in 0..<self.int(1...(limit / 3)) {
                result.append(self.start())
                if self.bool() { result.append(self.address()) }
                result.append(self.end())
            }
        case .endBeforeStart:
            for _ in 0..<self.int(1...(limit / 6)) {
                result.append(self.end())
                result.append(self.start())
                result += (0..<self.int(0...3)).map { _ in self.address() }
            }
            if self.bool() { result.append(self.end()) }
        case .uniform:
            result = (0..<self.int(0...limit)).map { _ in self.anyElement() }
        case .wellFormed:
            // Built directly, not filtered: balanced, no start inside a group.
            while result.count < limit - Self.maximumGroupMembers - 2, self.int(0...7) != 0 {
                guard self.bool() else {
                    result.append(self.address())
                    continue
                }
                result.append(self.start())
                result += (0..<self.int(0...Self.maximumGroupMembers)).map { _ in self.address() }
                result.append(self.end())
            }
        }
        return Array(result.prefix(limit))
    }

    // MARK: Elements

    private mutating func anyElement() -> EmailAddress {
        switch self.int(0...2) {
        case 0: self.start()
        case 1: self.end()
        default: self.address()
        }
    }

    private mutating func start() -> EmailAddress {
        .groupStart(self.pick(Self.groupNames), sourceRoot: self.pick(Self.sourceRoots))
    }

    private mutating func end() -> EmailAddress {
        .groupEnd(sourceRoot: self.pick(Self.sourceRoots))
    }

    private mutating func address() -> EmailAddress {
        EmailAddress(
            personName: self.pick(Self.personNames),
            sourceRoot: self.pick(Self.sourceRoots),
            mailbox: self.pick(Self.mailboxes),
            host: self.pick(Self.hosts)
        )
    }

    // MARK: Wire form

    /// ENVELOPE with `addresses` as From; every other field NIL.
    mutating func wireEnvelope(from addresses: [EmailAddress]) -> String {
        "(NIL NIL \(self.wireAddressList(addresses)) NIL NIL NIL NIL NIL NIL NIL)"
    }

    private mutating func wireAddressList(_ addresses: [EmailAddress]) -> String {
        guard !addresses.isEmpty else { return self.bool() ? "NIL" : "()" }
        let items = addresses.map { address in
            let fields = [address.personName, address.sourceRoot, address.mailbox, address.host]
            return "(" + fields.map { self.wireNString($0) }.joined(separator: " ") + ")"
        }
        return "(" + items.joined() + ")"
    }

    /// Varies the encoding of the same value: NIL / nil, quoted, literal.
    private mutating func wireNString(_ value: ByteBuffer?) -> String {
        guard let value else { return self.bool() ? "NIL" : "nil" }
        let string = String(buffer: value)
        guard self.bool() else { return "\"\(string)\"" }
        return "{\(value.readableBytes)}\r\n\(string)"
    }

    // MARK: Randomness

    private mutating func int(_ range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &self.rng)
    }

    private mutating func bool() -> Bool {
        Bool.random(using: &self.rng)
    }

    private mutating func pick<T>(_ values: [T]) -> T {
        values[self.int(0...(values.count - 1))]
    }
}
