#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v shellcheck >/dev/null 2>&1; then
	echo "ERROR: shellcheck not found." >&2
	exit 1
fi

echo "==> shellcheck"
shellcheck -S warning build.sh config.sh tools/*.sh root/usr/libexec/glacier-branding \
	root/usr/bin/glacier-install root/var/lib/livesys/livesys-session-extra
shellcheck -s sh root/etc/fstab.script root/etc/profile.d/editor.sh

echo "==> Glacier.kiwi / dconf"
python3 - <<'PY'
import configparser
import glob
import sys
import xml.etree.ElementTree as ET

errors = []
root = ET.parse("Glacier.kiwi").getroot()

declared = {p.get("name") for p in root.findall("./profiles/profile")}
per_type = {}
for block in root.findall("packages"):
    names = [e.get("name") for e in block.findall("package")]
    for n in sorted({n for n in names if names.count(n) > 1}):
        errors.append(f"<package name='{n}'> listed twice in one <packages> block")
    profiles = [x for x in (block.get("profiles") or "").split(",") if x]
    for prof in profiles:
        if prof not in declared:
            errors.append(f"profile '{prof}' is used but not declared in <profiles>")
    bucket = per_type.setdefault(block.get("type"), {"base": set(), "profiled": set()})
    bucket["profiled" if profiles else "base"].update(names)
for ptype, bucket in per_type.items():
    for n in sorted(bucket["base"] & bucket["profiled"]):
        errors.append(f"'{n}' is in the base {ptype} packages and again in a profile")

for path in sorted(glob.glob("root/etc/dconf/db/local.d/*")):
    cp = configparser.ConfigParser(interpolation=None, strict=True)
    cp.optionxform = str
    try:
        cp.read(path)
    except configparser.Error as exc:
        errors.append(f"{path}: {exc}")

try:
    from kiwi.xml_description import XMLDescription
    from kiwi.xml_state import XMLState
except ImportError:
    print("note: `kiwi` Python package not installed, skipping schema validation")
else:
    try:
        description = XMLDescription("Glacier.kiwi").load()
        for prof in [None, *sorted(declared)]:
            state = XMLState(description, [prof] if prof else None)
            count = len(state.get_bootstrap_packages()) + len(state.get_system_packages())
            print(f"kiwi schema OK, profile={prof or '(none)'}: {count} packages")
    except Exception as exc:
        errors.append(f"KIWI rejected Glacier.kiwi: {exc}")

for e in errors:
    print("ERROR:", e, file=sys.stderr)
sys.exit(1 if errors else 0)
PY

echo "lint OK"
