#!/usr/bin/env python3
"""Builds the Web Cloner site into docs/.

Page bodies live in tools/pages/<slug>.html. This wraps each one in the shared
head, nav and footer, then rewrites sitemap.xml, robots.txt, llms.txt and
llms-full.txt from the same list so they cannot drift.

    python3 tools/build-site.py
"""

import hashlib
import os
import re

SITE = "https://web-cloner.sarimtools.com"
REPO = "https://github.com/DeveloperSarim/web-cloner-mac"
DMG = REPO + "/releases/latest/download/WebCloner.dmg"
VERSION = "1.2.0"
UPDATED = "2026-10-11"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs")
SRC = os.path.join(ROOT, "tools", "pages")

# slug, nav label, title, description, h1, lede
PAGES = [
    ("", "Home",
     "Web Cloner — save any website to your Mac",
     "A native macOS app that downloads a whole website for offline reading, scans it for every page, or captures a full-page screenshot of each one. Free and open source.",
     "", ""),
    ("features/", "Features",
     "Features — Web Cloner for macOS",
     "Clone a site for offline reading, scan it for every page, or screenshot each one. Sitemaps, CDN images, a live page list and the wget flags behind them.",
     "Everything Web Cloner does",
     "Three jobs, the repair pass that keeps images from going missing, and the options behind them."),
    ("download/", "Download",
     "Download Web Cloner for macOS — free and open source",
     "Download the free Web Cloner disk image or install it with Homebrew. macOS 13 and later, universal for Intel and Apple Silicon, MIT licensed.",
     "Download Web Cloner",
     "Free, MIT licensed, and the same build on Intel and Apple Silicon."),
    ("guide/", "Guide",
     "How to download an entire website on a Mac",
     "A step by step guide to saving a complete website on macOS, from installing the app to opening the copy with the network switched off.",
     "How to save a whole website on a Mac",
     "From a blank window to a copy that opens with the network off."),
    ("developers/", "Developers",
     "Developer options and wget flags — Web Cloner",
     "Every advanced field in Web Cloner and the wget flag it maps to: skip paths, URL patterns, file types, extra domains, size caps and the command it builds.",
     "Options for developers",
     "Each field is one wget flag, and the app will hand you the finished command."),
    ("faq/", "FAQ",
     "Web Cloner FAQ — questions about cloning websites on macOS",
     "Answers about offline copies, JavaScript-heavy sites, file sizes, licensing, updates and what Web Cloner can and cannot save.",
     "Questions people ask",
     "What the app can save, what it cannot, and how it behaves."),
    ("httrack-alternative/", "HTTrack alternative",
     "HTTrack alternative for Mac — Web Cloner",
     "Looking for HTTrack on macOS? Web Cloner is a native Mac app that mirrors websites, with a live page list, sitemaps and full-page screenshots.",
     "An HTTrack alternative for the Mac",
     "Same job, a native window, and a few things HTTrack never did."),
]


