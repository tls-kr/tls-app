#!/usr/bin/env bash
set -euo pipefail

exist_home="${EXIST_HOME:-/data/tls-exist}"
target="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$target/build/classes"
javac -proc:none --release 8 -cp "$exist_home/lib/*" -d "$target/build/classes" \
  "$target/src/org/hxwd/tls/OrcidFilter.java"
jar cf "$target/build/tls-orcid-filter.jar" -C "$target/build/classes" .
