#!/usr/bin/env python3
"""PreToolUse hook: block compound Bash commands (safe-pipe allowlist).

Enforces one command per Bash call so every action stands alone in the
permission log. Blocks command chaining (&&, ||, ;), command/process
substitution ($()/backticks/<()/>()), redirects, subshell grouping, and
background (&). Permits exactly ONE pipe, and only when the piped-to command
is a read-only filter from an allowlist (so `kubectl get pods | grep err`
works but `... | xargs kubectl delete` does not).

I/O contract (Claude Code PreToolUse hook):
  stdin  : JSON  {"tool_name": "Bash", "tool_input": {"command": "..."}, ...}
  stdout : on DENY, a JSON permission decision; on ALLOW, nothing.
  exit   : always 0 (a nonzero exit would surface as a hook error).

Fail-open: any unexpected internal error logs a warning and allows the
command, so a hook bug can never brick a session. Only the explicit,
understood cases deny.
"""

import json
import os
import re
import shlex
import sys

# Read-only filters a single pipe may target. Left side of the pipe is the
# real command being inspected and is unrestricted; the right side must be one
# of these so the pipe can only ever view/reduce output, never mutate state.
READONLY_FILTERS = {
    "grep", "egrep", "fgrep", "rg", "head", "tail", "wc", "jq", "yq",
    "sort", "uniq", "cut", "tr", "column", "less", "cat", "nl", "awk", "sed",
}

LOG_PATH = os.environ.get(
    "HARNESS_HOOK_LOG", os.path.expanduser("~/.claude/harness-hook.log")
)

ASSIGN_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")


def _log(msg):
    try:
        with open(LOG_PATH, "a") as fh:
            fh.write("[block-compound-bash] " + msg + "\n")
    except Exception:
        pass


def scan_top_level(cmd):
    """Quote- and escape-aware scan for top-level shell operators.

    Operators inside single/double quotes (or backslash-escaped) do not count,
    so `echo "a && b"` is a single command. Returns a findings dict.
    """
    findings = {
        "chain": [],       # && || ;
        "background": False,
        "cmdsub": False,    # $(...) or `...`
        "procsub": False,   # <(...) or >(...)
        "redirect": [],     # > >> < << &> 2> ...
        "subshell": False,  # ( ) grouping
        "pipes": [],        # indices of top-level single |
    }
    i, n = 0, len(cmd)
    in_single = in_double = False
    while i < n:
        c = cmd[i]
        if in_single:
            if c == "'":
                in_single = False
            i += 1
            continue
        if in_double:
            if c == "\\" and i + 1 < n:
                i += 2
                continue
            if c == '"':
                in_double = False
            i += 1
            continue
        # unquoted context
        if c == "\\":
            i += 2
            continue
        if c == "'":
            in_single = True
            i += 1
            continue
        if c == '"':
            in_double = True
            i += 1
            continue
        if c == "`":
            findings["cmdsub"] = True
            i += 1
            continue
        two = cmd[i:i + 2]
        if two == "$(":
            findings["cmdsub"] = True
            i += 2
            continue
        if two in ("<(", ">("):
            findings["procsub"] = True
            i += 2
            continue
        if two in ("&&", "||"):
            findings["chain"].append(two)
            i += 2
            continue
        if two in (">>", "<<", "&>"):
            findings["redirect"].append(two)
            i += 2
            continue
        if c == ";":
            findings["chain"].append(";")
            i += 1
            continue
        if c == "&":
            findings["background"] = True
            i += 1
            continue
        if c in (">", "<"):
            findings["redirect"].append(c)
            i += 1
            continue
        if c in ("(", ")"):
            findings["subshell"] = True
            i += 1
            continue
        if c == "|":
            findings["pipes"].append(i)
            i += 1
            continue
        i += 1
    findings["unbalanced_quotes"] = in_single or in_double
    return findings


