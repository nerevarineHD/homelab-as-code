import os, sys
log = sys.argv[1]
for line in open(log):
    src, dst = line.rstrip("\n").split("\t")
    os.makedirs(os.path.dirname(src), exist_ok=True)
    os.rename(dst, src)
print("restored everything in", log)
