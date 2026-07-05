---
name: secrets-hygiene
description: >-
  Pre-commit credential scanning and encrypted-secrets management for GitOps
  repos. Use before committing anything, when reviewing a diff for leaked
  secrets, when adding secrets to a repo, or when working with sops/age or
  sealed-secrets in ArgoCD/Flux manifests. Triggers on "scan for secrets",
  "did I leak a key", "check for credentials", "is this safe to commit",
  ".env in git", "encrypt this secret", "sops", "age", "sealed secret",
  "kubeconfig in repo", "rotate a key". Blocks plaintext credentials from
  reaching a commit and knows encrypted-at-rest from an actual leak.
---

# Secrets hygiene

Runbook for keeping credentials out of git and managing the ones that
legitimately live there (encrypted). Assume every repo may be pushed to a
remote and cloned widely — treat "committed" as "published."

## Golden rules

- **Scan before every commit.** Before staging or committing, read the full
  working/staged diff and scan it for credentials. Do this even when the user
  says "just commit it" — flag findings and stop.
- **Read before write.** `git diff` and `git diff --staged` first; never commit
  a diff you haven't inspected for secrets.
- **A found secret that is already committed is compromised — rotate, don't just
  delete.** Deleting the line or `git rm` does not unpublish it; the value lives
  in history and possibly in every clone/fork/CI cache. Name the exact
  credential and tell the user to rotate it at the source (revoke the token,
  regenerate the key, change the password), then remove it from the repo.
- **Confirm destructive history rewrites by naming the target.** History
  surgery (`git filter-repo`, BFG) rewrites every downstream clone. Only after
  the secret is rotated, and only with explicit confirmation naming the file and
  ref range. Rewriting history is secondary to rotation, never a substitute.
- **One command per call.** No `&&`, `||`, `;`, `$(...)`, backticks, or
  redirects. A single pipe into a read-only filter (`grep`, `head`, `wc`) only.

## What to scan for

Read the diff and look for these classes:

- **Cloud/API keys**: `AKIA[0-9A-Z]{16}` (AWS), `AIza[0-9A-Za-z_\-]{35}`
  (Google), `ghp_`/`github_pat_` (GitHub), `xox[baprs]-` (Slack), `sk-` /
  `sk-ant-` (OpenAI / Anthropic), `glpat-` (GitLab).
- **Private keys**: `-----BEGIN (RSA|EC|OPENSSH|PGP) PRIVATE KEY-----`.
- **Kubeconfigs**: files/blobs with `client-certificate-data:`,
  `client-key-data:`, or `token:` under `users:`.
- **`.env` values**: `PASSWORD=`, `SECRET=`, `TOKEN=`, `API_KEY=`,
  `DATABASE_URL=postgres://user:pass@...` with a non-placeholder RHS.
- **Connection strings** with embedded credentials (`mongodb+srv://`,
  `amqp://`, `redis://:pass@`).
- **JWTs**: `eyJ...` triplets that decode to real claims.
- **High-entropy blobs** assigned to suspicious names.

A fast manual pass (read-only):

```
git diff --staged | grep -nE 'BEGIN.*PRIVATE KEY|AKIA[0-9A-Z]{16}|xox[baprs]-|ghp_|sk-ant-|client-key-data|PASSWORD=|SECRET='
```

## Tooling (describe, don't require)

If installed, prefer a real scanner — but the workflow must not depend on it:

- **gitleaks** — `gitleaks protect --staged` scans staged changes;
  `gitleaks detect` scans full history. Config in `.gitleaks.toml`.
- **trufflehog** — `trufflehog git file://. --only-verified` actively verifies
  found credentials against their providers (high signal, low false positive).

If neither is present, fall back to the manual grep pass above and note that a
scanner should be wired into pre-commit / CI.

## .gitignore hygiene

Ensure these are ignored before they can be staged. Check `.gitignore` (and
`git check-ignore -v <file>` to confirm a path is actually covered):

```gitignore
.env
.env.*
!.env.example
*.key
*.pem
*.p12
*.pfx
kubeconfig
*.kubeconfig
id_rsa
id_ed25519
*.tfvars
*.tfstate
```

Commit a `.env.example` with **keys only, empty/placeholder values** so
collaborators know the shape without the secrets.

## Encrypted secrets in git (GitOps)

For ArgoCD/Flux repos where manifests live in git, secrets are stored
**encrypted at rest** and decrypted in-cluster. Two dominant patterns:

### sops + age

Values are encrypted; structure/keys stay readable. Encrypt in place:

```
sops --encrypt --age <age-recipient-pubkey> --in-place secret.yaml
```

An encrypted sops file is safe to commit and looks like this — note the
`sops:` metadata block and that each value is an `ENC[AES256_GCM,data:...]`
envelope, not raw text:

```yaml
apiVersion: v1
kind: Secret
metadata:
    name: db-creds
data:
    password: ENC[AES256_GCM,data:8xK...,iv:...,tag:...,type:str]
sops:
    age:
        - recipient: age1ql3z...
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
    lastmodified: "2026-07-05T..."
    mac: ENC[AES256_GCM,...]
```

### sealed-secrets (Bitnami)

`kubeseal` encrypts a `Secret` into a `SealedSecret` CR that only the
in-cluster controller can decrypt:

```
kubeseal --format yaml --cert pub-cert.pem
```

The committed `SealedSecret` has `spec.encryptedData.<key>:` set to a long
base64 ciphertext — safe to commit; only the controller's private key decrypts.

## Encrypted-at-rest vs. an actual leak

Before you cry wolf on a `Secret`-shaped file, check which it is:

- **Encrypted (safe):** `kind: SealedSecret`, or a `sops:` metadata block with
  `mac:`/`age:`/`pgp:`, or values wrapped as `ENC[AES256_GCM,...]`. These are
  ciphertext — committing them is the intended design.
- **Leak (act now):** `kind: Secret` with `stringData:` in cleartext, or
  `data:` whose base64 decodes to a real credential, or a raw `.env`/`.pem`/
  kubeconfig. Base64 is **encoding, not encryption** — `data:` in a plain
  `Secret` is a leak.

When unsure, decode one value read-only (`echo <b64> | base64 -d`) and judge. If
it's a real secret in a non-encrypted resource: rotate first, then remediate.
