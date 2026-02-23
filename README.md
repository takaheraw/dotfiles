# dotfiles

macOS 開発環境の設定ファイル。mise + sheldon + XDG 準拠のディレクトリ構成。

## セットアップ

```bash
git clone https://github.com/takaheraw/dotfiles.git ~/ghq/github.com/takaheraw/dotfiles
cd ~/ghq/github.com/takaheraw/dotfiles
./install.sh
```

`install.sh` が以下を自動実行:

1. Homebrew インストール（未導入の場合）
2. mise インストール（CLIツール・言語バージョン管理）
3. sheldon インストール（zsh プラグイン管理）
4. シンボリックリンク作成（dotfiles → `$HOME`）
5. mise 管理ツールの一括インストール

セットアップ後、シークレットを配置:

```bash
echo 'export GITHUB_PERSONAL_ACCESS_TOKEN="your_token"' >> ~/.zshrc.local
```

## ディレクトリ構成

```
dotfiles/
├── install.sh                    # メインインストーラー
├── .gitignore
├── .zshenv                       # 環境変数・PATH・エイリアス
├── .zshrc                        # mise + sheldon（最小限）
├── .vimrc                        # Vim 設定
├── .config/
│   ├── ghostty/config            # ターミナル設定
│   ├── git/
│   │   ├── config                # gitconfig（XDG 準拠）
│   │   ├── config_work           # 仕事用 gitconfig
│   │   └── ignore                # グローバル gitignore
│   ├── mise/config.toml          # ツール定義
│   └── sheldon/plugins.toml      # zsh プラグイン定義
├── .zsh/
│   ├── sync/
│   │   └── zsh_setting.zsh       # ヒストリ・色・プロンプト（即時読込）
│   └── defer/
│       ├── completion.zsh        # 補完設定（遅延読込）
│       └── git.zsh              # git エイリアス（遅延読込）
└── .claude/
    ├── agents/                   # Claude Code エージェント
    ├── commands/                 # Claude Code コマンド
    ├── rules/                    # Claude Code ルール
    └── skills/                   # Claude Code スキル
```

## ツール管理（mise）

### mise で管理しているツール

| カテゴリ | ツール |
|---------|--------|
| 言語 | node, python, ruby, go, deno |
| パッケージマネージャ | pnpm, uv |
| CLI | gh, ghq, fzf, jq, eza, ripgrep, bat, fd, delta |
| インフラ | terraform |
| TUI | lazygit, yazi |

### よく使うコマンド

```bash
# ツール一覧を表示
mise ls

# 全ツールを最新にインストール
mise install --yes

# ツールを追加（config.toml に追記 + インストール）
mise use -g <tool>@latest

# 特定バージョンをインストール
mise use -g node@20

# ツールのアップグレード
mise upgrade <tool>

# 利用可能なバージョンを確認
mise ls-remote <tool>
```

### Homebrew で管理しているツール

mise で管理できないものは Homebrew:

```bash
brew install git curl awscli
```

## シェル設定

### 読み込み順序

```
.zshenv        → 環境変数・PATH・エイリアス（全セッション）
.zshrc         → brew → mise → sheldon（対話シェルのみ）
  └─ sheldon
       ├─ zsh-defer          （遅延読込の基盤）
       ├─ zsh-autosuggestions（入力補完候補）
       ├─ fast-syntax-highlighting（構文ハイライト）
       ├─ pure               （プロンプトテーマ）
       ├─ .zsh/sync/*        （即時: ヒストリ・色設定）
       └─ .zsh/defer/*       （遅延: 補完・git エイリアス）
.zshrc.local   → シークレット・マシン固有設定（gitignore 対象）
```

### エイリアス

| エイリアス | コマンド | 説明 |
|-----------|---------|------|
| `ll` | `eza -la --icons --git` | ファイル一覧（アイコン・git ステータス付き） |
| `g` | `cd $(ghq list -p \| fzf)` | リポジトリ移動 |
| `gs` | `git status` | git ステータス |
| `gd` | `git diff` | git 差分 |
| `gl` | `git log --oneline --graph -20` | git ログ |

## シークレット管理

ハードコードせず `.zshrc.local` に配置（gitignore 対象）:

```bash
# ~/.zshrc.local
export GITHUB_PERSONAL_ACCESS_TOKEN="your_token"
```

## 設定変更後の反映

```bash
# シェル設定を反映
exec zsh

# シンボリックリンクを再作成（ファイル追加時）
./install.sh
```
