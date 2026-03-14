# Supported IMAP Extensions

NIOIMAP supports a variety of known IMAP extensions. This page documents the complete list of supported capabilities and their corresponding RFC specifications.

For more information about IMAP capabilities, see the [IANA IMAP Capabilities Registry](https://www.iana.org/assignments/imap-capabilities/imap-capabilities.xhtml).

## Extension Capabilities

| Capability | | RFC | Title |
| --- | --- | --- | --- |
| `APPENDLIMIT` | ``Capability/mailboxSpecificAppendLimit`` + ``Capability/appendLimit(_:)`` | [RFC 7889](https://www.iana.org/go/rfc7889) | IMAP Extensions: APPENDLIMIT |
| `AUTH=` | | [RFC 3501](https://www.iana.org/go/rfc3501) | IMAP4rev1 |
| `BINARY` | ``Capability/binary`` | [RFC 3516](https://www.iana.org/go/rfc3516) | IMAP4 Binary Content Extension |
| `CATENATE` | ``Capability/catenate`` | [RFC 4469](https://www.iana.org/go/rfc4469) | IMAP CATENATE Extension |
| `CHILDREN` | ``Capability/children`` | [RFC 3348](https://www.iana.org/go/rfc3348) | IMAP4 Child Mailbox Extension |
| `CONDSTORE` | ``Capability/condStore`` | [RFC 7162](https://www.iana.org/go/rfc7162) | IMAP Extensions: CONDSTORE and QRESYNC |
| `CREATE-SPECIAL-USE` | ``Capability/createSpecialUse`` | [RFC 6154](https://www.iana.org/go/rfc6154) | IMAP LIST Extension for Special-Use Mailboxes |
| `ENABLE` | ``Capability/enable`` | [RFC 5161](https://www.iana.org/go/rfc5161) | The IMAP ENABLE Extension |
| `ESEARCH` | ``Capability/extendedSearch`` | [RFC 4731](https://www.iana.org/go/rfc4731) | IMAP4 Extension to SEARCH Command for Controlling What Kind of Information is Returned |
| `ID` | ``Capability/id`` | [RFC 2971](https://www.iana.org/go/rfc2971) | IMAP4 ID Extension |
| `IDLE` | ``Capability/idle`` | [RFC 2177](https://www.iana.org/go/rfc2177) | IMAP4 IDLE Command |
| `LIST-EXTENDED` | ``Capability/listExtended`` | [RFC 5258](https://www.iana.org/go/rfc5258) | Internet Message Access Protocol - LIST Command Extensions |
| `LIST-STATUS` | ``Capability/listStatus`` | [RFC 5819](https://www.iana.org/go/rfc5819) | IMAP4 Extension for Returning STATUS Information in Extended LIST |
| `LITERAL-` | ``Capability/literalMinus`` | [RFC 7888](https://www.iana.org/go/rfc7888) | IMAP4 Non-synchronizing Literals |
| `LITERAL+` | ``Capability/literalPlus`` | [RFC 7888](https://www.iana.org/go/rfc7888) | IMAP4 Non-synchronizing Literals |
| `LOGIN-REFERRALS` | ``Capability/loginReferrals`` | [RFC 2221](https://www.iana.org/go/rfc2221) | IMAP4 Login Referrals |
| `LOGINDISABLED` | ``Capability/loginDisabled`` | [RFC 3501](https://www.iana.org/go/rfc3501) | IMAP4rev1 |
| `MESSAGELIMIT` | | [RFC 9738](https://www.iana.org/go/rfc9738) | IMAP4 Extension for Message Limit |
| `METADATA` | ``Capability/metadata`` | [RFC 5464](https://www.iana.org/go/rfc5464) | The IMAP METADATA Extension |
| `METADATA-SERVER` | ``Capability/metadataServer`` | [RFC 5464](https://www.iana.org/go/rfc5464) | The IMAP METADATA Extension |
| `MOVE` | ``Capability/move`` | [RFC 6851](https://www.iana.org/go/rfc6851) | IMAP4 Extension for Moving Messages (MOVE Command) |
| `MULTIAPPEND` | | [RFC 3502](https://www.iana.org/go/rfc3502) | Internet Message Access Protocol (IMAP) - MULTIAPPEND Extension |
| `MULTISEARCH` | ``Capability/multiSearch`` | [RFC 7377](https://www.iana.org/go/rfc7377) | IMAP4 Multisearch Extension |
| `NAMESPACE` | ``Capability/namespace`` | [RFC 2342](https://www.iana.org/go/rfc2342) | IMAP4 Namespace |
| `OBJECTID` | ``Capability/objectID`` | [RFC 8474](https://www.iana.org/go/rfc8474) | IMAP Extension for Object Identifiers |
| `PARTIAL` | ``Capability/partial`` | [RFC 9394](https://www.iana.org/go/rfc9394) | IMAP Partial Extension for Fetching Parts of Messages |
| `PREVIEW` | ``Capability/preview`` | [RFC 8970](https://www.iana.org/go/rfc8970) | IMAP4 PREVIEW Extension |
| `QRESYNC` | ``Capability/qresync`` | [RFC 7162](https://www.iana.org/go/rfc7162) | IMAP Extensions: CONDSTORE and QRESYNC |
| `QUOTA` | ``Capability/quota`` | [RFC 2087](https://www.iana.org/go/rfc2087) | IMAP4 Quota Extension |
| `SASL-IR` | ``Capability/saslIR`` | [RFC 4959](https://www.iana.org/go/rfc4959) | IMAP Extension for Simple Authentication and Security Layer (SASL) Initial Client Response |
| `SEARCHRES` | ``Capability/searchRes`` | [RFC 5182](https://www.iana.org/go/rfc5182) | IMAP Extension for Referencing the Last SEARCH Result |
| `SPECIAL-USE` | ``Capability/specialUse`` | [RFC 6154](https://www.iana.org/go/rfc6154) | IMAP LIST Extension for Special-Use Mailboxes |
| `STARTTLS` | ``Capability/startTLS`` | [RFC 3501](https://www.iana.org/go/rfc3501) | IMAP4rev1 |
| `STATUS=SIZE` | | [RFC 8438](https://www.iana.org/go/rfc8438) | IMAP4 STATUS Command Extension for Message Size Information |
| `UIDBATCHES` | ``Capability/uidBatches`` | [draft-ietf-mailmaint-imap-uidbatches](https://datatracker.ietf.org/doc/draft-ietf-mailmaint-imap-uidbatches/) | IMAP UID BATCH Extension |
| `UIDONLY` | ``Capability/uidOnly`` | [RFC 9586](https://www.iana.org/go/rfc9586) | IMAP4 UIDONLY Extension |
| `UIDPLUS` | ``Capability/uidPlus`` | [RFC 4315](https://www.iana.org/go/rfc4315) | Internet Message Access Protocol (IMAP) - UIDPLUS Extension |
| `UNSELECT` | ``Capability/unselect`` | [RFC 3691](https://www.iana.org/go/rfc3691) | Internet Message Access Protocol (IMAP) UNSELECT Command |
| `URLAUTH` | ``Capability/authenticatedURL`` | [RFC 4467](https://www.iana.org/go/rfc4467) | Internet Message Access Protocol (IMAP) - URLAUTH Extension |
| `WITHIN` | ``Capability/within`` | [RFC 5032](https://www.iana.org/go/rfc5032) | WITHIN Search Extension to the IMAP Protocol |

## Additional Specifications

In addition to the extension capabilities listed above, NIOIMAP also implements:

- **RFC 4466**: [Collected Extensions to IMAP4 ABNF Syntax](https://www.iana.org/go/rfc4466)
- **Gmail IMAP Extensions**: [Google Gmail IMAP Extension Documentation](https://developers.google.com/gmail/imap/imap-extensions)
