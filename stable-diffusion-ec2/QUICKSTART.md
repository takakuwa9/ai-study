# Stable Diffusion on EC2 Spot - Quick Start (5 minutes)

## 前提条件（初回のみ）

```bash
# 1. AWS CLI がインストールされていることを確認
aws --version

# 2. AWS クレデンシャル設定
aws configure

# 3. EC2 キーペア作成
aws ec2 create-key-pair \
  --key-name stable-diffusion-key \
  --query 'KeyMaterial' \
  --output text > stable-diffusion-key.pem

chmod 400 stable-diffusion-key.pem

# 4. GPU クォータ確認（必須）
# https://console.aws.amazon.com/servicequotas
# 検索: "All G and VT Spot Instance Requests"
# 値が 4 以上であることを確認
# なければ増加申請（1-2 時間で承認）
```

## デプロイ（3 ステップ）

### ステップ 1: スタック作成

```bash
# このディレクトリで実行
bash deploy.sh

# 対話的に以下を入力：
# - Key Pair Name: stable-diffusion-key
# - Instance Type: g4dn.xlarge (デフォルト可)
# - Spot Max Price: 0.50 (デフォルト可)
# - Model: runwayml/stable-diffusion-v1-5 (デフォルト可)
# - SSH CIDR: 0.0.0.0/0 (テスト用、本番は IP 限定)
# - EBS Size: 100 (デフォルト可)
```

**実行時間: 10-15 分**

### ステップ 2: セットアップ完了待機

```bash
# CloudFormation スタック作成完了確認
aws cloudformation describe-stacks \
  --stack-name stable-diffusion-stack \
  --query 'Stacks[0].StackStatus'
# -> CREATE_COMPLETE が表示されたら OK

# 出力値取得
aws cloudformation describe-stacks \
  --stack-name stable-diffusion-stack \
  --query 'Stacks[0].Outputs' \
  --output table
```

### ステップ 3: インスタンスセットアップ確認

```bash
# 出力から PublicIP を取得して、インスタンスに SSH 接続
ssh -i stable-diffusion-key.pem ubuntu@<PublicIP>

# セットアップ進捗確認
tail -f /var/log/user-data.log

# "Stable Diffusion setup completed!" が表示されたら OK
# (合計 15-25 分)
```

## テスト（1 分）

### ヘルスチェック

```bash
# PublicIP を取得
PUBLIC_IP=$(aws cloudformation describe-stacks \
  --stack-name stable-diffusion-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`PublicIP`].OutputValue' \
  --output text)

# ヘルスチェック
curl http://$PUBLIC_IP:8000/health
# {"status":"ok","device":"cuda","model":"runwayml/stable-diffusion-v1-5"}
```

### 画像生成テスト

```bash
# Python クライアントで生成
python3 client.py \
  --url http://$PUBLIC_IP:8000 \
  --prompt "a beautiful sunset" \
  --output sunset.png

# または curl
curl -X POST http://$PUBLIC_IP:8000/generate \
  -F "prompt=a cat wearing a hat" \
  --output cat.png

# 画像確認
open sunset.png  # macOS
# または
display sunset.png  # Linux
```

### Web UI での確認

ブラウザで以下にアクセス：
```
http://<PublicIP>:8000/docs
```

Swagger UI で API を対話的にテストできます。

## コスト削減

### 使わない時は停止

```bash
# インスタンス停止（データは保持、EBS 料金のみ）
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:aws:cloudformation:stack-name,Values=stable-diffusion-stack" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

aws ec2 stop-instances --instance-ids $INSTANCE_ID

# 再開
aws ec2 start-instances --instance-ids $INSTANCE_ID
```

### 完全削除

```bash
# S3 バケット を空にする
BUCKET=$(aws cloudformation describe-stacks \
  --stack-name stable-diffusion-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
  --output text)

aws s3 rm s3://$BUCKET --recursive

# スタック削除
aws cloudformation delete-stack --stack-name stable-diffusion-stack

# 完了待機
aws cloudformation wait stack-delete-complete \
  --stack-name stable-diffusion-stack
```

## よくある質問

