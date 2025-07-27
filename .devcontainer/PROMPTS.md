Codespaces Copilot で Claude Sonnet 4 を使用
# 1. 最初のプロンプト：
F-RevoCRM を GCP 上にデプロイする terraform のコードを作成してください。Codespaces で使用しますので、パラメータは環境変数を参照し、 devcontainer.json で Codespaces を起動時には環境が準備できているようにしてください。terraform や Dockerfile の編集が便利なように devcontainer.json には VSCode の設定も入れてください。F-RevoCRM は Dockerfile でコンテナイメージ化してください。作成したコンテナイメージを Dockerhub に登録するようにしてください。 Dockerhub では組織のチームとそこにデプロイできるアカウントを持っていますので、 アカウントの情報はGithub で Codespaces  secrets として参照できる前提としてください。GCPのプロジェクトも保有していますので、同様にアカウントの情報は Codespaces  secrets として参照できる前提としてください。DNS でインターネット経由 HTTPS でアクセスできるようにしたいので、無償のサーバ証明書をつけるようにしてください。DNS のAレコードは別途追加できる前提としてください。以下の手順でデプロイできるようにしてください。
1. コンテナイメージをビルドして Dockerhub にプッシュ
2. terraform で GCP に第一フェーズデプロイ（グローバルIP確定）
3. DNS にグローバルIPを付与
2. terraform で GCP に第二フェーズデプロイ（サーバ証明書取得&HTTPSポート解放）
secrets に設定する内容も含めて利用手順を README.md にまとめてください。

## 作成した内容の要約
📁 プロジェクト構成
DevContainer設定 - Codespaces での開発環境自動化
Dockerfile - F-RevoCRM のコンテナ化
Terraform設定 - GCP インフラストラクチャの定義
デプロイスクリプト - 2段階デプロイメントの自動化
GitHub Actions - CI/CD パイプライン
Makefile - 便利なコマンド集
詳細なREADME - 完全な利用手順書
🚀 デプロイフロー
第一フェーズ: コンテナビルド → GCPデプロイ → グローバルIP確定
DNSマニュアル設定: 確定したIPをAレコードに追加
第二フェーズ: SSL証明書取得 → HTTPS有効化
🔧 主要機能
✅ Docker Hub への自動プッシュ
✅ GCP Load Balancer + Managed Instance Group
✅ 無償SSL証明書（Let's Encrypt）
✅ オートスケーリング対応
✅ ヘルスチェック機能
✅ ログ監視
✅ 環境変数での設定管理
📋 必要な Secrets
GitHub Codespaces で以下のシークレットを設定してください：

GCP_PROJECT_ID - GCP プロジェクト ID
GCP_SERVICE_ACCOUNT_KEY - GCP サービスアカウントキー（Base64）
DOMAIN_NAME - アプリケーションドメイン
DOCKERHUB_USERNAME - Docker Hub ユーザー名
DOCKERHUB_TOKEN - Docker Hub アクセストークン
これで、F-RevoCRM を安全で拡張性の高いGCP環境にデプロイする準備が整いました！