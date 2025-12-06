# Stable Diffusion EC2 Spot - File Overview

## 📁 ファイル一覧

```
stable-diffusion-ec2/
├── QUICKSTART.md              ← 5分スタートガイド
├── README.md                  ← 詳細ドキュメント
├── FILES.md                   ← このファイル
├── deploy.sh                  ← 自動デプロイスクリプト
├── template.yaml              ← CloudFormation テンプレート
├── client.py                  ← API テストクライアント
├── commands.sh                ← AWS CLI コマンド集
└── requirements.txt           ← Python 依存ライブラリ
```

## 📄 各ファイルの役割

### 🚀 デプロイ関連

#### `deploy.sh` (実行推奨)
**目的**: CloudFormation スタックの自動作成  
**実行方法**:
```bash
bash deploy.sh
```
**内容**:
- AWS CLI の確認
- CloudFormation テンプレート検証
- スタック作成コマンド実行
- パラメータの対話的入力
- スタック作成完了待機
- 出力値（IP、API URL）の表示

**前提**:
- AWS CLI インストール済み
- AWS クレデンシャル設定済み
- EC2 キーペア作成済み

---

#### `template.yaml` (IaC)
**目的**: AWS リソース定義（Infrastructure as Code）  
**内容**:
- VPC + Subnet + Route Table
- Security Group
- IAM Role + Instance Profile
- EC2 スポットインスタンス
- S3 バケット

**パラメータ**:
```yaml
KeyPairName          # EC2 SSH キー
InstanceType         # GPU インスタンスタイプ
SpotMaxPrice         # スポット入札額 (USD/時)
ModelName            # Hugging Face モデルID
AllowedSSHCIDR       # SSH アクセス許可範囲
EBSVolumeSize        # ストレージ容量 (GB)
```

**UserData スクリプト内で自動実行**:
- NVIDIA ドライバインストール
- PyTorch + CUDA セットアップ
- Stable Diffusion 環境構築
- FastAPI サーバー起動

---

### 📖 ドキュメント

#### `QUICKSTART.md` (⭐ 最初に読む)
**目的**: 5分で環境構築できる手順書  
**内容**:
- 前提条件チェック
- デプロイ手順（3 ステップ）
- API テスト方法
- トラブルシューティング
- よくある質問

**推奨読了時間**: 5-10 分  
**対象**: 急いでセットアップしたい人

---

#### `README.md` (詳細マニュアル)
**目的**: 全機能・詳細説明  
**内容**:
- 概要とコスト
- 前提条件（AWS クォータなど）
- デプロイ手順（詳細）
- API 使用方法
- Python クライアント例
- トラブルシューティング詳細
- カスタマイズ方法
- パフォーマンス最適化

**推奨読了時間**: 20-30 分  
**対象**: 詳しく理解したい人、トラブルが発生した人

---

#### `FILES.md` (このファイル)
**目的**: ファイル構成と役割の説明  
**いつ読むか**: ファイルの役割を理解したい時

---

### 🧪 テスト・運用ツール

#### `client.py` (API テストクライアント)
**目的**: コマンドラインから API を利用  
**使用例**:
```bash
# ヘルスチェック
python3 client.py --url http://54.1.2.3:8000 --health

# 画像生成（ファイル保存）
python3 client.py \
  --url http://54.1.2.3:8000 \
  --prompt "a beautiful sunset" \
  --output sunset.png

# 画像生成（S3 保存）
python3 client.py \
  --url http://54.1.2.3:8000 \
  --prompt "a cat" \
  --s3

# カスタムパラメータ
python3 client.py \
  --url http://54.1.2.3:8000 \
  --prompt "a cat" \
  --steps 30 \
  --guidance 7.5 \
  --output cat.png
```

**機能**:
- ✅ ヘルスチェック
- ✅ 画像生成（ファイル返却）
- ✅ 画像生成（S3 アップロード）
- ✅ カスタムパラメータ指定

**依存**: `requests`, `pillow`（requirements.txt 参照）

---

#### `commands.sh` (AWS CLI コマンド集)
**目的**: よく使う AWS コマンドをコピペで実行  
**内容**:
- スタック管理（作成、削除、確認）
- EC2 インスタンス操作（開始、停止、再起動）
- S3 バケット操作（一覧、ダウンロード、削除）
- ログ・モニタリング
- コスト管理
- トラブルシューティング

**使用方法**:
各コマンドを単独で実行するか、スクリプトをソース化：
```bash
source commands.sh
```

**含まれるカテゴリ**:
- Stack Management
- EC2 Instance Management
- S3 Bucket Management
- Monitoring & Logs
- SSH Connections
- Security & Access
- Cost Estimation
- Cleanup & Deletion
- Advanced Operations

---

### 📦 依存ライブラリ

#### `requirements.txt`
**用途**: Python パッケージ管理  
**インストール**:
```bash
pip install -r requirements.txt
```

**含まれるライブラリ**:
- `requests>=2.31.0` - HTTP リクエスト
- `pillow>=10.0.0` - 画像処理
- `boto3>=1.28.0` - AWS SDK（S3 アップロード用）

---

## 🚀 セットアップフロー

```
┌─────────────────────────┐
│ 1. ファイル確認          │
│ (このドキュメント)       │
└────────────┬────────────┘
             ↓
┌─────────────────────────┐
│ 2. QUICKSTART.md を読む  │
│ (5 分)                  │
└────────────┬────────────┘
             ↓
┌─────────────────────────┐
│ 3. bash deploy.sh       │
│ (自動デプロイ 15 分)     │
└────────────┬────────────┘
             ↓
┌─────────────────────────┐
│ 4. client.py でテスト    │
│ (1 分)                  │
└────────────┬────────────┘
             ↓
┌─────────────────────────┐
│ 5. 本番運用開始          │
└─────────────────────────┘
```

---

## 📚 推奨読了順序

### 初めてセットアップする場合
1. **このファイル** (5 分) - ファイル構成を理解
2. **QUICKSTART.md** (10 分) - 手順確認
3. **deploy.sh** (実行) - 自動セットアップ
4. **client.py** (実行) - API テスト

### 詳しく理解したい場合
1. **README.md** - 全体的な説明
2. **template.yaml** - AWS リソース確認
3. **commands.sh** - 運用コマンド学習
4. **client.py** - API 実装詳細

### トラブルが発生した場合
1. **README.md** - トラブルシューティングセクション
2. **commands.sh** - デバッグコマンド
3. **AWS Console** - スタック/インスタンス確認

---

## 💡 ファイル変更時の注意

### 編集可能なファイル
```bash
# カスタマイズ推奨
template.yaml         # パラメータ追加など
client.py             # API 拡張など
requirements.txt      # ライブラリ追加など
```

### 変更後は検証
```bash
# CloudFormation テンプレート検証
aws cloudformation validate-template --template-body file://template.yaml

# Python 構文チェック
python3 -m py_compile client.py

# Shell スクリプト検証
bash -n deploy.sh
```

---

## 📝 次のステップ

1. **QUICKSTART.md** で手順を確認
2. **deploy.sh** を実行
3. **client.py** で API テスト
4. 本番運用開始！

---

**総セットアップ時間**: 30-40 分  
**月額コスト**: $120-200 (24/7 実行時)  
**推奨リージョン**: us-east-1
