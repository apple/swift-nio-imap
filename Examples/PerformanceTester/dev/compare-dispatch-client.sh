#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftNIO open source project
##
## Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftNIO project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##
#
# Measures the `dispatch-client.*` and `bytebuffer-client.*` cases against two libraries and prints the
# comparisons: this working tree, and a worktree pinned to the commit before the ByteBuffer migration.
# See `Benchmarks/IMAPDispatchClient/DispatchClient.swift` and
# `Benchmarks/IMAPByteBufferClient/ByteBufferClient.swift` for what the two configurations do.
#
# Run from `Examples/PerformanceTester`:
#
#     ./dev/compare-dispatch-client.sh
#     TARGETS=bytebuffer ./dev/compare-dispatch-client.sh     # or `dispatch`; default is both
#
# Roughly seven minutes with warm builds, longer when building the two libraries. Both configurations share this
# package's `.benchmarkBaselines` directory, which is what lets `baseline compare` pair them up by case
# name. Baselines are `main-<phase>` / `branch-<phase>` for the dispatch client and
# `bytebuffer-main-<phase>` / `bytebuffer-branch-<phase>` for the ByteBuffer client, so neither
# overwrites the other. `FILTER` and `FILTER_ENCODE` override the case filter for every client run, so
# pair them with `TARGETS`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKTREE="${IMAP_MAIN_PATH:-$REPO_ROOT/.worktrees/pre-migration}"

# The library as it was before the migration, pinned by commit rather than by branch name.
#
# This is the merge base of the `buffers` branch — `main` as it stood while the comparison was taken. It
# has to be a commit: once that branch merges, `main` *is* the migrated library, and building the legacy
# half of the driver against it fails to compile, since it names `AppendCommand.messageBytes(ByteBuffer)`
# and the migrated model has no such case. Pinning keeps the comparison runnable after the merge, and
# keeps it honest before it — a moving `main` would silently change what "before" means.
#
# It will not stay runnable forever: a library from 2026 stops building on some future toolchain, and at
# that point the recorded numbers in `README.md` are what survives. That is the expected end state, not a
# regression to fix.
PRE_MIGRATION_COMMIT="${IMAP_PRE_MIGRATION_COMMIT:-6b1b196cd6cf0c9861671359656c19d67265b8e6}"

# Same metric selection for both sides of a comparison. Counters are only comparable between runs that
# agree on it — the same case has reported five retains under the full set and three under a subset — so
# each set is defined once and used twice rather than typed per invocation.
#
# Two sets, and the split is not cosmetic. The dispatch client's `encode.*` cases donate large regions to
# a `DispatchData`, which frees on a background queue, so their ARC counters are noise. The cases opt
# out in their own configuration, but a `--metric` on the command line overrides that — so that encode
# phase must not ask. See the note in `Benchmarks/IMAPDispatchClient/IMAPDispatchClient.swift`. The
# ByteBuffer client frees synchronously and gates ARC on writes too, so it uses the full set throughout.
PARSE_METRICS=(
    --metric wallClock
    --metric mallocCountTotal
    --metric mallocBytesCount
    --metric objectAllocCount
    --metric retainCount
    --metric releaseCount
    --metric retainReleaseDelta
)
ENCODE_METRICS_DISPATCH=(
    --metric wallClock
    --metric mallocCountTotal
    --metric mallocBytesCount
)

# One entry per client: <SwiftPM target>:<case-name prefix>:<baseline-name prefix>:<encode metric set>.
CLIENTS_DISPATCH="IMAPDispatchClient:dispatch-client::dispatch"
CLIENTS_BYTEBUFFER="IMAPByteBufferClient:bytebuffer-client:bytebuffer-:full"
case "${TARGETS:-both}" in
    both) CLIENTS=("$CLIENTS_DISPATCH" "$CLIENTS_BYTEBUFFER") ;;
    dispatch) CLIENTS=("$CLIENTS_DISPATCH") ;;
    bytebuffer) CLIENTS=("$CLIENTS_BYTEBUFFER") ;;
    *) echo "error: TARGETS must be both, dispatch or bytebuffer" >&2; exit 1 ;;
esac

cd "$PACKAGE_DIR"

if [ ! -d "$WORKTREE" ]; then
    echo "==> Checking out the pre-migration library at $WORKTREE"
    git -C "$REPO_ROOT" worktree add --detach "$WORKTREE" "$PRE_MIGRATION_COMMIT"
else
    # A worktree left at some other commit would make "before" mean something else without saying so.
    at="$(git -C "$WORKTREE" rev-parse HEAD)"
    if [ "$at" != "$PRE_MIGRATION_COMMIT" ]; then
        echo "error: $WORKTREE is at $at, expected $PRE_MIGRATION_COMMIT" >&2
        echo "       Either 'git -C $WORKTREE checkout --detach $PRE_MIGRATION_COMMIT', or remove the" >&2
        echo "       worktree and re-run to have it recreated." >&2
        exit 1
    fi
    echo "==> Using the existing pre-migration worktree at $WORKTREE"
    echo "    $(git -C "$WORKTREE" log --oneline -1)"
fi

# Separate scratch paths, so flipping the path dependency does not force a full rebuild of the other
# configuration every time. The baselines are per-package, not per-scratch-path, so they still pair up.
record() {  # record <baseline-name> <scratch> <target> <filter> <metrics…>
    local name="$1" scratch="$2" target="$3" filter="$4"
    shift 4
    if [ "$scratch" = ".build-main" ]; then
        IMAP_IMPL=main IMAP_MAIN_PATH="$WORKTREE" \
            swift package --disable-sandbox --scratch-path "$scratch" \
            benchmark baseline update "$name" --target "$target" --filter "$filter" "$@"
    else
        swift package --disable-sandbox --scratch-path "$scratch" \
            benchmark baseline update "$name" --target "$target" --filter "$filter" "$@"
    fi
}

for client in "${CLIENTS[@]}"; do
    IFS=: read -r target prefix baseline_prefix encode_set <<< "$client"

    for phase in parse encode; do
        if [ "$phase" = parse ]; then
            filter="${FILTER:-$prefix.parse.*}"
            metrics=("${PARSE_METRICS[@]}")
        else
            filter="${FILTER_ENCODE:-$prefix.encode.*}"
            if [ "$encode_set" = dispatch ]; then
                metrics=("${ENCODE_METRICS_DISPATCH[@]}")
            else
                metrics=("${PARSE_METRICS[@]}")
            fi
        fi
        before="${baseline_prefix}main-$phase"
        after="${baseline_prefix}branch-$phase"

        echo
        echo "==> $target $phase: recording '$before' (pre-migration library)"
        record "$before" .build-main "$target" "$filter" "${metrics[@]}"

        echo
        echo "==> $target $phase: recording '$after' (this working tree)"
        record "$after" .build-branch "$target" "$filter" "${metrics[@]}"

        echo
        echo "==> $target $phase: main -> branch"
        swift package --disable-sandbox --scratch-path .build-branch \
            benchmark baseline compare "$before" "$after" \
            --target "$target" --filter "$filter" "${metrics[@]}"
    done
done
