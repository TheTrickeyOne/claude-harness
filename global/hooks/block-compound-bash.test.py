#!/usr/bin/env python3
"""Pinned behavior for block-compound-bash.py.

Run:  python3 global/hooks/block-compound-bash.test.py
Exits nonzero if any case regresses. No third-party deps.
"""

import importlib.util
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
HOOK_PATH = os.path.join(HERE, "block-compound-bash.py")

spec = importlib.util.spec_from_file_location("bcb", HOOK_PATH)
bcb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bcb)

# (command, expected_allowed). Mirrors the approved plan preview plus edges.
CASES = [
    # --- must ALLOW: single commands ---
    ("kubectl get pods -A", True),
    ("talosctl get members", True),
    ("make", True),
    ("ls /x", True),
    ("find . -name '*.log'", True),
    ("git status", True),
    # --- must ALLOW: single pipe into a read-only filter ---
    ("kubectl get pods -A | grep -i error", True),
    ("journalctl -u sshd | tail -50", True),
    ("ls | grep x", True),
    ("cat file | jq '.items'", True),
    ("dmesg | grep -i usb", True),
    ("kubectl get pods | wc -l", True),
    ("cat access.log | awk '{print $1}'", True),
    # --- must ALLOW: operators safely inside quotes ---
    ('echo "a && b"', True),
    ("echo 'pipe | not real'", True),
    ('grep "foo;bar" file', True),
    # --- must BLOCK: chaining ---
    ("kubectl get pods && kubectl logs foo", False),
    ("make && make test", False),
    ("rm -rf build; make", False),
    ("cd /x; ls", False),
    ("false || true", False),
    # --- must BLOCK: substitution ---
    ("echo $(cat secrets)", False),
    ("echo `whoami`", False),
    ("diff <(sort a) <(sort b)", False),
    # --- must BLOCK: redirects / background / subshell ---
    ("grep foo file > out.txt", False),
    ("cat a >> b", False),
    ("kubectl logs pod 2>&1", False),
    ("myprog &", False),
    ("(cd x && make)", False),
    # --- must BLOCK: pipe rule violations ---
    ("cat f | tee g", False),
    ("ls | grep x | wc -l", False),
    ("kubectl get pods | xargs kubectl delete", False),
    ("find . | xargs rm", False),
    ("cat data | sed -i 's/a/b/' file", False),
    ("cat log | python3 evil.py", False),
]


def run_unit():
    failures = []
    for cmd, expected in CASES:
        allowed, reason = bcb.evaluate(cmd)
        if allowed != expected:
            failures.append((cmd, expected, allowed, reason))
    return failures


def run_io_contract():
    """Verify the stdin/stdout JSON contract end-to-end via subprocess."""
    failures = []

    def invoke(payload):
        proc = subprocess.run(
            [sys.executable, HOOK_PATH],
            input=json.dumps(payload),
            capture_output=True, text=True,
        )
        return proc

    # deny case emits a decision
    p = invoke({"tool_name": "Bash", "tool_input": {"command": "a && b"}})
    if p.returncode != 0:
        failures.append(("deny exit code", 0, p.returncode))
    try:
        out = json.loads(p.stdout)
        dec = out["hookSpecificOutput"]["permissionDecision"]
        if dec != "deny":
            failures.append(("deny decision", "deny", dec))
    except Exception as exc:
        failures.append(("deny json parse", "ok", "{}: {!r}".format(exc, p.stdout)))

    # allow case is silent
    p = invoke({"tool_name": "Bash", "tool_input": {"command": "ls | grep x"}})
    if p.stdout.strip():
        failures.append(("allow silence", "", p.stdout.strip()))

    # non-Bash tool is ignored
    p = invoke({"tool_name": "Read", "tool_input": {"file_path": "/x"}})
    if p.stdout.strip():
        failures.append(("non-bash silence", "", p.stdout.strip()))

    # malformed input fails open (no output, exit 0)
    p = subprocess.run(
        [sys.executable, HOOK_PATH], input="not json",
        capture_output=True, text=True,
    )
    if p.returncode != 0 or p.stdout.strip():
        failures.append(("failopen", "exit0/silent", "{}/{!r}".format(p.returncode, p.stdout)))

    return failures


def main():
    unit = run_unit()
    io = run_io_contract()
    for cmd, exp, got, reason in unit:
        verb = "ALLOW" if exp else "BLOCK"
        print("FAIL [{}] {!r} -> got allowed={} ({})".format(verb, cmd, got, reason))
    for f in io:
        print("FAIL [io] {}".format(f))
    total = len(unit) + len(io)
    if total:
        print("\n{} failing case(s).".format(total))
        return 1
    print("all {} unit cases + IO contract passed".format(len(CASES)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
