#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PROFILE="${PROFILE:-}"
OUTPUT_DIR="${OUTPUT_DIR:-output}"
CONTAINER_IMAGE="registry.fedoraproject.org/fedora:45"
BOX="${BOX:-}"

usage() {
	cat <<EOF
Usage: $0 [--native] [--boxbuild] [--profile <profile>] [--output <dir>] [--box <name>]

  (no flag)   Build inside a privileged Fedora 45 container (Podman/Docker).
  --native    Build directly on a Fedora 45 host.
  --boxbuild  Build in a self-contained KIWI box (needs a configured --box).

  --profile   Optional KIWI profile name.
  --output    Directory for build artefacts (default: output).
  --box       Box name for --boxbuild (see 'kiwi-ng system boxbuild --list-boxes').
EOF
	exit 0
}

MODE="container"
while [ $# -gt 0 ]; do
	case "$1" in
		--native)    MODE="native" ;;
		--boxbuild)  MODE="boxbuild" ;;
		--profile)   PROFILE="$2"; shift ;;
		--output)    OUTPUT_DIR="$2"; shift ;;
		--box)       BOX="$2"; shift ;;
		-h|--help)   usage ;;
		*) echo "Unknown option: $1" >&2; usage ;;
	esac
	shift
done

mkdir -p "$OUTPUT_DIR"

PROFILE_ARGS=()
if [ -n "$PROFILE" ]; then
	PROFILE_ARGS=(--profile "$PROFILE")
fi

if [ "$MODE" = "native" ]; then
	if ! command -v kiwi-ng >/dev/null 2>&1; then
		echo "ERROR: kiwi-ng not found. Install KIWI NG on a Fedora 45 host:" >&2
		echo "  sudo dnf install kiwi kiwi-systemdeps-iso-media distribution-gpg-keys" >&2
		exit 1
	fi
	echo "==> Building natively"
	kiwi-ng ${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"} --temp-dir "$OUTPUT_DIR/kiwi-tmp" system build \
		--description . \
		--target-dir "$OUTPUT_DIR"

elif [ "$MODE" = "boxbuild" ]; then
	if ! command -v kiwi-ng >/dev/null 2>&1; then
		echo "ERROR: kiwi-ng not found. Install KIWI NG first:" >&2
		echo "  sudo dnf install kiwi kiwi-systemdeps-iso-media distribution-gpg-keys" >&2
		exit 1
	fi
	if [ -z "$BOX" ]; then
		echo "ERROR: --boxbuild requires --box <name>." >&2
		echo "List available boxes with: kiwi-ng system boxbuild --list-boxes" >&2
		exit 1
	fi
	echo "==> Box building with box: $BOX"
	kiwi-ng ${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"} --temp-dir "$OUTPUT_DIR/kiwi-tmp" system boxbuild \
		--box "$BOX" \
		-- system build \
		--description . \
		--target-dir "$OUTPUT_DIR"

else
	if command -v podman >/dev/null 2>&1; then
		RUNNER=(podman run --rm --privileged --network=host)
		RUNNER+=(-v "$PWD/$OUTPUT_DIR:$PWD/$OUTPUT_DIR" -v "$PWD:$PWD" -w "$PWD")
		RUNNER+=(--pull=newer --security-opt label=type:unconfined_t)
	elif command -v docker >/dev/null 2>&1; then
		RUNNER=(docker run --rm --privileged --network=host)
		RUNNER+=(-v "$PWD/$OUTPUT_DIR:$PWD/$OUTPUT_DIR" -v "$PWD:$PWD" -w "$PWD")
		RUNNER+=(--pull always --security-opt label=type:unconfined_t)
	else
		echo "ERROR: neither podman nor docker found. Install one to build." >&2
		exit 1
	fi

	echo "==> Building inside privileged Fedora 45 container"
	"${RUNNER[@]}" "$CONTAINER_IMAGE" \
		bash -c "mkdir -p '$OUTPUT_DIR/kiwi-tmp' && dnf install -y --setopt=install_weak_deps=False kiwi kiwi-systemdeps-iso-media distribution-gpg-keys && dnf clean all && \
			kiwi-ng ${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"} --temp-dir '$OUTPUT_DIR/kiwi-tmp' system build --description '.' --target-dir '$OUTPUT_DIR'"
fi

echo
echo "==> Build complete. ISO(s) in: $OUTPUT_DIR"
find "$OUTPUT_DIR" -maxdepth 3 -type f \( -name '*.iso' -o -name 'SHA256SUMS' \) -exec ls -lh {} \;
