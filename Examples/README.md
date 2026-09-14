# Examples

This directory contains example and tool projects built on top of `swift-nio-imap`.
Each subdirectory is its **own standalone Swift package** that depends on the library
in the repository root via a local path dependency (`.package(path: "../..")`).

Keeping them out of the root package means the library's own dependency graph stays
smaller — consumers don't resolve example-only dependencies such as `ArgumentParser`.
(Dependencies that the library products themselves use — for example `swift-log`, which
`IMAPCommands` depends on — remain part of the root package's graph.)

| Example | What it is |
| --- | --- |
| [`IMAPTool`](IMAPTool) | Command-line IMAP debugging tool (`imap-tool`) built on the `IMAPToolLib` library product. |
| [`CLI`](CLI) | A smaller command-line interface plus its supporting `CLILib` (with tests). |
| [`Proxy`](Proxy) | An IMAP proxy that logs the traffic flowing through it. |
| [`Fuzzer`](Fuzzer) | Fuzzing harness for the IMAP parser (`NIOIMAPFuzzer`). |
| [`PerformanceTester`](PerformanceTester) | Micro-benchmarks for parsing/encoding (`NIOIMAPPerformanceTester`). |

## Building and running

Each example builds independently. From the repository root:

```sh
swift build --package-path Examples/IMAPTool
swift run   --package-path Examples/IMAPTool imap-tool --help
```

Because they are separate packages, `swift build` / `swift test` at the repository
root builds only the library targets — not these examples. CI builds them via a
dedicated `Build examples` job.