def stamp(path):
    """Short content hash, so a redeploy cannot serve a stale stylesheet."""
    with open(os.path.join(OUT, path), "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()[:8]


def read(name):
    with open(os.path.join(SRC, name), encoding="utf-8") as f:
        return f.read()


SPRITE = read("_sprite.svg")
SOFTWARE_LD = read("_jsonld.html").replace("SITE", SITE).replace("DMG", DMG).replace("REPO", REPO)


def head(slug, title, desc, extra_ld=""):
    url = SITE + "/" + slug
    ld = SOFTWARE_LD if slug == "" else ""
    return (
        '<!DOCTYPE html>\n<html lang="en">\n<head>\n'
        '<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        "<title>" + title + "</title>\n"
        '<meta name="description" content="' + desc + '">\n'
        '<link rel="canonical" href="' + url + '">\n'
        '<link rel="icon" href="/icon.png">\n'
        '<link rel="apple-touch-icon" href="/icon.png">\n'
        '<meta name="theme-color" content="#0c1819" media="(prefers-color-scheme: dark)">\n'
        '<meta name="theme-color" content="#f3f7f5" media="(prefers-color-scheme: light)">\n'
        '<meta property="og:type" content="website">\n'
        '<meta property="og:site_name" content="Web Cloner">\n'
        '<meta property="og:title" content="' + title + '">\n'
        '<meta property="og:description" content="' + desc + '">\n'
        '<meta property="og:url" content="' + url + '">\n'
        '<meta property="og:image" content="' + SITE + '/banner.png">\n'
        '<meta name="twitter:card" content="summary_large_image">\n'
        '<meta name="twitter:title" content="' + title + '">\n'
        '<meta name="twitter:description" content="' + desc + '">\n'
        '<meta name="twitter:image" content="' + SITE + '/banner.png">\n'
        '<link rel="preconnect" href="https://fonts.googleapis.com">\n'
        '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
        '<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700'
        '&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">\n'
        '<link rel="stylesheet" href="/styles.css?v=' + stamp("styles.css") + '">\n'
        "<script>\n  try {\n    var saved = localStorage.getItem('theme');\n"
        "    if (saved) document.documentElement.setAttribute('data-theme', saved);\n"
        "  } catch (e) {}\n</script>\n"
        + ld + extra_ld +
        "</head>\n<body>\n\n" + SPRITE + "\n\n"
    )


def nav(slug):
    links = ""
    for s, label, _t, _d, _h, _l in PAGES:
        if s == "" or label == "HTTrack alternative":
            continue
        current = ' aria-current="page"' if s == slug else ""
        links += '      <a class="link" href="/' + s + '"' + current + ">" + label + "</a>\n"
    return (
        '<header class="top">\n  <div class="wrap">\n'
        '    <a class="brand" href="/"><img src="/icon.png" alt=""> Web Cloner</a>\n'
        "    <nav>\n" + links +
        '      <a class="star" href="' + REPO + '" aria-label="Star Web Cloner on GitHub">\n'
        '        <span><svg class="i sstar"><use href="#star"/></svg> Star</span>\n'
        '        <span class="num" id="stars">&mdash;</span>\n      </a>\n'
        '      <button class="icon-btn" id="theme" type="button" aria-label="Switch colour theme">\n'
        '        <svg class="i sun"><use href="#sun"/></svg>\n'
        '        <svg class="i moon"><use href="#moon"/></svg>\n      </button>\n'
        '      <a class="btn btn-main" href="/download/"><svg class="i"><use href="#dl"/></svg> Download</a>\n'
        "    </nav>\n  </div>\n</header>\n\n"
    )


def page_head(slug, label, h1, lede):
    if not slug:
        return ""
    return (
        '<div class="page-head">\n  <div class="wrap">\n'
        '    <p class="crumbs"><a href="/">Home</a> <svg class="i"><use href="#caret"/></svg> ' + label + "</p>\n"
        "    <h1>" + h1 + "</h1>\n"
        '    <p class="lede">' + lede + "</p>\n"
        "  </div>\n</div>\n\n"
    )


def build():
    footer = read("_footer.html").replace("REPO", REPO).replace("APPJS", stamp("app.js"))
    cta = read("_cta.html").replace("REPO", REPO).replace("DMG", DMG).replace("VERSION", VERSION)

    for slug, label, title, desc, h1, lede in PAGES:
        body = read((slug.strip("/") or "index") + ".html")
        body = body.replace("REPO", REPO).replace("DMG", DMG).replace("VERSION", VERSION).replace("SITE", SITE)
        extra = ""
        ld_file = os.path.join(SRC, "_ld_" + (slug.strip("/") or "index") + ".html")
        if os.path.exists(ld_file):
            with open(ld_file, encoding="utf-8") as f:
                extra = f.read()
        html = head(slug, title, desc, extra) + nav(slug) + "<main>\n\n"
        html += page_head(slug, label, h1, lede) + body + "</main>\n\n" + cta + footer

        folder = os.path.join(OUT, slug.strip("/"))
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, "index.html"), "w", encoding="utf-8") as f:
            f.write(html)
        print("wrote", os.path.relpath(os.path.join(folder, "index.html"), ROOT))

    write_sitemap()
    write_robots()
    write_llms()


def write_sitemap():
    urls = ""
    for slug, _l, _t, _d, _h, _le in PAGES:
        priority = "1.0" if slug == "" else ("0.9" if slug in ("download/", "features/") else "0.8")
        urls += ("  <url>\n    <loc>" + SITE + "/" + slug + "</loc>\n"
                 "    <lastmod>" + UPDATED + "</lastmod>\n"
                 "    <changefreq>monthly</changefreq>\n"
                 "    <priority>" + priority + "</priority>\n  </url>\n")
    xml = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + urls + "</urlset>\n")
    open(os.path.join(OUT, "sitemap.xml"), "w", encoding="utf-8").write(xml)
    print("wrote docs/sitemap.xml")


