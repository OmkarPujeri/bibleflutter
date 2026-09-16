"""Converts the World English Bible (public domain) from getbible/v2 into
Bible Connect's asset format.

Usage: python tools/convert_web.py --out assets/bible
Downloads https://api.getbible.net/v2/web/{1..66}.json and writes one JSON
file per book (lazy loading) plus an index.json for the book picker.
"""
import argparse
import json
import os
import sys
import urllib.request

OSIS_IDS = [
    "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT",
    "1SA", "2SA", "1KI", "2KI", "1CH", "2CH", "EZR", "NEH", "EST",
    "JOB", "PSA", "PRO", "ECC", "SNG", "ISA", "JER", "LAM", "EZK", "DAN",
    "HOS", "JOL", "AMO", "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL",
    "MAT", "MRK", "LUK", "JHN", "ACT",
    "ROM", "1CO", "2CO", "GAL", "EPH", "PHP", "COL",
    "1TH", "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS",
    "1PE", "2PE", "1JN", "2JN", "3JN", "JUD", "REV",
]
# The getbible WEB edition is a critical-text edition: it omits Luke 17:36,
# Acts 8:37, Acts 15:34 and Acts 24:7, and merges the Romans 16:25-27
# doxology into Romans 14:23. Its total is therefore 31095 verses
# (the KJV count would be 31102). Verified against
# https://api.getbible.net/v2/web.json.
EXPECTED_TOTAL_VERSES = 31095
BASE_URL = "https://api.getbible.net/v2/web/{}.json"

def fetch_book(nr):
    # api.getbible.net 403s the default "Python-urllib/x" User-Agent.
    req = urllib.request.Request(
        BASE_URL.format(nr), headers={"User-Agent": "bible-connect-convert/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))

def convert(book_nr, raw):
    osis = OSIS_IDS[book_nr - 1]
    name = raw.get("name") or raw.get("book_name") or osis
    chapters_raw = raw["chapters"]
    if isinstance(chapters_raw, dict):  # some translations key by number
        chapters_raw = [chapters_raw[k] for k in sorted(chapters_raw, key=int)]
    chapters = []
    for ch in sorted(chapters_raw, key=lambda c: c["chapter"]):
        verses = [
            {"v": v["verse"], "text": " ".join(v["text"].split())}
            for v in sorted(ch["verses"], key=lambda v: v["verse"])
        ]
        chapters.append({"number": ch["chapter"], "verses": verses})
    return osis, {
        "id": osis,
        "name": name,
        "testament": "OT" if book_nr <= 39 else "NT",
        "chapters": chapters,
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    books_dir = os.path.join(args.out, "books")
    os.makedirs(books_dir, exist_ok=True)

    index = []
    total = 0
    for nr in range(1, 67):
        raw = fetch_book(nr)
        osis, content = convert(nr, raw)
        with open(os.path.join(books_dir, f"{osis}.json"), "w", encoding="utf-8") as f:
            json.dump(content, f, ensure_ascii=False, separators=(",", ":"))
        index.append({
            "id": osis,
            "name": content["name"],
            "testament": content["testament"],
            "chapterCount": len(content["chapters"]),
        })
        total += sum(len(c["verses"]) for c in content["chapters"])
        print(f"{osis}: {len(content['chapters'])} chapters")

    with open(os.path.join(args.out, "index.json"), "w", encoding="utf-8") as f:
        json.dump({"books": index}, f, ensure_ascii=False, separators=(",", ":"))

    print(f"Total verses: {total}")
    if total != EXPECTED_TOTAL_VERSES:
        sys.exit(f"FAIL: expected {EXPECTED_TOTAL_VERSES} verses, got {total}")

    with open(os.path.join(books_dir, "JHN.json"), encoding="utf-8") as f:
        jhn = json.load(f)
    v316 = [v for v in jhn["chapters"][2]["verses"] if v["v"] == 16][0]
    print("John 3:16 ->", v316["text"][:80])

if __name__ == "__main__":
    main()