def _leading_command(segment):
    """First real command word of a segment, skipping VAR=val and env prefixes."""
    seg = segment.strip()
    if not seg:
        return None
    try:
        parts = shlex.split(seg, posix=True)
    except ValueError:
        parts = seg.split()
    idx = 0
    while idx < len(parts) and ASSIGN_RE.match(parts[idx]):
        idx += 1
    if idx < len(parts) and parts[idx] == "env":
        idx += 1
        while idx < len(parts) and ASSIGN_RE.match(parts[idx]):
            idx += 1
    if idx >= len(parts):
        return None
    return parts[idx]


def _sed_awk_readonly(segment):
    """False if a sed/awk segment carries an in-place/write flag."""
    try:
        parts = shlex.split(segment, posix=True)
    except ValueError:
        parts = segment.split()
    for p in parts:
        if p == "-i" or p == "--in-place" or p.startswith("--in-place"):
            return False
        if p.startswith("-i") and len(p) > 2 and p[2] in ".='\"":
            return False  # sed -i.bak style
        if p == "inplace":  # gawk: -i inplace
            return False
    return True


def evaluate(cmd):
    """Return (allowed: bool, reason: str) for a raw Bash command string."""
    if cmd is None or not cmd.strip():
        return True, ""
    f = scan_top_level(cmd)
    if f["chain"]:
        ops = ", ".join(sorted(set(f["chain"])))
        return False, (
            "Command chaining ({}) is blocked. Run one command per call so each "
            "stands alone in the permission log.".format(ops)
        )
    if f["cmdsub"]:
        return False, "Command substitution ($()/backticks) is blocked."
    if f["procsub"]:
        return False, "Process substitution (<()/>()) is blocked."
    if f["redirect"]:
        ops = ", ".join(sorted(set(f["redirect"])))
        return False, "Redirects ({}) are blocked.".format(ops)
    if f["background"]:
        return False, "Background execution (&) is blocked."
    if f["subshell"]:
        return False, "Subshell grouping ( ) is blocked."
    pipes = f["pipes"]
    if not pipes:
        return True, ""
    if len(pipes) > 1:
        return False, (
            "Only a single pipe into a read-only filter is allowed (found {} "
            "pipes).".format(len(pipes))
        )
    right = cmd[pipes[0] + 1:]
    lead = _leading_command(right)
    if lead is None:
        return False, "Could not parse the piped-to command."
    base = os.path.basename(lead)
    if base not in READONLY_FILTERS:
        return False, (
            "Pipe target '{}' is not a read-only filter. Allowed pipe targets: "
            "{}.".format(base, ", ".join(sorted(READONLY_FILTERS)))
        )
    if base in ("sed", "awk") and not _sed_awk_readonly(right):
        return False, "{} with an in-place/write flag is blocked.".format(base)
    return True, ""


def main():
    if any(a in ("-h", "--help") for a in sys.argv[1:]):
        print(
            "block-compound-bash.py — PreToolUse hook that blocks compound Bash.\n\n"
            "Usage: registered as a Claude Code PreToolUse hook on the Bash tool.\n"
            "  Reads the tool-call JSON on stdin; on a disallowed command prints a\n"
            "  deny decision as JSON on stdout, otherwise stays silent. Always exits 0.\n"
            "  Run the test suite: python3 block-compound-bash.test.py\n"
        )
        print(__doc__ or "")
        return 0
    try:
        raw = sys.stdin.read()
        data = json.loads(raw) if raw.strip() else {}
    except Exception as exc:  # malformed input → allow, don't brick the session
        _log("could not parse hook input, allowing: {}".format(exc))
        return 0

    if data.get("tool_name") != "Bash":
        return 0

    command = (data.get("tool_input") or {}).get("command")
    try:
        allowed, reason = evaluate(command)
    except Exception as exc:  # parser bug → fail open
        _log("evaluate() raised, allowing: {!r}: {}".format(command, exc))
        return 0

    if allowed:
        return 0

    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
