#!/usr/bin/env python3
"""Build a plugin walkthrough PDF.

    build.py <plugin-dir> [doc] [-it|--lang LANG] [--live] [--out FILE]

The document is Markdown with YAML front matter, in <plugin>/docs/<doc>.<lang>.md.
Command output comes from <plugin>/docs/evidence/*.txt, captured with --live and
committed so the PDF rebuilds anywhere without a VM.
"""
import argparse, html, os, re, shlex, shutil, subprocess, sys

try:
    import yaml, markdown
except ImportError as e:
    sys.exit("missing python module: %s (pip install pyyaml markdown weasyprint)" % e.name)

HERE = os.path.dirname(os.path.abspath(__file__))

STRINGS = {
    "en": {"figure": "Figure", "of": "/", "untranslated":
           "This document has no English version yet; showing the original."},
    "it": {"figure": "Figura", "of": "/", "untranslated":
           "Questo documento non ha ancora una versione italiana; mostro l'originale."},
}


# --------------------------------------------------------------------------- #
# front matter
# --------------------------------------------------------------------------- #
def split_front_matter(text):
    if not text.startswith("---"):
        return {}, text
    end = text.find("\n---", 3)
    if end < 0:
        return {}, text
    meta = yaml.safe_load(text[3:end]) or {}
    return meta, text[end + 4:].lstrip("\n")


# --------------------------------------------------------------------------- #
# evidence
# --------------------------------------------------------------------------- #
ANSI = re.compile(r'\x1b\[[0-9;?]*[A-Za-z]')

def load_evidence(docs_dir, eid):
    path = os.path.join(docs_dir, "evidence", eid + ".txt")
    if not os.path.exists(path):
        return None
    return ANSI.sub("", open(path, encoding="utf-8", errors="replace").read())

CTRL = re.compile(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]')

def filter_evidence(text, opts):
    # Serial captures carry backspaces, bells and other control bytes that have
    # no glyph in any font and would render as .notdef boxes in the PDF.
    lines = [CTRL.sub("", l) for l in text.splitlines()]
    if "grep" in opts:
        rx = re.compile(opts["grep"])
        lines = [l for l in lines if rx.search(l)]
    if "drop" in opts:
        rx = re.compile(opts["drop"])
        lines = [l for l in lines if not rx.search(l)]
    if "only" in opts:
        # Like grep -o. A serial capture of a full-screen installer puts a whole
        # redrawn screen on one line; keeping the line would paste pages of
        # box-drawing characters. This keeps just what matched.
        rx = re.compile(opts["only"])
        lines = [m.group(0) for l in lines for m in rx.finditer(l)]
    if opts.get("uniq"):
        seen, uniq = set(), []
        for l in lines:
            if l not in seen:
                seen.add(l); uniq.append(l)
        lines = uniq
    if opts.get("number"):
        lines = ["%2d. %s" % (i + 1, l) for i, l in enumerate(lines)]
    if opts.get("strip") == "syslog":
        lines = [re.sub(r'^\w{3} +\d+ [\d:]+ \S+ ', '', l) for l in lines]
        lines = [re.sub(r'^[a-z-]+\[\d+\]: ', '', l) for l in lines]
        lines = [re.sub(r'^\d{9,} ', '', l) for l in lines]
    if opts.get("tail"):
        lines = lines[-int(opts["tail"]):]
    if opts.get("limit"):
        lines = lines[:int(opts["limit"])]
    return "\n".join(l.rstrip() for l in lines).strip("\n")


# --------------------------------------------------------------------------- #
# markdown preprocessing
# --------------------------------------------------------------------------- #
EVIDENCE_RE = re.compile(r'^\{\{evidence:([A-Za-z0-9_.-]+)([^}]*)\}\}\s*$', re.M)
CALLOUT_OPEN = re.compile(r'^:::(note|warn)(?:\s+(.*))?$', re.M)

