#!/bin/sh

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
ROOT="$SCRIPT_DIR/.."
if ! test -f "$ROOT/Sources/Backend/keys/DJLKeys.h" ; then
    cp "$ROOT/Sources/Backend/keys/DJLKeys.h.template" "$ROOT/Sources/Backend/keys/DJLKeys.h"
fi

