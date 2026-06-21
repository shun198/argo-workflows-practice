#!/usr/bin/env bash

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-asia-northeast1}"
CLUSTER_NAME="${CLUSTER_NAME:-argo-workflows-lab}"
NODE_COUNT="${NODE_COUNT:-2}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-standard-2}"
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
  echo "例: PROJECT_ID=my-project ./scripts/gke/teardown.sh" >&2
  exit 1
fi

if [[ -z "${TF_STATE_BUCKET}" ]]; then
  echo "TF_STATE_BUCKET を指定してください。" >&2
  echo "例: TF_STATE_BUCKET=my-tf-state-bucket PROJECT_ID=my-project ./scripts/gke/teardown.sh" >&2
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform が見つかりません。インストールしてください。" >&2
  exit 1
fi

echo "Terraform で GKE クラスタを削除します"
terraform -chdir="${TF_DIR}" init -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="prefix=${TF_STATE_PREFIX}"
terraform -chdir="${TF_DIR}" destroy -auto-approve \
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

echo "削除完了"
