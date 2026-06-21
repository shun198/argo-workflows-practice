#!/usr/bin/env bash

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-asia-northeast1}"
CLUSTER_NAME="${CLUSTER_NAME:-argo-workflows-lab}"
NODE_COUNT="${NODE_COUNT:-2}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-standard-2}"
ARGO_NAMESPACE="${ARGO_NAMESPACE:-argo}"
ARGO_VERSION="${ARGO_VERSION:-v3.6.8}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v2.14.11}"
TF_DIR="${TF_DIR:-infra/gke}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:-}"
TF_STATE_PREFIX="${TF_STATE_PREFIX:-argo-workflows-practice/gke}"
NETWORK_NAME="${NETWORK_NAME:-argo-gke-vpc}"
SUBNETWORK_NAME="${SUBNETWORK_NAME:-argo-gke-subnet}"
SUBNETWORK_CIDR="${SUBNETWORK_CIDR:-10.10.0.0/20}"
PODS_SECONDARY_RANGE_NAME="${PODS_SECONDARY_RANGE_NAME:-gke-pods}"
PODS_SECONDARY_CIDR="${PODS_SECONDARY_CIDR:-10.20.0.0/16}"
SERVICES_SECONDARY_RANGE_NAME="${SERVICES_SECONDARY_RANGE_NAME:-gke-services}"
SERVICES_SECONDARY_CIDR="${SERVICES_SECONDARY_CIDR:-10.30.0.0/20}"
RELEASE_CHANNEL="${RELEASE_CHANNEL:-REGULAR}"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "PROJECT_ID を指定してください。" >&2
  echo "例: PROJECT_ID=my-project ./scripts/gke/setup.sh" >&2
  exit 1
fi

if [[ -z "${TF_STATE_BUCKET}" ]]; then
  echo "TF_STATE_BUCKET を指定してください。" >&2
  echo "例: TF_STATE_BUCKET=my-tf-state-bucket PROJECT_ID=my-project ./scripts/gke/setup.sh" >&2
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform が見つかりません。インストールしてください。" >&2
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud が見つかりません。インストールしてください。" >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl が見つかりません。インストールしてください。" >&2
  exit 1
fi

echo "Terraform で GKE クラスタを作成/更新します"
terraform -chdir="${TF_DIR}" init -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="prefix=${TF_STATE_PREFIX}"
terraform -chdir="${TF_DIR}" apply -auto-approve \
  -var="project_id=${PROJECT_ID}" \
  -var="region=${REGION}" \
  -var="cluster_name=${CLUSTER_NAME}" \
  -var="node_count=${NODE_COUNT}" \
  -var="machine_type=${MACHINE_TYPE}" \
  -var="network_name=${NETWORK_NAME}" \
  -var="subnetwork_name=${SUBNETWORK_NAME}" \
  -var="subnetwork_cidr=${SUBNETWORK_CIDR}" \
  -var="pods_secondary_range_name=${PODS_SECONDARY_RANGE_NAME}" \
  -var="pods_secondary_cidr=${PODS_SECONDARY_CIDR}" \
  -var="services_secondary_range_name=${SERVICES_SECONDARY_RANGE_NAME}" \
  -var="services_secondary_cidr=${SERVICES_SECONDARY_CIDR}" \
  -var="release_channel=${RELEASE_CHANNEL}"

# https://docs.cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl?hl=ja
echo "kubectl コンテキストを取得します（gcloud）"
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --project "${PROJECT_ID}"

kubectl create namespace "${ARGO_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "Argo Workflows ${ARGO_VERSION} をインストールします"
kubectl apply -n "${ARGO_NAMESPACE}" -f "https://raw.githubusercontent.com/argoproj/argo-workflows/${ARGO_VERSION}/manifests/quick-start-minimal.yaml"

kubectl -n "${ARGO_NAMESPACE}" rollout status deployment/workflow-controller --timeout=300s
kubectl -n "${ARGO_NAMESPACE}" rollout status deployment/argo-server --timeout=300s

kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
echo "Argo CD ${ARGOCD_VERSION} をインストールします"
kubectl apply -n "${ARGOCD_NAMESPACE}" -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl -n "${ARGOCD_NAMESPACE}" rollout status deployment/argocd-server --timeout=600s

echo "セットアップ完了"
echo "サンプル実行: kubectl create -n ${ARGO_NAMESPACE} -f workflows/hello-world.yaml"
echo "Argo CD UI: kubectl -n ${ARGOCD_NAMESPACE} port-forward svc/argocd-server 8080:443"
echo "Argo CD 初期パスワード: kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode; echo"
