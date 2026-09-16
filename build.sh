#!/bin/sh
set -eu
cd "$(dirname "$0")/bin"
../rasm -s ../src/termM4.s
../rasm ../src/charset.s
