// OpenCode plugin: precise compound-command block (safe-pipe allowlist).
//
// The opencode.json permission globs (../opencode.permissions.json) catch the
// obvious operators but can't express "a single pipe into a read-only filter".
// This plugin implements that precise rule in `tool.execute.before`, mirroring
// global/hooks/block-compound-bash.py. Keep the two in sync.
//
// Install: drop this file in .opencode/plugin/ (project) or ~/.config/opencode/
// plugin/ (global). OpenCode loads TS plugins automatically.

const READONLY_FILTERS = new Set([
  "grep", "egrep", "fgrep", "rg", "head", "tail", "wc", "jq", "yq",
  "sort", "uniq", "cut", "tr", "column", "less", "cat", "nl", "awk", "sed",
]);

type Findings = {
  chain: boolean; background: boolean; cmdsub: boolean; procsub: boolean;
  redirect: boolean; subshell: boolean; pipes: number[];
};

function scan(cmd: string): Findings {
  const f: Findings = {
    chain: false, background: false, cmdsub: false, procsub: false,
    redirect: false, subshell: false, pipes: [],
  };
  let i = 0;
  const n = cmd.length;
  let inS = false, inD = false;
  while (i < n) {
    const c = cmd[i];
    if (inS) { if (c === "'") inS = false; i++; continue; }
    if (inD) {
      if (c === "\\" && i + 1 < n) { i += 2; continue; }
      if (c === '"') inD = false;
      i++; continue;
    }
    if (c === "\\") { i += 2; continue; }
    if (c === "'") { inS = true; i++; continue; }
    if (c === '"') { inD = true; i++; continue; }
    if (c === "`") { f.cmdsub = true; i++; continue; }
    const two = cmd.slice(i, i + 2);
    if (two === "$(") { f.cmdsub = true; i += 2; continue; }
    if (two === "<(" || two === ">(") { f.procsub = true; i += 2; continue; }
    if (two === "&&" || two === "||") { f.chain = true; i += 2; continue; }
    if (two === ">>" || two === "<<" || two === "&>") { f.redirect = true; i += 2; continue; }
    if (c === ";") { f.chain = true; i++; continue; }
    if (c === "&") { f.background = true; i++; continue; }
    if (c === ">" || c === "<") { f.redirect = true; i++; continue; }
    if (c === "(" || c === ")") { f.subshell = true; i++; continue; }
    if (c === "|") { f.pipes.push(i); i++; continue; }
    i++;
  }
  return f;
}

function leadingCommand(seg: string): string | null {
  const t = seg.trim().split(/\s+/).filter(Boolean);
  let idx = 0;
  while (idx < t.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(t[idx])) idx++;
  if (idx < t.length && t[idx] === "env") {
    idx++;
    while (idx < t.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(t[idx])) idx++;
  }
  if (idx >= t.length) return null;
  return t[idx].split("/").pop() || null;
}

export function evaluate(cmd: string): { allowed: boolean; reason: string } {
  if (!cmd || !cmd.trim()) return { allowed: true, reason: "" };
  const f = scan(cmd);
  if (f.chain) return { allowed: false, reason: "Command chaining (&&, ||, ;) is blocked — run one command per call." };
  if (f.cmdsub) return { allowed: false, reason: "Command substitution ($()/backticks) is blocked." };
  if (f.procsub) return { allowed: false, reason: "Process substitution (<()/>()) is blocked." };
  if (f.redirect) return { allowed: false, reason: "Redirects are blocked." };
  if (f.background) return { allowed: false, reason: "Background execution (&) is blocked." };
  if (f.subshell) return { allowed: false, reason: "Subshell grouping ( ) is blocked." };
  if (f.pipes.length === 0) return { allowed: true, reason: "" };
  if (f.pipes.length > 1) return { allowed: false, reason: "Only a single pipe into a read-only filter is allowed." };
  const right = cmd.slice(f.pipes[0] + 1);
  const lead = leadingCommand(right);
  if (!lead) return { allowed: false, reason: "Could not parse the piped-to command." };
  if (!READONLY_FILTERS.has(lead)) {
    return { allowed: false, reason: `Pipe target '${lead}' is not a read-only filter.` };
  }
  if ((lead === "sed" || lead === "awk") && /(^|\s)-i(\b|\.|=)|--in-place/.test(right)) {
    return { allowed: false, reason: `${lead} with an in-place/write flag is blocked.` };
  }
  return { allowed: true, reason: "" };
}

export const BlockCompoundBash = async ({}: any) => ({
  "tool.execute.before": async (input: any, output: any) => {
    if (input?.tool !== "bash") return;
    const cmd: string = output?.args?.command ?? "";
    const { allowed, reason } = evaluate(cmd);
    if (!allowed) {
      throw new Error(`[block-compound-bash] ${reason}`);
    }
  },
});
