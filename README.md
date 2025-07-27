# F-RevoCRM-GCP

F-RevoCRM を Google Cloud Platform (GCP) 上にデプロイするための Terraform ベースのインフラストラクチャコードとデプロイメント自動化ツール

## 概要

このリポジトリは以下を提供します：

- F-RevoCRM アプリケーションの Docker コンテナ化
- GCP 上でのスケーラブルなインフラストラクチャ（Load Balancer、Compute Engine、SSL証明書）
- Docker Hub への自動イメージプッシュ
- 2段階デプロイメント（グローバルIP確定 → DNS設定 → SSL有効化）
- GitHub Codespaces での開発環境

## アーキテクチャ

```
Internet → Cloud Load Balancer → Managed Instance Group → Container Optimized OS → F-RevoCRM Docker Container
```

- **Load Balancer**: HTTP/HTTPS トラフィックの負荷分散
- **Managed Instance Group**: オートスケーリングとヘルスチェック
- **Container Optimized OS**: セキュアなコンテナ実行環境
- **Managed SSL Certificate**: 無償のサーバ証明書

## 前提条件

### 必要なアカウント・権限

1. **Google Cloud Platform**
   - プロジェクトの作成権限
   - Compute Engine、Certificate Manager API の有効化権限
   - サービスアカウントの作成・管理権限

2. **Docker Hub**
   - 組織アカウントまたは個人アカウント
   - パブリックリポジトリの作成権限

3. **DNS プロバイダー**
   - ドメインの管理権限
   - A レコードの追加権限

## セットアップ手順

### 1. GitHub Codespaces Secrets の設定

GitHub リポジトリの Settings > Secrets and variables > Codespaces で以下のシークレットを設定：

#### 必須シークレット

| シークレット名 | 説明 | 例 |
|---|---|---|
| `GCP_PROJECT_ID` | GCP プロジェクト ID | `my-project-12345` |
| `GCP_SERVICE_ACCOUNT_KEY` | GCP サービスアカウントキー（Base64エンコード） | `ewogICJ0eXBlIjogInNlcnZpY2VfYWN...` |
| `DOMAIN_NAME` | アプリケーションのドメイン名 | `myapp.example.com` |
| `DOCKERHUB_USERNAME` | Docker Hub ユーザー名または組織名 | `myorg` |
| `DOCKERHUB_TOKEN` | Docker Hub アクセストークン | `dckr_pat_1234567890abcdef` |

#### GCP サービスアカウントキーの作成方法

1. GCP Console でサービスアカウントを作成
2. 以下の権限を付与：
   ```
   - Compute Admin
   - Security Admin
   - Service Account User
   - Project Editor
   ```
3. キーを JSON 形式でダウンロード
4. Base64 でエンコード：
   ```bash
   base64 -w 0 path/to/service-account-key.json
   ```

#### Docker Hub アクセストークンの作成方法

1. Docker Hub にログイン
2. Account Settings > Security > New Access Token
3. Read, Write, Delete 権限を選択

### 2. Codespaces の起動

1. GitHub リポジトリで「Code」→「Codespaces」→「Create codespace」
2. 自動的に開発環境がセットアップされます

### 3. デプロイメント実行

#### オプション 1: Make コマンドを使用（推奨）

```bash
# 1. Docker イメージのビルドとプッシュ
make build

# 2. 第一フェーズデプロイ（グローバルIP確定）
make phase1

# 3. DNS設定（手動）
# 出力されたグローバルIPをドメインのAレコードに設定

# 4. 第二フェーズデプロイ（SSL有効化）
make phase2
```

#### オプション 2: スクリプトを直接実行

```bash
# 1. Docker イメージのビルドとプッシュ
./scripts/deploy.sh build

# 2. 第一フェーズデプロイ
./scripts/deploy.sh phase1

# 3. DNS設定後、第二フェーズデプロイ
./scripts/deploy.sh phase2
```

#### オプション 3: 一括デプロイ（第一フェーズのみ）

```bash
make deploy
# または
./scripts/deploy.sh all
```

### 4. DNS設定

第一フェーズデプロイ完了後、以下の手順でDNS設定を行います：

