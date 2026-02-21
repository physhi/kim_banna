#!/usr/bin/env bash
#
# build_all_branches.sh — Build Docker images for all custom Kibana branches
#
# Builds: main (9.4.0), 8.19 (8.19.11), 9.3 (9.3.0)
# Each branch is checked out, built via Dockerfile.build, and tagged.
# The script returns to the original branch when done.
#
# Usage:
#   ./build_all_branches.sh              # Build all branches
#   ./build_all_branches.sh main 8.19    # Build specific branches
#
set -euo pipefail

BRANCHES=("main" "8.19" "9.3")

# Allow overriding branches via arguments
if [[ $# -gt 0 ]]; then
  BRANCHES=("$@")
fi

ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cleanup() {
  echo ""
  echo "==> Returning to branch: $ORIGINAL_BRANCH"
  git checkout "$ORIGINAL_BRANCH" --quiet
}
trap cleanup EXIT

echo "============================================"
echo "  Kibana Custom Docker Build"
echo "  Branches: ${BRANCHES[*]}"
echo "============================================"
echo ""

for branch in "${BRANCHES[@]}"; do
  echo "==> Checking out branch: $branch"
  git checkout "$branch" --quiet

  # Read version from package.json
  VERSION=$(node -e "console.log(require('./package.json').version)")

  # Read Node.js version
  NODE_VERSION=$(cat .node-version)

  IMAGE_TAG="kibana-custom:${branch}"
  IMAGE_TAG_VERSION="kibana-custom:${VERSION}"

  echo "    Version:       $VERSION"
  echo "    Node.js:       $NODE_VERSION"
  echo "    Image tag:     $IMAGE_TAG"
  echo "    Alt tag:       $IMAGE_TAG_VERSION"
  echo ""

  echo "==> Building Docker image for branch: $branch (version $VERSION)"
  docker build \
    -f Dockerfile.build \
    --build-arg NODE_VERSION="$NODE_VERSION" \
    -t "$IMAGE_TAG" \
    -t "$IMAGE_TAG_VERSION" \
    .

  echo ""
  echo "==> Successfully built: $IMAGE_TAG ($IMAGE_TAG_VERSION)"
  echo "--------------------------------------------"
  echo ""
done

echo ""
echo "============================================"
echo "  Build complete! Images:"
echo "============================================"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep kibana-custom || true
echo ""
echo "Run with:"
echo "  docker run -p 5601:5601 kibana-custom:<branch>"
echo ""
