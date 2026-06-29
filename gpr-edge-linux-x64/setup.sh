#!/usr/bin/env bash
# 하위 호환 — install.sh 를 호출합니다.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install.sh" "$@"
