# Benchmarks

Micro-benchmarks for the IMAP parser and encoder, built on
[ordo-one/benchmark](https://github.com/ordo-one/benchmark).

This is a standalone package so that the benchmark dependencies never enter the library's own
dependency graph — building or testing `swift-nio-imap` at the repository root resolves none of them.
It requires **Swift 6.3 or later**; see [Toolchain](#toolchain) for why.

It replaces the hand-rolled harness that used to live here (`NIOIMAPPerformanceTester`), which timed
things with `Date()` and printed raw seconds. What is new is that allocation and ARC counters are
measured and gated, that server responses are covered at all, and that the command corpus is chosen
from what clients actually send.

## Running

```sh
# From this directory. `--disable-sandbox` is required: the plugin writes results to disk.
swift package --disable-sandbox benchmark

# One case, or a regex over case names.
swift package --disable-sandbox benchmark --filter "parse.responses.*"

# Two of the six gated metrics (see below).
swift package --disable-sandbox benchmark --metric mallocCountTotal --metric retainCount
```

Benchmarks always build in release mode, regardless of how you invoke them.

## Layout

| Path | What it is |
| --- | --- |
| `Sources/IMAPCorpus` | The corpora, as wire bytes and wire text. Names nothing the buffer migration changed, so it compiles against either library version — which is what lets the before/after comparison feed both configurations byte-identical input. |
| `Sources/IMAPBenchmarkSupport` | Drivers, and the model-value helpers that name post-migration types. No dependency on `Benchmark`, so it can also be driven from a plain executable or a test. |
| `Benchmarks/IMAPParsing` | Parser benchmarks — commands (what a server parses) and responses (what a client parses). |
| `Benchmarks/IMAPEncoding` | Encoder benchmarks, same two directions. |
| `Benchmarks/IMAPDispatchClient` | A client whose transport is `DispatchData` in both directions — `DispatchIO` or Network.framework — parsing responses and encoding commands and responses. |
| `Thresholds/` | Committed p90 ceilings for the deterministic metrics. See below. |

## Toolchain

The package declares `swift-tools-version:6.3`, which is newer than the library needs.

From Swift 6.3 `ordo-one/benchmark` counts allocations with
[`ordo-one/malloc-interposer`](https://github.com/ordo-one/malloc-interposer). Earlier toolchains use
jemalloc, which has to be installed as a system library and — more importantly — **counts
differently**: the two backends split small-versus-large allocations at different sizes, and the
interposer counts a `realloc`-grow as a paired free plus malloc while jemalloc does not. Thresholds
recorded against one backend are meaningless against the other. Requiring 6.3 keeps a single backend
and no system dependency, which is why CI builds this package in its own job rather than alongside the
other examples.

## What is gated, and what is only recorded

Every benchmark records wall clock, throughput, resident-memory delta, malloc counts, malloc bytes
and the four ARC counters. They are not equally trustworthy:

- **Gated: `mallocCountTotal`, `mallocBytesCount`, `objectAllocCount`, `retainCount`,
  `releaseCount`, `retainReleaseDelta`.** These are deterministic — across 10,000 samples every
  percentile from p0 to p100 reports the same value. They measure the goals ("zero bytes copied",
  "no retain/release attributable to the cursor"), and they do not depend on how busy the machine
  is.
- **Recorded but not gated: wall clock, throughput, resident memory.** Sampled, machine-dependent
  and noisy at the tail. Useful for a before/after on one machine, useless as a committed ceiling.
- **One exception, on the `encode.dispatch.*` cases: no ARC metric is measured at all.** A donated region
  carries a custom deallocator block, and libdispatch runs a custom destructor on the default global queue
  when the queue is `nil` rather than inline, so this is the only path in the suite that does reference
  counting on a thread the benchmark does not own. Two consequences, and the registrations carry the full
  reasoning: the ARC counters there are *not* deterministic (successive runs of the same binary reported
  retain/release deltas of 61, 128 and 212 on `encode.dispatch.regions.64` while every allocation counter
  was identical to the byte), and *requesting* an ARC metric makes the harness install a `swift_retain`
  hook whose teardown races any off-thread retain — which segfaulted roughly one run in three. The
  allocation counters remain exact there, and they are the ones the zero-copy claims are written in terms
  of, because an asynchronous `free` cannot change how many times something was allocated.

`mallocBytesCount` is the stand-in for "bytes copied": there is no bytes-copied metric, but a
copying implementation's allocated bytes scale with payload size and a zero-copy one's do not. That
is what the paired `1MB` / `4MB` cases are for — when the two report the same number, the payload is
no longer being copied.

Wall clock drifts ~7% run to run on the development machine (measured by re-running identical code), so a
single-digit percentage there is not a result. Trust the allocation counters.

Which pair to read matters. `encode.append.1MB` / `.4MB` still scale with the payload, because their
driver coalesces every chunk into one contiguous `ByteBuffer` — that is a copy the *driver* asks for, not
one the encoder makes. The cases that answer the question are the ones whose driver models a transport:
`encode.handler.append.*` (both report ~1.9 KB) and `encode.dispatch.append.*.array-payload` (both report
~2.4 KB).

### Checking against the committed thresholds

```sh
# Fails if a gated metric regressed past its committed p90, and also if one improved past it (then
# update the thresholds).
swift package --disable-sandbox benchmark thresholds check \
  --metric mallocCountTotal --metric mallocBytesCount --metric objectAllocCount \
  --metric retainCount --metric releaseCount --metric retainReleaseDelta

# Accept the current numbers as the new ceiling (i.e. after a deliberate change).
swift package --disable-sandbox benchmark thresholds update \
  --metric mallocCountTotal --metric mallocBytesCount --metric objectAllocCount \
  --metric retainCount --metric releaseCount --metric retainReleaseDelta
```

Not wired into CI: the committed thresholds were measured on macOS/arm64 with one toolchain, and
allocation counts differ across platforms and across stdlib versions even though they are stable on
any single one. A CI gate would need per-platform, per-version threshold directories — the shape
`swift-nio` itself uses (`Thresholds/${SWIFT_VERSION}/`).

### Baselines

```sh
swift package --disable-sandbox benchmark baseline update main   # record
swift package --disable-sandbox benchmark baseline compare main  # compare a later run against it
```

Baselines land in `.benchmarkBaselines/` and are git-ignored — they embed the host they were
measured on, so they are only meaningful locally.

Hold the filter set and the `--metric` selection fixed between `update` and `compare`. Counters are only
comparable between runs that agree on both: the same binary and case reported 5 retains under the full
metric set and 3 under `--metric mallocCountTotal --metric retainCount`. Two ad-hoc runs with different
flags are not a before and after. Counts are per benchmark, not per symbol; to find *where*, see
[Profiling](#profiling).

`baseline compare` prints a percentile table per metric per case (~16,000 lines for the full suite).
Summarise it with `dev/summarize-comparison.py`, see [Summarizing a comparison](#summarizing-a-comparison).

#### Getting an exact absolute number

`Thresholds/*.json` is the harness's own exact p90 export for the gated counters, so a before/after in
whole allocations and whole bytes is `git show HEAD:<path>` against the working copy. For wall clock,
derive it from `Throughput (# / s)` (`1 / throughput`), whose suffix is a plain multiplier, or run the
single case standalone:

```sh
.build/release/IMAPParsing --filter 'parse\.responses\.bodystructure\.200$'
```

## Profiling

The suite says *what* costs, not *where*. Attributing by ablation (remove a thing, re-measure) only finds
what you thought to remove.

### Attributing allocations

`IMAPProfile` is a plain executable that runs one corpus a chosen number of times. The benchmark runners
are the wrong thing to trace: they choose their iteration count from a time budget, and they run inside
the malloc interposer, which attributes every allocation to itself. Under `Allocations` the budget is
badly wrong too: the body-structure case allocates ~110,000 times per iteration, so the runner would
record millions of events.

```sh
swift build -c release --disable-sandbox --product IMAPProfile
.build/release/IMAPProfile                     # lists the scenarios
xcrun xctrace record --template Allocations --output /tmp/a.trace \
  --launch -- .build/release/IMAPProfile bodystructure 3
open /tmp/a.trace
```

In Instruments, select the Allocations track, set the allocation lifespan to *All Allocations*, switch
the detail view from *Statistics* to *Call Trees*, and turn on *Invert Call Tree* and *Hide System
Libraries*: each root of the call tree is then the library frame that asked for the memory, with its
allocation count. Divide by the messages parsed (here 200 x 3) for a
per-message rate. Use one scenario per trace. `Allocations` is more useful than `Time Profiler` here
because the parser is allocation-bound. `IMAPProfile` runs faster than the same work under the
interposer, so its wall clock is not comparable with the suite's.

### Summarizing a comparison

```sh
swift package --disable-sandbox benchmark baseline compare before 2>&1 | tr '\r' '\n' > /tmp/cmp.txt
./dev/summarize-comparison.py /tmp/cmp.txt --filter 'parse.'
```

Prints one row per case: p90 of each gated counter on both sides and the percentage change. It
deliberately neither rescales nor sums anything, because the header suffixes are unreliable (see
[Known hazards](#known-hazards)); a per-case ratio is exact. `--filter` is a substring match;
`--min-delta` hides changes below a threshold (default 0.5). Comparing two *stored* baselines labels
the rows after them, so pass the labels:

```sh
./dev/summarize-comparison.py /tmp/cmp.txt --before main --after branch
```

## How the corpora were chosen

### Commands

The starting point was the list from the old harness, which had been assembled for breadth. Audited
against what a mail client actually sends, it had three problems:

- **No UID commands at all** — `uidFetch`, `uidStore`, `uidCopy`, `uidMove`, `uidSearch` and
  `uidExpunge` were all absent. A real client sends almost nothing else once a mailbox is selected,
  because sequence numbers shift under it and UIDs do not.
- **`LIST`, `STATUS`, `SEARCH` and every `BODY[…]` fetch were missing**, while `QUOTA` had four
  entries and `GENURLAUTH` two. The corpus was weighted towards commands a client sends once per
  session or never, and away from the handful it sends thousands of times.
- **One entry was a duplicate**: `move_last command` and `move_all` were both
  `.move(.lastCommand, .inbox)`.

So the corpus is now split. `CommandCorpus.hot` is what a client sends in volume and gets a benchmark
per case — seven of its entries are `UID FETCH` variants, because that is where a client spends its
protocol budget. `CommandCorpus.coverage` is breadth over the rest of the grammar (extensions,
administrative commands, the sequence-number twins) and is measured only in aggregate.

### Responses

The old corpus had none at all — it measured only client-to-server traffic. There are now three
response corpora, because server traffic is not one thing, and all three are defined **as wire
bytes**. The model values the encode benchmarks need are obtained by parsing those bytes once at
registration time, so the two directions cannot drift apart and there is no hand-written
`BodyStructure` literal to keep in sync with the text it is supposed to represent.

- **`sessionBytes()`** — everything a client sees that is not a message: capabilities, `ID`,
  `NAMESPACE`, the mailbox tree, `LSUB`, `STATUS`, the full `SELECT` preamble with its response codes,
  `SEARCH` and `ESEARCH` results, an unsolicited flag update, an `EXPUNGE`, a continuation request,
  `BYE`. Two kilobytes, and most of the distinct response grammar a client handles.
- **`bodyStructureBytes(messageCount:)`** — the heavy FETCH: UID, flags, internal date, size, a full
  `ENVELOPE`, and a nested `BODYSTRUCTURE` for a reply that carries an attachment and a forwarded
  message:

  ```
  multipart/mixed
    multipart/alternative
      text/plain
      text/html
    application/pdf          (with a Content-Disposition and an MD5)
    message/rfc822           (nesting a second envelope and a second body)
  ```

  That is what a client receives for a reply-with-attachment, and it covers all three structurally
  different single-part forms the grammar has — `body-type-text` (which carries a line count),
  `body-type-basic` (which does not) and `body-type-msg` (which nests an envelope *and* a body *and* a
  line count) — plus two levels of multipart nesting and the extension fields on both.
- **`sweepBytes(messageCount:)`** — the light FETCH: UID, size, flags, and an envelope every eighth
  message. What a flag sync over an already-known mailbox looks like.

## The cases

### Parsing

| Case | What it is for |
| --- | --- |
| `parse.commands.all` | The whole command corpus, hot and coverage. |
| `parse.command.<name>` | One per hot command. A regression in `UID FETCH` matters in a way that one in `SETQUOTA` does not. |
| `roundtrip.commands.all` | Encode plus parse, which makes the split between the two attributable. |
| `parse.responses.session` | The session preamble. Wide rather than deep. |
| `parse.responses.bodystructure.200` | `ENVELOPE` plus nested `BODYSTRUCTURE` per message: the most expensive thing a client parses per message, and the deepest recursion in the grammar. |
| `parse.responses.bodystructure.200.read-<n>` | The same at MTU and 64 K reads. Responses here are ~1.4 KB, so at 1448-byte reads nearly every one straddles a read boundary — see the findings below. |
| `parse.responses.1000.contiguous` | A thousand-message light sweep in one buffer. |
| `parse.responses.1000.read-<n>` | The same sweep fed at 1448 (an Ethernet MTU minus headers, i.e. what a socket read actually delivers), 4 K, 16 K, 64 K. `copyThreshold` sits below 1448 on purpose. |
| `parse.responses.100.read-1` | One byte at a time: the per-read overhead in isolation, an append plus a parse attempt per byte. `IMAPInputBuffer` copies reads under `copyThreshold` into a shared 1 KiB tail rather than keeping one region per read; see the findings below. |
| `parse.literal-1MB.read-<n>` | A 1 MB `BODY[TEXT]` literal streamed through `FetchResponse.streamingBytes`, delivered by reference as an `IMAPBuffer` that borrows the received bytes. Zero-copy end to end, asserted separately by address in `ZeroCopyReadTests`; these numbers are the baseline that has to hold. |
| `parse.dispatch.*` | The same corpora fed as `DispatchData` instead of an `IMAPInputBuffer` of received `ByteBuffer`s. `DispatchData` is the genuinely multi-region input — appending copies nothing — and it is what the one-pass `enumerateBytes` gather exists for, so without these the gather was only measured on types that take a different path. Read each against the case of the same name: three costs live only here, and all are per parse call rather than per read. See the findings below. |

### Encoding

| Case | What it is for |
| --- | --- |
| `encode.commands.all`, `encode.command.<name>` | The same command corpus, encode side. |
| `encode.login.sync-literal` / `.literal-plus` | The chunking path. With quoted strings off, every string becomes a synchronizing literal and `nextChunk()` hands out several chunks whose `nextStep` is `.awaitContinuationRequest`; the LITERAL+ variant needs no continuation at all. This is the path where an off-by-one deadlocks the protocol rather than producing wrong bytes. |
| `encode.create.quoted-string` / `.literal` | The same 60-byte mailbox name written as a quoted string and as a literal. `writeQuotedIMAPString` used to issue one primitive write per byte, so the pair measured what rewriting that loop was worth; it now stages into a temporary buffer and emits one write, and the pair stays as the regression net for it. |
| `encode.append.128B` / `.1MB` / `.4MB` | `AppendCommand.messageBytes`, appended to the sink **by reference** rather than copied. These three coalesce every chunk into one contiguous buffer, so their allocated bytes still scale with the payload — deliberately, because a caller whose transport needs contiguous bytes pays exactly that. For the zero-copy question read `encode.handler.append.*` instead. |
| `encode.responses.session` | The session preamble, encode side. |
| `encode.responses.bodystructure.200` | The heavy FETCH, encode side. |
| `encode.responses.1000.reused-buffer` / `.fresh-buffer` | One long-lived `ResponseEncodeBuffer` — what `IMAPServerHandler` keeps for a connection's lifetime — against a fresh one per response. `readBytes()` hands the bytes out and then clears, and what clearing costs is the whole difference: the sink keeps the segment it is writing into and its learned segment size, and drops the rest. |
| `encode.literal-1MB.streamed` | The server side of the streaming path: a 1 MB body written as MTU-sized `streamingBytes` events. |
| `encode.handler.*.<sink>` | What a NIO handler does rather than what a contiguous-bytes caller does: no coalescing, one `ByteBuffer` per payload and one for the small regions around it. Registered as a pair over the two shipped sinks, because the hand-out is where they differ — `IMAPOutputBuffer` copies each region into a fresh `ByteBuffer`, `ByteBufferOutput` hands out slices of the buffer it encoded into and pays by starting a fresh one once bytes have gone out. |
| `encode.dispatch.*.<sink>` | The same, for a transport that takes `DispatchData`. This is the path `IMAPOutputBuffer` exists for: a `ByteBuffer` can only be filled in place, so this sink fills memory it allocated itself and then donates it. `ByteBufferOutput` is zero-copy here too: `ByteBuffer` is a `StableAddressByteRegion`, so its regions are donated as well. Either sink copies regions shorter than `IMAPBuffer.dispatchDonationThreshold`, one allocation per run. |
| `encode.dispatch.append.<n>MB.array-payload` | The same payload array-backed rather than `ByteBuffer`-backed. Both promise a fixed address, so both are donated; a backing that does not, such as `Data`, would be copied. |
| `encode.dispatch.regions.<n>` | The conversion with no encoder in front of it, swept over region count up to the per-chunk cap of 64. The slope is the per-region cost and the intercept the flat one, and three design decisions rest on those two numbers — the 64 KB segment cap, the refusal to split eagerly, and the region cap itself. They were originally measured in a scratch directory that no longer exists. |

### The before/after comparison

| Case | What it is for |
| --- | --- |
| `dispatch-client.parse.*` | One client's read path — a transport handing over `DispatchData` — run against both library versions. Corpora and read sizes mirror `parse.responses.*` so the two suites cross-check each other: this target's `parse.sweep.1000.read-1448` reports the same counters as `parse.responses.1000.read-1448` does, because it is the same work. |
| `dispatch-client.encode.*` | The same client's write path, plus the response-encoding shape a Dispatch-based *server* has, which is where encoding is expensive enough to be worth measuring. |

Both halves of the driver are in `Benchmarks/IMAPDispatchClient`, selected by `IMAP_LEGACY_BUFFERS`.
The committed thresholds are the current implementation's only: the `main` side needs a worktree that
is not part of the repository, so it cannot gate anything.

## Corpus self-checks

Both targets validate their corpora once at registration time, outside any measured region:

- the light sweep yields exactly the expected number of parse events;
- the body-structure corpus yields exactly eight events per message and at least one *multipart*
  `BODYSTRUCTURE` — so if it ever stops parsing as one nested attribute, it trips;
- the session corpus contains all twelve response kinds it claims to cover, checked by kind rather
  than by count, because breadth is its whole point;
- every encoded command parses back into at least one part;
- the 1 MB literal arrives as `streamingBytes` totalling exactly 1 MB;
- the synchronizing-literal options really do produce more than one chunk;
- the `DispatchData` drivers parse the session corpus into the same number of events as the
  `IMAPInputBuffer` drivers, because they reach the parser through a different conformance and a
  different gather, so "it parses at all" is not implied by the cases above;
- `DispatchConversion.makeRegionList` returns exactly the region count it was asked for — a region below
  `copyThreshold` would be copied into a segment and coalesced, silently turning a 64-region sweep into a
  1-region one.

A corpus that silently stops exercising the path it is named after would make every number here
meaningless.

## Baseline

Measured on an arm64 Mac (Apple Swift 6.4, malloc-interposer backend), p50, with the full default metric
set. Wall clock is machine-specific and drifts ~7% run to run here; the counts are deterministic
everywhere except the `encode.dispatch.*` cases (see below).

| Case | wall p50 | mallocs | malloc bytes | retains |
| --- | --- | --- | --- | --- |
| `parse.command.noop` | 791 ns | 4 | 142 | 5 |
| `parse.command.uid_fetch_headers` | 6 µs | 62 | 4 K | 37 |
| `parse.command.uid_search_compound` | 56 µs | 1 K | 64 K | 465 |
| `parse.commands.all` | 299 µs | 4 K | 216 K | 2 K |
| `roundtrip.commands.all` | 372 µs | 4 K | 256 K | 3 K |
| `parse.responses.session` | 171 µs | 2 K | 139 K | 1 K |
| `parse.responses.bodystructure.200` | 10 ms | 111 K | 8.2 M | 91 K |
| `parse.responses.bodystructure.200.read-1448` | 13 ms | 145 K | 10.6 M | 112 K |
| `parse.responses.1000.contiguous` | 8 ms | 99 K | 5.7 M | 66 K |
| `parse.responses.1000.read-1448` | 8 ms | 101 K | 5.9 M | 68 K |
| `parse.responses.1000.read-65536` | 8 ms | 99 K | 5.7 M | 66 K |
| `parse.responses.100.read-1` | 35 ms | 331 K | 26.0 M | 184 K |
| `parse.literal-1MB.read-1448` | 245 µs | 2 K | 110 K | 4 K |
| `parse.literal-1MB.read-65536` | 14 µs | 108 | 7 K | 148 |
| `parse.dispatch.responses.session` | 197 µs | 3 K | 154 K | 2 K |
| `parse.dispatch.responses.1000.contiguous` | 11 ms | 134 K | 7.3 M | 81 K |
| `parse.dispatch.responses.1000.read-1448` | 11 ms | 138 K | 7.6 M | 83 K |
| `parse.dispatch.responses.1000.read-65536` | 11 ms | 134 K | 7.4 M | 81 K |
| `parse.dispatch.responses.bodystructure.200.read-1448` | 14 ms | 157 K | 11.2 M | 117 K |
| `parse.dispatch.literal-1MB.read-1448` | 813 µs | 10 K | 1.5 M | 6 K |
| `parse.dispatch.literal-1MB.read-65536` | 45 µs | 344 | 1.1 M | 197 |
| `encode.command.noop` | 666 ns | 6 | 536 | 11 |
| `encode.commands.all` | 48 µs | 284 | 39 K | 854 |
| `encode.create.quoted-string` | 791 ns | 6 | 648 | 13 |
| `encode.create.literal` | 750 ns | 6 | 648 | 13 |
| `encode.login.sync-literal` | 1,208 ns | 9 | 704 | 24 |
| `encode.append.128B` | 2,375 ns | 22 | 2,376 | 38 |
| `encode.append.1MB` | 16 µs | 20 | 2,099 K | 37 |
| `encode.append.4MB` | 57 µs | 20 | 8,390 K | 37 |
| `encode.responses.session` | 14 µs | 27 | 5,928 | 256 |
| `encode.responses.bodystructure.200` | 1,361 µs | 471 | 358 K | 33 K |
| `encode.responses.1000.reused-buffer` | 798 µs | 41 | 133 K | 24 K |
| `encode.responses.1000.fresh-buffer` | 1,995 µs | 21 K | 2,463 K | 41 K |
| `encode.literal-1MB.streamed` | 60 µs | 11 | 1,464 | 2,204 |
| `encode.handler.command.noop.imap-sink` | 625 ns | 6 | 536 | 10 |
| `encode.handler.command.noop.bytebuffer-sink` | 666 ns | 4 | 497 | 13 |
| `encode.handler.commands.all.imap-sink` | 54 µs | 413 | 40 K | 853 |
| `encode.handler.commands.all.bytebuffer-sink` | 61 µs | 276 | 34 K | 1,058 |
| `encode.handler.append.1MB.imap-sink` | 2,459 ns | 22 | 1,922 | 40 |
| `encode.handler.append.4MB.imap-sink` | 2,417 ns | 22 | 1,922 | 40 |
| `encode.handler.append.1MB.bytebuffer-sink` | 2,501 ns | 16 | 1,827 | 51 |
| `encode.handler.append.4MB.bytebuffer-sink` | 2,501 ns | 16 | 1,827 | 51 |
| `encode.handler.responses.1000.imap-sink` | 1,382 µs | 10 K | 619 K | 29 K |
| `encode.handler.responses.1000.bytebuffer-sink` | 1,768 µs | 5,130 | 334 K | 40 K |
| `encode.handler.responses.1000.in-flight.imap-sink` | 1,403 µs | 10 K | 946 K | 35 K |
| `encode.handler.responses.1000.in-flight.bytebuffer-sink` | 2,204 µs | 16 K | 2,397 K | 45 K |
| `encode.handler.responses.bodystructure.200.imap-sink` | 1,552 µs | 3,706 | 800 K | 35 K |
| `encode.handler.responses.bodystructure.200.bytebuffer-sink` | 2,202 µs | 2,006 | 132 K | 38 K |
| `encode.dispatch.commands.all.imap-sink` | 70 µs | 482 | 43 K | not measured |
| `encode.dispatch.commands.all.bytebuffer-sink` | 62 µs | 414 | 41 K | not measured |
| `encode.dispatch.append.1MB.imap-sink` | 22 µs | 27 | 1,051 K | not measured |
| `encode.dispatch.append.4MB.imap-sink` | 61 µs | 27 | 4,197 K | not measured |
| `encode.dispatch.append.1MB.array-payload` | 3,959 ns | 29 | 2,393 | not measured |
| `encode.dispatch.append.4MB.array-payload` | 3,917 ns | 29 | 2,393 | not measured |
| `encode.dispatch.responses.1000.imap-sink` | 2,484 µs | 15 K | 1,037 K | not measured |
| `encode.dispatch.responses.1000.bytebuffer-sink` | 2,078 µs | 15 K | 784 K | not measured |
| `encode.dispatch.literal-1MB.streamed.imap-sink` | 178 µs | 1,475 | 1,097 K | not measured |
| `encode.dispatch.literal-1MB.streamed.bytebuffer-sink` | 151 µs | 1,464 | 1,096 K | not measured |
| `encode.dispatch.regions.1` | 1,416 ns | 4 | 200 | not measured |
| `encode.dispatch.regions.4` | 2,083 ns | 19 | 1,216 | not measured |
| `encode.dispatch.regions.16` | 6,919 ns | 79 | 7,459 | not measured |
| `encode.dispatch.regions.64` | 42 µs | 319 | 67 K | not measured |

The `encode.dispatch.*` cases measure no ARC metric, deliberately and for two reasons — the counters are
not deterministic there, and asking for them crashes the harness. Both come from the same cause and both
are explained in a comment above those registrations. Their wall clock is also the least trustworthy in
the suite for the same reason: a donated region's deallocator runs on a background queue, so a case's
measured time depends on how much destruction work the queue is still retiring from the case before it.
`encode.dispatch.regions.1` measures 417 ns run in isolation and 1,416 ns run after the 64-region case.
**Read the allocation counters on that sweep, not the times.**

Nine things this baseline says that are worth knowing before optimising anything:

1. **Parsing is allocation-bound.** ~99 allocations per light-FETCH message and ~554 per body-structure
   message. Whatever else is true, that is still the number to attack — but it is **not** the *output
   model*, which is what this list previously asserted. Profiled under `Allocations`, three mechanisms
   unrelated to the model were 74% of the allocations the parser made: a hand-rolled UTF-8 decode that
   regrew a `String` once per scalar, `[String: SubParser]` lookup tables rebuilt on every call, and heap
   closure contexts from passing `GrammarParser` methods as function values. All three are fixed; find the next ones with
   [Profiling](#profiling). The model's per-field `[UInt8]` is real —
   `extractBytes` is 106 allocations per body-structure message — but it is a minority of the remainder.
2. **Encoding is ~8× cheaper than parsing** on the same traffic: 48 µs against 299 µs for the command
   corpus, 1.3 ms against 10 ms for the body structures. The parser is still where the work is. The gap
   used to be 20–30×; it closed because the parser got faster, not because the encoder got slower.
3. **Read size matters, but only once responses are big enough to straddle one.** The light sweep, whose
   responses are ~70 bytes, costs 99 K mallocs contiguous and 101 K at MTU-sized reads — 2% apart. The
   body-structure sweep, whose responses are ~1.4 KB and therefore straddle nearly every 1448-byte read,
   goes from 111 K to 145 K — **31% apart**. Anything measuring only short responses will conclude,
   wrongly, that read size is irrelevant.
4. **Byte-at-a-time input costs a parse attempt per byte, not a region per byte.** Per-call parse work
   is O(live regions), so one region per read made parsing one line quadratic in its length:
   `parse.responses.100.read-1` cost 71 ms, 418 K mallocs, 70.3 M bytes and 1.5 M retains before small
   reads were coalesced. `IMAPInputBuffer.append` now copies a read under `copyThreshold` into a shared
   1 KiB tail, so live regions number about one per KiB. Each read still starts a parse attempt over the
   partial response.
5. **`DispatchData` input costs ~10% on line-oriented traffic and 3× on literals.** (Figures in this
   item and the three below it were measured before the 2026-08-14 allocation work; both sides of each
   comparison improved together, so the ratios hold but the absolutes are lower now.) 33 ms against 30 ms
   for the light sweep, but **773 µs against 257 µs** with **12× the allocated bytes** for a 1 MB literal
   at MTU reads, and 67× the bytes at 64 K reads. That is the "extraction always copies" property: the
   `DispatchData` gather passes no owner, so a literal is copied out region by region, where an
   `IMAPInputBuffer` hands it over by reference. Zero copy on the read side is a property of
   `IMAPInputBuffer` alone.
6. **A payload reaches either transport uncopied.** `encode.handler.append.*` reports 1,922 B for both
   1 MB and 4 MB payloads, and `encode.dispatch.append.*.array-payload` reports 2,393 B for both — flat
   lines, i.e. nothing copying the payload. `encode.dispatch.append.1MB/4MB` hand in a
   `ByteBuffer`-backed payload, which is a `StableAddressByteRegion` and so is donated too, on either
   sink. Only `IMAPOutputBuffer`'s own regions are copied, and only on their way into a `ByteBuffer`.
7. **A `DispatchData` output region costs ~5 allocations and ~1 KB, not the ~150 ns + ~40 ns the encoder
   design assumed.** Across the region sweep the malloc count goes 4 → 19 → 79 → 319 for 1 → 4 → 16 → 64
   regions, i.e. 5.0 per region, and the bytes go 200 → 67,007, i.e. ~1,060 per region. The design's
   "minimise regions per chunk" rule is right and considerably more important than the number behind it
   suggested; a 64-region chunk is not cheap insurance.
8. **Converting to `DispatchData` roughly doubles the cost of many small messages.**
   `encode.dispatch.responses.1000.imap-sink` is 2,484 µs against 1,382 µs for the same sweep handed out
   as `ByteBuffer`s — about 1.1 µs per response of pure conversion, which is a per-message tax a
   `ByteBuffer` transport does not pay.
9. **A reused `ResponseEncodeBuffer` is now better on both counts** — 798 µs / 41 mallocs / 133 KB against
   1,995 µs / 21 K / 2,463 KB for a fresh one per response. It used to allocate *fewer times but more
   bytes*, because clearing a `ByteBuffer` whose storage was no longer uniquely referenced reallocated it
   once per response. The sink keeps the segment it is writing into instead.

## Adding a case

Benchmark names must not contain spaces or slashes. `thresholds update` replaces both with `_` when
it writes `Thresholds/<target>.<name>.p90.json`, but `thresholds check` looks the file up under the
unmangled name — so a name with a space writes a threshold file that is then never read, and the
check fails with "Could not find any matching absolute thresholds" instead of gating anything. Hence
the dotted, hyphenated identifiers used throughout. (Upstream bug, `ordo-one/benchmark` 1.36.2.)

Build the corpus in a local `let` inside the `benchmarks` closure rather than as a lazy global:
globals are initialised on first touch, which would otherwise happen inside the first measured
iteration.

Prefer defining a response corpus as wire bytes and deriving the model values with
`ResponseCorpus.responses(parsing:)` over hand-writing model literals. The parse happens at
registration time, and it means the encode and parse sides describe the same traffic by construction.

If the case is one you will want to profile, add a matching entry to the `scenarios` dictionary in
`Sources/IMAPProfile/main.swift` too; see [Profiling](#profiling).

### Known hazards

- **The magnitude suffixes in `baseline compare` headers are not scale factors, and differ between
  metrics within one case.** On `parse.responses.bodystructure.200`, `Retains (K)` prints `207` for a
  true 207,000, while `Malloc (bytes total) (K)` prints `20` for a true 20 MB. `Time (wall clock) (ns)`
  on `parse.command.uid_fetch_headers` prints `24` for a true ~22 µs. Never compare or sum printed values
  across cases. Ratios within a case are exact; for absolutes use the threshold JSONs or a standalone
  run (see [Baselines](#baselines)).
- **`thresholds update` writes every `--metric` you pass to every case, including ones that opted out.**
  The six-metric set above adds ARC counters to the `encode.dispatch.*` and
  `dispatch-client.encode.*` threshold files, which must not be gated (see
  [What is gated](#what-is-gated-and-what-is-only-recorded)). After any update, revert them;
  the grep must print nothing:

  ```sh
  git checkout -- Thresholds/IMAPEncoding.encode.dispatch.*.json \
    Thresholds/IMAPDispatchClient.dispatch-client.encode.*.json
  grep -l retainCount Thresholds/IMAPEncoding.encode.dispatch.*.json \
    Thresholds/IMAPDispatchClient.dispatch-client.encode.*.json
  ```

  The same override applies to `thresholds check` and `baseline update`.
- **`EXC_BAD_ACCESS` at address 0 on `com.apple.root.default-qos`** is the upstream ARC-hook race, not a
  `DispatchData` use-after-free. Details in
  [What is gated](#what-is-gated-and-what-is-only-recorded). The stack is not always
  symbolicated; the only sign may be `frame #0: 0x0000000000000000` on that queue.
- **Occasional "1 benchmark job(s) failed during runtime" on full-suite runs.** Re-running the case alone
  has always succeeded. Afterwards, check every registered case got a threshold file: compare
  `swift package --disable-sandbox benchmark list` against `ls Thresholds`.
