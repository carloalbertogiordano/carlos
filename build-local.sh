#!/bin/bash
# Local build script — uses podman layer cache for fast iteration
# First build: ~30-40 min (cold). Subsequent builds with only config/skel changes: ~3-5 min.
set -euo pipefail

TAG="${1:-carlos:local}"

echo "==> Building $TAG"
echo "==> Layer cache: ~/.local/share/containers/storage (persists between runs)"

podman build \
    --layers \
    --cap-add=ALL \
    --security-opt label=disable \
    --tag "$TAG" \
    .

echo ""
echo "==> Done: $TAG"
echo "==> To run a shell in the image:"
echo "    podman run --rm -it $TAG bash"
echo "==> To test bootc lint:"
echo "    podman run --rm -it $TAG bootc container lint"
