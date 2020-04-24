#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftNIO open source project
##
## Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftNIO project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##


set -eu

last_begin=""
last_lines=()
all_types=()

function functionalise() {
    string="$1"
    uppercase_next=true
    for (( i=0; i<${#string}; i++ )); do
        if [[ "${string:$i:1}" = "-" ]]; then
            uppercase_next=true
            continue
        fi
        if $uppercase_next; then
            echo -n "${string:$i:1}" | tr a-z A-Z
            uppercase_next=false
        else
            echo -n "${string:$i:1}"
        fi
    done
}

function output_last() {
    local line
    if [[ -z "$last_begin" ]]; then
        return
    fi
    echo
    for line in "${last_lines[@]}"; do
        echo "// $line"
    done
    swift_id=$(functionalise "$last_begin")
    all_types+=( "$swift_id" )

    returnType=$swift_id
    returnType=$( echo $swift_id | sed "s/Addr/Address\./g" )
    returnType=$( echo $swift_id | sed "s/Env/Envelope\./g" )
    returnType=$( echo $swift_id | sed "s/Fld/Field\./g" )

    echo "func parse$swift_id(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAO.$returnType {"
    echo "    return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> $swift_id in"
    echo "        fatalError(\"$last_begin is not implemented yet\")"
    echo "    }"
    echo "}"
}

while IFS="" read -r line; do
    if [[ "$line" =~ ^([a-zA-Z0-9-]+)\ += ]]; then
        output_last
        last_begin="${BASH_REMATCH[1]}"
        last_lines=()
    fi

    last_lines+=( "$line" )
done
output_last
