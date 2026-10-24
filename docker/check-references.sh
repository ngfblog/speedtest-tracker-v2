#!/bin/bash
# Fails if the image config, build history or filesystem references the old
# images nirgf/speedtest-tracker-v2 or the upstream author's speedtest-tracker.
# The credit link to the upstream GitHub project in NOTICE.md is not an image
# reference; it is listed but allowed in exactly that file.
# Usage: docker/check-references.sh IMAGE

set -euo pipefail

image="${1:?usage: check-references.sh IMAGE}"
# The upstream owner name is assembled from parts so this file does not contain it
upstream="henry""whitaker3/speedtest-tracker"
pattern="nirgf/speedtest-tracker-v2|$upstream"
allowed='^(site/NOTICE\.md)$'
fail=0

echo "== image config (labels, env, entrypoint)"
if docker image inspect "$image" | grep -iE "$pattern"; then fail=1; else echo "none"; fi

echo "== build history"
if docker history --no-trunc --format '{{.CreatedBy}}' "$image" | grep -iE "$pattern"; then fail=1; else echo "none"; fi

echo "== filesystem"
fs="$(mktemp -d)"
cid="$(docker create "$image")"
docker export "$cid" | tar -x -C "$fs" 2> /dev/null || true
docker rm "$cid" > /dev/null
matches="$(cd "$fs" && grep -rlIiE "$pattern" . 2> /dev/null | sed 's#^\./##' | sort || true)"
for f in $matches; do
    if [[ "$f" =~ $allowed ]] && ! grep -qiE 'nirgf/speedtest-tracker-v2' "$fs/$f"; then
        echo "allowed (upstream GitHub link): /$f"
    else
        echo "REFERENCE: /$f"
        grep -noiE ".{0,40}($pattern).{0,40}" "$fs/$f" | head -3
        fail=1
    fi
done
[ -n "$matches" ] || echo "none"

if [ "$fail" -ne 0 ]; then
    echo "FAIL: the image references an old image"
    exit 1
fi
echo "OK: no reference to nirgf/speedtest-tracker-v2 or $upstream images"
