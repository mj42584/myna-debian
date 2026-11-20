"""Inventaire des licences des paquets Python embarqués (dist-info/METADATA)."""
import email.parser
import pathlib
import sys


def licence(msg):
    if msg.get("License-Expression"):
        return msg["License-Expression"]
    classifiers = [c.split("::")[-1].strip()
                   for c in msg.get_all("Classifier") or [] if c.startswith("License ::")]
    if classifiers:
        return "; ".join(classifiers)
    text = (msg.get("License") or "").strip()
    return text.splitlines()[0][:60] if text else "voir le dist-info"


site = pathlib.Path(sys.argv[1])
for meta in sorted(site.glob("*.dist-info/METADATA")):
    msg = email.parser.Parser().parsestr(meta.read_text(encoding="utf-8", errors="replace"))
    print(f"{msg['Name'] + ' ' + msg['Version']:<40} {licence(msg)}")
