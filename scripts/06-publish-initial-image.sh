#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1090
source "$ROOT_DIR/config/lab.env"

REPO="$GITHUB_REPOSITORY"

gh workflow run publish-api.yml --repo "$REPO" -f image_tag="$IMAGE_TAG"
sleep 3
RUN_ID=$(gh run list --repo "$REPO" --workflow publish-api.yml --event workflow_dispatch --limit 1 --json databaseId -q '.[0].databaseId')
[[ -n "$RUN_ID" ]] || { echo "No se encontró la ejecución del workflow publish-api.yml" >&2; exit 1; }
gh run watch "$RUN_ID" --repo "$REPO" --exit-status
printf 'Imagen inicial publicada en ACR.\n'
