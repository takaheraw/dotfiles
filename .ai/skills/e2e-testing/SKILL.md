---
name: e2e-testing
description: Playwrightを使用したE2Eテストパターン。Page Object Modelの実装、設定、CI連携、Flakyテスト対策など。
---

Playwrightを利用して、安定的で高速かつ保守しやすいE2Eテストスイートを構築・保守するためのベストプラクティススキルです。
このスキルは `rspec-tdd` 等から E2E テスト記述・修正の実装パターンとして参照されます。ツールを用いたブラウザ操作のアクションは `playwright-cli` スキルを利用してください。

## テストファイルの構成（推奨）
```
tests/
├── e2e/
│   ├── auth/
│   │   ├── login.spec.ts
│   │   ├── logout.spec.ts
│   │   └── register.spec.ts
│   ├── features/
│   │   ├── browse.spec.ts
│   │   ├── search.spec.ts
│   │   └── create.spec.ts
│   └── api/
│       └── endpoints.spec.ts
├── fixtures/
│   ├── auth.ts
│   └── data.ts
└── playwright.config.ts
```
※ 既存のRailsリポジトリ等でシステムテスト環境が独立している場合（例: `e2e/` 直下）は、プロジェクト側の構造に合わせます。

## Page Object Model (POM) の実装
```typescript
import { Page, Locator } from '@playwright/test'

export class ItemsPage {
  readonly page: Page
  readonly searchInput: Locator
  readonly itemCards: Locator
  readonly createButton: Locator

  constructor(page: Page) {
    this.page = page
    this.searchInput = page.locator('[data-testid="search-input"]')
    this.itemCards = page.locator('[data-testid="item-card"]')
    this.createButton = page.locator('[data-testid="create-btn"]')
  }

  async goto() {
    await this.page.goto('/items')
    await this.page.waitForLoadState('networkidle')
  }

  async search(query: string) {
    await this.searchInput.fill(query)
    // ネットワークリクエストと安定を待つ
    await this.page.waitForResponse(resp => resp.url().includes('/api/search'))
    await this.page.waitForLoadState('networkidle')
  }

  async getItemCount() {
    return await this.itemCards.count()
  }
}
```

## テストの構造と記述
```typescript
import { test, expect } from '@playwright/test'
import { ItemsPage } from '../../pages/ItemsPage'

test.describe('アイテム検索', () => {
  let itemsPage: ItemsPage

  test.beforeEach(async ({ page }) => {
    itemsPage = new ItemsPage(page)
    await itemsPage.goto()
  })

  test('キーワードで検索できること', async ({ page }) => {
    await itemsPage.search('test')

    const count = await itemsPage.getItemCount()
    expect(count).toBeGreaterThan(0)

    // 正規表現による柔軟な検証
    await expect(itemsPage.itemCards.first()).toContainText(/test/i)
    await page.screenshot({ path: 'artifacts/search-results.png' })
  })

  test('結果が0件の場合の表示をハンドリングできること', async ({ page }) => {
    await itemsPage.search('xyznonexistent123')

    await expect(page.locator('[data-testid="no-results"]')).toBeVisible()
    expect(await itemsPage.getItemCount()).toBe(0)
  })
})
```

## Playwright 共通設定 (playwright.config.ts)
```typescript
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  // CI上では exclusive test(.only) を禁止
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['junit', { outputFile: 'playwright-results.xml' }]
  ],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry', // CIや失敗時のみトレース取得
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 10000,
    navigationTimeout: 30000,
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile-chrome', use: { ...devices['Pixel 5'] } },
  ],
})
```

## 不安定なテスト（Flaky Tests）への対応策

### 1. 検証条件と隔離
```typescript
// 一時的な回避（SkipやFixme）
test('flaky: 複雑な検索機能', async ({ page }) => {
  test.fixme(true, 'Flaky - Issue #123を修正するまで無効化')
  // ...
})

// CI環境限定でスキップ
test('条件付きスキップ', async ({ page }) => {
  test.skip(!!process.env.CI, 'CI上でのみFlaky - Issue #123')
  // ...
})
```

### 2. Flakinessの特定（デバッグ実行例）
```bash
npx playwright test tests/search.spec.ts --repeat-each=10
npx playwright test tests/search.spec.ts --retries=3
```

### 3. 一般的な原因と賢い実装方法

**競合状態（Race Conditions）の防止:**
```typescript
// 悪い例: DOMが準備できていると仮定してしまう
await page.click('[data-testid="button"]')

// 良い例: LocatorによるAuto-Waitの活用
await page.locator('[data-testid="button"]').click()
```

**通信のタイミング問題:**
```typescript
// 悪い例: 固定時間のWait（非常に不安定）
await page.waitForTimeout(5000)

// 良い例: 特定のレスポンス条件を待機
await page.waitForResponse(resp => resp.url().includes('/api/data'))
```

**アニメーションの完了待機:**
```typescript
// 悪い例: アニメーション途中にクリックしてしまう
await page.click('[data-testid="menu-item"]')

// 良い例: アニメーションの完了/安定状態を待つ
await page.locator('[data-testid="menu-item"]').waitFor({ state: 'visible' })
await page.waitForLoadState('networkidle')
await page.locator('[data-testid="menu-item"]').click()
```

## アーティファクトとデバッグ手法

### スクリーンショット
```typescript
await page.screenshot({ path: 'artifacts/after-login.png' })
await page.screenshot({ path: 'artifacts/full-page.png', fullPage: true })
// 特定の要素だけをスクリーンショット
await page.locator('[data-testid="chart"]').screenshot({ path: 'artifacts/chart.png' })
```

### トレースの活用
コードの任意区間のトレースを手動で取得する場合：
```typescript
await browser.startTracing(page, {
  path: 'artifacts/trace.json',
  screenshots: true,
  snapshots: true,
})
// ...テストアクション...
await browser.stopTracing()
```

### クリティカルなフローのテスト例（決済等）
```typescript
test('取引実行フロー', async ({ page }) => {
  // 本番環境（実際の課金）ではスキップ
  test.skip(process.env.NODE_ENV === 'production', 'Skip real transactions on prod')

  await page.goto('/markets/test-market')
  await page.locator('[data-testid="position-yes"]').click()
  await page.locator('[data-testid="trade-amount"]').fill('1.0')

  // 確認ボタンクリックと通信待機
  await page.locator('[data-testid="confirm-trade"]').click()
  await page.waitForResponse(
    resp => resp.url().includes('/api/trade') && resp.status() === 200,
    { timeout: 30000 }
  )

  await expect(page.locator('[data-testid="trade-success"]')).toBeVisible()
})
```

---
**注意事項**: テスト記述と並行して実際のブラウザ動作を確認したい場合は、`playwright-cli` ツールスキルを活用してください。
