# Omarchy Keyguide

[English](README.md) · [한국어](README.ko.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md)

> 公開リポジトリ：<https://github.com/mrai125kr/omarchy-keyguide>

Omarchy Keyguide は、Omarchy 用のショートカット案内 HUD と、安全範囲を限定
したショートカットエディターです。`Super` と `Ctrl`・`Shift`・`Alt` による
8 種類の組み合わせを押すと、現在有効なショートカットだけを表示します。
入力を奪取・消費・合成せず、Omarchy のユーザー `bindings.lua` を直接変更
しません。

## 主な機能

- HUD の位置、倍率、透明度、テーマ連動、表示グループ、個別行の設定
- 空きキーは中央ポップアップで登録し、既存キーはその行の近くで変更・削除
- 一般アクション、インストール済みアプリ、コマンドを 1 つの検索欄から登録
- 英語（既定）、韓国語、日本語、簡体字中国語、スペイン語で設定と HUD を表示
- メニューに出ないバインドも含む Hyprland ランタイム全体での重複検査
- 現在の XKB キーボード配列に基づく物理 `code:` キーの衝突検査
- Keyguide の初期設定、移動前のキー、新規追加キーをまとめてリセット
- 衝突、同時変更、リロード不一致が起きた場合の正確なロールバック

設定画面には、修飾キーグループごとの現在のバインドが表示されます。キー選択
欄で空きキーを選ぶと中央に登録ポップアップが開き、既存行の `Change` を押す
と同じ編集ポップアップがその行の近くに開きます。各キーは `Free` または
`Assigned — <タイトル>` と表示されます。割り当て済みキーには、編集可能な
タイトル、アクションの種類と引数、`Current key`、`Omarchy default` または
`Managed by Keyguide` の状態が表示されます。各行の `Shown`/`Hidden`、
`Change`、`Remove`（削除）は独立して操作できます。削除後、その組み合わせは
空きキーになり、復元可能な元のバインドは `Reset all` で戻せます。

空きキーでは、1 つの検索欄から安全に再構築できる Omarchy アクション、
インストール済みのグラフィカルアプリ、または実行コマンドを選択できます。
一般アクションは選択言語と英語のどちらでも検索できます。アプリ行には
デスクトップアイコン、コマンド行には `(CMD)` が表示されます。選択画面を
開いている間は、追加・削除されたアプリとコマンドが自動更新され、任意の引数
入力はコマンドの場合だけ表示されます。既存アクションの登録は複製ではなく
現在のキーから新しいキーへの移動です。割り当て済みキーを変更する場合は、
削除されるアクション名を示したうえで 2 回目の明示的な確認が必要です。

変更できないバインドも表示・非表示を独立して設定でき、一般的な読み取り専用
表示ではなく具体的な理由が示されます。理由は次のいずれかです。

- `Mouse binding`、`Duplicate chord`、`Unsupported key`
- `Action cannot be reconstructed`
- `Ambiguous action metadata`、`Malformed action record`
- `Unsupported action kind`

使用中のキーを指定するとエラーを表示し、登録しません。公開直前と Hyprland
のリロード後にも実際の状態を再確認するため、途中で外部設定が変わっても重複
状態を成功として扱いません。安全に解決できない物理キーがある場合は編集を
フェイルクローズします。

`Reset all`（すべてリセット）は Keyguide が管理する内容だけを初回状態へ
戻します。Keyguide が移動または置換した既存ショートカットとタイトルを元に
戻し、追加したショートカットを削除し、HUD 表示設定を初期値に戻します。他の
Omarchy、Hyprland、プラグイン設定はリセットしません。

## 互換性とインストール準備

対象は Omarchy `4.0.0-1`、Hyprland `0.56.2` 以降です。Python 3、
`xkbcli`、読み取り可能なキーボードイベントデバイスが必要です。ソースまたは
Git プラグインとして導入する場合は C コンパイラー（Arch Linux の
`base-devel`）も必要です。

次のコマンドで GitHub から直接追加できます。

```sh
omarchy plugin add https://github.com/mrai125kr/omarchy-keyguide.git --enable
```

Git プラグインの更新は `omarchy plugin update mrai.keyguide --yes`、削除は
`omarchy plugin remove mrai.keyguide` を使用します。ソースツリーでは
`make test` で検証、`make install` で導入、`make uninstall` で削除できます。

## 安全方針

- `/usr/share/omarchy/` と `~/.config/hypr/bindings.lua` を変更しません。
- ショートカット変更はユーザー状態ディレクトリ内の Keyguide 専用 Lua
  モジュール 1 個だけへアトミックに保存します。
- 通常のアンインストールでは表示設定と独立管理されたショートカット状態を
  保持します。
- 検証済みの所有ファイル一覧だけを削除し、ユーザー設定を再帰削除しません。

ライセンスは MIT です。詳細は [LICENSE](LICENSE) と [NOTICE](NOTICE) を参照して
ください。
