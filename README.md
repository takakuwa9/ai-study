# AI Study Repository

このリポジトリは、AWS インフラストラクチャを使用した AI 関連のプロジェクトを管理しています。

## 📁 ディレクトリ構成

```
ai-study/
├── stable-diffusion-ec2/        ← Stable Diffusion EC2 スポットインスタンス設定
│   ├── QUICKSTART.md            ← 5分スタートガイド
│   ├── README.md                ← 詳細ドキュメント
│   ├── deploy.sh                ← 自動デプロイスクリプト
│   ├── template.yaml            ← CloudFormation テンプレート
│   ├── client.py                ← API テストクライアント
│   ├── commands.sh              ← AWS CLI コマンド集
│   ├── requirements.txt          ← Python 依存ライブラリ
│   └── FILES.md                 ← ファイル説明
└── README.md                    ← このファイル
```

## 🚀 クイックスタート

### Stable Diffusion EC2 セットアップ

```bash
cd stable-diffusion-ec2
cat QUICKSTART.md
bash deploy.sh
```

詳細は [stable-diffusion-ec2/README.md](stable-diffusion-ec2/README.md) を参照してください。

## 📋 プロジェクト一覧

### 1. Stable Diffusion on EC2 Spot Instance
- **概要**: AWS EC2 スポットインスタンスで Stable Diffusion を実行
- **目的**: コスト効率的に画像生成 API をホスト
- **特徴**:
  - スポットインスタンスで最大 70% コスト削減
  - CloudFormation で IaC 管理
  - FastAPI REST API
  - S3 統合

**セットアップ時間**: 30-40 分  
**月額コスト**: $120-200 (24/7 実行)

[詳細はこちら →](./stable-diffusion-ec2/)

---

## 🔧 共通セットアップ

### 前提条件

```bash
# AWS CLI インストール確認
aws --version

# AWS クレデンシャル設定
aws configure

# Git インストール確認
git --version
```

### リポジトリクローン

```bash
git clone https://github.com/takakuwa9/ai-study.git
cd ai-study
```

---

## 💾 ローカルセットアップ（ai-study フォルダ構造）

```bash
# 1. ai-study フォルダに stable-diffusion-ec2 ディレクトリを作成
mkdir -p stable-diffusion-ec2

# 2. ファイルをコピー（またはダウンロードして配置）
# このリポジトリの stable-diffusion-ec2/ 内のファイルをすべてコピー

# 3. パーミッション設定
chmod +x stable-diffusion-ec2/deploy.sh
chmod +x stable-diffusion-ec2/client.py

# 4. 確認
ls -la stable-diffusion-ec2/
```

---

## 📝 各プロジェクトのステップ

### Stable Diffusion EC2

1. **QUICKSTART.md を読む** (5 分)
   ```bash
   cd stable-diffusion-ec2
   cat QUICKSTART.md
   ```

2. **前提条件セットアップ** (5-10 分)
   - AWS クォータ確認
   - EC2 キーペア作成

3. **自動デプロイ実行** (15 分)
   ```bash
   bash deploy.sh
   ```

4. **セットアップ確認** (1 分)
   ```bash
   python3 client.py --url http://<IP>:8000 --health
   ```

5. **本番運用開始** 🚀

---

## 🔗 リンク

### Stable Diffusion EC2
- [QUICKSTART](./stable-diffusion-ec2/QUICKSTART.md) - 5分スタートガイド
- [README](./stable-diffusion-ec2/README.md) - 詳細ドキュメント
- [FILES](./stable-diffusion-ec2/FILES.md) - ファイル説明

### 外部リソース
- [AWS Documentation](https://docs.aws.amazon.com/)
- [Hugging Face Diffusers](https://huggingface.co/docs/diffusers)
- [Stable Diffusion](https://huggingface.co/CompVis/stable-diffusion-v1-4)
- [CloudFormation Reference](https://docs.aws.amazon.com/cloudformation/)

---

## 💡 トラブルシューティング

各プロジェクトのフォルダ内の README.md を参照してください。

**一般的な問題**:
- AWS CLI エラー → AWS クレデンシャル設定確認
- CloudFormation エラー → テンプレート検証
- インスタンス起動失敗 → GPU クォータ確認

---

## 📊 コスト管理

### Stable Diffusion EC2

**停止中**:
```bash
aws ec2 stop-instances --instance-ids <INSTANCE_ID>
# 費用: EBS ストレージのみ (~$0.40/月)
```

**再開**:
```bash
aws ec2 start-instances --instance-ids <INSTANCE_ID>
```

**削除**:
```bash
# S3 バケット空にする
aws s3 rm s3://<BUCKET_NAME> --recursive

# スタック削除
aws cloudformation delete-stack --stack-name stable-diffusion-stack
```

---

## 🤝 コントリビューション

改善提案やバグ報告は Issue を作成してください。

---

## 📄 ライセンス

各プロジェクトのライセンスを参照。

**Stable Diffusion**: Creative ML OpenRAIL M License

---

## 👤 著者

takakuwa9

---

**最終更新**: 2025年12月6日  
**バージョン**: 1.0.0
