---
name: tdd-workflow
description: 新機能の作成、バグ修正、コードのリファクタリング時にこのスキルを使用。ユニット、統合、E2Eテストを含む80%以上のカバレッジでテスト駆動開発を強制。
---

# テスト駆動開発ワークフロー（Rails RSpec）

すべてのコード開発がTDDの原則に従い、包括的なテストカバレッジを持つことを保証するスキル。

## 起動するタイミング

- 新機能や機能を書くとき
- バグや問題を修正するとき
- 既存のコードをリファクタリングするとき
- APIエンドポイントを追加するとき
- 新しいモデルやサービスを作成するとき

## コア原則

### 1. コードの前にテスト

常にまずテストを書き、テストをパスするためのコードを実装します。

### 2. カバレッジ要件

- 最低80%カバレッジ（ユニット + 統合 + システム）
- すべてのエッジケースをカバー
- エラーシナリオをテスト
- 境界条件を検証

### 3. テストタイプ

#### モデルスペック（ユニットテスト）
- バリデーション
- アソシエーション
- スコープ
- インスタンスメソッド・クラスメソッド
- コールバック

#### リクエストスペック（統合テスト）
- APIエンドポイント
- 認証・認可
- レスポンスステータスとJSON構造
- エラーハンドリング

#### システムスペック（E2Eテスト）
- 重要なユーザーフロー
- フォーム操作
- ブラウザ自動化（Capybara）
- UIインタラクション

#### サービス・ジョブスペック
- サービスオブジェクト
- Active Jobキュー
- メーラー
- カスタムバリデータ

## TDDワークフローステップ

### ステップ1: ユーザージャーニーを書く

```
[ロール]として、
[アクション]したい、
そうすれば[ベネフィット]が得られる

例:
ユーザーとして、
記事をキーワードで検索したい、
そうすれば関連する記事を素早く見つけられる。
```

### ステップ2: テストケースを生成

各ユーザージャーニーについて、包括的なテストケースを作成:

```ruby
RSpec.describe Article, type: :model do
  describe "検索" do
    it "キーワードに一致する記事を返す" do
      # テスト実装
    end

    it "空のクエリで全件を返す" do
      # エッジケースをテスト
    end

    it "一致しない場合は空の結果を返す" do
      # 境界条件をテスト
    end

    it "大文字小文字を区別しない" do
      # ソートロジックをテスト
    end
  end
end
```

### ステップ3: テストを実行（失敗するはず）

```bash
bundle exec rspec spec/models/article_spec.rb  # テストは失敗するはず
```

### ステップ4: コードを実装

テストをパスする最小限のコードを書く:

```ruby
class Article < ApplicationRecord
  scope :search, ->(query) {
    where("title ILIKE :q OR body ILIKE :q", q: "%#{query}%")
  }
end
```

### ステップ5: 再度テストを実行

```bash
bundle exec rspec spec/models/article_spec.rb  # テストはパスするはず
```

### ステップ6: リファクタリング

テストをグリーンに保ちながらコード品質を改善:

- 重複を削除
- 命名を改善
- パフォーマンスを最適化
- 可読性を向上

### ステップ7: カバレッジを確認

```bash
COVERAGE=true bundle exec rspec  # 80%以上のカバレッジを確認
# SimpleCovレポート: coverage/index.html
```

## テストパターン

### モデルスペック

```ruby
RSpec.describe User, type: :model do
  describe "バリデーション" do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe "アソシエーション" do
    it { is_expected.to have_many(:articles).dependent(:destroy) }
    it { is_expected.to belong_to(:organization).optional }
  end

  describe "#full_name" do
    it "姓と名を結合する" do
      user = build(:user, first_name: "太郎", last_name: "山田")
      expect(user.full_name).to eq("山田 太郎")
    end
  end

  describe ".active" do
    it "アクティブなユーザーのみ返す" do
      active_user = create(:user, active: true)
      create(:user, active: false)

      expect(described_class.active).to contain_exactly(active_user)
    end
  end
end
```

### リクエストスペック

```ruby
RSpec.describe "Articles API", type: :request do
  describe "GET /api/v1/articles" do
    it "記事一覧を返す" do
      create_list(:article, 3)

      get api_v1_articles_path, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["data"].size).to eq(3)
    end

    it "ページネーションパラメータを受け付ける" do
      create_list(:article, 15)

      get api_v1_articles_path, params: { page: 1, per: 10 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["data"].size).to eq(10)
    end

    it "不正なパラメータで422を返す" do
      get api_v1_articles_path, params: { per: "invalid" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/articles" do
    let(:user) { create(:user) }
    let(:valid_params) { { article: { title: "テスト記事", body: "本文" } } }

    context "認証済み" do
      it "記事を作成する" do
        post api_v1_articles_path,
             params: valid_params,
             headers: auth_headers(user),
             as: :json

        expect(response).to have_http_status(:created)
        expect(Article.count).to eq(1)
      end
    end

    context "未認証" do
      it "401を返す" do
        post api_v1_articles_path, params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
```

### システムスペック（Capybara）

```ruby
RSpec.describe "記事検索", type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it "ユーザーが記事を検索してフィルタリングできる" do
    create(:article, title: "Rails入門")
    create(:article, title: "Ruby基礎")
    user = create(:user)

    sign_in user
    visit articles_path

    # ページがロードされたことを確認
    expect(page).to have_css("h1", text: "記事一覧")

    # 記事を検索
    fill_in "検索", with: "Rails"
    click_button "検索する"

    # 検索結果が表示されたことを確認
    expect(page).to have_css("[data-testid='article-card']", count: 1)
    expect(page).to have_content("Rails入門")
    expect(page).not_to have_content("Ruby基礎")
  end

  it "検索結果がない場合にメッセージを表示する" do
    user = create(:user)

    sign_in user
    visit articles_path

    fill_in "検索", with: "存在しないキーワード"
    click_button "検索する"

    expect(page).to have_content("該当する記事が見つかりませんでした")
  end
end
```