def write_robots():
    txt = ("User-agent: *\nAllow: /\n\n"
           "Sitemap: " + SITE + "/sitemap.xml\n")
    open(os.path.join(OUT, "robots.txt"), "w", encoding="utf-8").write(txt)
    print("wrote docs/robots.txt")


TAGS = re.compile(r"<[^>]+>")
SPACES = re.compile(r"[ \t]+")
BLANKS = re.compile(r"\n{3,}")

ENTITIES = [
    ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", '"'), ("&#39;", "'"),
    ("&mdash;", "—"), ("&ndash;", "–"), ("&hellip;", "…"),
    ("&rarr;", "->"), ("&times;", "x"), ("&nbsp;", " "),
]


def to_text(html):
    """Turns a page body into plain markdown-ish text for llms-full.txt."""
    html = re.sub(r"(?is)<svg.*?</svg>", "", html)
    html = re.sub(r"(?is)<figcaption.*?</figcaption>", "", html)
    for tag, mark in (("h2", "## "), ("h3", "### "), ("h4", "#### ")):
        html = re.sub(r"(?is)<" + tag + r"[^>]*>(.*?)</" + tag + ">", "\n\n" + mark + r"\1\n", html)
    html = re.sub(r"(?is)<li[^>]*>(.*?)</li>", r"- \1\n", html)
    html = re.sub(r"(?is)<(p|div|tr|section)[^>]*>", "\n", html)
    html = re.sub(r"(?is)<br\s*/?>", "\n", html)
    html = re.sub(r"(?is)</(td|th)>", " | ", html)
    text = TAGS.sub("", html)
    for ent, ch in ENTITIES:
        text = text.replace(ent, ch)
    text = SPACES.sub(" ", text)
    text = "\n".join(line.strip() for line in text.split("\n"))
    return BLANKS.sub("\n\n", text).strip()


def write_llms():
    index = ["# Web Cloner", "",
             "> A native macOS app that downloads a whole website for offline reading, scans a "
             "site for every page, or captures a full-page screenshot of each one. Free and open "
             "source under the MIT licence, a universal binary for Intel and Apple Silicon, "
             "macOS 13 or later.", "",
             "Web Cloner drives wget from a SwiftUI window. After a mirror it runs a repair pass "
             "that downloads assets served from other domains and relinks them, so an offline "
             "copy keeps its images. Current version " + VERSION + ".", "",
             "## Pages", ""]
    for slug, label, title, desc, _h, _l in PAGES:
        index.append("- [" + label + "](" + SITE + "/" + slug + "): " + desc)
    index += ["", "## Project", "",
              "- [Source code](" + REPO + "): Swift source, build script and tests",
              "- [Releases](" + REPO + "/releases): every version with its disk image",
              "- [Homebrew tap](https://github.com/DeveloperSarim/homebrew-tap): "
              "brew install --cask DeveloperSarim/tap/web-cloner",
              "- [Full text](" + SITE + "/llms-full.txt): every page of this site as plain text", ""]
    open(os.path.join(OUT, "llms.txt"), "w", encoding="utf-8").write("\n".join(index))
    print("wrote docs/llms.txt")

    full = ["# Web Cloner — full site text", "",
            "Source: " + SITE + "  |  Version " + VERSION + "  |  Updated " + UPDATED, ""]
    for slug, label, title, desc, h1, lede in PAGES:
        body = read((slug.strip("/") or "index") + ".html")
        body = body.replace("REPO", REPO).replace("DMG", DMG).replace("VERSION", VERSION).replace("SITE", SITE)
        full += ["", "---", "", "# " + (h1 or title), "", "URL: " + SITE + "/" + slug, ""]
        if lede:
            full += [lede, ""]
        full += [to_text(body), ""]
    open(os.path.join(OUT, "llms-full.txt"), "w", encoding="utf-8").write("\n".join(full))
    print("wrote docs/llms-full.txt")


if __name__ == "__main__":
    build()
