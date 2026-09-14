# Walkthrough builder

Turns a plugin's walkthrough document into a printable PDF, with the lab's own
output pasted in from a real run.

```
tools/walkthrough/build.py <plugin-dir> [doc] [-it] [--live] [--out FILE]
```

- `<plugin-dir>` — a plugin checkout, or `.qlab/plugins/<name>`
- `doc` — document name, default `walkthrough`; a plugin with several labs can
  ship several (`debian`, `windows`, …)
- `-it` / `--lang it` — Italian. English is the default.
- `--live` — re-run the evidence commands against the running lab first.
  Without it the committed `docs/evidence/*.txt` is used, so the PDF builds
  anywhere, with no VM.

## What a plugin ships

```
<plugin>/docs/
  walkthrough.yaml        evidence commands, optional VNC console
  walkthrough.en.md       the document (YAML front matter + Markdown)
  walkthrough.it.md       optional translation
  img/                    screenshots
  evidence/               captured output, committed so builds are reproducible
  walkthrough-en.pdf      built artifact
```

## Markdown extensions

| Syntax | Effect |
|---|---|
| `{{evidence:id}}` | paste `docs/evidence/id.txt` as a terminal block |
| `{{evidence:id grep="A\|B" limit=20}}` | …filtered (options are shell-like words, so a pattern may contain `\|`) |
| `{{evidence:id only="…" uniq=1 number=1}}` | keep only what matched (like `grep -o`), de-duplicate, number — for serial captures where a whole installer screen sits on one line |
| `strip=syslog` `tail=N` `drop=…` `as=shell` | drop syslog prefixes · last N lines · exclude · light "what you type" skin |
| `{{shell}}…{{/shell}}` | a light "what you type" block |
| `:::note` / `:::warn` … `:::` | a callout box |
| `![caption](img/x.png)` | a numbered figure |

Everything else is ordinary Markdown: headings, tables, lists, `code`.
