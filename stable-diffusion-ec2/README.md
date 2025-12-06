# Stable Diffusion on AWS EC2 Spot Instance - Setup Guide

## 概要

このセットアップは AWS CloudFormation を使用して、EC2 スポットインスタンス上に Stable Diffusion の推論環境を自動構築します。

**特徴：**
- ✅ スポットインスタンスで最大 70% コスト削減
- ✅ CloudFormation でワンコマンドデプロイ
- ✅ FastAPI による REST API インターフェース
- ✅ S3 統合による推論結果の永続化
- ✅ 自動セットアップ（UserData スクリプト）

**コスト目安（us-east-1 での例）：**
- g4dn.xlarge オンデマンド: $0.526/時間
- g4dn.xlarge スポット（平均70%割引）: 約 $0.16/時間

## 前提条件

### 1. AWS アカウント準備

#### EC2 GPU インスタンス クォータ増加

スポットインスタンスの g4dn.xlarge は 4 vCPU を使用します。デフォルトクォータ（0）では起動できません。

```bash
# CLI でクォータ増加を申請
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-3819A6DF \
  --desired-value 4
```

または AWS Console から：
1. **Service Quotas** に移動
2. 検索：「All G and VT Spot Instance Requests」
3. 「Request quota increase」をクリック
4. 希望値を「4」に設定
5. 申請（通常 1-2 時間で承認）

#### EC2 キーペア作成

```bash
# キーペア作成
aws ec2 create-key-pair \
  --key-name stable-diffusion-key \
  --query 'KeyMaterial' \
  --output text > stable-diffusion-key.pem

# パーミッション設定
chmod 400 stable-diffusion-key.pem
```

### 2. ローカル環境準備

```bash
# AWS CLI インストール
# macOS
brew install awscli

# Linux/Windows は公式ドキュメント参照

# AWS CLI 設定
aws configure
# 以下を入力：
# AWS Access Key ID: [your-access-key]
# AWS Secret Access Key: [your-secret-key]
# Default region: us-east-1  (好みのリージョン)
# Default output format: json
```

## デプロイ手順

### ステップ 1: CloudFormation スタック作成

```bash
# テンプレートをデプロイ
aws cloudformation create-stack \
  --stack-name stable-diffusion-stack \
  --template-body file://template.yaml \
  --parameters \
    ParameterKey=KeyPairName,ParameterValue=stable-diffusion-key \
    ParameterKey=InstanceType,ParameterValue=g4dn.xlarge \
    ParameterKey=SpotMaxPrice,ParameterValue=0.50 \
    ParameterKey=ModelName,ParameterValue=runwayml/stable-diffusion-v1-5 \
    ParameterKey=AllowedSSHCIDR,ParameterValue=YOUR_IP/32 \
  --capabilities CAPABILITY_NAMED_IAM
```

**パラメータ説明：**
- `KeyPairName`: 作成した EC2 キーペア名
- `InstanceType`: g4dn.xlarge (VRAM 16GB) または g4dn.2xlarge (VRAM 24GB)
- `SpotMaxPrice`: スポット入札上限 USD/時間
- `ModelName`: Hugging Face モデルID（デフォルト: runwayml/stable-diffusion-v1-5）
- `AllowedSSHCIDR`: SSH アクセス許可範囲（本番は IP を限定）

### ステップ 2: スタック作成確認

```bash
# スタック状態確認
aws cloudformation describe-stacks \
  --stack-name stable-diffusion-stack \
  --query 'Stacks[0].StackStatus'

# CREATE_COMPLETE になるまで待機（10-15 分）
```

### ステップ 3: インスタンス情報取得

```bash
# 出力値取得
aws cloudformation describe-stacks \
  --stack-name stable-diffusion-stack \
  --query 'Stacks[0].Outputs'

# 以下の情報が表示されます：
# - InstanceId: i-xxxxxxxxxx
# - PublicIP: xx.xx.xx.xx
# - APIEndpoint: http://xx.xx.xx.xx:8000/docs
# - S3BucketName: stable-diffusion-xxxxxx-region
```

### ステップ 4: インスタンスセットアップ確認

```bash
# EC2 インスタンスに SSH 接続
ssh -i stable-diffusion-key.pem ubuntu@<PublicIP>

# セットアップ進捗確認
tail -f /var/log/user-data.log

# セットアップ完了確認
ls -la /opt/stable-diffusion/setup-complete.txt
```

**セットアップ時間目安：**
- NVIDIA ドライバインストール: 3-5 分
- PyTorch + CUDA 環境: 5-10 分
- モデルダウンロード: 2-5 分（モデルサイズに依存）
- **合計: 約 15-25 分**

## API 使用方法

### 1. ヘルスチェック

```bash
curl http://<PublicIP>:8000/health

# 応答例：
# {"status":"ok","device":"cuda","model":"runwayml/stable-diffusion-v1-5"}
```

### 2. 画像生成（ファイル返却）

```bash
curl -X POST http://<PublicIP>:8000/generate \
  -F "prompt=a beautiful landscape painting" \
  -F "negative_prompt=blurry, low quality" \
  -F "num_inference_steps=50" \
  -F "guidance_scale=7.5" \
  --output output.png
```

### 3. 画像生成（JSON + S3 保存）

