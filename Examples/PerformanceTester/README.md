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
| `Benchmarks/IMAPDispatchClient` | One client, measured against two libraries: this tree and a worktree of the pre-migration library. See [Before and after: a `DispatchData` client](#before-and-after-a-dispatchdata-client). |
| `Benchmarks/IMAPByteBufferClient` | The same comparison for a client whose transport is `ByteBuffer`. See [Before and after: a `ByteBuffer` client](#before-and-after-a-bytebuffer-client). |
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
- **One exception, on the `encode.dispatch.*` and `dispatch-client.encode.*` cases: no ARC metric is
  gated.** A donated region carries a custom deallocator block, and libdispatch runs a custom destructor on
  the default global queue when the queue is `nil` rather than inline, so this is the only path in the suite
  that does reference counting on a thread the benchmark does not own. The ARC counters there are *not*
  deterministic: successive runs of the same binary reported retain/release deltas of 61, 128 and 212 on
  `encode.dispatch.regions.64` while every allocation counter was identical to the byte. The registrations
  carry the full reasoning. The allocation counters remain exact there, and they are the ones the zero-copy
  claims are written in terms of, because an asynchronous `free` cannot change how many times something was
  allocated.

`mallocBytesCount` is the stand-in for "bytes copied": there is no bytes-copied metric, but a
copying implementation's allocated bytes scale with payload size and a zero-copy one's do not. That
is what the paired `1MB` / `4MB` cases are for — when the two report the same number, the payload is
no longer being copied.

Wall clock drifts ~7% run to run on the development machine (measured by re-running identical code), so a
single-digit percentage there is not a result. Trust the allocation counters.

Which pair to read matters. `encode.append.1MB` / `.4MB` still scale with the payload, because their
driver coalesces every chunk into one contiguous `ByteBuffer` — that is a copy the *driver* asks for, not
one the encoder makes. The cases that answer the question are the ones whose driver models a transport:
`encode.handler.append.*` (both report ~1.9 KB) and `encode.dispatch.append.*` (all report ~2.1–2.3 KB).

### Checking against the committed thresholds

```sh
six=(--metric mallocCountTotal --metric mallocBytesCount --metric objectAllocCount
     --metric retainCount --metric releaseCount --metric retainReleaseDelta)
two=(--metric mallocCountTotal --metric mallocBytesCount)
# `check` fails if a gated metric regressed past its committed p90, and also if one improved past it
# (then update the thresholds). `update` accepts the current numbers as the new ceiling (i.e. after a
# deliberate change).
op=check
swift package --disable-sandbox benchmark thresholds $op --target IMAPParsing "${six[@]}"
swift package --disable-sandbox benchmark thresholds $op --target IMAPEncoding \
  --skip 'encode\.dispatch\..*' "${six[@]}"
swift package --disable-sandbox benchmark thresholds $op --target IMAPEncoding \
  --filter 'encode\.dispatch\..*' "${two[@]}"
swift package --disable-sandbox benchmark thresholds $op --target IMAPDispatchClient \
  --filter 'dispatch-client\.parse\..*' "${six[@]}"
swift package --disable-sandbox benchmark thresholds $op --target IMAPDispatchClient \
  --filter 'dispatch-client\.encode\..*' "${two[@]}"
swift package --disable-sandbox benchmark thresholds $op --target IMAPByteBufferClient "${six[@]}"
```

Six invocations, because a `--metric` on the command line overrides each case's own metric list, and
`thresholds update` writes every metric passed to every case it runs. The `encode.dispatch.*` and
`dispatch-client.encode.*` cases donate regions of at least the dispatch donation threshold (512 B)
to `DispatchData`, which frees them on a background queue: their ARC counters are not deterministic (see
[the ARC counters](#the-arc-counters)). So they gate `mallocCountTotal` and `mallocBytesCount` only, and
every other case gates all six, including `bytebuffer-client.encode.*`, whose writes free
synchronously. The flags also keep `update` from writing the sampled metrics into the threshold files.

Not wired into CI: the committed thresholds were measured on macOS/arm64 with Swift 6.4 and
`ordo-one/benchmark` 1.38.1, and allocation counts differ across platforms and across stdlib versions
even though they are stable on any single one. A CI gate would need per-platform, per-version threshold directories — the shape
`swift-nio` itself uses (`Thresholds/${SWIFT_VERSION}/`).

### Baselines

```sh
swift package --disable-sandbox benchmark baseline update main   # record
swift package --disable-sandbox benchmark baseline compare main  # compare a later run against it
```

Baselines land in `.benchmarkBaselines/` and are git-ignored — they embed the host they were
measured on, so they are only meaningful locally.

Hold the filter set and the `--metric` selection fixed between `update` and `compare`. Counters are only
comparable between runs that agree on both: `parse.command.noop` reports 8 retains under the default
metric set and 6 under `--metric mallocCountTotal --metric retainCount`. Two ad-hoc runs with different
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
badly wrong too: the body-structure case allocates ~42,000 times per iteration, so the runner would
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
./dev/summarize-comparison.py /tmp/cmp.txt --before main-parse --after branch-parse
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
| `parse.dispatch.*` | The same corpora read as `DispatchData` and appended to the `IMAPInputBuffer` with `append(contentsOf:)`, instead of as `ByteBuffer`s. Read each against the case of the same name: what differs is the append, and the owner a kept literal pins — the whole `DispatchData` read. |

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
| `encode.handler.*.<sink>` | What a NIO handler does rather than what a contiguous-bytes caller does: no coalescing, one `ByteBuffer` per payload and one for the small regions around it. Registered as a pair over `IMAPOutputBuffer` and `ByteBufferOutput` — a benchmark-local sink in `IMAPBenchmarkSupport`, not shipped — because the hand-out is where they differ — `IMAPOutputBuffer` copies each region into a fresh `ByteBuffer`, `ByteBufferOutput` hands out slices of the buffer it encoded into and pays by starting a fresh one once bytes have gone out. |
| `encode.dispatch.*.<sink>` | The same, for a transport that takes `DispatchData`. This is the path `IMAPOutputBuffer` exists for: a `ByteBuffer` can only be filled in place, so this sink fills memory it allocated itself and then donates it. `ByteBufferOutput` is zero-copy here too: `ByteBuffer` is a `StableAddressByteRegion`, so its regions are donated as well. Either sink copies regions shorter than the dispatch donation threshold (512 B), one allocation per run. |
| `encode.dispatch.append.<n>MB.array-payload` | The same payload array-backed rather than `ByteBuffer`-backed. Both promise a fixed address, so both are donated; a backing that does not, such as `Data`, would be copied. |
| `encode.dispatch.regions.<n>` | The conversion with no encoder in front of it, swept over region count up to the per-chunk cap of 64. The slope is the per-region cost and the intercept the flat one, and three design decisions rest on those two numbers — the 64 KB segment cap, the refusal to split eagerly, and the region cap itself. They were originally measured in a scratch directory that no longer exists. |

### The before/after comparisons

| Case | What it is for |
| --- | --- |
| `dispatch-client.parse.*` | One client's read path — a transport handing over `DispatchData` — run against both library versions. Corpora and read sizes mirror `parse.responses.*` so the two suites cross-check each other: this target's `parse.sweep.1000.read-1448` reports nearly the same counters as `parse.responses.1000.read-1448` does (40,827 against 40,575 mallocs), because it is nearly the same work. |
| `dispatch-client.encode.*` | The same client's write path, plus the response-encoding shape a Dispatch-based *server* has, which is where encoding is expensive enough to be worth measuring. |
| `bytebuffer-client.parse.*` | The same cases for a client whose transport hands over `ByteBuffer`s, as a NIO `Channel` does. Same corpora, same case set. |
| `bytebuffer-client.encode.*` | The same client's write path: each chunk written as `ByteBuffer`s, the way `IMAPClientHandler` writes it. Unlike the dispatch client, these gate ARC counters too — nothing is freed on another queue. |

Both halves of each driver are in `Benchmarks/IMAPDispatchClient` and `Benchmarks/IMAPByteBufferClient`, selected by `IMAP_LEGACY_BUFFERS`.
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
  `ByteBuffer` drivers, because they append through a different entry point, so "it parses at all"
  is not implied by the cases above;
- `DispatchConversion.makeRegionList` returns exactly the region count it was asked for — a region below
  `copyThreshold` would be copied into a segment and coalesced, silently turning a 64-region sweep into a
  1-region one.

A corpus that silently stops exercising the path it is named after would make every number here
meaningless.

## Baseline

Apple M5 Max, macOS 27.3, Swift 6.4.4, malloc-interposer backend. Counts are the committed thresholds
(`Thresholds/`). Wall clock is the lower p50 of three full default runs; it is machine-specific. The
three runs differed by a median of 4.2% per case, by more than 15% on 14 of 185 cases and by more than 29%
on three (largest 33%, `bytebuffer-client.parse.literal-4MB.read-1448`), at a load average of 2-3. Read the times as ±15%. The counts are deterministic everywhere except the `encode.dispatch.*` cases (see below).
Retains depend on the metric selection (see [Baselines](#baselines)), so a default run reports slightly
different ones.

| Case | wall p50 | mallocs | malloc bytes | retains |
| --- | --- | --- | --- | --- |
| `parse.command.noop` | 708 ns | 6 | 1,230 | 6 |
| `parse.command.uid_fetch_headers` | 3,584 ns | 35 | 3,044 | 42 |
| `parse.command.uid_search_compound` | 20 µs | 344 | 22,143 | 485 |
| `parse.commands.all` | 152 µs | 1,848 | 162,399 | 2,260 |
| `roundtrip.commands.all` | 199 µs | 2,191 | 197,215 | 3,167 |
| `parse.responses.session` | 77 µs | 979 | 50,267 | 2,029 |
| `parse.responses.bodystructure.200` | 4,975 µs | 41,811 | 2,413,255 | 91,824 |
| `parse.responses.bodystructure.200.read-1448` | 6,667 µs | 55,557 | 3,114,320 | 114,358 |
| `parse.responses.1000.contiguous` | 3,802 µs | 39,389 | 1,805,452 | 72,279 |
| `parse.responses.1000.read-1448` | 3,922 µs | 40,575 | 1,868,356 | 73,916 |
| `parse.responses.1000.read-65536` | 3,802 µs | 39,403 | 1,806,151 | 72,306 |
| `parse.responses.100.read-1` | 15 ms | 159,186 | 8,074,913 | 197,247 |
| `parse.literal-1MB.read-1448` | 105 µs | 751 | 60,339 | 3,667 |
| `parse.literal-1MB.read-65536` | 5,650 ns | 43 | 3,475 | 127 |
| `parse.dispatch.responses.session` | 77 µs | 982 | 50,379 | 2,028 |
| `parse.dispatch.responses.1000.contiguous` | 3,759 µs | 39,392 | 1,805,564 | 72,278 |
| `parse.dispatch.responses.1000.read-1448` | 3,922 µs | 40,827 | 1,877,764 | 73,916 |
| `parse.dispatch.responses.1000.read-65536` | 3,759 µs | 39,409 | 1,806,375 | 72,306 |
| `parse.dispatch.responses.bodystructure.200.read-1448` | 6,452 µs | 56,157 | 3,136,720 | 114,360 |
| `parse.dispatch.literal-1MB.read-1448` | 223 µs | 2,926 | 141,539 | 3,669 |
| `parse.dispatch.literal-1MB.read-65536` | 8,772 ns | 94 | 5,379 | 129 |
| `encode.command.noop` | 375 ns | 5 | 464 | 7 |
| `encode.commands.all` | 31 µs | 216 | 34,512 | 840 |
| `encode.create.quoted-string` | 458 ns | 5 | 576 | 9 |
| `encode.create.literal` | 417 ns | 5 | 576 | 9 |
| `encode.login.sync-literal` | 667 ns | 8 | 632 | 14 |
| `encode.append.128B` | 1,250 ns | 18 | 2,088 | 29 |
| `encode.append.1MB` | 14 µs | 17 | 2,098,760 | 30 |
| `encode.append.4MB` | 53 µs | 17 | 8,390,216 | 30 |
| `encode.responses.session` | 6,211 ns | 23 | 5,320 | 148 |
| `encode.responses.bodystructure.200` | 923 µs | 71 | 332,040 | 30,317 |
| `encode.responses.1000.reused-buffer` | 425 µs | 41 | 133,200 | 13,682 |
| `encode.responses.1000.fresh-buffer` | 1,129 µs | 16,378 | 2,103,384 | 30,381 |
| `encode.literal-1MB.streamed` | 40 µs | 11 | 1,464 | 2,195 |
| `encode.handler.command.noop.imap-sink` | 375 ns | 5 | 464 | 5 |
| `encode.handler.command.noop.bytebuffer-sink` | 417 ns | 4 | 512 | 10 |
| `encode.handler.commands.all.imap-sink` | 36 µs | 345 | 34,888 | 770 |
| `encode.handler.commands.all.bytebuffer-sink` | 37 µs | 276 | 35,120 | 1,114 |
| `encode.handler.append.1MB.imap-sink` | 1,416 ns | 19 | 1,706 | 27 |
| `encode.handler.append.4MB.imap-sink` | 1,499 ns | 19 | 1,706 | 27 |
| `encode.handler.append.1MB.bytebuffer-sink` | 1,541 ns | 16 | 1,872 | 44 |
| `encode.handler.append.4MB.bytebuffer-sink` | 1,541 ns | 16 | 1,872 | 44 |
| `encode.handler.responses.1000.imap-sink` | 901 µs | 10,308 | 618,528 | 18,823 |
| `encode.handler.responses.1000.bytebuffer-sink` | 1,059 µs | 5,130 | 411,024 | 39,262 |
| `encode.handler.responses.1000.in-flight.imap-sink` | 978 µs | 10,310 | 946,144 | 23,949 |
| `encode.handler.responses.1000.in-flight.bytebuffer-sink` | 1,393 µs | 15,506 | 2,474,128 | 44,388 |
| `encode.handler.responses.bodystructure.200.imap-sink` | 1,085 µs | 3,306 | 774,008 | 31,951 |
| `encode.handler.responses.bodystructure.200.bytebuffer-sink` | 1,115 µs | 1,606 | 130,048 | 38,212 |
| `encode.dispatch.commands.all.imap-sink` | 32 µs | 345 | 33,573 | not measured |
| `encode.dispatch.commands.all.bytebuffer-sink` | 36 µs | 414 | 42,357 | not measured |
| `encode.dispatch.append.1MB.imap-sink` | 2,793 ns | 22 | 1,855 | not measured |
| `encode.dispatch.append.4MB.imap-sink` | 2,667 ns | 22 | 1,855 | not measured |
| `encode.dispatch.append.1MB.bytebuffer-sink` | 2,959 ns | 25 | 2,279 | not measured |
| `encode.dispatch.append.4MB.bytebuffer-sink` | 3,040 ns | 25 | 2,279 | not measured |
| `encode.dispatch.append.1MB.array-payload` | 2,584 ns | 23 | 1,879 | not measured |
| `encode.dispatch.append.4MB.array-payload` | 2,874 ns | 23 | 1,879 | not measured |
| `encode.dispatch.responses.1000.imap-sink` | 861 µs | 10,293 | 582,717 | not measured |
| `encode.dispatch.responses.1000.bytebuffer-sink` | 1,170 µs | 15,382 | 860,541 | not measured |
| `encode.dispatch.literal-1MB.streamed.imap-sink` | 146 µs | 2,191 | 129,407 | not measured |
| `encode.dispatch.literal-1MB.streamed.bytebuffer-sink` | 147 µs | 2,189 | 128,767 | not measured |
| `encode.dispatch.regions.1` | 1,333 ns | 4 | 200 | not measured |
| `encode.dispatch.regions.4` | 1,957 ns | 19 | 1,216 | not measured |
| `encode.dispatch.regions.16` | 4,785 ns | 79 | 7,459 | not measured |
| `encode.dispatch.regions.64` | 26 µs | 319 | 66,992 | not measured |

The `encode.dispatch.*` cases measure no ARC metric, deliberately: the counters are not deterministic
there, as a comment above those registrations explains. Their wall clock is also the least trustworthy in
the suite for the same reason: a donated region's deallocator runs on a background queue, so a case's
measured time depends on how much destruction work the queue is still retiring from the case before it.
`encode.dispatch.regions.4` measured 1,957 / 2,041 / 2,123 ns in three full runs — a 8% spread on identical
code. **Read the allocation counters on that sweep, not the times.**

Nine things this baseline says that are worth knowing before optimising anything:

1. **Parsing is allocation-bound.** ~39 allocations per light-FETCH message and ~209 per body-structure
   message. Two rounds of work removed mechanisms unrelated to the output model. First, three were 74% of
   the allocations: a hand-rolled UTF-8 decode that regrew a `String` once per scalar,
   `[String: SubParser]` lookup tables rebuilt on every call, and heap closure contexts from passing
   `GrammarParser` methods as function values. Then typed throws roughly halved what remained (46–57% on
   the response corpora): an untyped throw boxes its error with `swift_allocError`, and every failed
   speculative match threw one. What is left is mostly the model: `extractBytes`, which copies each small
   field into its own `[UInt8]`, is 106 of the ~218 allocations per body-structure message that an
   `IMAPProfile` trace counts. Find the rest with [Profiling](#profiling).
2. **Encoding is ~5× cheaper than parsing** on the same traffic: 31 µs against 152 µs for the command
   corpus, 0.92 ms against 4.98 ms for the body structures. The parser is still where the work is. The gap
   used to be 20–30×; it closed because the parser got faster, not because the encoder got slower. The
   encoder stages writes under 256 bytes and appends them to its sink in one call, so a primitive write
   is an inline copy rather than a call into the sink; the two sinks differ in how they hand bytes out
   (`encode.handler.*`), not in what a write costs.
3. **Read size matters, but only once responses are big enough to straddle one.** The light sweep, whose
   responses are ~70 bytes, costs 39,389 mallocs contiguous and 40,575 at MTU-sized reads — 3% apart. The
   body-structure sweep, whose responses are ~1.4 KB and therefore straddle nearly every 1448-byte read,
   goes from 41,811 to 55,557 — **33% apart**. Anything measuring only short responses will conclude,
   wrongly, that read size is irrelevant.
4. **Byte-at-a-time input costs a parse attempt per byte, not a region per byte.** Per-call parse work
   is O(live regions), so one region per read made parsing one line quadratic in its length:
   `parse.responses.100.read-1` cost 71 ms, 418 K mallocs, 70.3 M bytes and 1.5 M retains before small
   reads were coalesced. `IMAPInputBuffer.append` now copies a read under `copyThreshold` into a shared
   1 KiB tail, so live regions number about one per KiB; the case is now 159 K mallocs and 8.1 M bytes.
   Each read still starts a parse attempt over the partial response.
5. **`DispatchData` input costs what `ByteBuffer` input does, plus a region per read.** It is appended
   to an `IMAPInputBuffer` like any read, so a literal is kept by reference here too. The 1000-response
   sweep at 1448-byte reads is 3,922 µs and 40,827 mallocs against 3,922 µs and 40,575 for
   `ByteBuffer` reads. A large literal shows the per-read cost: `parse.dispatch.literal-1MB.read-1448`
   is 2,926 mallocs and 141,539 B against 751 and 60,339 for `ByteBuffer` input (~3 more allocations per
   read), and at 64 K reads 94 against 43. The bytes stay flat in the payload size either way.
6. **A payload reaches either transport uncopied.** `encode.handler.append.*` reports 1,706 B (imap-sink)
   and 1,872 B (bytebuffer-sink) for both 1 MB and 4 MB payloads. On the Dispatch path the
   `ByteBuffer`-backed payload, a `StableAddressByteRegion`, is donated on either sink — 1,855 B
   (imap-sink) and 2,279 B (bytebuffer-sink) — and the array-backed one reports 1,879 B for both sizes.
   Flat lines, i.e. nothing copying the payload. Still copied: into a `ByteBuffer`, a run of small
   regions and any region not backed by one (`IMAPOutputBuffer`'s own included); into a `DispatchData`,
   a region under 512 B (finding 8) or without a fixed address.
7. **A `DispatchData` output region costs ~5 allocations and ~1 KB, not the ~150 ns + ~40 ns the encoder
   design assumed.** Across the region sweep the malloc count goes 4 → 19 → 79 → 319 for 1 → 4 → 16 → 64
   regions, i.e. 5.0 per region, and the bytes go 200 → 66,992, i.e. ~1,060 per region. The design's
   "minimise regions per chunk" rule is right and considerably more important than the number behind it
   suggested; a 64-region chunk is not cheap insurance.
8. **Converting many small messages to `DispatchData` costs about what handing them out as `ByteBuffer`s
   does.** `encode.dispatch.responses.1000.imap-sink` is 861 µs and 10,293 mallocs against 901 µs and
   10,308 for the same sweep handed out as `ByteBuffer`s: `makeDispatchData()` copies regions shorter than
   the dispatch donation threshold (512 B), each run into one allocation, and donates only the
   rest. With `ByteBufferOutput` it is 1,170 µs, 15,382 mallocs and 861 KB against 1,059 µs, 5,130 and
   411 KB.
9. **A reused `ResponseEncodeBuffer` is now better on both counts** — 425 µs / 41 mallocs / 133 KB against
   1,129 µs / 16 K / 2,103 KB for a fresh one per response. It used to allocate *fewer times but more
   bytes*, because clearing a `ByteBuffer` whose storage was no longer uniquely referenced reallocated it
   once per response. The sink keeps the segment it is writing into instead.

## Before and after: a `DispatchData` client

Everything above measures the current library against itself. These sections measure it against
**`main`** — the library before the `ByteBuffer` migration — from the point of view of one caller each.
This one is a client whose transport is `DispatchData` in both directions, i.e. `DispatchIO` or
Network.framework, the second backing the output abstraction exists for. Its `main` side also pays
`DispatchData` ↔ `ByteBuffer` conversions that a `ByteBuffer` client never does; for that client see
[Before and after: a `ByteBuffer` client](#before-and-after-a-bytebuffer-client). One script,
`dev/compare-dispatch-client.sh`, runs both (`TARGETS=dispatch` or `TARGETS=bytebuffer` for one).

```sh
cd Examples/PerformanceTester
./dev/compare-dispatch-client.sh                       # ~7 minutes for both clients with warm builds, longer when building

# The script prints both comparisons. To summarise one again, one row per case (phase: parse, encode):
phase=parse
swift package --disable-sandbox --scratch-path .build-branch benchmark baseline compare \
  main-$phase branch-$phase --target IMAPDispatchClient --filter "dispatch-client.$phase.*" 2>&1 \
  | tr '\r' '\n' > /tmp/cmp.txt
./dev/summarize-comparison.py /tmp/cmp.txt --before main-$phase --after branch-$phase
```

The script checks out the pre-migration library under `.worktrees/pre-migration` — pinned to commit
`6b1b196c`, not to the branch name, so that it keeps meaning "before" after this branch merges — points
this package's path dependency at it via `IMAP_IMPL=main`, records a baseline, then does the same for
this tree and compares. One set of case names, two libraries.

### What each side does

| | before (`main`) | after (this tree) |
| --- | --- | --- |
| read | copy every received region into one `ByteBuffer`; compact when the parsed prefix passes half | append every region to an `IMAPInputBuffer`; parse where it landed |
| payload | copy it out of the accumulator | keep the `IMAPBuffer` the parser handed over |
| write | encode into the encoder's `ByteBuffer`, then `DispatchData(bytes:)` | encode into `IMAPOutputBuffer`, then `makeDispatchData()`, which donates large regions and copies short ones |

Two things bound what the numbers mean, and both are deliberate:

- **The `main` side is the best client that API allows, not the client anybody wrote.** Capacity
  reserved up front, amortised compaction rather than a `discardReadBytes()` per read, and payloads
  copied *out* of the accumulator rather than held as slices of it — holding a slice leaves the
  accumulator multiply-referenced, so the next append copies the whole storage, which for a 1 MB
  literal at MTU reads works out at roughly 45 MB of copy-on-write against 1 MB for copying the payload
  out. So every figure below is a **floor** on what the migration is worth.
- **The comparison is of the whole branch**, not of the buffer types alone: the parser's allocation work
  (finding 1 above) and the model's move off `ByteBuffer` are in the same number. Nothing here attributes
  the win between them.

### Results

Measured against `6b1b196c` on an Apple M5 Max, macOS 27.3, Swift 6.4.4, `ordo-one/benchmark` 1.38.1,
malloc-interposer backend. Wall clock is, per side, the lowest of two script runs (up to 1,000 iterations
per case, capped at 3 s) and five standalone runs of each binary, interleaved main/branch; `encode.append.*`
is standalone only (below). Counters and times come from the same tree. Load average was 2.0-3.3 during the runs, which is
the benchmarks' own footprint (1.7 idle afterwards); I could not inspect other processes. The two script runs of a
case differed by 0-7%, five standalone runs of `main` by 0-11% (the sweep once by +33%) and of this tree by
1-21%, with two outliers (+36% on the 4 MB literal at 64 K reads, +44% on the 1 MB literal at 1448), hence the lowest figure.
Read-side counters are deterministic; write-side ones vary by up to 2 allocations per iteration, because
deallocators run on a background queue, and the table quotes their p50 (equal to the committed p90). The
read cases are measured with ARC counting on, which taxes both sides — re-measured with it off (two runs,
lower p50 each side), the sweep goes from 26.4 → 3.99 ms to 20.6 → 3.27 ms and its time ratio from −84.9% to
−84.1%, i.e. by under a point. The write cases do not measure ARC counters at all; see below.
`encode.append.*` is bimodal on this side (asynchronous deallocation): the harness reports the lower mode,
1.5 µs for this tree and 27 / 112 µs for `main`. The table quotes five standalone runs, which are tight
(2.8-2.9 µs at 1 MB, 2.6-2.8 µs at 4 MB here; 34.5 and 108 µs for `main`).

| Case | wall clock | mallocs | malloc bytes | retains |
| --- | --- | --- | --- | --- |
| `parse.session` | 368 µs → 83.5 µs | 8,107 → 1,015 | 471 K → 52.9 K | 6,502 → 2,079 |
| `parse.sweep.1000.read-1448` | 25.9 ms → 3.94 ms | 583 K → 40.8 K | 32.5 M → 1.88 M | 527 K → 73.9 K |
| `parse.bodystructure.200.read-1448` | 31.2 ms → 6.43 ms | 617 K → 56.2 K | 33.4 M → 3.14 M | 741 K → 114 K |
| `parse.literal-1MB.read-1448` | 281 µs → 243 µs | 4,647 → 2,937 | 1.81 M → 223 K | 4,647 → 4,394 |
| `parse.literal-1MB.read-65536` | 53.7 µs → 9.26 µs | 393 → 99 | 1.14 M → 6,531 | 399 → 146 |
| `parse.literal-4MB.read-65536` | 165 µs → 26.1 µs | 682 → 293 | 4.30 M → 19.4 K | 687 → 434 |
| `encode.commands.all` | 13.0 µs → 9.46 µs | 260 → 141 | 16.1 K → 13.7 K | not measured |
| `encode.responses.session` | 13.8 µs → 10.2 µs | 204 → 113 | 21.8 K → 10.3 K | not measured |
| `encode.responses.bodystructure.200` | 1.67 ms → 1.25 ms | 6,615 → 3,487 | 2.13 M → 568 K | not measured |
| `encode.append.1MB` | 34.5 µs → 2.83 µs | 27 → 23 | 2.10 M → 1,879 | not measured |
| `encode.append.4MB` | 108 µs → 2.58 µs | 27 → 23 | 8.40 M → 1,879 | not measured |

Five things this says:

1. **The read side wins everywhere, and by a factor rather than a percentage.** Ordinary traffic — the
   session preamble, a thousand-message flag sweep, two hundred body structures — costs **8–14× fewer
   allocations, 9–17× fewer allocated bytes and 4.4–6.6× less time**. None of that is the buffer plumbing
   alone; it is the migration plus the allocation work that followed it, which is the honest scope of
   the question "what is this branch worth".
2. **The payload path becomes O(1) in the payload, in bytes *and* in time.** A 1 MB literal at 64 K reads
   allocates 1.14 MB before and 6.5 KB after; at 4 MB it is 4.30 MB against 19.4 KB. The write side is
   the cleaner demonstration: an `APPEND` allocates **1,879 bytes and takes ~2.6-2.8 µs (standalone) whether the
   message is 1 MB or 4 MB**, against 2.10 MB / 34.5 µs and 8.40 MB / 108 µs. Flat against
   proportional — **~12× faster at 1 MB and ~42× at 4 MB** — which is what "the payload is never copied" looks
   like in a counter.
3. **At MTU reads a large literal gains least.** `parse.literal-1MB.read-1448` is 243 µs against 281 µs,
   with about as many retains (4,394 against 4,647), because a 1 MB literal arriving in 1448-byte pieces
   is ~700 extractions, each boxing a region and taking a reference, where `main` does one `memcpy` per
   read into a buffer it already owns. The allocated bytes fall 8.1×. This is the documented trade —
   per-region bookkeeping against copies — and the shape where the migration buys the least time.
4. **Small-message encoding is faster too: 27% for commands, 26% for the session preamble,** with 46%
   and 45% fewer allocations. `encode.commands.all` measured 9.46 µs against 13.0 µs and
   `encode.responses.session` 10.2 µs against 13.8 µs (interleaved standalone pairs: 26–29% and 23–29%). On cases this short, read the direction rather
   than the exact figure. Donating a region (`bytesNoCopy` plus a custom deallocator block holding the
   owner) costs more than copying a few bytes, so `makeDispatchData()` copies regions shorter than
   the dispatch donation threshold (512 B), each run into one allocation, the way
   `IMAPInputBuffer` copies small reads; corroborated in-tree by finding 8 of the baseline above.
5. **Encoding heavy responses wins on every axis it is measured on.** `encode.responses.bodystructure.200`
   is ~25% faster (1.25 against 1.67 ms; 19–26% across five interleaved standalone pairs) with 3.7× fewer allocated bytes and 47% fewer allocations (3,487 against 6,615), which is
   the traffic the segment sink was chosen for — hundreds of small writes into memory the encoder owns,
   its large regions handed over without a copy.

### The ARC counters

The write cases **do not measure ARC metrics**, for the reason `encode.dispatch.*` already carries: large
regions are donated to a `DispatchData`, which frees the memory it adopted on a background queue, so how
many of a chunk's releases land inside the measured region depends on how far that queue has got.
`encode.responses.session` reported retain deltas of 38 and 58 across two runs of the same binary with
byte-identical allocation counters.

**A `--metric` on the command line overrides the per-case opt-out.** So
`thresholds check --metric retainCount …` over a filter that includes these cases gates noise, which is
why `dev/compare-dispatch-client.sh` runs the read and write halves as two phases
with different metric sets, and why the committed thresholds for the write cases hold `mallocCountTotal`
and `mallocBytesCount` only. Read those cases' ratios in allocations and bytes; the wall clock is
directional and the ARC counters are not measured at all.

## Before and after: a `ByteBuffer` client

The same comparison for a client whose transport is `ByteBuffer` in both directions — a NIO `Channel`
client, the usual one. Its `main` side pays no `DispatchData` conversion, so unlike the section above
every difference is the parser and encoder themselves.

```sh
./dev/compare-dispatch-client.sh            # both clients, ~7 minutes with warm builds
TARGETS=bytebuffer ./dev/compare-dispatch-client.sh
```

Baselines are `bytebuffer-main-<phase>` and `bytebuffer-branch-<phase>`, so the two clients do not
overwrite each other. `FILTER` and `FILTER_ENCODE` apply to every client the script runs, so set them
together with `TARGETS`. To summarise, as above, with `--target IMAPByteBufferClient`, `bytebuffer-client.$phase.*`
and those baseline names.

### What each side does

| | before (`main`) | after (this tree) |
| --- | --- | --- |
| read | copy every received `ByteBuffer` into one accumulator; compact when the parsed prefix passes half | append every `ByteBuffer` to an `IMAPInputBuffer`; parse where it landed |
| payload | copy it out of the accumulator | keep the `IMAPBuffer` the parser handed over |
| write | encode into the encoder's `ByteBuffer`; write each chunk as it is | encode into `IMAPOutputBuffer`; write each chunk as `IMAPClientHandler` does (`makeOutboundBuffers()`) |

The `main` side is the best client its API allows, as above, so every figure is a floor — with one
exception. Its read model copies every received byte into the accumulator, whereas a real NIO
cumulation can keep a read by reference when the cumulation buffer is empty. That is a small effect at
MTU reads and possibly a larger one at 64 K reads on the sweep, where a read often holds whole
messages; it is not measured. The write
side uses the library's default sink, because that is what `IMAPClientHandler` uses; the benchmark-local
`ByteBufferOutput` is measured against it in `encode.handler.*`. The `APPEND` payload is
`ByteBuffer`-backed on both sides, and is built outside the measured region on both. A client that
holds a `[UInt8]` pays one extra copy to get it into a `ByteBuffer` on each side, so for that client
the win is two copies down to one, not the ratios below. An array-backed payload on the current side
would be copied by `makeOutboundBuffers()`.

**How `main` yields an `APPEND` payload.** `CommandEncodeBuffer` on `main` writes `.messageBytes` with
`EncodeBuffer.writeBuffer`, which copies it into the encoder's own `ByteBuffer`; `nextChunk()` then returns
`readSlice` views of that buffer. So a `ByteBuffer` client pays **one** payload copy, not two (the
`DispatchData` client pays the second one when it converts the chunk), and the chunk that carries the
payload is one `ByteBuffer`. The win below is that one copy.

### Results

Measured against `6b1b196c` on an Apple M5 Max, macOS 27.3, Swift 6.4.4, `ordo-one/benchmark` 1.38.1,
malloc-interposer backend. Wall clock is, per side, the lowest of two script runs and five standalone runs of
each binary, interleaved main/branch. Load average was 2.0-3.3 during the runs, which is the benchmarks' own
footprint (1.7 idle afterwards); I could not inspect other processes. The two script runs of a case
differed by 0-10% (a 36% / 25% outlier on `parse.session`); five standalone runs of a case varied by 0-10%. Cases under ~20 µs reproduce only within
±15% (rows marked `~`); quote them as approximate.
Counters on this tree are exact. On `main` they were identical across the five standalone runs of every case
(`parse.literal-4MB.read-1448`: 14,791 retains and 8,991 mallocs), and the table quotes them; `main`'s retains under 10,000 come from
the harness comparison, which gates the same metric set as the thresholds, since retains depend on the metric selection
(see [Baselines](#baselines)). Reads and writes are measured with ARC counting on, which taxes both sides — and
the small encode cases most: under the runner's malloc interposer every extra malloc, retain and release is counted,
which plausibly overstates the cost of this tree's small writes. That is a hypothesis; it was not isolated here.

| Case | wall clock | mallocs | malloc bytes | retains |
| --- | --- | --- | --- | --- |
| `parse.session` | 369 µs → 83.6 µs | 8,099 → 1,009 | 470 K → 52.6 K | 6,500 → 2,077 |
| `parse.sweep.1000.contiguous` | 25.4 ms → 3.84 ms | 571 K → 39.4 K | 31.9 M → 1.81 M | 511 K → 72.3 K |
| `parse.sweep.1000.read-1448` | 26.0 ms → 3.98 ms | 582 K → 40.6 K | 32.5 M → 1.87 M | 526 K → 73.9 K |
| `parse.sweep.1000.read-65536` | 25.2 ms → 3.83 ms | 571 K → 39.4 K | 31.8 M → 1.81 M | 511 K → 72.3 K |
| `parse.bodystructure.200.read-1448` | 31.2 ms → 6.49 ms | 616 K → 55.6 K | 33.4 M → 3.11 M | 740 K → 114 K |
| `parse.bodystructure.200.read-65536` | 25.3 ms → 5.04 ms | 508 K → 42.3 K | 27.5 M → 2.44 M | 588 K → 92.5 K |
| `parse.literal-1MB.read-1448` | 185 µs → 121 µs | 2,471 → 762 | 1.73 M → 142 K | 3,922 → 4,392 |
| `parse.literal-1MB.read-16384` | 54.4 → ~14.6 µs | 487 → 98 | 1.14 M → 12.1 K | 622 → 432 |
| `parse.literal-1MB.read-65536` | 50.7 → ~6.08 µs | 342 → 48 | 1.14 M → 4,627 | 382 → 144 |
| `parse.literal-4MB.read-1448` | 708 µs → 474 µs | 8,991 → 2,935 | 6.68 M → 414 K | 14.8 K → 17.4 K |
| `parse.literal-4MB.read-65536` | 156 → ~14.5 µs | 487 → 98 | 4.29 M → 12.1 K | 622 → 432 |
| `encode.commands.all` | ~11.4 → ~10.8 µs | 204 → 141 | 13.3 K → 14.2 K | 108 → 158 |
| `encode.responses.session` | ~10.8 → ~11.9 µs | 114 → 122 | 16.8 K → 11.9 K | 90 → 202 |
| `encode.responses.bodystructure.200` | 1.74 ms → 1.07 ms | 3,413 → 3,306 | 1.75 M → 774 K | 50.2 K → 32.0 K |
| `encode.append.1MB` | ~12.2 → ~1.42 µs | 19 → 19 | 1.05 M → 1,706 | 11 → 27 |
| `encode.append.4MB` | 49.4 → ~1.42 µs | 19 → 19 | 4.20 M → 1,706 | 11 → 27 |

Findings:

1. **Reads win by the same factor as for the `DispatchData` client.** Ordinary traffic — the session
   preamble, a thousand-message sweep, two hundred body structures — costs **8–15× fewer allocations,
   9–18× fewer allocated bytes and 4.4–6.6× less time**. The gap is the accumulator copy, the
   parser's allocation work and the model together; this comparison does not separate them.
2. **Payloads become O(1) in the payload on read and on `APPEND`.** A 4 MB literal at 64 K reads allocates
   4.29 MB before and 12.1 KB after, in ~15 µs against ~156 µs (~11×). `APPEND` allocates 1,706 bytes for
   1 MB and for 4 MB alike, against 1.05 MB and 4.20 MB. The `APPEND` win is the single copy `main`
   makes, as above: ~12 → ~1.4 µs at 1 MB, ~49 → ~1.4 µs at 4 MB (9× and 35×). The same cases take 2.5× the retains
   (11 → 27) and the same mallocs (19).
3. **At MTU reads a large literal gains least.** 1 MB at 1448-byte reads is 121 µs against 185 µs
   (−35%), and retains go *up* 12% (3,922 → 4,392; 4 MB: +18%): ~700 extractions each box a region and
   take a reference, where `main` does one `memcpy` per read into a buffer it owns. The allocated bytes
   still fall 12×.
4. **Small-message encoding is a small win for commands and a small loss for the session preamble, with more retains.**
   In five interleaved standalone pairs `encode.commands.all` was faster every time, by 3.5–9.1% (lowest p50 10.8 against 11.4 µs), and
   `encode.responses.session` slower every time, by 9.2–12.2% (11.9 against 10.8 µs). Both differences are about 1 µs, and measured under the malloc interposer.
   The counters: commands take 31% fewer mallocs (141 against 204) but 1.5× the retains (108 → 158) and 7% more
   allocated bytes (14.2 K against 13.3 K); the session takes 7% more mallocs (122 against 114), 2.2× the retains (90 → 202)
   and 29% fewer bytes. The retains are consistent with `IMAPOutputBuffer` and `IMAPBufferList` against `main` handing the encoder's `ByteBuffer` over as is.
   The `DispatchData` client does not see this, because its `main` side also pays a conversion per chunk.
5. **Heavy encoding wins.** `encode.responses.bodystructure.200` takes 39% less time (1.07 against 1.74 ms), with 2.3× fewer allocated
   bytes and 36% fewer retains.

The wall clock of `encode.append.*` is bimodal for the `DispatchData` client because of asynchronous
deallocation. It is not here: harness and standalone p50 agree within ~6% (1.33 against 1.42 µs for the after side, 12.2 against 12.2 µs for `main`'s 1 MB `APPEND`),
and the ARC counters of the write cases are exact, which is why they are gated.

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

- **The magnitude suffixes in `baseline compare` headers differ between cases.** On
  `bytebuffer-client.parse.sweep.1000.read-1448`, `Retains (K)` prints `74` and `Time (wall clock) (μs)` prints
  `4116`; on `bytebuffer-client.parse.literal-1MB.read-65536`, `Retains` prints `144` and `Time (wall clock) (ns)` prints
  `6419`. With `ordo-one/benchmark` 1.36.2 the suffixes were not even scale factors; with 1.38.1 they are.
  Never compare or sum printed values across cases. Ratios within a case are exact; for absolutes use the
  threshold JSONs or a standalone run (see [Baselines](#baselines)).
- **`thresholds update` writes every `--metric` you pass to every case, including ones that opted out.**
  A six-metric update over all cases adds ARC counters to the `encode.dispatch.*` and
  `dispatch-client.encode.*` threshold files, which must not be gated — hence the six invocations in
  [Checking against the committed thresholds](#checking-against-the-committed-thresholds). After any
  update, this must print nothing:

  ```sh
  grep -l retainCount Thresholds/IMAPEncoding.encode.dispatch.*.json \
    Thresholds/IMAPDispatchClient.dispatch-client.encode.*.json
  ```

  The same override applies to `thresholds check` and `baseline update`.
- **Occasional "1 benchmark job(s) failed during runtime" on full-suite runs.** Re-running the case alone
  has always succeeded. Afterwards, check every registered case got a threshold file: compare
  `swift package --disable-sandbox benchmark list` against `ls Thresholds`.
