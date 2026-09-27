#!/usr/bin/env python3
"""Read-only, redacted secret scan of all workspace files and Git objects.

This is a heuristic publication check, not proof that arbitrary secrets are absent.
No matching values, Git identities, or file contents are printed.
"""
import argparse
import collections
import os
from pathlib import Path
import re
import subprocess
import sys

PATTERNS = {
    "provider-key": rb"\b(?:sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{16,}|AIza[0-9A-Za-z_-]{30,}|AQ\.Ab8RN[0-9A-Za-z_.-]{15,})",
    "google-oauth-secret": rb"(?:GOCSPX-[0-9A-Za-z_-]{15,}|\b1//[0-9A-Za-z_-]{25,})",
    "google-client-id": rb"\b[0-9]{6,}-[0-9A-Za-z_-]+\.apps\.googleusercontent\.com",
    "private-key": rb"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----",
    "other-token": rb"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[A-Z0-9]{16}|xox[baprs]-[0-9A-Za-z-]{20,})",
    "jwt": rb"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}",
    "credential-literal": rb"(?i)\b(?:api[_-]?key|client[_-]?secret|refresh[_-]?token|access[_-]?token|password|passwd|secret|session[_-]?token|password[_-]?hash|salt)\b\s*[:=]\s*[\"'][^\"'\r\n]{4,512}[\"']",
    "bearer-literal": rb"(?i)\bBearer\s+[A-Za-z0-9_.-]{16,}",
    "email": rb"\b[A-Za-z0-9._%+-]{1,64}@[A-Za-z0-9.-]{1,253}\.[A-Za-z]{2,24}\b",
    "personal-path": rb"(?:/Users/[^/\s\"']+|/home/[^/\s\"']+)",
    "internal-url": rb"(?i)\b(?:https?|wss?)://(?:localhost|127\.0\.0\.1|10\.[0-9.]+|192\.168\.[0-9.]+|[a-z0-9.-]+\.(?:internal|local|corp))(?=[:/\s\"']|$)",
}
COMPILED = {name: re.compile(pattern) for name, pattern in PATTERNS.items()}
GENERATED = {"node_modules", ".next", "out", ".build", "build", ".spm-test", ".tmp", "ModuleCache", "ModuleCache.noindex", "1MTWNDVONU6Q"}


def scan(data):
    for name, pattern in COMPILED.items():
        for match in pattern.finditer(data):
            yield name, data.count(b"\n", 0, match.start()) + 1


def git_objects(repo):
    result = subprocess.run(["git", "-C", str(repo), "cat-file", "--batch-all-objects", "--batch-check=%(objectname) %(objecttype)"], capture_output=True, check=True)
    for line in result.stdout.splitlines():
        oid, kind = line.split()
        if kind in (b"blob", b"commit", b"tag"):
            data = subprocess.run(["git", "-C", str(repo), "cat-file", kind.decode(), oid.decode()], capture_output=True, check=True).stdout
            yield oid.decode(), kind.decode(), data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--git-detail", action="store_true", help="Print every redacted Git candidate, including compiler path metadata.")
    parser.add_argument("--include-generated", action="store_true", help="Also scan dependency and build bytes; report aggregate candidate counts.")
    args = parser.parse_args()
    root = args.root.resolve()
    counts = collections.Counter()
    generated_hits = collections.Counter()
    git_hits = collections.Counter()
    repos = []
    errors = []
    for directory, dirs, files in os.walk(root, followlinks=False):
        if ".git" in dirs:
            repos.append(Path(directory))
            dirs.remove(".git")
        # Scan local Git configuration and reflogs as text, as well as object contents.
        if Path(directory) in repos:
            for metadata in ["config", "COMMIT_EDITMSG", "logs/HEAD"]:
                path = Path(directory) / ".git" / metadata
                if path.is_file():
                    try:
                        for category, line in sorted(set(scan(path.read_bytes()))):
                            print(f"REVIEW git-metadata-{category}: {path.relative_to(root)}:{line}")
                    except OSError:
                        errors.append(str(path.relative_to(root)))
        if not args.include_generated:
            dirs[:] = [d for d in dirs if d not in GENERATED]
        for filename in files:
            path = Path(directory) / filename
            relative = path.relative_to(root)
            if path.is_symlink():
                print(f"symlink (review target): {relative}")
                continue
            generated = bool(set(relative.parts) & GENERATED) or path.suffix in {".swiftmodule", ".pcm", ".o"} or filename in {"main", "modules.timestamp", ".DS_Store"}
            if generated and not args.include_generated:
                continue
            try:
                data = path.read_bytes()
                counts["generated-files" if generated else "source-files"] += 1
                hits = sorted(set(scan(data)))
                for category, line in hits:
                    if generated:
                        generated_hits[category] += 1
                    else:
                        print(f"REVIEW {category}: {relative}:{line}")
                        counts["source-candidates"] += 1
            except OSError:
                errors.append(str(relative))
    for repo in repos:
        try:
            for oid, kind, data in git_objects(repo):
                counts["git-objects"] += 1
                for category, line in sorted(set(scan(data))):
                    git_hits[category] += 1
                    if args.git_detail or category not in {"personal-path", "email", "internal-url"}:
                        print(f"REVIEW git-{category}: {repo.relative_to(root)}/.git {kind} {oid[:12]}:{line}")
                    counts["git-candidates"] += 1
        except subprocess.CalledProcessError:
            errors.append(f"{repo.relative_to(root)}/.git objects")
    print("Counts:", dict(sorted(counts.items())))
    print("Git candidates:", dict(sorted(git_hits.items())))
    print("Generated candidates (excluded from publication, review locally):", dict(sorted(generated_hits.items())))
    if errors:
        for path in errors:
            print(f"ERROR unreadable: {path}")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
