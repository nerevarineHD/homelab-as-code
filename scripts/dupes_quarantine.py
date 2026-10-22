import csv, os, sys, time
APPLY = "--apply" in sys.argv
CT, HOST = "/mnt/media/", "/media/library/"
Q = HOST + "_duplicates/"
rows = [r for r in csv.DictReader(open("/root/dupes.tsv"), delimiter="\t") if r["action"] == "extra"]
log = f"/root/dupes-moved-{time.strftime('%Y%m%d-%H%M%S')}.tsv"
dev = os.stat(HOST).st_dev
moved = skipped = total = 0
if APPLY:
    os.makedirs(Q, exist_ok=True)
    assert os.stat(Q).st_dev == dev, "quarantine is on a different filesystem; refusing (would copy, not rename)"
    out = open(log, "w")
for r in rows:
    rel = r["path"][len(CT):]
    src, dst = HOST + rel, Q + rel
    if not os.path.isfile(src):
        print(f"SKIP (missing): {src}"); skipped += 1; continue
    if os.stat(src).st_dev != dev:
        print(f"SKIP (other filesystem): {src}"); skipped += 1; continue
    total += os.path.getsize(src)
    if APPLY:
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        os.rename(src, dst)
        out.write(f"{src}\t{dst}\n"); moved += 1
    else:
        print(f"would move: {rel}")
mode = "MOVED" if APPLY else "DRY RUN"
print(f"{mode}: {moved if APPLY else len(rows) - skipped} files, {total/1e9:.1f} GB, skipped {skipped}" + (f" | log: {log}" if APPLY else ""))
