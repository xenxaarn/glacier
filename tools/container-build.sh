#!/usr/bin/env bash
# usage: container-build.sh <output-dir> <uid:gid> [kiwi-ng options...]
set -euxo pipefail

out="$1"
owner="$2"
shift 2

trap 'chown -R "$owner" "$out"' EXIT

mkdir -p "$out/kiwi-tmp"
dnf install -y --setopt=install_weak_deps=False \
	kiwi kiwi-systemdeps-iso-media distribution-gpg-keys
dnf clean all

kiwi-ng "$@" --temp-dir "$out/kiwi-tmp" system build \
	--description . \
	--target-dir "$out"