```bash
curl -X POST http://<PublicIP>:8000/generate-json \
  -F "prompt=a cat wearing a hat" \
  -F "num_inference_steps=50" \
  -F "guidance_scale=7.5"

# 応答例：
# {
#   "status": "success",
#   "image_id": "uuid-string",
#   "s3_url": "s3://stable-diffusion-xxxxx-region/results/uuid.png",
#   "prompt": "a cat wearing a hat"
# }
```

### 4. インタラクティブ API ドキュメント

ブラウザで以下にアクセス：
```
http://<PublicIP>:8000/docs
```

Swagger UI で API をテストできます。

## Python クライアント例

```python
import requests
from PIL import Image
import io

API_URL = "http://<PublicIP>:8000"

# 画像生成
response = requests.post(
    f"{API_URL}/generate",
    files={
        "prompt": (None, "a futuristic city at sunset"),
        "negative_prompt": (None, "blurry, distorted"),
        "num_inference_steps": (None, "50"),
        "guidance_scale": (None, "7.5"),
    }
)

# 画像を表示
if response.status_code == 200:
    image = Image.open(io.BytesIO(response.content))
    image.show()
else:
    print(f"Error: {response.status_code} - {response.text}")
```

## トラブルシューティング

### 1. インスタンスが起動しない

```bash
# CloudFormation イベント確認
aws cloudformation describe-stack-events \
  --stack-name stable-diffusion-stack \
  --query 'StackEvents[0:5]'

# EC2 インスタンス状態確認
aws ec2 describe-instances \
  --filters "Name=tag:aws:cloudformation:stack-name,Values=stable-diffusion-stack" \
  --query 'Reservations[0].Instances[0].State'
```

### 2. セットアップが進まない

```bash
# インスタンスにログイン
ssh -i stable-diffusion-key.pem ubuntu@<PublicIP>

# UserData ログ確認
cat /var/log/cloud-init-output.log
tail -f /var/log/user-data.log

# サービス状態確認
sudo systemctl status stable-diffusion
sudo journalctl -u stable-diffusion -n 50
```

### 3. API への接続ができない

```bash
# セキュリティグループ確認
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=StableDiffusionSG*"

# ポート開放確認
sudo netstat -tlnp | grep 8000

# インスタンスのファイアウォール確認
sudo ufw status
```

### 4. メモリ不足エラー

モデルが VRAM に収まらない場合：
- `--pipeline.enable_attention_slicing()` で最適化（自動実装済み）
- より小さいモデルを使用（例：`stabilityai/stable-diffusion-2-1-base`）
- g4dn.2xlarge（VRAM 24GB）にアップグレード

## コスト管理

### スポットインスタンスを停止する

```bash
# インスタンス停止（スポット = 自動再起動）
aws ec2 stop-instances \
  --instance-ids <InstanceId>

# インスタンス開始
aws ec2 start-instances \
  --instance-ids <InstanceId>
```

### スタック削除（すべてのリソース削除）

```bash
# ⚠️ 注意: S3 バケットを先に空にする必要があります
aws s3 rm s3://<BucketName> --recursive

# CloudFormation スタック削除
aws cloudformation delete-stack \
  --stack-name stable-diffusion-stack

# 削除確認
aws cloudformation list-stacks \
  --query "StackSummaries[?StackName=='stable-diffusion-stack']"
```

## カスタマイズ

### 別のモデルを使用する場合

```bash
# スタック更新
aws cloudformation update-stack \
  --stack-name stable-diffusion-stack \
  --use-previous-template \
  --parameters \
    ParameterKey=ModelName,ParameterValue=stabilityai/stable-diffusion-2-1 \
    UsePreviousValue=true
```

**おすすめモデル：**
- `runwayml/stable-diffusion-v1-5`: 標準（推奨）
- `stabilityai/stable-diffusion-2-1`: より高品質
- `stabilityai/stable-diffusion-2-1-base`: 軽量版
- `OFA-Sys/model-bk`: アニメ向け

### メモリ最適化

`inference_api.py` を編集して：

```python
# enable_attention_slicing() の他に：
pipe.enable_vae_slicing()  # VAE メモリ削減
pipe.enable_xformers_memory_efficient_attention()  # xformers がある場合
```

## パフォーマンス最適化

### 推論速度の改善

1. **ステップ数を減らす**: `num_inference_steps=20-30` で高速化
2. **精度を下げる**: `fp16` 使用（自動実装済み）
3. **キャッシング**: モデルはメモリに保持されるため 2 回目以降は高速

### ベンチマーク（g4dn.xlarge）

- **ウォームアップ**: 初回起動 30-60 秒
- **50 ステップ推論**: 約 20-30 秒
- **20 ステップ推論**: 約 8-10 秒

## サポートとリソース

- **Hugging Face Models**: https://huggingface.co/models
- **Diffusers Documentation**: https://huggingface.co/docs/diffusers
- **AWS EC2 Pricing**: https://aws.amazon.com/ec2/pricing/on-demand/
- **AWS CloudFormation**: https://docs.aws.amazon.com/cloudformation/

## ライセンス

Stable Diffusion は Creative ML OpenRAIL M ライセンスで配布されています。
詳細: https://huggingface.co/spaces/CompVis/stable-diffusion-license
