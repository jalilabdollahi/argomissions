"""Writes the CMDB export as a ConfigMap manifest (about 415 KB, over the 262144-byte annotation limit)."""
import sys

out = sys.argv[1]
lines = [f"10.{i // 65536 % 256}.{i // 256 % 256}.{i % 256} host-{i:05d}.corp.internal zone-{i % 9 + 1}"
         for i in range(9000)]
body = "\n".join("    " + line for line in lines)
with open(out, "w", encoding="utf-8") as fh:
    fh.write("apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: host-inventory\n  labels: {app: host-registry}\n"
             "data:\n  hosts.txt: |\n" + body + "\n")