1. デプロイ出力からグローバルIPアドレスを確認
2. DNS プロバイダーでAレコードを追加：
   ```
   タイプ: A
   名前: myapp (ドメインが myapp.example.com の場合)
   値: <グローバルIPアドレス>
   TTL: 300 (5分)
   ```
3. DNS の浸透を確認：
   ```bash
   nslookup myapp.example.com
   # または
   dig myapp.example.com
   ```

### 5. SSL証明書の確認

第二フェーズデプロイ後、SSL証明書のステータスを確認：

```bash
make ssl-status
# または
cd terraform && terraform output ssl_certificate_status
```

証明書が `ACTIVE` になるまで最大15分程度かかる場合があります。

## 利用可能なコマンド

### Make コマンド

```bash
make help          # ヘルプ表示
make build         # Docker イメージビルド・プッシュ
make phase1        # 第一フェーズデプロイ
make phase2        # 第二フェーズデプロイ
make deploy        # 一括デプロイ（第一フェーズのみ）
make destroy       # リソース削除
make status        # デプロイ状況確認
make ssl-status    # SSL証明書状況確認
make logs          # アプリケーションログ表示
make health        # ヘルスチェック
```

### Terraform コマンド

```bash
cd terraform
terraform init     # 初期化
terraform plan     # 実行プラン表示
terraform apply    # 適用
terraform output   # 出力値表示
terraform destroy  # リソース削除
```

## ファイル構成

```
.
├── .devcontainer/
│   ├── devcontainer.json    # Codespaces設定
│   └── post-create.sh       # 環境セットアップスクリプト
├── .github/
│   └── workflows/
│       └── deploy.yml       # GitHub Actions ワークフロー
├── scripts/
│   └── deploy.sh           # デプロイメントスクリプト
├── terraform/
│   ├── providers.tf        # プロバイダー設定
│   ├── variables.tf        # 変数定義
│   ├── network.tf          # ネットワーク設定
│   ├── compute.tf          # コンピュートリソース
│   ├── outputs.tf          # 出力定義
│   └── container-declaration.yaml # コンテナ設定
├── Dockerfile              # アプリケーションコンテナ
├── Makefile               # ビルド・デプロイタスク
├── package.json           # Node.js設定
├── index.js              # アプリケーションコード（サンプル）
└── README.md             # このファイル
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. SSL証明書が ACTIVE にならない

**原因**: DNS設定が正しくない、または浸透していない

**解決方法**:
```bash
# DNS確認
nslookup <ドメイン名>
dig <ドメイン名>

# SSL証明書ステータス確認
make ssl-status
```

#### 2. Docker イメージプッシュが失敗する

**原因**: Docker Hub認証情報が正しくない

**解決方法**:
```bash
# 認証情報確認
docker login
echo $DOCKERHUB_TOKEN | docker login -u $DOCKERHUB_USERNAME --password-stdin
```

#### 3. GCP認証エラー

**原因**: サービスアカウントキーが正しくない、または権限不足

**解決方法**:
```bash
# サービスアカウント確認
gcloud auth list
gcloud config get-value project

# 権限確認
gcloud projects get-iam-policy $GCP_PROJECT_ID
```

#### 4. Terraform エラー

**原因**: APIが有効化されていない、またはリソース制限

**解決方法**:
```bash
# API有効化確認
gcloud services list --enabled

# 必要なAPI有効化
gcloud services enable compute.googleapis.com
gcloud services enable certificatemanager.googleapis.com
```

### ログ確認

```bash
# アプリケーションログ
make logs

# Terraform状態
terraform show

# GCP コンソール
# https://console.cloud.google.com/
```

## セキュリティ考慮事項

- サービスアカウントキーは適切に管理し、定期的にローテーションしてください
- Docker Hub トークンには最小限の権限のみを付与してください
- ファイアウォールルールは必要最小限に留めてください
- SSL証明書は自動更新されますが、期限切れ通知を設定することを推奨します

## コスト最適化

- 本番環境以外では `make destroy` でリソースを削除してください
- Instance Group のスケーリング設定を適切に調整してください
- 不要なログやメトリクスは無効化を検討してください

## サポート

問題が発生した場合は、以下を確認してください：

1. [GCP公式ドキュメント](https://cloud.google.com/docs)
2. [Terraform GCP プロバイダー](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
3. GitHub Issues でのバグレポート

## ライセンス

MIT License
