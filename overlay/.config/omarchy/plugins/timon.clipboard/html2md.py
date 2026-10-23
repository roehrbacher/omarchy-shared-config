#!/usr/bin/env python3
"""timon.clipboard: HTML from a browser/office copy -> Markdown, on stdin/stdout.

Used by `clipboard.sh paste-md` when pandoc is not installed. Standard
library only. Handles headings, paragraphs, line breaks, links, images,
bold/italic (also Google Docs' styled spans), inline code, code blocks,
nested ordered/unordered lists, block quotes, rules and simple tables.
Anything else is kept as plain text.
"""
import re
import sys
from html.parser import HTMLParser

BLOCK = {"p", "div", "section", "article", "header", "footer", "main", "figure", "figcaption", "dl", "dt", "dd"}
SKIP = {"script", "style", "title", "noscript", "template"}


def esc(text):
    return re.sub(r"([\\`*_\[\]])", r"\\\1", text)


class Md(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out = []          # finished blocks/pieces
        self.buf = []          # current inline run
        self.lists = []        # stack of ["ul"|"ol", counter]
        self.quote = 0
        self.pre = 0
        self.skip = 0
        self.links = []        # stack of href
        self.marks = []        # stack of closing marks per element
        self.table = None      # list of rows (list of cells)
        self.cell = None

    # ---- helpers ----
    def flush(self, sep="\n\n"):
        text = "".join(self.buf)
        self.buf = []
        if self.cell is not None:
            self.cell.append(text)
            return
        if not text.strip():
            return
        lines = text.strip("\n").split("\n") if self.pre else [self.tidy(l) for l in text.strip("\n").split("\n")]
        while lines and not lines[-1].strip():
            lines.pop()
        if lines:
            lines[-1] = lines[-1].rstrip()
        prefix = "> " * self.quote
        self.out.append("\n".join(prefix + l for l in lines) + sep)

    def open_mark(self, m):
        self.marks.append((m, len(self.buf)))

    def close_mark(self):
        if not self.marks:
            return
        m, idx = self.marks.pop()
        if not isinstance(m, str) or not m or idx > len(self.buf):
            return
        inner = "".join(self.buf[idx:])
        if not inner.strip() or "\n" in inner.strip():
            return
        # Markdown marks must hug the text: spaces go outside them.
        lead = inner[: len(inner) - len(inner.lstrip())]
        trail = inner[len(inner.rstrip()):]
        close = m if m == "`" else m[::-1]
        self.buf[idx:] = [lead + m + inner.strip() + close + trail]

    @staticmethod
    def tidy(line):
        hard = line.endswith("  ")
        m = re.match(r"^( +)(?=- |\d+\. )", line)
        indent = m.group(1) if m else ""
        body = re.sub(r"[ \t]+", " ", line).strip()
        return indent + body + ("  " if hard and body else "")

    def emit(self, s):
        self.buf.append(s)

    # ---- parser callbacks ----
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag in SKIP:
            self.skip += 1
            return
        if self.skip:
            return
        style = (a.get("style") or "").replace(" ", "").lower()
        if re.fullmatch(r"h[1-6]", tag):
            self.flush()
            self.emit("#" * int(tag[1]) + " ")
            self.marks.append(("", len(self.buf)))
        elif tag in BLOCK:
            self.flush()
            self.marks.append(("", len(self.buf)))
        elif tag == "br":
            self.emit("  \n" if not self.pre else "\n")
        elif tag == "hr":
            self.flush()
            self.out.append("---\n\n")
        elif tag in ("ul", "ol"):
            self.flush("\n")
            self.lists.append([tag, int(a.get("start") or 1) - 1])
        elif tag == "li":
            self.flush("\n")
            depth = max(0, len(self.lists) - 1)
            kind = self.lists[-1] if self.lists else ["ul", 0]
            if kind[0] == "ol":
                kind[1] += 1
                bullet = "%d. " % kind[1]
            else:
                bullet = "- "
            self.emit("   " * depth + bullet)
        elif tag == "blockquote":
            self.flush()
            self.quote += 1
        elif tag == "pre":
            self.flush()
            self.pre += 1
            self.emit("```\n")
        elif tag == "code":
            self.open_mark("" if self.pre else "`")
        elif tag in ("b", "strong") and "font-weight:normal" not in style:
            self.open_mark("**")
        elif tag in ("i", "em"):
            self.open_mark("*")
        elif tag in ("s", "del", "strike"):
            self.open_mark("~~")
        elif tag == "span":
            m = ""
            if re.search(r"font-weight:(bold|[6-9]00)", style):
                m += "**"
            if "font-style:italic" in style:
                m += "*"
            self.open_mark(m)
        elif tag == "a":
            href = a.get("href") or ""
            self.links.append(href)
            if href and not href.startswith("javascript:"):
                self.emit("[")
        elif tag == "img":
            src = a.get("src") or ""
            if src and not src.startswith("data:"):
                self.emit("![%s](%s)" % (esc(a.get("alt") or ""), src))
        elif tag == "table":
            self.flush()
            self.table = []
        elif tag == "tr" and self.table is not None:
            self.table.append([])
        elif tag in ("td", "th") and self.table is not None:
            self.flush()
            self.cell = []
        elif tag in ("b", "strong"):
            self.marks.append(("", len(self.buf)))

    def handle_endtag(self, tag):
        if tag in SKIP:
            self.skip = max(0, self.skip - 1)
            return
        if self.skip:
            return
        if re.fullmatch(r"h[1-6]", tag) or tag in BLOCK:
            if self.marks:
                self.marks.pop()
            self.flush()
        elif tag in ("ul", "ol"):
            self.flush("\n")
            if self.lists:
                self.lists.pop()
            if not self.lists:
                self.out.append("\n")
        elif tag == "li":
            self.flush("\n")
        elif tag == "blockquote":
            self.flush()
            self.quote = max(0, self.quote - 1)
        elif tag == "pre":
            self.emit("\n```")
            self.flush()
            self.pre = max(0, self.pre - 1)
        elif tag in ("code", "b", "strong", "i", "em", "s", "del", "strike", "span"):
            self.close_mark()
        elif tag == "a":
            href = self.links.pop() if self.links else ""
            if href and not href.startswith("javascript:"):
                self.emit("](%s)" % href.replace(" ", "%20").replace(")", "%29"))
        elif tag in ("td", "th") and self.table is not None and self.cell is not None:
            self.flush()
            cell = " ".join("".join(self.cell).split()).replace("|", "\\|")
            self.cell = None
            if self.table:
                self.table[-1].append(cell)
        elif tag == "table" and self.table is not None:
            rows = [r for r in self.table if r]
            self.table = None
            if rows:
                w = max(len(r) for r in rows)
                rows = [r + [""] * (w - len(r)) for r in rows]
                lines = ["| " + " | ".join(rows[0]) + " |", "|" + "---|" * w]
                lines += ["| " + " | ".join(r) + " |" for r in rows[1:]]
                self.out.append("\n".join(lines) + "\n\n")

    def handle_data(self, data):
        if self.skip:
            return
        if self.pre:
            self.emit(data)
            return
        text = re.sub(r"\s+", " ", data)
        if not "".join(self.buf).strip():
            text = text.lstrip()
        self.emit(esc(text) if text.strip() else text)

    def result(self):
        self.flush()
        md = "".join(self.out)
        md = re.sub(r"\n{3,}", "\n\n", md)
        return md.strip() + "\n"


def main():
    raw = sys.stdin.buffer.read().decode("utf-8", "replace")
    raw = re.sub(r"<!--.*?-->", "", raw, flags=re.S)
    p = Md()
    p.feed(raw)
    p.close()
    sys.stdout.write(p.result())


if __name__ == "__main__":
    main()
