#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-argo-local}"
ARGO_NAMESPACE="${ARGO_NAMESPACE:-argo}"
ARGO_VERSION="${ARGO_VERSION:-v3.7.10}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v2.14.11}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIND_CONFIG_FILE="${SCRIPT_DIR}/kind-config.yaml"

if ! command -v kind >/dev/null 2>&1; then
  echo "kind が見つかりません。インストールしてください。" >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl が見つかりません。インストールしてください。" >&2
  exit 1
fi

if ! kind get clusters | awk -v name="${CLUSTER_NAME}" '$0 == name { found=1 } END { exit !found }'; then
  echo "kind クラスタ ${CLUSTER_NAME} を作成します"
  kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG_FILE}"
else
  echo "kind クラスタ ${CLUSTER_NAME} は既に存在します"
fi

# 1) create --dry-run=client -o yaml で「作成マニフェストだけ」を生成し（実作成はしない）
# 2) その YAML を apply することで、初回は作成・2回目以降は unchanged になり安全に再実行できる
kubectl create namespace "${ARGO_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "Argo Workflows ${ARGO_VERSION} をインストールします"
kubectl apply -n "${ARGO_NAMESPACE}" -f "https://raw.githubusercontent.com/argoproj/argo-workflows/${ARGO_VERSION}/manifests/quick-start-minimal.yaml"

# workflow-controller(ワークフローの実行を担当) と argo-server(UIを提供) が ready になるのを待つ
# https://argo-workflows.readthedocs.io/en/latest/architecture/#argo-workflow-overview
kubectl -n "${ARGO_NAMESPACE}" rollout status deployment/workflow-controller --timeout=180s
kubectl -n "${ARGO_NAMESPACE}" rollout status deployment/argo-server --timeout=180s

# namespace 作成を冪等化するため、上と同じく dry-run + apply で適用する
kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
echo "Argo CD ${ARGOCD_VERSION} をインストールします"
kubectl apply -n "${ARGOCD_NAMESPACE}" --server-side -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl -n "${ARGOCD_NAMESPACE}" rollout status deployment/argocd-server --timeout=300s
# Argo CD アプリケーションを作成
kubectl apply -n "${ARGOCD_NAMESPACE}" -f argocd/application.yaml

echo "セットアップ完了"
echo "サンプル実行: kubectl create -n ${ARGO_NAMESPACE} -f kubernetes/templates/workflows/hello-world.yaml"
echo "Argo Workflows UI: kubectl -n ${ARGO_NAMESPACE} port-forward service/argo-server 2746:2746"
echo "Argo CD UI: kubectl -n ${ARGOCD_NAMESPACE} port-forward svc/argocd-server 8080:443"
# https://argo-workflows.readthedocs.io/en/latest/access-token/#token-creation
echo "Argo Workflows, Argo CD ユーザ名: admin, 初期パスワード: kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode; echo"
