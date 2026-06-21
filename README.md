# argo-workflows-practice

Argo Workflows を検証するためのリポジトリです。以下 2 パターンを用意しています。

- Local: `kind` でローカル Kubernetes クラスタを起動して検証
- GKE: Google Kubernetes Engine 上で検証

## ディレクトリ構成

- `workflows/`: サンプル Workflow
- `events/`: Argo Events サンプル（Webhook -> Workflow）
- `scripts/local/`: ローカル検証用スクリプト
- `scripts/gke/`: GKE 検証用スクリプト
- `infra/gke/`: GKE クラスタを作成する Terraform

## 前提ツール

### Local

- `docker`
- `kind`
- `kubectl`

### GKE

- `terraform`
- `gcloud`
- `kubectl`
- Google Cloud プロジェクト（課金有効）

## Local で検証する

1) ローカルクラスタ作成 + Argo Workflows インストール

```bash
./scripts/local/setup.sh
```
このスクリプトは Argo Workflows と Argo CD の両方をインストールします。

2) サンプル Workflow を実行

```bash
kubectl create -n argo -f workflows/hello-world.yaml
kubectl get wf -n argo
```

CronWorkflow も試す場合:

```bash
kubectl apply -n argo -f workflows/cron-hello-world.yaml
kubectl get cronwf -n argo
kubectl get wf -n argo
```

3) Argo UI を確認（任意）

```bash
kubectl -n argo port-forward service/argo-server 2746:2746
```

ブラウザで [https://localhost:2746](https://localhost:2746) を開きます。

4) 後片付け

```bash
./scripts/local/teardown.sh
```

## GKE で検証する

事前に `gcloud auth login` / `gcloud auth application-default login` を実行してください。
クラスタ構築は Terraform で行います。
また、state は `infra/gke/backend.tf` により GCS バックエンドを使う想定です。

1) クラスタ作成 + Argo Workflows インストール

```bash
terraform -chdir=infra/gke init \
  -backend-config="bucket=<your-terraform-state-bucket>" \
  -backend-config="prefix=argo-workflows-practice/gke"
```

次に以下を実行します。

```bash
TF_STATE_BUCKET=<your-terraform-state-bucket> \
PROJECT_ID=<your-gcp-project-id> \
REGION=asia-northeast1 \
CLUSTER_NAME=argo-workflows-lab \
NETWORK_NAME=argo-gke-vpc \
SUBNETWORK_NAME=argo-gke-subnet \
SUBNETWORK_CIDR=10.10.0.0/20 \
./scripts/gke/setup.sh
```
このスクリプトは Argo Workflows と Argo CD の両方をインストールします。

必要なら `infra/gke/terraform.tfvars.example` をコピーして `infra/gke/terraform.tfvars` を作成し、`TF_DIR=infra/gke` のまま `setup.sh` / `teardown.sh` を実行できます。

2) サンプル Workflow を実行

```bash
kubectl create -n argo -f workflows/hello-world.yaml
kubectl get wf -n argo
```

CronWorkflow も試す場合:

```bash
kubectl apply -n argo -f workflows/cron-hello-world.yaml
kubectl get cronwf -n argo
kubectl get wf -n argo
```

3) 後片付け（課金停止のため推奨）

```bash
TF_STATE_BUCKET=<your-terraform-state-bucket> \
PROJECT_ID=<your-gcp-project-id> \
REGION=asia-northeast1 \
CLUSTER_NAME=argo-workflows-lab \
./scripts/gke/teardown.sh
```

## メモ

- Argo Workflows のバージョンは各セットアップスクリプト内の `ARGO_VERSION` で変更できます。
- 検証時は `argo` namespace にリソースを作成します。
- GKE 破棄は `terraform destroy` 相当を `scripts/gke/teardown.sh` で実行します。
- Argo Workflows 単体の検証に Argo CD は必須ではありません。GitOps 運用（WorkflowTemplate などを Git から同期）をしたい場合に導入を検討します。
- `workflows/cron-hello-world.yaml` は 5 分ごとに Workflow を起動します。停止するときは `kubectl delete -n argo -f workflows/cron-hello-world.yaml` を実行してください。

## GKE の運用寄り設定

`infra/gke/main.tf` は、検証用の最小構成より一段運用を意識して以下を有効化しています。

- クラスタ専用 VPC / Subnet を作成（デフォルト VPC 依存を避ける）
- Pod / Service 用の secondary IP range（VPC-native / alias IP）
- GKE release channel（デフォルト: `REGULAR`）
- Workload Identity（`<project>.svc.id.goog`）
- Node Pool の自動修復 / 自動アップグレード

必要に応じて `infra/gke/terraform.tfvars` で CIDR や release channel を調整してください。

VPC だけ先に構築したい場合は、以下のように target を使って適用できます。

```bash
terraform -chdir=infra/gke apply \
  -var="project_id=<your-gcp-project-id>" \
  -var="region=asia-northeast1" \
  -target=google_compute_network.gke \
  -target=google_compute_subnetwork.gke
```

## Argo Events を試す

1) Argo Events をインストール

```bash
kubectl create namespace argo-events
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install-validating-webhook.yaml
```

2) EventBus / EventSource / Sensor / RBAC / WorkflowTemplate を作成

```bash
kubectl apply -n argo-events -f events/eventbus.yaml
kubectl apply -n argo -f workflows/webhook-message-template.yaml
kubectl apply -f events/rbac-sensor-workflow-trigger.yaml
kubectl apply -n argo-events -f events/eventsource-webhook.yaml
kubectl apply -n argo-events -f events/sensor-webhook-workflow.yaml
```

3) Webhook でイベント送信

```bash
kubectl -n argo-events port-forward svc/webhook-eventsource-svc 12000:12000
```

別ターミナルで以下を実行:

```bash
curl -X POST http://localhost:12000/hook \
  -H "Content-Type: application/json" \
  -d '{"message":"hello from webhook"}'
```

4) Workflow 作成を確認

```bash
kubectl get wf -n argo
kubectl get pods -n argo-events
```

## Argo CD コンソールへアクセス

`setup.sh` 実行後、以下でアクセスできます。

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

ブラウザで [https://localhost:8080](https://localhost:8080) を開きます（ユーザー名は `admin`）。
初期パスワード:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 --decode; echo
```
