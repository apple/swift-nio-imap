### IMAP Extensions

NIOIMAP supports a variety of known IMAP [extensions](https://www.iana.org/assignments/imap-capabilities/imap-capabilities.xhtml). If you'd like support for an extension not listed or ticket below, file an issue, or create a PR.

| Capability | RFC |
| --- | --- |
APPENDLIMIT|[RFC7889]((https://www.iana.org/go/rfc7889)
AUTH=|[RFC3501](https://www.iana.org/go/rfc3501)
BINARY|[RFC3516](https://www.iana.org/go/rfc3516)
CATENATE|[RFC4469](https://www.iana.org/go/rfc4469)
CHILDREN|[RFC3348](https://www.iana.org/go/rfc3348)
CONDSTORE|[RFC7162](https://www.iana.org/go/rfc7162)
CREATE-SPECIAL-USE|[RFC6154](https://www.iana.org/go/rfc6154)
ENABLE|[RFC5161](https://www.iana.org/go/rfc5161)
ESEARCH|[RFC4731](https://www.iana.org/go/rfc4731)
IDLE|[RFC2177](https://www.iana.org/go/rfc2177)
ID|[RFC2971](https://www.iana.org/go/rfc2971)
LIST-EXTENDED|[RFC5258](https://www.iana.org/go/rfc5258)
LIST-STATUS|[RFC5819](https://www.iana.org/go/rfc5819)
LITERAL+|[RFC7888](https://www.iana.org/go/rfc7888)
LITERAL-|[RFC7888](https://www.iana.org/go/rfc7888)
LOGIN-REFERRALS|[RFC2221](https://www.iana.org/go/rfc2221)
LOGINDISABLED|[RFC3501](https://www.iana.org/go/rfc3501)
MESSAGELIMIT|[RFC9738](https://www.iana.org/go/rfc9738)
METADATA-SERVER|[RFC5464](https://www.iana.org/go/rfc5464)
METADATA|[RFC5464](https://www.iana.org/go/rfc5464)
MOVE|[RFC6851](https://www.iana.org/go/rfc6851)
MULTIAPPEND|[RFC3502](https://www.iana.org/go/rfc3502)
MULTISEARCH|[RFC7377](https://www.iana.org/go/rfc7377)
NAMESPACE|[RFC2342](https://www.iana.org/go/rfc2342)
PARTIAL|[RFC9394](https://www.iana.org/go/rfc9394)
PREVIEW|[RFC8970](https://www.iana.org/go/rfc8970)
QRESYNC|[RFC7162](https://www.iana.org/go/rfc7162)
QUOTA|[RFC2087](https://www.iana.org/go/rfc2087)
SASL-IR|[RFC4959](https://www.iana.org/go/rfc4959)
SEARCHRES|[RFC5182](https://www.iana.org/go/rfc5182)
SPECIAL-USE|[RFC6154](https://www.iana.org/go/rfc6154)
STARTTLS|[RFC3501](https://www.iana.org/go/rfc3501)
STATUS=SIZE|[RFC8438](https://www.iana.org/go/rfc8438)
UIDONLY|[RFC9586](https://www.iana.org/go/rfc9586)
UIDPLUS|[RFC4315](https://www.iana.org/go/rfc4315)
UNSELECT|[RFC3691](https://www.iana.org/go/rfc3691)
URLAUTH|[RFC4467](https://www.iana.org/go/rfc4467)
WITHIN|[RFC5032](https://www.iana.org/go/rfc5032)

We have also implemented:
- "Collected Extensions to IMAP 4", [RFC4466](https://www.iana.org/go/rfc4466).
- Gmail IMAP extensions https://developers.google.com/gmail/imap/imap-extensions