### Q: セットアップが完了しない

```bash
# インスタンスに SSH 接続
ssh -i stable-diffusion-key.pem ubuntu@<PublicIP>

# ログ確認
sudo tail -f /var/log/user-data.log
sudo journalctl -u stable-diffusion -n 50

# サービス状態確認
sudo systemctl status stable-diffusion
```

### Q: API に接続できない

```bash
# セキュリティグループ確認
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=StableDiffusionSG*"

# インスタンスのポート確認
ssh -i stable-diffusion-key.pem ubuntu@<PublicIP>
sudo netstat -tlnp | grep 8000
```

### Q: 異なるモデルを使いたい

```bash
# Hugging Face モデル一覧
# https://huggingface.co/models?other=stable-diffusion

# スタック更新
aws cloudformation update-stack \
  --stack-name stable-diffusion-stack \
  --use-previous-template \
  --parameters \
    ParameterKey=ModelName,ParameterValue=stabilityai/stable-diffusion-2-1 \
    UsePreviousValue=true
```

### Q: 生成速度が遅い

1. **ステップ数を減らす**: `--steps 20` (デフォルト 50)
2. **ガイダンススケール調整**: `--guidance 5.0` (デフォルト 7.5)
3. より小さいモデルを使用

### Q: メモリ不足エラー

より大きいインスタンスタイプを使用：
```bash
# g4dn.2xlarge (VRAM 24GB) に変更
aws cloudformation update-stack \
  --stack-name stable-diffusion-stack \
  --use-previous-template \
  --parameters \
    ParameterKey=InstanceType,ParameterValue=g4dn.2xlarge \
    UsePreviousValue=true
```

## パフォーマンス目安（g4dn.xlarge）

| 設定 | 生成時間 | 品質 |
|------|--------|------|
| 20 steps, guidance 5.0 | 8-10 秒 | 良好 |
| 50 steps, guidance 7.5 | 20-30 秒 | 高品質 |
| 100 steps, guidance 10 | 40-50 秒 | 最高品質 |

## トラブルシューティング

### ステップ 1: スタック状態確認

```bash
aws cloudformation describe-stacks \
  --stack-name stable-diffusion-stack \
  --query 'Stacks[0].[StackStatus,StackStatusReason]'
```

**CREATE_IN_PROGRESS**: デプロイ中（待機）
**CREATE_COMPLETE**: 成功
**CREATE_FAILED**: エラー（詳細確認）
**ROLLBACK_COMPLETE**: 失敗して自動ロールバック

### ステップ 2: イベント確認

```bash
aws cloudformation describe-stack-events \
  --stack-name stable-diffusion-stack \
  --query 'StackEvents[0:10]' \
  --output table
```

### ステップ 3: インスタンス状態確認

```bash
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:aws:cloudformation:stack-name,Values=stable-diffusion-stack" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

aws ec2 describe-instances --instance-ids $INSTANCE_ID --output table
```

### ステップ 4: UserData ログ確認

```bash
ssh -i stable-diffusion-key.pem ubuntu@<PublicIP>
cat /var/log/user-data.log
cat /var/log/cloud-init-output.log
```

## ファイル一覧

```
stable-diffusion-ec2-spot/
├── template.yaml           # CloudFormation テンプレート
├── deploy.sh              # デプロイスクリプト（実行推奨）
├── client.py              # API テストクライアント
├── commands.sh            # AWS CLI コマンド集
├── README.md              # 詳細ドキュメント
└── QUICKSTART.md          # このファイル
```

## 次のステップ

1. ✅ CloudFormation スタック作成
2. ✅ インスタンスセットアップ確認
3. ✅ API テスト実行
4. → 本番運用開始
5. → カスタマイズ（モデル、パラメータ）

## サポート

- **問題が発生したら**: README.md のトラブルシューティングを参照
- **詳細情報**: https://huggingface.co/docs/diffusers
- **AWS ドキュメント**: https://docs.aws.amazon.com/ec2/

---

**推定デプロイ時間**: 25 分
**最初の画像生成**: ~30 秒
**推定月額コスト**: $150-200（24/7 稼働時）
