#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-argo-local}"

if ! command -v kind >/dev/null 2>&1; then
  echo "kind が見つかりません。インストールしてください。" >&2
  exit 1
fi

echo "kind クラスタ ${CLUSTER_NAME} を削除します"
kind delete cluster --name "${CLUSTER_NAME}"
echo "削除完了"