### サービスオブジェクトスペック

```ruby
RSpec.describe ArticleSearchService do
  describe "#call" do
    it "キーワードに一致する記事を返す" do
      article = create(:article, title: "Rails入門")
      create(:article, title: "Python入門")

      result = described_class.new(query: "Rails").call

      expect(result).to contain_exactly(article)
    end

    it "外部API障害時にフォールバックする" do
      allow(ExternalSearchApi).to receive(:search).and_raise(Faraday::Error)

      result = described_class.new(query: "Rails").call

      expect(result).to eq([])
    end
  end
end
```

### ジョブスペック

```ruby
RSpec.describe ArticleIndexJob, type: :job do
  it "ジョブをキューに入れる" do
    article = create(:article)

    expect {
      described_class.perform_later(article.id)
    }.to have_enqueued_job.with(article.id).on_queue("default")
  end

  it "検索インデックスを更新する" do
    article = create(:article)
    allow(SearchIndex).to receive(:update)

    described_class.perform_now(article.id)

    expect(SearchIndex).to have_received(:update).with(article)
  end
end
```

## テストヘルパー・共通設定

### FactoryBot

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { "太郎" }
    last_name { "山田" }
    password { "password123" }

    trait :admin do
      role { :admin }
    end

    trait :with_articles do
      transient do
        articles_count { 3 }
      end

      after(:create) do |user, evaluator|
        create_list(:article, evaluator.articles_count, user: user)
      end
    end
  end
end
```

### 共有コンテキスト

```ruby
# spec/support/shared_contexts/authenticated.rb
RSpec.shared_context "authenticated" do
  let(:current_user) { create(:user) }
  before { sign_in current_user }
end

# 使用例
RSpec.describe "ダッシュボード", type: :system do
  include_context "authenticated"

  it "ダッシュボードを表示する" do
    visit dashboard_path
    expect(page).to have_content("ダッシュボード")
  end
end
```

### カスタムマッチャー

```ruby
# spec/support/matchers/json_response.rb
RSpec::Matchers.define :have_json_key do |key|
  match do |response|
    JSON.parse(response.body).key?(key.to_s)
  end
end
```

## 外部サービスのモック

### WebMock + VCR

```ruby
# spec/support/vcr.rb
VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data("<API_KEY>") { ENV["API_KEY"] }
end

# 使用例
RSpec.describe ExternalApiClient do
  it "データを取得する", vcr: { cassette_name: "external_api/fetch" } do
    result = described_class.new.fetch("query")
    expect(result).to be_present
  end
end
```

### Redis モック

```ruby
before do
  redis_mock = instance_double(Redis)
  allow(Redis).to receive(:new).and_return(redis_mock)
  allow(redis_mock).to receive(:get).and_return(nil)
  allow(redis_mock).to receive(:set).and_return("OK")
end
```

### ActiveJob テストモード

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.include ActiveJob::TestHelper

  config.around(:each, type: :job) do |example|
    perform_enqueued_jobs do
      example.run
    end
  end
end
```

## 避けるべき一般的なテストミス

### NG: 実装の詳細をテスト

```ruby
# 内部の実装詳細に依存しない
expect(user.instance_variable_get(:@cache)).to eq({})
```

### OK: 振る舞いをテスト

```ruby
# 公開インターフェースをテスト
expect(user.cached_profile).to eq(expected_profile)
```

### NG: テストの分離がない

```ruby
# テストが互いに依存
it "ユーザーを作成" do
  @user = User.create!(name: "Test")
end

it "同じユーザーを更新" do
  @user.update!(name: "Updated") # 前のテストに依存
end
```

### OK: 独立したテスト

```ruby
# 各テストが自分のデータをセットアップ
it "ユーザーを作成" do
  user = create(:user)
  expect(user).to be_persisted
end

it "ユーザーを更新" do
  user = create(:user)
  user.update!(name: "Updated")
  expect(user.name).to eq("Updated")
end
```

## ベストプラクティス

1. **テストを先に書く** - 常にTDD
2. **テストごとに1つの振る舞い** - 単一の動作に集中
3. **説明的なテスト名** - 何がテストされているか日本語で説明
4. **Arrange-Act-Assert** - 明確なテスト構造（let/before → action → expect）
5. **FactoryBotを使う** - fixturesよりfactoryを優先
6. **エッジケースをテスト** - nil、空文字、境界値
7. **エラーパスをテスト** - ハッピーパスだけでなく
8. **テストを高速に保つ** - `build`/`build_stubbed` を優先、必要な時だけ `create`
9. **テスト後にクリーンアップ** - DatabaseCleanerで副作用なし
10. **`let`と`let!`を使い分ける** - 遅延評価 vs 即時評価を理解

## 成功メトリクス

- 80%以上のコードカバレッジ達成（SimpleCov）
- すべてのテストがパス（グリーン）
- スキップまたはpendingなテストなし
- 高速なテスト実行（モデルスペックは30秒以内）
- システムスペックが重要なユーザーフローをカバー
- テストが本番前にバグをキャッチ

---

**覚えておくこと**: テストはオプションではありません。自信を持ったリファクタリング、迅速な開発、本番の信頼性を可能にするセーフティネットです。
