#!/usr/bin/env python3
# ===----------------------------------------------------------------------===
#
# This source file is part of the SwiftNIO open source project
#
# Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
# Licensed under Apache License v2.0
#
# See LICENSE.txt for license information
# See CONTRIBUTORS.txt for the list of SwiftNIO project authors
#
# SPDX-License-Identifier: Apache-2.0
#
# ===----------------------------------------------------------------------===
"""Collapse a `swift package benchmark baseline compare` run into one table of percentage changes.

`baseline compare` prints a percentile table per metric per case — about 16,000 lines for the
147-case suite, which is more than anyone reads. This reduces it to one row per case: the p90 of
each gated counter on both sides, and the percentage change.

    cd Examples/PerformanceTester
    swift package --disable-sandbox benchmark baseline compare before 2>&1 \\
      | tr '\\r' '\\n' > /tmp/cmp.txt
    ./dev/summarize-comparison.py /tmp/cmp.txt

**It reports percentages, and deliberately does not rescale or sum anything.** The harness appends a
magnitude suffix to each column header, and the suffixes cannot be trusted as scale factors:

- On `parse.responses.bodystructure.200`, `Retains (K)` prints `207` where the true count is 207,000
  — so there `(K)` is ×10³. In the same case's table `Malloc (bytes total) (K)` prints `20` where the
  true figure is 20 MB — so there the same suffix is ×10⁶.
- `Time (wall clock) (ms)` prints `25` for that case and 25 ms is right; but on
  `parse.command.uid_fetch_headers`, `Time (wall clock) (ns)` prints `24` where the true value is
  ~22 µs, cross-checked against both `Throughput (# / s)` and a standalone run of the case.

Within one case's table both rows carry the same suffix, so **a per-case ratio is exact** whatever the
suffix means. Anything absolute has to come from elsewhere: run the single case directly, which prints
unscaled values —

    .build/release/IMAPParsing --filter 'parse\\.responses\\.bodystructure\\.200$'

Every metric here is lower-is-better, so the sign of the number is the sign of the change. Trust the
allocation counters and distrust the timings: they drift ~7% run to run on the development machine, so
only double-digit percentages there mean anything.
"""

import argparse
import re
import statistics
import sys

# The p90 column, which is what the committed thresholds gate on.
PERCENTILE = "p90"

# (column label as the harness prints it, minus any magnitude suffix; display name)
METRICS = [
    ("Malloc (total)", "mallocs"),
    ("Malloc (bytes total)", "bytes"),
    ("Object allocs", "objs"),
    ("Retains", "retains"),
    ("Releases", "releases"),
    ("Time (wall clock)", "time"),
]
SUFFIXES = {"K", "M", "G", "#", "ns", "μs", "us", "ms", "s"}


def parse(path, before_label, after_label):
    """Return {(case, metric): {row_label: printed_value_at_PERCENTILE}}, unscaled."""
    rows = {}
    case = metric = None
    percentile_column = None
    for line in open(path, encoding="utf-8", errors="replace"):
        stripped = line.strip()
        header = re.match(r"^(\S+) metrics$", stripped)
        if header:
            case, metric = header.group(1), None
            continue
        if not stripped.startswith("│"):
            continue
        cells = [c.strip() for c in stripped.strip("│").split("│")]
        if len(cells) > 1 and cells[1] == "p0":
            # `Malloc (total) (K) *` -> `Malloc (total)`. The suffix is dropped, not applied: see
            # the module docstring for why it is not a usable scale factor.
            label = cells[0].rstrip(" *")
            units = re.findall(r"\(([^()]*)\)\s*$", label)
            if units and units[0] in SUFFIXES:
                label = label[: label.rindex("(")].strip()
            metric = label
            percentile_column = cells.index(PERCENTILE) - 1 if PERCENTILE in cells else None
            continue
        if cells[0] in (before_label, after_label) and case and metric and percentile_column is not None:
            try:
                value = float(cells[1 + percentile_column].replace(",", "").replace(" ", ""))
            except (ValueError, IndexError):
                continue
            rows.setdefault((case, metric), {})[cells[0]] = value
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("comparison", help="captured output of `benchmark baseline compare`")
    ap.add_argument("--min-delta", type=float, default=0.5,
                    help="hide cases whose malloc count moved less than this %% (default: 0.5)")
    ap.add_argument("--filter", default="", help="only cases whose name contains this")
    # `baseline compare` labels its two rows with whatever the baselines are called, and comparing a
    # stored baseline against a fresh run calls them `before` and `Current_run`. Comparing two stored
    # baselines — which is how the IMAPDispatchClient before/after runs, as `main` and `branch` — names
    # the rows after the baselines instead, so the labels have to be sayable.
    ap.add_argument("--before", default="before", help="row label of the baseline (default: before)")
    ap.add_argument("--after", default="Current_run",
                    help="row label of what it is compared against (default: Current_run)")
    args = ap.parse_args()

    rows = parse(args.comparison, args.before, args.after)
    if not rows:
        sys.exit(f"no comparison tables found in {args.comparison} — was the output truncated?")
    cases = [c for c in dict.fromkeys(k[0] for k in rows) if args.filter in c]

    header = f"{'case':<52}" + "".join(f"{name:>11}" for _, name in METRICS)
    print(header)
    print(f"{'':<52}" + "".join(f"{'Δ%':>11}" for _ in METRICS))
    print("-" * len(header))

    deltas = {name: [] for _, name in METRICS}
    lines = []
    regressed = []
    for case in cases:
        cells = f"{case:<52}"
        primary = None
        for label, name in METRICS:
            side = rows.get((case, label), {})
            before, after = side.get(args.before), side.get(args.after)
            if before is None or after is None or not before:
                cells += f"{'-':>11}"
                continue
            delta = 100 * (after - before) / before
            deltas[name].append(delta)
            if name == "mallocs":
                primary = delta
            cells += f"{delta:>11.1f}"
        if primary is None:
            continue
        lines.append((primary, cells))
        if primary > args.min_delta:
            regressed.append((primary, case))

    for primary, cells in sorted(lines):
        if abs(primary) >= args.min_delta:
            print(cells)

    print("-" * len(header))
    print(f"{len(lines)} cases. Distribution of the per-case percentage change "
          f"(the only figure that is comparable across cases):")
    print(f"  {'metric':<10}{'median':>10}{'mean':>10}{'best':>10}{'worst':>10}{'cases':>8}")
    for _, name in METRICS:
        values = deltas[name]
        if not values:
            continue
        print(f"  {name:<10}{statistics.median(values):>+10.1f}{statistics.fmean(values):>+10.1f}"
              f"{min(values):>+10.1f}{max(values):>+10.1f}{len(values):>8}")

    print(f"\nCases whose malloc count went UP by more than {args.min_delta}%: {len(regressed)}")
    for delta, case in sorted(regressed, reverse=True):
        print(f"  {case:<52}{delta:>+7.1f}%")


if __name__ == "__main__":
    main()
