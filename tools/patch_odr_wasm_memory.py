#!/usr/bin/env python3
"""Deterministically cap the pinned OpenDocument.core WASM linear memory.

The npm v7.6.1 binary declares a 4 GiB maximum (65,536 pages). DeskSuite's
read-only preview uses a 256 MiB maximum (4,096 pages). This changes only the
WebAssembly memory section; it does not compile a new engine. Corresponding
source and licensing: docs/engineering/OFFICE_SUPPORT.md.

Usage: python3 tools/patch_odr_wasm_memory.py upstream.wasm output.wasm
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

UPSTREAM_SHA256 = "ec17dc0b81bb8bb8f3224bfe364fbc0879f15818f938119bc06121b15c206c9d"
INITIAL_PAGES = 512  # 32 MiB
UPSTREAM_MAX_PAGES = 65536
DESKSUITE_MAX_PAGES = 4096  # 256 MiB; JS/DOM and WebView memory are additional.


def read_uleb(data: bytes, offset: int) -> tuple[int, int]:
    value = 0
    for shift in range(0, 35, 7):
        if offset >= len(data):
            raise ValueError("Truncated WebAssembly integer")
        byte = data[offset]
        offset += 1
        value |= (byte & 0x7f) << shift
        if not byte & 0x80:
            return value, offset
    raise ValueError("Oversized WebAssembly integer")


def uleb(value: int) -> bytes:
    result = bytearray()
    while True:
        byte = value & 0x7f
        value >>= 7
        result.append(byte | (0x80 if value else 0))
        if not value:
            return bytes(result)


def patch(source: bytes) -> bytes:
    if hashlib.sha256(source).hexdigest() != UPSTREAM_SHA256:
        raise ValueError("Not the pinned @opendocument/odr-core 7.6.1 WASM")
    if source[:8] != b"\0asm\x01\0\0\0":
        raise ValueError("Invalid WebAssembly header")
    output = bytearray(source[:8])
    at = 8
    patched = False
    while at < len(source):
        section = source[at]
        size, body_at = read_uleb(source, at + 1)
        end = body_at + size
        if end > len(source):
            raise ValueError("Truncated WebAssembly section")
        body = source[body_at:end]
        if section == 5:
            if patched:
                raise ValueError("More than one memory section")
            count, pos = read_uleb(body, 0)
            flags, pos = read_uleb(body, pos)
            initial, pos = read_uleb(body, pos)
            maximum, pos = read_uleb(body, pos)
            if (count, flags, initial, maximum, pos) != (
                1, 1, INITIAL_PAGES, UPSTREAM_MAX_PAGES, len(body)
            ):
                raise ValueError("Unexpected upstream memory declaration")
            body = b"\x01\x01" + uleb(initial) + uleb(DESKSUITE_MAX_PAGES)
            patched = True
        output.append(section)
        output.extend(uleb(len(body)))
        output.extend(body)
        at = end
    if not patched:
        raise ValueError("No memory section")
    return bytes(output)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    source, target = map(Path, sys.argv[1:])
    patched = patch(source.read_bytes())
    target.write_bytes(patched)
    print(f"Wrote {target}: {len(patched)} bytes; SHA-256 {hashlib.sha256(patched).hexdigest()}")


if __name__ == "__main__":
    main()
