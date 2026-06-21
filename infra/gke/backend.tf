terraform {
  # GCS remote backend.
  # 実際の bucket / prefix は terraform init 時の -backend-config で渡します。
  backend "gcs" {}
}
