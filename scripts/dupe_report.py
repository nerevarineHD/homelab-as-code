import collections, csv, getpass, json, re, urllib.request
key = getpass.getpass("Jellyfin API key: ").strip()
base = "http://192.168.0.21:8096"
req = urllib.request.Request(
    base + "/Items?IncludeItemTypes=Movie&Recursive=true&Fields=ProviderIds,Path,MediaSources&Limit=10000",
    headers={"Authorization": f'MediaBrowser Token="{key}"'})
items = json.load(urllib.request.urlopen(req))["Items"]

MULTIPART = re.compile(r'(?:^|[\s._\-/\[(])(cd|disc|disk|part|pt)[\s._-]?\d', re.I)
CAM = re.compile(r'(?:^|[\s._\-\[(])(hdcam|cam|camrip|hdts|telesync|ts|tc|telecine|r5|scr|screener|dvdscr)(?:[\s._\-\])]|$)', re.I)

groups = collections.defaultdict(list)
for it in items:
    gid = (it.get("ProviderIds") or {}).get("Tmdb") or f'{it["Name"]}|{it.get("ProductionYear")}'
    for ms in it.get("MediaSources", []):
        video = [s for s in ms.get("MediaStreams", []) if s.get("Type") == "Video"]
        width = (video[0].get("Width") if video else 0) or 0
        path = ms.get("Path", "")
        groups[gid].append({"title": it["Name"], "year": it.get("ProductionYear"), "width": width,
                            "size": ms.get("Size") or 0, "path": path,
                            "multi": bool(MULTIPART.search(path)), "cam": bool(CAM.search(path))})

rows, safe_gb, safe_n, review = [], 0, 0, 0
for gid, copies in groups.items():
    if len(copies) < 2:
        continue
    if any(c["multi"] for c in copies):
        review += 1
        for c in copies:
            rows.append(["REVIEW-multipart", c["title"], c["year"], c["width"], f'{c["size"]/1e9:.2f}',
                         "CAM" if c["cam"] else "", c["path"]])
        continue
    copies.sort(key=lambda c: (not c["cam"], c["width"], c["size"]), reverse=True)
    for i, c in enumerate(copies):
        if i:
            safe_n += 1
            safe_gb += c["size"]
        rows.append(["KEEP" if i == 0 else "extra", c["title"], c["year"], c["width"], f'{c["size"]/1e9:.2f}',
                     "CAM" if c["cam"] else "", c["path"]])

order = {"KEEP": 0, "extra": 1, "REVIEW-multipart": 2}
rows.sort(key=lambda r: (order[r[0]] == 2, r[1], order[r[0]]))
with open("/root/dupes.tsv", "w", newline="") as f:
    w = csv.writer(f, delimiter="\t")
    w.writerow(["action", "title", "year", "width", "GB", "note", "path"])
    w.writerows(rows)
print(f"safe extras: {safe_n} files, {safe_gb/1e9:.1f} GB | multi-part groups to review: {review} -> /root/dupes.tsv")
