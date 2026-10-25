# Benchmarks

Benchmarks for the IMAP parser and encoder, built on
[ordo-one/benchmark](https://github.com/ordo-one/benchmark).

This is a standalone package so that the benchmark dependencies never enter the library's own
dependency graph — building or testing `swift-nio-imap` at the repository root resolves none of them.
It requires **Swift 6.3 or later**; see [Toolchain](#toolchain) for why.

It replaces the hand-rolled harness that used to live here (`NIOIMAPPerformanceTester`), which timed
things with `Date()` and printed raw seconds. Allocation and ARC counters are now measured and gated.

## Running

```sh
# From this directory. `--disable-sandbox` is required: the plugin writes results to disk.
swift package --disable-sandbox benchmark

# One case, or a regex over case names.
swift package --disable-sandbox benchmark --filter "dispatch-client.parse.*"

# Two of the six gated metrics (see below).
swift package --disable-sandbox benchmark --metric mallocCountTotal --metric retainCount
```

Benchmarks always build in release mode, regardless of how you invoke them.

## Layout

| Path | What it is |
| --- | --- |
| `Sources/IMAPCorpus` | The corpora, as wire bytes and wire text. |
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

Every benchmark records wall clock, throughput, resident-memory delta, malloc counts and malloc bytes.
The read cases also record the four ARC counters. They are not equally trustworthy:

- **Gated: `mallocCountTotal`, `mallocBytesCount`, `objectAllocCount`, `retainCount`,
  `releaseCount`, `retainReleaseDelta`.** These are deterministic and do not depend on how busy the
  machine is.
- **Recorded but not gated: wall clock, throughput, resident memory.** Sampled, machine-dependent
  and noisy at the tail. Useful for a before/after on one machine, useless as a committed ceiling.
- **The `dispatch-client.encode.*` cases measure no ARC metric at all.** Requesting one makes the
  harness install a `swift_retain` hook whose teardown races any retain on a thread the benchmark does
  not own — an `EXC_BAD_ACCESS` at `0x0` on `com.apple.root.default-qos` (upstream,
  `ordo-one/benchmark` 1.36.2). The registration carries the full reasoning.

`mallocBytesCount` is the stand-in for "bytes copied": there is no bytes-copied metric, but a
copying implementation's allocated bytes scale with payload size and a zero-copy one's do not. That
is what the paired `1MB` / `4MB` cases are for.

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

A `--metric` on the command line overrides a case's own metric set, so `thresholds update` with the
set above also writes ARC counters into the `dispatch-client.encode.*` files, which must not be gated.
After any update, revert them; the grep must print nothing:

```sh
git checkout -- Thresholds/IMAPDispatchClient.dispatch-client.encode.*.json
grep -l retainCount Thresholds/IMAPDispatchClient.dispatch-client.encode.*.json
```

Not wired into CI: the committed thresholds were measured on macOS/arm64 with one toolchain, and
allocation counts differ across platforms and across stdlib versions even though they are stable on
any single one.

### Baselines

```sh
swift package --disable-sandbox benchmark baseline update main   # record
swift package --disable-sandbox benchmark baseline compare main  # compare a later run against it
```

Baselines land in `.benchmarkBaselines/` and are git-ignored — they embed the host they were
measured on, so they are only meaningful locally. Hold the filter set and the `--metric` selection
fixed between `update` and `compare`; counters are only comparable between runs that agree on both.

## Adding a case

Benchmark names must not contain spaces or slashes. `thresholds update` replaces both with `_` when
it writes `Thresholds/<target>.<name>.p90.json`, but `thresholds check` looks the file up under the
unmangled name, so the threshold is never read. Hence the dotted, hyphenated identifiers.

Build the corpus in a local `let` inside the `benchmarks` closure rather than as a lazy global:
globals are initialised on first touch, which would otherwise happen inside the first measured
iteration.
