# QLab plugin standards

The conventions every plugin follows, so READMEs, tests, docs and releases are
consistent across the collection. New plugins follow these from the start;
existing ones are brought in line when touched. Companion to
[`CREATE_PLUGIN_PROMPT.md`](CREATE_PLUGIN_PROMPT.md) (how to build the plugin)
and enforced in part by [`../tools/check-versions.sh`](../tools/check-versions.sh).

## README — a concise landing page

The README is a landing page, not a manual: a hook, how to run it, what's inside,
and links to the deeper files that already live in the repo. Depth goes in
`guide.md` and the walkthrough PDFs; the README points at them. Target ~40–75
lines. Do **not** include boilerplate that repeats across every plugin ("How It
Works", "Resetting", a long "Usage" dump) — that mechanism is QLab's, linked once.

Structure, in order:

1. **Title** — `# <name> — <Short Title>`
2. **Badges** — exactly three: QLab Plugin, License, Walkthrough
3. **Hook** — 2–3 sentences: what the lab is and its one idea
4. **Quick start** — a single fenced block: `install` / `run` / `shell` / `test` / `stop`
5. **What's inside** — a compact table of exercises/chapters (the real value)
6. **Access** (single VM) or **Network** (multi-VM) — credentials + ports/topology, compact
7. **Learn more** — links to `guide.md`, the walkthrough PDFs (EN + IT), and QLab

Skeleton:

```markdown
# foo-lab — Foo Server Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Walkthrough](https://img.shields.io/badge/walkthrough-EN%20%26%20IT-informational)](docs/walkthrough-en.pdf)

A single-VM [QLab](https://github.com/manzolo/qlab) lab that <one idea, 2–3 sentences>.

## Quick start

```bash
qlab install foo-lab
qlab run foo-lab       # boots N VM(s) (~Xs)
qlab shell foo-lab     # log in: labuser / labpass
qlab test foo-lab      # run the automated checks
qlab stop foo-lab
```

## What's inside

| # | Exercise | What you do |
|---|----------|-------------|
| 1 | ... | ... |

## Access                          <!-- single VM -->

| | |
|---|---|
| **SSH** | `labuser` / `labpass` |
| **Ports** | SSH + <service>, dynamically allocated — see `qlab ports` |

## Network                         <!-- multi-VM: use this instead of Access -->

Private LAN `192.168.100.0/24`, isolated between the VMs.

| VM | Address | Role |
|----|---------|------|
| `foo-lab-server` | `192.168.100.1` | ... |

SSH: `labuser` / `labpass`, dynamically forwarded — see `qlab ports`.

## Learn more

- 📖 **[Step-by-step guide](guide.md)** — every exercise with full commands
- 📄 **Illustrated walkthrough** — a real run, captured live: **[English](docs/walkthrough-en.pdf)** · **[Italiano](docs/walkthrough-it.pdf)**
- 🧩 **[QLab](https://github.com/manzolo/qlab)** — the plugin runner: how install, overlays and cloud-init work
```

Rules:

- Every internal link must resolve — check `guide.md` and every `docs/*.pdf` exist.
- Chapter-based labs (the "…IS the test" family) keep their one-idea framing and a
  "Chapters" table instead of "Exercises"; everything else above still applies.

## The guide

- One file, **lowercase `guide.md`**, at the repo root. Never a second `GUIDE.md`
  (a case-only duplicate is invisible on case-insensitive filesystems and drifts).
- It holds the full walkthrough of every exercise — commands and expected output.
- The README's "Learn more" links to it.

## Illustrated walkthrough (docs/)

- Bilingual, built by the shared generator: `tools/walkthrough/build.py <plugin>`
  (English) and `… -it` (Italian); `--live` re-captures evidence from a running lab.
- Source: `docs/walkthrough.en.md` / `.it.md` + `docs/walkthrough.yaml` (the evidence
  manifest). Captured output lives under `docs/evidence/` and is committed, so the
  PDFs rebuild with no lab up. Output: `docs/walkthrough-{en,it}.pdf`.
- A plugin with distinct tracks may ship per-topic PDFs instead
  (e.g. `docs/debian-en.pdf`, `docs/windows-en.pdf`) — link them all in "Learn more".
- **Prose must not quote volatile values** (an address, a PID, an xid) that change
  under `--live`. Describe what a block shows; do not restate values out of it.

## Tests (tests/run_all.sh)

- `tests/run_all.sh` assumes the VM(s) are already running; `qlab test <name>` runs
  it. Exit 0 on all-pass, non-zero on failure. One `test_NN_*.sh` per exercise.
- **`assert_contains` / `assert_not_contains` use a here-string, never `echo "$o" | grep -q`.**
  Under `set -o pipefail`, `grep -q` closes the pipe early and the `echo` dies with
  SIGPIPE, so the assertion returns 141 on large inputs. Use `grep -qE "$pat" <<<"$o"`.
- **No shell globs in commands sent over SSH.** `labuser`'s shell is zsh; an unmatched
  glob raises `nomatch` instead of passing the literal (as bash would). Use
  `find -name '*.ext'` or an explicit path.
- Tests are **idempotent and self-restoring**: back up what you change and put it back,
  so the suite can run repeatedly (especially for PAM/config/network/firewall labs).
- Heavy tests (a real power-cycle, long installs) say so in the README quick-start.
- See also the cloud-init pitfalls in `CREATE_PLUGIN_PROMPT.md` (write_files owner,
  `sudo -Hu`, `${VAR}` expansion in runcmd).

## Versioning & publishing

The invariant `tools/check-versions.sh` enforces: for every plugin,
`plugin.conf.version` == the registry entry == a tag `v<version>` that is **at HEAD
and pushed**. `qlab install` checks out that tag, so anything not tagged never
reaches users.

- **Bump the version for any shipped change** — code, tests, docs or README. Patch
  bump (`x.y` → `x.(y+1)`) for docs/fixes.
- Publish with **`tools/publish-docs.sh <name> <version>`**: it bumps `plugin.conf`
  and the registry, commits, tags `v<version>`, and pushes both. It does **not**
  rewrite the README (the "Learn more" section already links the walkthrough); it
  only warns if no `docs/*.pdf` link is present.
- After bumping, keep the catalogue in sync (next section).
- Commit trailers: `Co-Authored-By:` and `Claude-Session:` as configured for the session.

## The catalogue (qlab/README.md)

The "Available Plugins" table has columns **Plugin | Ver | VMs | Description**.

- `Ver` mirrors the registry — resync it whenever a version changes.
- `VMs` is the real VM count `run.sh` starts (count `start_vm` / `start_vm_or_fail`).
- Add a row under the right category when registering a new plugin.