def preprocess(md, docs_dir, strings, missing):
    def evidence_sub(m):
        eid, rest = m.group(1), m.group(2)
        # Options are shell-like words, so a grep pattern may contain "|":
        #   {{evidence:dnsmasq grep="DHCPDISCOVER|DHCPACK" limit=20}}
        opts = {}
        for word in shlex.split(rest):
            k, _, v = word.partition("=")
            opts[k.strip()] = v
        text = load_evidence(docs_dir, eid)
        if text is None:
            missing.append(eid)
            body = "[evidence '%s' not captured — run with --live]" % eid
        else:
            body = filter_evidence(text, opts) or "[no matching line]"
        cls = "sh nodollar" if opts.get("as") == "shell" else ""
        return '<pre class="%s">%s</pre>\n' % (cls, html.escape(body))

    md = EVIDENCE_RE.sub(evidence_sub, md)

    # ::: note / ::: warn ... :::
    out, stack = [], []
    for line in md.split("\n"):
        m = CALLOUT_OPEN.match(line)
        if m:
            kind, title = m.group(1), (m.group(2) or "").strip()
            cls = "note warn" if kind == "warn" else "note"
            # markdown="1" + the md_in_html extension: without it everything
            # inside the div is treated as raw HTML and `code` stays literal.
            out.append('<div class="%s" markdown="1">' % cls)
            if title:
                out.append('<span class="t">%s</span>' % html.escape(title))
            stack.append(True)
        elif line.strip() == ":::" and stack:
            out.append("</div>")
            stack.pop()
        else:
            out.append(line)
    return "\n".join(out)


# --------------------------------------------------------------------------- #
# figures
# --------------------------------------------------------------------------- #
IMG_P = re.compile(r'<p>\s*(<img [^>]*?/?>)\s*</p>')

def figurize(body, strings):
    n = [0]
    def sub(m):
        tag = m.group(1)
        alt = re.search(r'alt="([^"]*)"', tag)
        cap = html.unescape(alt.group(1)) if alt else ""
        if cap:
            cap = markdown.markdown(cap).strip()
            if cap.startswith("<p>") and cap.endswith("</p>"):
                cap = cap[3:-4]
        tag = re.sub(r'alt="[^"]*"', 'alt=""', tag)
        n[0] += 1
        cap_html = '<figcaption><b>%s %d</b>%s</figcaption>' % (
            strings["figure"], n[0], (" — " + cap) if cap else "")
        return "<figure>%s%s</figure>" % (tag, cap_html)
    return IMG_P.sub(sub, body)


def check_figures(body, base):
    """A screenshot with nothing in it is a capture that landed between two
    screens. Refuse to ship one."""
    try:
        from PIL import Image
    except ImportError:
        return []
    bad = []
    for src in re.findall(r'<img src="([^"]+)"', body):
        path = src if os.path.isabs(src) else os.path.join(base, src)
        if not os.path.exists(path):
            bad.append("%s (missing)" % src); continue
        im = Image.open(path).convert("L"); w, h = im.size; px = im.load()
        rows = sum(1 for y in range(0, h, 2)
                   if any(px[x, y] > 40 for x in range(0, w, 2)))
        if rows < 2:
            bad.append("%s (blank)" % src)
    return bad


