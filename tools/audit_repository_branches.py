#!/usr/bin/env python3
"""Inventory first-party source blobs at all fetched origin branch tips.

Run `git fetch origin` first. This is a lexical inventory, not Dart analysis,
security certification, manual review of every function, or runtime testing.
Potential secrets are reported by path/blob only, never printed. Vendored binary
assets are excluded; licence and native binary review are separate release gates.
"""
import collections
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def git(*args, text=True):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=text)


def candidate(path):
    roots = ('lib/', 'test/', 'tools/', 'android/app/src/main/', '.github/', 'ci/', 'windows/')
    if not path.startswith(roots):
        return False
    return path.endswith(('.dart', '.kt', '.java', '.py', '.js', '.mjs', '.sh', '.yml', '.yaml', '.xml', '.gradle', '.kts', '.cc', '.cpp', '.h'))


def read_blobs(oids):
    proc = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=ROOT,
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    assert proc.stdin is not None and proc.stdout is not None
    # Interleave requests and reads to avoid filling a pipe on large source files.
    for oid in oids:
        proc.stdin.write((oid + '\n').encode())
        proc.stdin.flush()
        header = proc.stdout.readline().decode().strip().split()
        if len(header) != 3 or header[1] != 'blob':
            raise RuntimeError(f'Unexpected git object response for {oid}')
        size = int(header[2])
        data = proc.stdout.read(size)
        if len(data) != size or proc.stdout.read(1) != b'\n':
            raise RuntimeError(f'Truncated git object {oid}')
        yield oid, data
    proc.stdin.close()
    if proc.wait() != 0:
        raise RuntimeError('git cat-file failed')


def main():
    refs = git('for-each-ref', '--format=%(refname) %(symref)',
               'refs/remotes/origin/').splitlines()
    refs = [line.split()[0] for line in refs if len(line.split()) == 1]
    if not refs:
        raise SystemExit('No origin tracking refs found. Run git fetch origin first.')
    blobs = collections.defaultdict(set)
    branch_files = {}
    for ref in refs:
        entries = git('ls-tree', '-r', '-z', '--full-tree', ref, text=False).split(b'\0')
        paths = []
        for entry in filter(None, entries):
            meta, rawpath = entry.split(b'\t', 1)
            mode, kind, oid = meta.decode().split()
            path = rawpath.decode('utf-8', errors='replace')
            if kind == 'blob' and candidate(path):
                blobs[oid].add(path)
                paths.append(path)
        branch_files[ref] = len(paths)

    secret_patterns = [
        re.compile(rb'gh[pousr]_[A-Za-z0-9_]{20,}'),
        re.compile(rb'github_pat_[A-Za-z0-9_]{20,}'),
        re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
        re.compile(rb'AKIA[0-9A-Z]{16}'),
    ]
    marker = re.compile(rb'\b(?:TODO|FIXME|HACK)\b')
    network = re.compile(rb'\b(?:HttpClient|addJavascriptInterface|WebView|WebSocket|Process\.run|Process\.start)\b')
    decl = re.compile(rb'(?m)^\s*(?:[A-Za-z_$][\w$<>,?.\[\] ]*\s+)?([A-Za-z_$][\w$]*)\s*\([^;{}\n]*(?:\n[^;{}]*){0,3}\)\s*(?:async\s*\*?|sync\s*\*?)?\s*(?:=>|\{)')
    control = {b'if', b'for', b'while', b'switch', b'catch', b'assert'}
    secret_hits, marker_paths, boundary_paths = [], set(), set()
    total_bytes = lines = declarations = 0
    ext_counts = collections.Counter()
    for oid, data in read_blobs(sorted(blobs)):
        total_bytes += len(data)
        lines += data.count(b'\n')
        paths = blobs[oid]
        for path in paths:
            ext_counts[Path(path).suffix] += 1
        if any(p.search(data) for p in secret_patterns):
            secret_hits.append((oid, sorted(paths)))
        if marker.search(data):
            marker_paths.update(paths)
        if network.search(data):
            boundary_paths.update(paths)
        if any(path.endswith('.dart') for path in paths):
            declarations += sum(1 for m in decl.finditer(data) if m.group(1) not in control)
    print(f'Fetched origin branch tips: {len(refs)}')
    for ref in refs:
        short = ref.removeprefix('refs/remotes/')
        oid = git('rev-parse', '--short=12', ref).strip()
        counts = git('rev-list', '--left-right', '--count', f'refs/remotes/origin/main...{ref}').strip().replace('\t', '/')
        print(f'{short}\t{oid}\tmain-only/branch-only={counts}\tcode-paths={branch_files[ref]}')
    print(f'Unique first-party code blobs: {len(blobs)}; {total_bytes:,} bytes; {lines:,} newline-terminated lines')
    print(f'Approximate Dart callable-like declarations across unique blobs: {declarations:,} (lexical estimate only)')
    print(f'Paths containing TODO/FIXME/HACK markers: {len(marker_paths)}')
    print(f'Paths containing network/process/WebView boundary indicators: {len(boundary_paths)}')
    print(f'Potential credential-pattern matches: {len(secret_hits)}')
    for oid, paths in secret_hits:
        print(f'REVIEW {oid[:12]}: {", ".join(paths)}')
    if secret_hits:
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
