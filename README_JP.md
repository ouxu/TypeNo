# TypeNo

[English](README.md) | [中文](README_CN.md)

**無料・オープンソースの macOS 向けスマホ入力ツール。**

![TypeNo hero image](assets/hero.webp)

ミニマルな macOS メニューバーアプリ。スマホでローカルページを開いて入力したテキストを、そのまま Mac に送れます。

公式サイト: [https://typeno.com](https://typeno.com)

## 使い方

1. メニューバーから TypeNo を起動
2. **Phone Input** を有効にしたままにする
3. スマホでローカルリンクを開く
4. スマホのページで入力して送信する
5. アクセシビリティ権限があればアクティブな Mac アプリに直接ペーストされ、なければクリップボードにコピーされます

## インストール

### 方法 1：アプリをダウンロード

- [TypeNo for macOS をダウンロード](https://github.com/marswaveai/TypeNo/releases/latest)
- 最新の `TypeNo.app.zip` をダウンロード
- 解凍して `TypeNo.app` を `/Applications` に移動
- TypeNo を起動

TypeNo は Apple の署名と公証済みです。警告なしでそのまま開けます。

### 初回起動

TypeNo で必要になる可能性がある権限は 1 つだけです：
- **アクセシビリティ** — スマホから送ったテキストをアクティブなアプリに直接貼り付けたい場合に必要です

アクセシビリティ権限がなくても、テキストはクリップボードにコピーされます。

### トラブルシューティング：アクセシビリティ権限が有効にならない

**システム設定 → プライバシーとセキュリティ → アクセシビリティ** で TypeNo を有効にしても反応しない場合があります — macOS の既知のバグです。対処法：

1. リストで **TypeNo** を選択
2. **−** をクリックして削除
3. **+** をクリックして `/Applications` から TypeNo を再追加

![アクセシビリティ権限の修正](assets/accessibility-fix.gif)

### 方法 2：ソースからビルド

```bash
git clone https://github.com/marswaveai/TypeNo.git
cd TypeNo
scripts/generate_icon.sh
scripts/build_app.sh
```

アプリは `dist/TypeNo.app` に生成されます。権限を維持するため `/Applications/` に移動してください。

## 操作方法

| 操作 | トリガー |
|---|---|
| スマホ入力の有効/無効 | メニューバー → Enable/Disable Phone Input |
| この Mac でスマホページを開く | メニューバー → Open Phone Page |
| ローカルリンクをコピー | メニューバー → Copy Link |
| 直接ペースト権限を開く | メニューバー → Enable Paste Permission |
| アップデート確認 | メニューバー → Check for Updates... |
| 終了 | メニューバー → Quit（`⌘Q`） |

## 設計思想

TypeNo がやることはひとつだけです：スマホ入力 → Mac 挿入。録音も音声エンジンもなく、用途を絞ったユーティリティにしています。

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=marswaveai/TypeNo&type=Date)](https://star-history.com/#marswaveai/TypeNo&Date)

## ライセンス

GNU General Public License v3.0