# --------------------------------------------------------------------------- #
# cover
# --------------------------------------------------------------------------- #
def render_cover(meta, strings):
    def inline(s):
        return markdown.markdown(str(s)).replace("<p>", "").replace("</p>", "")
    title = str(meta.get("title", "")).strip().replace("\n", "<br>")
    facts = ""
    for row in meta.get("facts", []) or []:
        if isinstance(row, (list, tuple)) and len(row) == 2:
            facts += "<b>%s</b> &nbsp;%s<br>\n" % (html.escape(str(row[0])), inline(row[1]))
    return """<section class="cover">
  <div class="kicker">%s</div>
  <h1>%s</h1>
  <div class="sub">%s</div>
  <div class="meta">%s</div>
</section>
<h1 style="font-size:0;height:0;margin:0">%s</h1>
""" % (html.escape(str(meta.get("kicker", ""))), title,
       inline(meta.get("subtitle", "")), facts,
       html.escape(re.sub("<[^>]+>", " ", title)))


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def capture_live(plugin_dir, cfg, workspace, only=None):
    """Re-run the evidence commands against the running lab.

    `only` restricts the capture to a comma-separated list of evidence ids —
    handy when one block needs a retake and the rest are already good.
    """
    docs_dir = os.path.join(plugin_dir, "docs")
    os.makedirs(os.path.join(docs_dir, "evidence"), exist_ok=True)
    qlab = shutil.which("qlab") or "qlab"
    for item in cfg.get("evidence", []) or []:
        eid, vm, cmd = item["id"], item.get("vm"), item["cmd"]
        if only and eid not in only:
            continue
        if vm:
            argv = [qlab, "shell", vm, "--no-wait", "-c", cmd]
        else:
            argv = ["bash", "-lc", cmd]
        print("  capturing %-22s" % eid, end="", flush=True)
        try:
            r = subprocess.run(argv, capture_output=True, text=True, timeout=300,
                               cwd=workspace)
            out = (r.stdout or "") + (r.stderr or "")
        except Exception as e:
            out = "[capture failed: %s]" % e
        out = ANSI.sub("", out)
        open(os.path.join(docs_dir, "evidence", eid + ".txt"), "w",
             encoding="utf-8").write(out)
        print("%6d bytes" % len(out))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("plugin_dir")
    ap.add_argument("doc", nargs="?", default="walkthrough")
    ap.add_argument("-it", dest="it", action="store_true", help="shorthand for --lang it")
    ap.add_argument("--lang", default="en")
    ap.add_argument("--live", action="store_true",
                    help="re-capture evidence from the running lab first")
    ap.add_argument("--only", help="with --live: re-capture only these evidence ids (comma-separated)")
    ap.add_argument("--workspace", default=".",
                    help="directory holding .qlab (for --live)")
    ap.add_argument("--out")
    a = ap.parse_args()

    lang = "it" if a.it else a.lang
    strings = STRINGS.get(lang, STRINGS["en"])
    plugin_dir = os.path.abspath(a.plugin_dir)
    docs_dir = os.path.join(plugin_dir, "docs")
    if not os.path.isdir(docs_dir):
        sys.exit("no docs/ in %s" % plugin_dir)

    cfg_path = os.path.join(docs_dir, "walkthrough.yaml")
    cfg = yaml.safe_load(open(cfg_path)) if os.path.exists(cfg_path) else {}
    cfg = cfg or {}

    if a.live:
        print("Capturing evidence from the running lab...")
        only = set(x.strip() for x in a.only.split(",")) if a.only else None
        capture_live(plugin_dir, cfg, os.path.abspath(a.workspace), only)

    src = os.path.join(docs_dir, "%s.%s.md" % (a.doc, lang))
    fallback = False
    if not os.path.exists(src):
        alt = os.path.join(docs_dir, "%s.en.md" % a.doc)
        if os.path.exists(alt):
            src, fallback = alt, True
        else:
            sys.exit("no document: %s" % src)

    meta, body_md = split_front_matter(open(src, encoding="utf-8").read())
    missing = []
    body_md = preprocess(body_md, docs_dir, strings, missing)

    body = markdown.markdown(
        body_md,
        extensions=["extra", "md_in_html", "sane_lists", "attr_list"],
        output_format="html5",
    )
    body = figurize(body, strings)

    bad = check_figures(body, docs_dir)
    if bad:
        sys.exit("blank or missing figures:\n  " + "\n  ".join(bad))
    if missing:
        print("warning: evidence not captured: %s" % ", ".join(sorted(set(missing))),
              file=sys.stderr)

    notice = ('<div class="note">%s</div>' % strings["untranslated"]) if fallback else ""
    css = os.path.relpath(os.path.join(HERE, "style.css"), docs_dir)
    page = ('<!doctype html>\n<html lang="%s"><head><meta charset="utf-8">\n'
            '<title>%s</title>\n<link rel="stylesheet" href="%s"></head><body>\n'
            '%s%s%s\n</body></html>\n'
            % (lang, html.escape(re.sub("<[^>]+>", " ", str(meta.get("title", a.doc)))),
               css, render_cover(meta, strings), notice, body))

    html_out = os.path.join(docs_dir, "%s.%s.html" % (a.doc, lang))
    open(html_out, "w", encoding="utf-8").write(page)

    pdf = a.out or os.path.join(docs_dir, "%s-%s.pdf" % (a.doc, lang))
    subprocess.run(["weasyprint", html_out, pdf], check=True)
    os.remove(html_out)
    print("PDF: %s" % pdf)


if __name__ == "__main__":
    main()
