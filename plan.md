# Wealth Manager — AI Financial Advisor GSD Plan

> **On approval:** Copy this plan to `~/wealth_manager/wealth-manager/plan.md` so `/gsd` and future sessions auto-detect it.

## Context

Build a personal CFO iOS app from a fresh Xcode template. The app actively analyzes the user's complete financial picture and gives forward-looking, personalized guidance — not just a tracker. Architecture: SwiftUI + SwiftData iOS app backed by a Python/FastAPI server for Plaid integration and Claude API advisory intelligence.

**Decisions:** Data foundation first, hybrid AI (deterministic on-device + cloud LLM), Plaid for account sync, Stitch mockups before coding.

**Platform strategy:** macOS-first native app (sidebar navigation, toolbar, menu bar, multi-window). Port to iOS after macOS is working. Shared SwiftUI + SwiftData core, platform-specific UI shells.

---

## Architecture

```
macOS App (SwiftUI + SwiftData)     FastAPI Backend (Python)
  - MVVM + Repository pattern         - Plaid token exchange + webhooks
  - On-device calculation engine       - Claude API advisory prompts
  - Plaid Link via WKWebView           - PostgreSQL + Redis
  - Local cache via SwiftData          - JWT auth + Apple Sign-In
  - NavigationSplitView (sidebar)      - Celery for background tasks
  - Toolbar + menu bar integration
```

**macOS UI patterns:**
- Sidebar navigation (NavigationSplitView) — not tab bar
- Toolbar buttons for common actions (add account, refresh, settings)
- Menu bar commands (File > Export, View > Net Worth, etc.)
- Multiple windows support (detail views can open in new windows)
- Keyboard shortcuts throughout (Cmd+N new account, Cmd+R refresh, etc.)

**iOS port (later):**
- Same Models, Repositories, ViewModels, Services, Calculators (shared)
- Replace sidebar with TabView
- Replace toolbar with navigation bar buttons
- Replace Plaid WKWebView with native Plaid Link iOS SDK
- Add widgets (WidgetKit — iOS only initially)

**Data sync:** Backend is source of truth. App pulls deltas via `GET /sync?since={timestamp}`. Plaid webhooks trigger server-side updates. SwiftData is offline cache. Writes go backend-first, then mirror locally.

**Backend stack:** FastAPI, SQLAlchemy 2.0, Alembic, PostgreSQL, Redis, plaid-python, anthropic SDK, Celery, Docker, pytest.

---

## Design System — "Holographic JARVIS"

> Finalized via Stitch project `6224935428722455335`. All 5 reference screens approved.
> Remaining screens (Goals, Reports, Planning, Add Account) follow the same system — designed in-code, no Stitch needed.

**Aesthetic:** Holographic glassmorphism. Deep ocean blue background, frosted glass panels, projected typography. JARVIS-like HUD with subtle grid overlays, glowing data, and AI presence indicators. Sci-fi financial terminal meets Apple design.

**Color Palette:**
| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#070b14` → `#0c1220` | Deep ocean blue gradient mesh |
| `glassBg` | `rgba(255,255,255,0.10)` | Frosted glass panel fill |
| `glassBorder` | `rgba(255,255,255,0.12)` | 1px luminous panel borders |
| `primary` | `#3b82f6` | Electric blue — primary actions, selected states |
| `secondary` | `#06b6d4` | Cyan — secondary accents, chart lines |
| `tertiary` | `#14b8a6` | Teal — tertiary accents, subtle highlights |
| `glow` | `#7dd3fc` | Ice blue — glow effects, projected text |
| `positive` | `#22c55e` | Green — gains, positive change, on-track |
| `negative` | `#ef4444` | Red — losses, over-budget, alerts |
| `textPrimary` | `#ffffff` | White — headings, key numbers |
| `textMuted` | `rgba(255,255,255,0.50)` | Muted labels, secondary text |

**No purple/violet anywhere.**

**Typography:** Inter — all headings, body, labels, numbers. Thin weights for hero numbers (48px+), regular for body.

**Glass Treatment:**
- Backdrop blur: 25px
- Background: `glassBg` token
- Border: 1px solid `glassBorder` token
- Cards float with subtle blue-tinted shadow
- Panels feel like translucent ice sheets in space

**HUD Elements:**
- Faint grid overlays on charts
- Thin arc/ring decorations around key data points
- Chart lines with soft bloom/glow effect
- AI orb: blue-to-cyan gradient with ambient bloom
- Pulsing cyan dot on AI Advisor nav item

**AI Presence:**
- Frosted glass insight cards with cyan orb icon on every data screen
- Forward-looking AI commentary (not just reporting — advising)
- Suggested action chips with glass pill styling

**Sidebar Navigation (canonical — all screens):**
1. Dashboard (house icon)
2. Net Worth (chart.line icon)
3. Accounts (building.columns icon)
4. Budget (wallet icon)
5. Goals (target icon)
6. AI Advisor (bubble.left.and.bubble.right icon + pulsing cyan dot)
7. Reports (doc.text icon)
8. Planning (calendar icon)
- Bottom: User avatar circle + "Steve M." muted text

**Stitch Reference Screens:**
| # | Screen | Stitch ID | Notes |
|---|--------|-----------|-------|
| 1 | Dashboard | `22bf6d30...` | Hero net worth, health ring, AI insight, recent activity |
| 2 | Accounts | `483f4f7e...` | Three-column: nav + account list + detail with transactions |
| 3 | Net Worth | `74903c84...` | Multi-line chart, asset allocation, milestone timeline |
| 4 | AI Advisor | `f9eb939a...` | Chat interface, floating AI orb, embedded decision cards |
| 5 | Budget | `97ec8693...` | Month selector, category grid with progress rings, trend chart |

---

## Dependency Graph

```
Phase 0 (Stitch Mockups)
  |
  v
Phase 1 (Data Foundation)
  |
  +---> Phase 2 (Calc Engine)  -------+
  |     [parallel]                     |
  +---> Phase 3 (Backend + Plaid) ----+---> Phase 5 (Advanced Tools)
          |                                       |
          +---> Phase 4 (AI Advisory) -----------+---> Phase 6 (Polish)
```

---

## Sprint Plan with Concurrency Lanes

Each sprint maps tasks to parallel agent lanes. Independent tasks run simultaneously.
Use `Agent` tool with multiple parallel invocations per lane.

### [x] Sprint 0: Design (DONE)
```
Lane A (Stitch+Design)     Lane B (Research)
─────────────────────      ──────────────────
0.1 Dashboard mockup  ✓    Exa: macOS finance app UI patterns ✓
0.2 Accounts mockup   ✓    Exa: SwiftData + NavigationSplitView examples ✓
0.3 Account Detail    *    context7: SwiftUI macOS patterns ✓
0.4 Net Worth Chart   ✓
0.5 Add Account Flow  *    * = designed in-code using design system
0.6 Goals List        *
0.7 AI Advisor Chat   ✓
0.8 CFO Briefing      *
0.9 Budget            ✓
0.10 Planning         *
```
**Gate:** 5 Stitch reference screens approved ✓. Remaining screens designed in-code using the established design system. Lane B research complete — findings in `docs/research-sprint0-lane-b.md`.

### [x] Sprint 1: Data Foundation — Models & Repos (1 week)
```
Lane A (Models)                    Lane B (Repos + Enums)           Lane C (Xcode Setup)
──────────────────                 ─────────────────────            ──────────────────
1.3 Account model                  1.2 All enum types               1.0 Add macOS target
1.4 Transaction model              1.11 Repository protocols        1.1 Directory structure
1.5 InvestmentHolding model        1.13 Mock repositories
1.6 Debt model
1.7 FinancialGoal model
1.8 UserProfile model
1.9 NetWorthSnapshot model
1.10 FinancialHealthScore model
```
**Merge point:** All models + repos must compile together before Sprint 2
**Gate:** `1.32 Model unit tests` + `1.33 Repository unit tests` pass (80%+ coverage)

### [x] Sprint 2: Data Foundation — Views & Navigation (1 week)
```
Lane A (Shell + Dashboard + Theme)  Lane B (Accounts)                Lane C (Goals + Budget + Profile)
──────────────────────────────────  ──────────────────               ─────────────────────────────────
1.14 Delete Item.swift              1.19 AccountsViewModel           1.24 GoalsViewModel
1.15 Update App entry point         1.20 AccountsListView            1.25 GoalsListView
1.16 MainSplitView (sidebar)        1.21 AccountDetailViewModel      1.26 GoalDetailView
1.17 DashboardViewModel             1.22 AccountDetailView           1.27 AddGoalView
1.18 DashboardView                  1.23 AddAccountView              1.28 ProfileView + VM
1.29-1.31 Reusable components                                        1.36 BudgetViewModel
1.35 Theme/ design tokens                                            1.37 BudgetView
```
**Gate:** `1.34 ViewModel unit tests` pass, app builds + runs on macOS, sidebar nav works with all 8 sections
**Sprint end:** `/verify` + `/code-review` + `git commit`

### [x] Sprint 3: Calc Engine + Backend Scaffold (parallel tracks, 2 weeks)
```
Lane A (Swift Calculators)          Lane B (Python Backend)           Lane C (Plaid Signup + Research)
──────────────────────────          ───────────────────────           ────────────────────────────
2.1 CompoundInterestCalc            3.1 Scaffold FastAPI project      3.0 Sign up for Plaid
2.2 RetirementCalculator            3.2 config.py + database.py       Exa: FastAPI+Plaid templates
2.3 DebtCalculator                  3.3 SQLAlchemy models             Exa: WKWebView Plaid Link
2.4 TaxCalculator                   3.4 Pydantic schemas              context7: plaid-python SDK docs
2.5 NetWorthProjector               3.5 Alembic migrations
2.6 HealthScoreCalculator           3.6 Docker + docker-compose
2.7 InsuranceCalculator
2.8 NetWorthService
2.9 ProjectionService
```
**Gate A:** `2.13 Calculator unit tests` — every formula verified to the penny
**Gate B:** `docker-compose up` works, DB migrates, health endpoint responds

### [x] Sprint 4: Net Worth Views + Backend Auth/Plaid (parallel, 1-2 weeks)
```
Lane A (Swift Net Worth Views)      Lane B (Backend Auth + Plaid)     Lane C (Backend Sync)
──────────────────────────          ─────────────────────────         ──────────────────────
2.10 NetWorthView + chart    ✓     3.7 auth_service.py         ✓     3.11 sync_service.py       ✓
2.11 ProjectionView          ✓     3.8 Auth router + middleware ✓     3.12 Sync endpoints        ✓
2.12 WhatIfView              ✓     3.9 plaid_service.py         ✓     3.13 Docker deployment check [!]
                                    3.10 Plaid router            ✓
                                    3.10b Webhook handler        ✓
```
**Gate A:** 30 ViewModel tests pass, views wired to MainSplitView with tabbed navigation ✓
**Gate B:** JWT auth + Plaid sandbox service + webhook handler — 31 new tests pass ✓
**Gate C:** Delta sync (GET /sync?since=) + client push (POST /sync) — 11 new tests pass ✓
**Note:** 3.13 Docker deployment check deferred — not blocking for dev workflow

### [ ] Sprint 5: iOS Networking + Plaid Link (1 week)
```
Lane A (iOS Network Layer)          Lane B (Plaid WKWebView)          Lane C (Backend Tests)
──────────────────────────          ─────────────────────             ─────────────────────
3.15 APIClient.swift                3.18 PlaidLinkService.swift       3.21 Backend pytest suite
3.16 Endpoint.swift                 3.18b PlaidLinkWebView.swift      3.22 iOS networking tests
3.17 AuthService.swift              3.20 Update AddAccountView
3.19 SyncService.swift
```
**Gate:** `3.23 E2E test` — Plaid sandbox link → transaction sync → macOS display
**Sprint end:** `/verify` + `/code-review` + `/security-review` + `git commit`

### [ ] Sprint 6: AI Advisory Backend (1-2 weeks)
```
Lane A (Claude Integration)         Lane B (Prompts + Reports)        Lane C (Alert Rules)
────────────────────────            ──────────────────────            ────────────────────
4.1 claude_service.py               4.3 System prompts                4.7 alert_service.py
4.2 prompt_manager.py               4.4 Jinja2 templates              (7 alert rules)
4.5 advisory_service.py             4.6 report_service.py
4.8 Advisory routers
```
**Gate:** `4.10 Backend tests` — mock Claude responses, verify prompt construction

### [ ] Sprint 7: AI Advisory iOS (1 week)
```
Lane A (Chat UI)                    Lane B (Reports + Alerts)
────────────────                    ─────────────────────
4.9 New SwiftData models            4.12 CFOBriefingViewModel
4.10 AdvisorChatViewModel           4.13 CFOBriefingView
4.11 AdvisorChatView                4.14 AlertsListView + VM
4.15 Update MainSplitView           4.17 AdvisorService.swift
```
**Gate:** `4.18 E2E test` — calculation → prompt → Claude → rendered UI
**Sprint end:** `/verify` + `/code-review` + `git commit`

### [ ] Sprint 8: Advanced Financial Tools (2 weeks)
```
Lane A (Retirement+FIRE)            Lane B (Tax Intelligence)         Lane C (Debt + Insurance)
────────────────────────            ─────────────────────            ──────────────────────
5.1 RetirementDashboardView         5.6 TaxDashboardView              5.11 DebtStrategyView
5.2 FIRECalculatorView              5.7 HarvestingOppsView            5.12 RefinanceAnalysisView
5.3 ContributionOptimizerView       5.8 RothConversionView            5.13 DebtVsInvestView
5.4 SocialSecurityView              5.9 AssetLocationView             5.14 InsuranceDashboardView
5.5 Extend RetirementCalc           5.10 Extend TaxCalculator         5.15 LifeInsuranceCalcView
5.18a Retirement ViewModels         5.18b Tax ViewModels              5.16 EmergencyFundView
                                                                      5.17 EstatePlanningChecklist
                                                                      5.18c Debt+Insurance VMs
```
**Gate:** `5.19 Calculator tests` + `5.20 Integration tests` — all tools correct + AI explanations work
**Sprint end:** `/verify` + `/code-review` + `git commit`

### [ ] Sprint 9: Polish + iOS Port (2 weeks)
```
Lane A (macOS Polish)               Lane B (iOS Port)                 Lane C (Security + Launch)
──────────────────────              ──────────────                    ──────────────────────
6.1 Push notifications              6.11 Add iOS target               6.10 Security audit
6.2 macOS-specific polish            6.12 iOS MainTabView             6.9 App Store assets
6.3 Onboarding wizard               6.13 Adapt views for iOS
6.4 Biometric auth + Keychain       6.14 Plaid Link iOS SDK
6.5 Data export (CSV/PDF)           6.15 iOS widgets
6.6 Accessibility audit             6.16 iOS-specific testing
6.7 Annual Review mode
6.8 Performance optimization
```
**Final gate:** Full security audit, both platforms build + run, all tests pass
**Sprint end:** `/verify` + `/code-review` + `/security-review` + `/learn` + `/journal`

---

## Sprint Workflow (per sprint)

Every sprint follows this command sequence from the playbook:

```
/plan [sprint description]   <- Plan the sprint, confirm before coding
/tdd [first module]           <- Write tests first, then implement (per lane)
  ... implement across lanes using parallel Agent invocations ...
/verify [sprint gate]         <- Validate outputs at sprint boundary
/code-review                  <- Review diff before commit
git commit                    <- Atomic commit per logical change
/learn                        <- End of session: extract patterns
```

**If stuck (2+ failed attempts):** `/build-fix`
**If context heavy (~50 tool calls):** `/compact`
**Running parallel lanes:** Use multiple `Agent` tool calls in a single message, one per lane

### Session Handoff Protocol

**Each session = one sprint.** Complete the sprint, run all gate checks, then stop.

**At session start:**
1. Read `plan.md` at project root
2. Find the next `[ ]` sprint (all previous sprints should be `[x]`)
3. Announce: "Starting Sprint N: [name]. Lanes: A, B, C"
4. Launch agents for that sprint's lanes

**At sprint end (before session closes):**
1. Run `/verify` against sprint gate criteria
2. Run `/code-review` on all changes
3. Run `/security-review` if sprint touches auth/secrets/APIs
4. Commit all passing work: `git commit` with `feat: complete sprint N — [summary]`
5. Update `plan.md`: mark completed tasks `[x]`, note any `[!]` BLOCKED items
6. Run `/learn` to extract patterns
7. Run `/journal` with sprint summary

**New session picks up:** Reads `plan.md`, sees Sprint N is `[x]`, starts Sprint N+1.

**If context window is collapsing mid-sprint:**
1. `/compact` first — try to finish the sprint
2. If still collapsing: commit what's done, mark in-progress tasks `[~]`, note blockers
3. New session reads `[~]` tasks and resumes from there

---

## Skills Reference

These skills from the global environment should be invoked at specific phases:

| Skill | Phases | Purpose |
|-------|--------|---------|
| `/skill swift-mvvm` | 1, 2, 4, 5 | MVVM architecture with small, testable ViewModels |
| `/skill plaid-fintech` | 3 | Plaid Link token flows, transactions sync, Auth for ACH |
| `/skill swiftui-patterns` | 1, 2, 4, 5 | @Observable state, NavigationStack, view composition |
| `/skill swift-protocol-di-testing` | 1, 3 | Protocol-based DI for mocking network, file system, APIs |
| `/skill swift-actor-persistence` | 1 | Thread-safe data persistence using actors |
| `/skill foundation-models-on-device` | 4 | Apple FoundationModels for on-device LLM (hybrid approach) |
| `/skill ui-ux-pro-max` | 0, 1 | Design system, color palettes, typography for finance UI |
| `/skill api-design` | 3 | REST endpoint design, pagination, error envelope |
| `/skill backend-patterns` | 3, 4 | Repository pattern, service layer, caching, auth middleware |
| `/skill python-patterns` | 3, 4 | PEP 8, type hints, f-strings, pathlib |
| `/skill python-testing` | 3, 4 | pytest fixtures, parametrization, mocking, coverage |
| `/skill tdd-workflow` | all | Red-green-refactor cycle, 80%+ coverage gate |
| `/skill postgres-patterns` | 3 | Index strategy, data types, RLS policies |
| `/skill database-migrations` | 3 | Safe ALTER TABLE, concurrent index creation, zero-downtime |
| `/skill docker-patterns` | 3 | Multi-service compose, health checks, dev/prod stages |
| `/skill security-review` | 3, 6 | Secrets management, auth, input validation, OWASP |
| `/skill deployment-patterns` | 6 | CI/CD, health checks, rollback, production config |
| `/skill coding-standards` | all | Naming, immutability, error handling, file organization |

---

## Phase 0: Stitch Mockups (S)
> Deps: none
> Skills: `ui-ux-pro-max`

**Design pipeline per screen (from playbook):**
```
1. IDEATE      Nano Banana    -> generate mockup image (visual reference)
2. DESIGN      Stitch         -> design screen from mockup (HTML/CSS layout)
3. COMPONENTS  21st.dev Magic -> /ui create polished component
4. REFINE      ui-ux-pro-max  -> UX critique and iteration
5. BUILD       (Phase 1+)     -> convert approved design to SwiftUI
```
**Shortcut for simple screens:** skip steps 1-2, go straight to `/ui create [describe]`

Design system finalized: **Holographic JARVIS glassmorphism** (see Design System section above). 5 Stitch reference screens approved. Remaining screens designed in-code using the same tokens.

**macOS layout:** NavigationSplitView — sidebar (8-item nav) | content column (context-dependent list) | detail column. All panels use frosted glass treatment from the design system.

- [x] 0.1 **Dashboard** — Stitch `22bf6d30`. Hero net worth ($847,392.54) in thin white 48px Inter, daily change with green glow, sparkline with blue-to-cyan gradient stroke. AI insight card (frosted glass + cyan orb). Financial health ring (gradient blue-to-cyan, "78" centered). Monthly flow bar chart. Recent transactions as glass rows. Minimal search pill + "+" button in toolbar.
- [x] 0.2 **Accounts List + Detail** — Stitch `483f4f7e`. Three-column: sidebar | account list (grouped by Banking/Investments/Credit with section subtotals, frosted glass rows) | detail (account header, AI insight chip, segmented Transactions|Performance, transaction list, performance area chart). Filter pills with glow underline.
- [ ] 0.3 **Account Detail — Transaction Table** — Design in-code. macOS-native `Table` with sortable columns (Date, Merchant, Category, Amount, Status). Glass row styling. Search bar + category filter chips. Right-click context menu. Double-click opens edit sheet. Follows Accounts screen glass treatment.
- [x] 0.4 **Net Worth Chart** — Stitch `74903c84`. Massive thin "$847,392" hero. Time selector glass pills (1M–All). Multi-line chart: Assets (cyan), Liabilities (soft red), Net Worth (blue-to-teal gradient area). AI projection card. Asset allocation segmented bar + milestone timeline. Faint HUD grid overlay on chart.
- [ ] 0.5 **Add Account Sheet** — Design in-code. macOS `.sheet()` modal with frosted glass background. Step 1: two glass option cards (Link via Plaid / Add Manually). Step 2 (Manual): glass form fields. Cancel (ghost) + Save (blue glow) buttons. Follows glass card patterns from Dashboard.
- [ ] 0.6 **Goals List + Detail** — Design in-code. List column: glass rows with progress rings (blue-to-cyan gradient), goal name, current/target, projected date. Detail: large progress ring, milestone markers, contribution chart, AI insight card with goal-specific advice. Follows Budget screen's category card pattern.
- [x] 0.7 **AI Advisor Chat** — Stitch `f9eb939a`. Centered chat container (700px max). Floating blue-to-cyan AI orb with bloom. Frosted glass message bubbles (AI = cyan left border, user = blue glass right-aligned). Embedded decision cards. Glass pill input bar + suggested prompt chips. "Your personal CFO" subtitle.
- [ ] 0.8 **CFO Briefing (Reports)** — Design in-code. List column: past briefings by date (glass rows). Detail: health score ring (large), Executive Summary, Key Insights (3 bullets), Action Items, Goal Progress mini bars, Risk Alerts. All in frosted glass cards. "Generate New" + "Export PDF" ghost buttons. AI insight card at top.
- [x] 0.9 **Budget** — Stitch `97ec8693`. Month selector glass pill. Budget summary bar (Income/Spent/Remaining with gradient progress). AI insight card (spending alerts). 2x4 category grid: glass cards with progress rings, spend vs budget, trend arrows. Over-budget items glow red. Spending trend area chart (actual vs budget line).
- [ ] 0.10 **Planning** — Design in-code. Sections for Retirement, Tax, Debt, Insurance as glass cards with key metrics. Interactive scenario sliders (frosted glass controls). AI projection cards per section. Chart visualizations follow Net Worth screen patterns. Entry point for Sprint 8 advanced tools.

---

## Phase 1: Data Foundation (L)
> Deps: Phase 0
> Skills: `swift-mvvm`, `swiftui-patterns`, `swift-protocol-di-testing`, `swift-actor-persistence`, `tdd-workflow`, `coding-standards`
> Goal: Core SwiftData models, Repository pattern, MVVM scaffold, tab-based navigation, manual entry UI.

**Sprints:** 1 (Models + Repos) → 2 (Views + Navigation)
**See sprint plan above for concurrency lanes**

### 1A — Xcode Project Setup & Directory Structure

- [x] 1.0 **Add macOS destination to Xcode project.** Current project targets iOS 26.2. In Xcode: Target > General > Supported Destinations > add "Mac". Alternatively, create a fresh macOS SwiftUI + SwiftData project if easier. Verify SwiftData schema compiles for macOS. Set minimum deployment: macOS 15.0.

- [x] 1.1 **Create project directory structure.** All new Swift files go under `wealth-manager/wealth-manager/`:
  ```
  Models/
    Enums/
  Repositories/
    Protocols/
  ViewModels/
  Views/
    Dashboard/
    Accounts/
    Budget/
    Goals/
    NetWorth/
    AIAdvisor/
    Reports/
    Planning/
    Profile/
    Components/
  Services/
    Calculators/
    Network/
  Utilities/
  Extensions/
  Theme/          # Design system tokens (colors, glass modifiers, typography)
  ```

- [x] 1.2 **Create all enum types** in `Models/Enums/`. Each enum conforms to `String, Codable, CaseIterable, Identifiable`. Include `displayName` computed property for UI.
  - `AccountType.swift`: checking, savings, creditCard, investment, loan, retirement, other
  - `TransactionCategory.swift`: income, housing, transportation, food, utilities, healthcare, entertainment, shopping, education, personalCare, travel, gifts, fees, transfer, other
  - `GoalType.swift`: retirement, emergencyFund, homePurchase, debtPayoff, education, travel, investment, custom
  - `DebtType.swift`: mortgage, auto, student, creditCard, personal, medical, other
  - `HoldingType.swift`: stock, bond, etf, mutualFund, crypto, cash, reit, other
  - `AssetClass.swift`: usEquity, intlEquity, fixedIncome, realEstate, commodities, cash, alternative
  - `FilingStatus.swift`: single, marriedJoint, marriedSeparate, headOfHousehold
  - `RiskTolerance.swift`: conservative, moderate, aggressive

### 1B — SwiftData Models

All models use `@Model` macro, `Decimal` for money fields (never `Double`), and immutable patterns where possible. Use `swift-actor-persistence` for thread-safe access patterns.

- [x] 1.3 **Account.swift** — `@Model` class with:
  ```swift
  @Attribute(.unique) var id: UUID
  var plaidAccountId: String?
  var institutionName: String
  var accountName: String
  var accountType: AccountType
  var currentBalance: Decimal
  var availableBalance: Decimal?
  var currency: String = "USD"
  var isManual: Bool
  var isHidden: Bool = false
  var lastSyncedAt: Date?
  var createdAt: Date
  var updatedAt: Date
  @Relationship(deleteRule: .cascade, inverse: \Transaction.account) var transactions: [Transaction]
  @Relationship(deleteRule: .cascade, inverse: \InvestmentHolding.account) var holdings: [InvestmentHolding]
  ```
  Computed properties: `isAsset: Bool` (checking/savings/investment/retirement), `isLiability: Bool` (creditCard/loan), `formattedBalance: String` (currency formatted)

- [x] 1.4 **Transaction.swift** — `@Model` with:
  ```swift
  @Attribute(.unique) var id: UUID
  var plaidTransactionId: String?
  var account: Account
  var amount: Decimal  // positive = debit/expense, negative = credit/income
  var date: Date
  var merchantName: String?
  var category: TransactionCategory
  var subcategory: String?
  var note: String?
  var isRecurring: Bool = false
  var isPending: Bool = false
  var createdAt: Date
  ```

- [x] 1.5 **InvestmentHolding.swift** — `@Model` with:
  ```swift
  @Attribute(.unique) var id: UUID
  var account: Account
  var securityName: String
  var tickerSymbol: String?
  var quantity: Decimal
  var costBasis: Decimal?
  var currentPrice: Decimal
  var currentValue: Decimal  // quantity * currentPrice
  var holdingType: HoldingType
  var assetClass: AssetClass
  var lastPriceUpdate: Date
  ```
  Computed: `gainLoss: Decimal?` (currentValue - (costBasis ?? 0) * quantity), `gainLossPercent: Decimal?`

- [x] 1.6 **Debt.swift** — `@Model` with:
  ```swift
  @Attribute(.unique) var id: UUID
  var account: Account?  // optional — manual debts may not link to an account
  var debtName: String
  var debtType: DebtType
  var originalBalance: Decimal
  var currentBalance: Decimal
  var interestRate: Decimal  // annual rate as decimal (e.g. 0.065 for 6.5%)
  var minimumPayment: Decimal
  var payoffDate: Date?
  var isFixedRate: Bool
  var createdAt: Date
  var updatedAt: Date
  ```
  Computed: `monthlyInterest: Decimal` (currentBalance * interestRate / 12), `payoffProgress: Decimal` (1 - currentBalance/originalBalance)

- [x] 1.7 **FinancialGoal.swift** — `@Model` with:
  ```swift
  @Attribute(.unique) var id: UUID
  var goalName: String
  var goalType: GoalType
  var targetAmount: Decimal
  var currentAmount: Decimal
  var targetDate: Date?
  var monthlyContribution: Decimal?
  var priority: Int  // lower = higher priority
  var isActive: Bool = true
  var notes: String?
  var createdAt: Date
  var updatedAt: Date
  ```
  Computed: `progressPercent: Decimal` (currentAmount / targetAmount), `remainingAmount: Decimal`, `isOnTrack: Bool` (projection vs target date)

- [x] 1.8 **UserProfile.swift** — `@Model`, singleton pattern (only one per app):
  ```swift
  @Attribute(.unique) var id: UUID
  var dateOfBirth: Date?
  var annualIncome: Decimal?
  var monthlyExpenses: Decimal?
  var filingStatus: FilingStatus = .single
  var stateOfResidence: String?
  var retirementAge: Int = 65
  var riskTolerance: RiskTolerance = .moderate
  var dependents: Int = 0
  var hasSpouse: Bool = false
  var spouseIncome: Decimal?
  var createdAt: Date
  var updatedAt: Date
  ```
  Computed: `age: Int?` (from dateOfBirth), `yearsToRetirement: Int?`, `householdIncome: Decimal?`

- [x] 1.9 **NetWorthSnapshot.swift** — `@Model`, created periodically to track history:
  ```swift
  @Attribute(.unique) var id: UUID
  var date: Date
  var totalAssets: Decimal
  var totalLiabilities: Decimal
  var netWorth: Decimal  // totalAssets - totalLiabilities
  ```

- [x] 1.10 **FinancialHealthScore.swift** — `@Model`:
  ```swift
  @Attribute(.unique) var id: UUID
  var date: Date
  var overallScore: Int  // 0-100, weighted composite
  var savingsScore: Int   // savings rate vs income
  var debtScore: Int      // debt-to-income ratio
  var investmentScore: Int // diversification + growth
  var emergencyFundScore: Int // months of expenses covered
  var insuranceScore: Int  // coverage adequacy
  ```

- [x] 1.10b **BudgetCategory.swift** — `@Model` with:
  ```swift
  @Attribute(.unique) var id: UUID
  var category: TransactionCategory
  var monthlyLimit: Decimal
  var month: Int       // 1-12
  var year: Int
  var createdAt: Date
  var updatedAt: Date
  ```
  Computed: `spent: Decimal` (summed from transactions for this category/month/year), `remaining: Decimal`, `percentUsed: Decimal`, `isOverBudget: Bool`

### 1C — Repository Layer

Use `swift-protocol-di-testing` patterns: protocol-based DI so views never touch SwiftData directly. Each repository protocol has a mock implementation for testing.

- [x] 1.11 **Repository protocols** in `Repositories/Protocols/`:
  ```swift
  // AccountRepository.swift
  protocol AccountRepository {
      func fetchAll() async throws -> [Account]
      func fetchById(_ id: UUID) async throws -> Account?
      func fetchByType(_ type: AccountType) async throws -> [Account]
      func create(_ account: Account) async throws
      func update(_ account: Account) async throws
      func delete(_ account: Account) async throws
      func totalAssets() async throws -> Decimal
      func totalLiabilities() async throws -> Decimal
  }
  ```
  Same pattern for: `TransactionRepository` (with date range filtering, category filtering, pagination), `DebtRepository`, `GoalRepository`, `UserProfileRepository` (singleton fetch/update), `SnapshotRepository` (fetch by date range, create)

- [x] 1.12 **SwiftData repository implementations** in `Repositories/`:
  - `SwiftDataAccountRepository.swift` — uses `@ModelActor` for thread-safe background access
  - `SwiftDataTransactionRepository.swift` — supports `#Predicate` for filtering by date, category, account
  - `SwiftDataDebtRepository.swift`
  - `SwiftDataGoalRepository.swift`
  - `SwiftDataUserProfileRepository.swift`
  - `SwiftDataSnapshotRepository.swift`

- [x] 1.13 **Mock repositories** in `Repositories/Mocks/` for testing:
  - `MockAccountRepository.swift` — in-memory array, returns predefined data
  - Same for each repository — these use `swift-protocol-di-testing` patterns

### 1D — App Shell & Navigation

- [x] 1.14 **Delete Item.swift** — remove placeholder model
- [x] 1.15 **Update wealth_managerApp.swift** — register all SwiftData models in schema, set up `ModelContainer`, inject repositories via `@Environment`:
  ```swift
  @main struct WealthManagerApp: App {
      let container: ModelContainer
      init() {
          let schema = Schema([
              Account.self, Transaction.self, InvestmentHolding.self,
              Debt.self, FinancialGoal.self, UserProfile.self,
              NetWorthSnapshot.self, FinancialHealthScore.self
          ])
          container = try! ModelContainer(for: schema)
      }
      var body: some Scene {
          WindowGroup { MainSplitView() }
              .modelContainer(container)
      }
  }
  ```

- [x] 1.16 **MainSplitView.swift** — replace ContentView as root view. NavigationSplitView with frosted glass sidebar matching the design system. Flat nav list (no grouped sections — matches Stitch mockups):
  ```swift
  enum AppSection: String, CaseIterable, Identifiable {
      case dashboard, netWorth, accounts, budget, goals, aiAdvisor, reports, planning
      var id: String { rawValue }
      var label: String { ... }
      var icon: String { ... } // SF Symbol name
  }

  NavigationSplitView {
      // Sidebar — frosted glass panel, deep ocean blue
      List(selection: $selectedSection) {
          ForEach(AppSection.allCases) { section in
              Label(section.label, systemImage: section.icon)
                  .tag(section)
          }
      }
      // Bottom: user avatar + "Steve M."
  } content: {
      // List column (context-dependent — accounts list, goals list, etc.)
  } detail: {
      // Detail column
  }
  ```
  **Nav items (canonical order):**
  1. Dashboard — `house`
  2. Net Worth — `chart.line.uptrend.xyaxis`
  3. Accounts — `building.columns`
  4. Budget — `wallet.bifold`
  5. Goals — `target`
  6. AI Advisor — `bubble.left.and.bubble.right` (+ pulsing cyan dot overlay)
  7. Reports — `doc.text`
  8. Planning — `calendar`

  Keyboard shortcuts: Cmd+1 through Cmd+8. Selected state: subtle blue glow highlight (not solid block).

### 1E — Views & ViewModels (MVVM)

Use `swift-mvvm` skill: small ViewModels with `@Observable`, no business logic in views. Use `swiftui-patterns` for state management and navigation.

- [x] 1.17 **DashboardViewModel.swift** — `@Observable` class:
  ```swift
  @Observable final class DashboardViewModel {
      private let accountRepo: AccountRepository
      private let goalRepo: GoalRepository
      private let snapshotRepo: SnapshotRepository

      var netWorth: Decimal = 0
      var totalAssets: Decimal = 0
      var totalLiabilities: Decimal = 0
      var netWorthChange: Decimal = 0  // vs previous snapshot
      var healthScore: Int = 0
      var recentTransactions: [Transaction] = []
      var activeGoals: [FinancialGoal] = []
      var isLoading = false
      var error: Error?

      func loadDashboard() async { ... }
  }
  ```

- [x] 1.18 **DashboardView.swift** — macOS detail pane: net worth hero card, health score ring, quick action toolbar buttons, recent transactions table (macOS Table, not List). Uses Swift Charts for mini net worth sparkline. Fills the detail column when Dashboard is selected in sidebar.

- [x] 1.19 **AccountsViewModel.swift** — Groups accounts by type, computes section totals, handles add/delete:
  ```swift
  var groupedAccounts: [AccountType: [Account]]
  func addAccount(_ account: Account) async throws
  func deleteAccount(_ account: Account) async throws
  func refreshBalances() async
  ```

- [x] 1.20 **AccountsListView.swift** — Content column: sectioned list grouped by AccountType. Each section shows type header + subtotal. Each row: institution name, account name, balance. Right-click context menu (edit, delete, hide). Selection drives detail column. Toolbar: "Add Account" button, filter dropdown.

- [x] 1.21 **AccountDetailViewModel.swift** — Loads transactions for account, supports filtering:
  ```swift
  var account: Account
  var transactions: [Transaction]
  var selectedCategory: TransactionCategory?
  var dateRange: ClosedRange<Date>?
  func loadTransactions() async
  func filterByCategory(_ category: TransactionCategory?) async
  ```

- [x] 1.22 **AccountDetailView.swift** — Detail column: account header with balance + institution + last synced. Picker (segmented): Transactions | Analytics. Transactions: macOS `Table` with sortable columns (Date, Merchant, Category, Amount, Status). Search bar + category filter chips. Analytics: spending breakdown chart. Double-click transaction row to edit in sheet.

- [x] 1.23 **AddAccountView.swift** — macOS `.sheet()` modal: choice between "Link Account" (Phase 3: WKWebView Plaid) and "Add Manually". Manual form: account type picker, institution name, account name, balance decimal input, currency picker (default USD). Cancel + Save buttons. Keyboard shortcut: Cmd+N.

- [x] 1.24 **GoalsViewModel.swift** — CRUD for goals, sorted by priority:
  ```swift
  var goals: [FinancialGoal]
  func addGoal(_ goal: FinancialGoal) async throws
  func updateGoal(_ goal: FinancialGoal) async throws
  func deleteGoal(_ goal: FinancialGoal) async throws
  func reorderGoals(_ goals: [FinancialGoal]) async throws
  ```

- [x] 1.25 **GoalsListView.swift** — Content column: list with circular progress rings, goal name, current/target amounts, projected date. Drag to reorder priority. Selection drives GoalDetailView in detail column. Right-click context menu. Toolbar: "Add Goal" button.

- [x] 1.26 **GoalDetailView.swift** — Large progress ring, milestone markers, contribution history, edit button. Phase 2 adds projection chart here.

- [x] 1.27 **AddGoalView.swift** — Form: goal type picker, name, target amount, target date (optional), monthly contribution, priority, notes.

- [x] 1.28 **ProfileView.swift + ProfileViewModel.swift** — Form for UserProfile fields: date of birth, annual income, monthly expenses, filing status, state, retirement age, risk tolerance, dependents, spouse info. Auto-saves on edit.

### 1F — Budget & Planning Views

- [x] 1.36 **BudgetViewModel.swift** — `@Observable` class:
  ```swift
  var selectedMonth: Date  // current month
  var categories: [BudgetCategorySummary]  // category + spent + limit + trend
  var totalIncome: Decimal
  var totalSpent: Decimal
  var remaining: Decimal
  func loadBudget(for month: Date) async
  func updateCategoryLimit(_ category: TransactionCategory, limit: Decimal) async throws
  ```
- [x] 1.37 **BudgetView.swift** — Detail view matching Stitch `97ec8693`: month selector glass pill, budget summary bar (income/spent/remaining with gradient progress), AI insight card, 2x4 category grid (glass cards with progress rings), spending trend area chart (actual vs budget dashed line). Over-budget categories glow red.
- [x] 1.38 **PlanningView.swift** — Placeholder hub view with glass cards for Retirement, Tax, Debt, Insurance. Each card shows key metric + "Explore" button. Full implementations in Sprint 8. AI insight card with holistic planning advice.

### 1F2 — Design System & Reusable Components

- [x] 1.35 **Theme/ directory** — Design system tokens from Stitch mockups:
  - `Theme/WMColors.swift` — All color tokens from design system (background, glassBg, glassBorder, primary, secondary, tertiary, glow, positive, negative, textPrimary, textMuted)
  - `Theme/WMGlassModifier.swift` — `.glassCard()` ViewModifier (25px blur, 10% white bg, 12% luminous border, blue-tinted shadow)
  - `Theme/WMTypography.swift` — Font styles (heroNumber: Inter thin 48pt, heading: Inter semibold, body: Inter regular, muted: Inter regular + 50% opacity)
  - `Theme/WMComponents.swift` — `AIInsightCard` (frosted glass + cyan orb + text), `GlassButton`, `GlassPill`
- [x] 1.29 **Components/CurrencyText.swift** — Formats `Decimal` as currency string with locale support. Handles sign coloring (green glow positive, red glow negative per design system).
- [x] 1.30 **Components/ProgressRing.swift** — Circular progress indicator with gradient stroke (blue-to-cyan), percentage label, customizable size. Over-threshold turns red.
- [x] 1.31 **Components/EmptyStateView.swift** — Generic empty state with icon, title, description, action button. Frosted glass card styling.

### 1G — Testing

Use `tdd-workflow`: write tests FIRST (red), then implement (green), then refactor (improve). Target 80%+ coverage.

- [x] 1.32 **Model unit tests** — Test computed properties, initializers, Codable conformance for all 9 models (including BudgetCategory). Example: Account.isAsset returns true for checking, false for creditCard. Debt.monthlyInterest computes correctly. BudgetCategory.isOverBudget triggers correctly.
- [x] 1.33 **Repository unit tests** — Use mock repositories to test CRUD operations, filtering, sorting. Verify protocol conformance. Test edge cases: empty results, duplicate IDs, concurrent access.
- [x] 1.34 **ViewModel unit tests** — Inject mock repositories. Test: DashboardViewModel.loadDashboard populates all fields. AccountsViewModel.groupedAccounts groups correctly. GoalsViewModel.reorderGoals updates priorities. BudgetViewModel.loadBudget computes category summaries correctly.
- [x] 1.35 **Build + run verification** — Clean build, run on simulator, verify tab navigation, add/edit/delete accounts and goals manually.

---

## Phase 2: Calculation Engine + Net Worth (M)
> Deps: Phase 1
> Skills: `swift-mvvm`, `swiftui-patterns`, `tdd-workflow`, `coding-standards`
> Goal: On-device deterministic financial math, net worth tracking/projections, health score, what-if simulator, Swift Charts.
> Note: Can run in parallel with Phase 3.

**Sprints:** 3 (Calculators, Lane A) → 4 (Net Worth Views, Lane A)
**See sprint plan above for concurrency lanes — runs parallel with Backend (Lanes B+C)**

**Critical rule: Use `Decimal` throughout. Never `Double` for money. All calculators are pure functions (input → output, no side effects) for easy testing.**

### 2A — Core Calculators

Each calculator is a `struct` with static methods. No dependencies, no state — pure math.

- [x] 2.1 **CompoundInterestCalculator.swift** in `Services/Calculators/`:
  ```swift
  struct CompoundInterestCalculator {
      /// Future value of a lump sum: FV = PV * (1 + r/n)^(n*t)
      static func futureValue(presentValue: Decimal, annualRate: Decimal, years: Int, compoundingPerYear: Int = 12) -> Decimal

      /// Future value with regular contributions: FV = PMT * (((1 + r/n)^(n*t) - 1) / (r/n))
      static func futureValueWithContributions(monthlyContribution: Decimal, annualRate: Decimal, years: Int) -> Decimal

      /// Present value needed for a target future value
      static func presentValue(futureValue: Decimal, annualRate: Decimal, years: Int) -> Decimal

      /// CAGR from starting and ending values
      static func cagr(startValue: Decimal, endValue: Decimal, years: Int) -> Decimal

      /// Required monthly contribution to reach a target
      static func requiredMonthlyContribution(targetValue: Decimal, currentValue: Decimal, annualRate: Decimal, years: Int) -> Decimal
  }
  ```

- [x] 2.2 **RetirementCalculator.swift**:
  ```swift
  struct RetirementCalculator {
      struct FIREResult {
          let fireNumber: Decimal        // annual expenses / withdrawal rate
          let yearsToFIRE: Int?          // nil if already reached
          let monthlyContributionNeeded: Decimal
          let projectedRetirementIncome: Decimal
      }

      enum FIREType { case lean, regular, fat }

      /// Calculate FIRE number based on annual expenses and withdrawal rate
      static func fireNumber(annualExpenses: Decimal, withdrawalRate: Decimal = 0.04) -> Decimal

      /// Years to reach FIRE from current portfolio
      static func yearsToFIRE(currentPortfolio: Decimal, annualContribution: Decimal, annualExpenses: Decimal, expectedReturn: Decimal, withdrawalRate: Decimal = 0.04) -> Int?

      /// Safe withdrawal rate modeling (4% rule, dynamic spending, guardrails)
      static func safeWithdrawal(portfolio: Decimal, rate: Decimal, inflationRate: Decimal, years: Int) -> [YearlyWithdrawal]

      /// Contribution impact: "increase by X% → retire Y years earlier"
      static func contributionImpact(currentContribution: Decimal, increasePercent: Decimal, currentPortfolio: Decimal, annualExpenses: Decimal, expectedReturn: Decimal) -> (originalYears: Int, newYears: Int, yearsSaved: Int)

      /// Social Security breakeven: when does delaying benefits pay off?
      static func socialSecurityBreakeven(age62Benefit: Decimal, age67Benefit: Decimal, age70Benefit: Decimal) -> (delayTo67Breakeven: Int, delayTo70Breakeven: Int)

      /// Retirement readiness score (0-100)
      static func readinessScore(currentPortfolio: Decimal, annualContribution: Decimal, yearsToRetirement: Int, annualExpensesInRetirement: Decimal, expectedReturn: Decimal, socialSecurityBenefit: Decimal?) -> Int
  }
  ```

- [x] 2.3 **DebtCalculator.swift**:
  ```swift
  struct DebtCalculator {
      struct AmortizationEntry {
          let month: Int
          let payment: Decimal
          let principal: Decimal
          let interest: Decimal
          let remainingBalance: Decimal
      }

      struct PayoffPlan {
          let debts: [(name: String, payoffMonth: Int, totalInterestPaid: Decimal)]
          let totalMonths: Int
          let totalInterestPaid: Decimal
      }

      /// Full amortization schedule for a single debt
      static func amortizationSchedule(balance: Decimal, annualRate: Decimal, monthlyPayment: Decimal) -> [AmortizationEntry]

      /// Avalanche method: highest interest rate first
      static func avalanchePayoff(debts: [Debt], extraMonthlyPayment: Decimal) -> PayoffPlan

      /// Snowball method: smallest balance first
      static func snowballPayoff(debts: [Debt], extraMonthlyPayment: Decimal) -> PayoffPlan

      /// Hybrid: factor in investment opportunity cost (if debt rate < expected return, invest instead)
      static func optimizedPayoff(debts: [Debt], extraMonthlyPayment: Decimal, expectedInvestmentReturn: Decimal) -> PayoffPlan

      /// Mortgage refinance break-even: months until savings exceed closing costs
      static func refinanceBreakeven(currentBalance: Decimal, currentRate: Decimal, newRate: Decimal, closingCosts: Decimal, remainingMonths: Int) -> Int?

      /// Should I pay off debt or invest? Net benefit comparison over N years
      static func debtVsInvest(debtBalance: Decimal, debtRate: Decimal, investmentReturn: Decimal, monthlyAmount: Decimal, years: Int) -> (payDebtBenefit: Decimal, investBenefit: Decimal, recommendation: String)
  }
  ```

- [x] 2.4 **TaxCalculator.swift**:
  ```swift
  struct TaxCalculator {
      /// 2026 federal tax brackets (update annually)
      static func federalTax(taxableIncome: Decimal, filingStatus: FilingStatus) -> Decimal

      /// Marginal vs effective tax rate
      static func taxRates(taxableIncome: Decimal, filingStatus: FilingStatus) -> (marginal: Decimal, effective: Decimal)

      /// Capital gains tax (short-term vs long-term)
      static func capitalGainsTax(gains: Decimal, holdingPeriodMonths: Int, ordinaryIncome: Decimal, filingStatus: FilingStatus) -> Decimal

      /// Roth conversion analysis: tax cost now vs tax savings later
      static func rothConversionAnalysis(conversionAmount: Decimal, currentTaxableIncome: Decimal, filingStatus: FilingStatus, yearsToRetirement: Int, expectedRetirementTaxRate: Decimal) -> (taxCostNow: Decimal, projectedTaxSavings: Decimal, netBenefit: Decimal)

      /// Tax-loss harvesting opportunities: holdings with unrealized losses
      static func harvestingOpportunities(holdings: [InvestmentHolding]) -> [(holding: InvestmentHolding, unrealizedLoss: Decimal, estimatedTaxSavings: Decimal)]

      /// Asset location optimization: which assets in taxable vs tax-advantaged?
      static func assetLocationRecommendation(holdings: [InvestmentHolding], taxableAccountIds: Set<UUID>, taxAdvantaedAccountIds: Set<UUID>) -> [AssetLocationSuggestion]

      /// Estimated annual tax liability from all income sources
      static func estimatedAnnualTax(salary: Decimal, capitalGains: Decimal, dividends: Decimal, filingStatus: FilingStatus, deductions: Decimal) -> Decimal
  }
  ```

- [x] 2.5 **NetWorthProjector.swift**:
  ```swift
  struct NetWorthProjector {
      struct ProjectionPoint {
          let year: Int
          let netWorth: Decimal
          let assets: Decimal
          let liabilities: Decimal
      }

      struct ScenarioResult {
          let label: String  // "Conservative", "Moderate", "Aggressive"
          let points: [ProjectionPoint]
          let finalNetWorth: Decimal
      }

      /// Linear projection based on current savings rate and return assumptions
      static func linearProjection(currentNetWorth: Decimal, annualSavings: Decimal, annualReturn: Decimal, years: Int) -> [ProjectionPoint]

      /// Multi-scenario projection (conservative/moderate/aggressive)
      static func multiScenario(currentNetWorth: Decimal, annualSavings: Decimal, years: Int) -> [ScenarioResult]
      // Conservative: 4% return, Moderate: 7%, Aggressive: 10%

      /// Monte Carlo simulation (1000 runs, random returns based on historical distribution)
      static func monteCarlo(currentNetWorth: Decimal, annualSavings: Decimal, years: Int, runs: Int = 1000) -> MonteCarloResult
      // Returns percentile bands: 10th, 25th, 50th, 75th, 90th

      /// Milestone timeline: when do I hit $X?
      static func milestoneTimeline(currentNetWorth: Decimal, annualSavings: Decimal, annualReturn: Decimal, milestones: [Decimal]) -> [(milestone: Decimal, yearsFromNow: Int, date: Date)]

      /// What-if scenarios
      static func whatIf(currentNetWorth: Decimal, annualSavings: Decimal, annualReturn: Decimal, years: Int, adjustment: WhatIfAdjustment) -> [ProjectionPoint]
      // WhatIfAdjustment: .increaseSavings(Decimal), .payOffMortgage(Decimal), .sabbatical(months: Int), .sellRSUs(Decimal)
  }
  ```

- [x] 2.6 **HealthScoreCalculator.swift**:
  ```swift
  struct HealthScoreCalculator {
      /// Composite financial health score (0-100)
      /// Weights: savings 25%, debt 25%, investments 20%, emergency 20%, insurance 10%
      static func calculate(
          monthlySavingsRate: Decimal,       // savings / income
          debtToIncomeRatio: Decimal,        // total debt payments / income
          investmentDiversification: Decimal, // 0-1 based on asset class spread
          emergencyFundMonths: Decimal,       // liquid savings / monthly expenses
          hasAdequateInsurance: Bool
      ) -> FinancialHealthScore

      /// Individual component scores
      static func savingsScore(rate: Decimal) -> Int  // 20%+ = 100, 0% = 0
      static func debtScore(dtiRatio: Decimal) -> Int  // <20% = 100, >50% = 0
      static func investmentScore(diversification: Decimal, growthRate: Decimal) -> Int
      static func emergencyFundScore(months: Decimal) -> Int  // 6+ = 100, 0 = 0
      static func insuranceScore(hasLife: Bool, hasDisability: Bool, hasHealth: Bool) -> Int
  }
  ```

- [x] 2.7 **InsuranceCalculator.swift**:
  ```swift
  struct InsuranceCalculator {
      /// Life insurance needs using DIME method
      /// D=Debt, I=Income replacement, M=Mortgage, E=Education
      static func lifeInsuranceNeed(totalDebt: Decimal, annualIncome: Decimal, yearsToReplace: Int, mortgageBalance: Decimal, educationCosts: Decimal, existingCoverage: Decimal) -> (totalNeed: Decimal, gap: Decimal)

      /// Emergency fund adequacy (months of expenses)
      static func emergencyFundAdequacy(liquidSavings: Decimal, monthlyExpenses: Decimal) -> (monthsCovered: Decimal, targetMonths: Int, shortfall: Decimal)
      // Target: 3 months (single, stable job), 6 months (default), 9+ months (freelancer/variable income)

      /// Disability insurance coverage gap
      static func disabilityCoverageGap(annualIncome: Decimal, existingCoverage: Decimal) -> (recommendedCoverage: Decimal, gap: Decimal)
      // Recommended: 60-70% of income
  }
  ```

### 2B — Services

- [x] 2.8 **NetWorthService.swift** — Orchestrates snapshot creation:
  ```swift
  @Observable final class NetWorthService {
      private let accountRepo: AccountRepository
      private let snapshotRepo: SnapshotRepository

      /// Create a snapshot of current net worth
      func createSnapshot() async throws -> NetWorthSnapshot

      /// Get historical snapshots for charting
      func history(dateRange: ClosedRange<Date>) async throws -> [NetWorthSnapshot]

      /// Net worth change over a period
      func change(period: TimePeriod) async throws -> (amount: Decimal, percent: Decimal)
  }
  ```

- [x] 2.9 **ProjectionService.swift** — Wraps calculators with user context:
  ```swift
  @Observable final class ProjectionService {
      func netWorthProjection(profile: UserProfile, currentNetWorth: Decimal, years: Int) async -> [ScenarioResult]
      func retirementReadiness(profile: UserProfile, portfolio: Decimal, annualContribution: Decimal) async -> RetirementCalculator.FIREResult
      func milestones(currentNetWorth: Decimal, profile: UserProfile) async -> [(milestone: Decimal, date: Date)]
  }
  ```

### 2C — Net Worth Views

- [ ] 2.10 **NetWorthView.swift** — Main net worth screen:
  - Hero: current net worth, daily/weekly change with arrow
  - Swift Charts line chart with time range selector (1M, 3M, 6M, 1Y, 5Y, All)
  - Assets vs Liabilities stacked bar chart
  - Breakdown list: each account's contribution to net worth
  - NavigationLink to ProjectionView and WhatIfView

- [ ] 2.11 **ProjectionView.swift** — Trajectory visualization:
  - Multi-line chart showing conservative/moderate/aggressive scenarios
  - Adjustable sliders: annual savings, expected return rate, years to project
  - Milestone markers on the chart ($100k, $250k, $500k, $1M, etc.)
  - Monte Carlo probability bands (10th-90th percentile shading)

- [ ] 2.12 **WhatIfView.swift** — Interactive simulator:
  - Base case line shown as reference
  - Toggle scenarios: "Pay off mortgage early", "Increase savings by $X/mo", "Take a sabbatical year", "Sell RSUs now vs hold"
  - Each toggle adds/removes a comparison line on the chart
  - Summary card: "This scenario results in $X more/less at retirement"

### 2D — Testing

- [x] 2.13 **Calculator unit tests** — Exhaustive tests for every calculator method. Use known financial formulas to verify. Example test cases:
  - CompoundInterest: $10,000 at 7% for 30 years = $76,122.55 (verify to the penny)
  - FIRE: $40k expenses at 4% = $1M FIRE number
  - Amortization: verify total payments = principal + total interest
  - Tax brackets: verify against IRS published tables
  - Monte Carlo: verify output range is reasonable, percentiles ordered correctly

- [x] 2.14 **Decimal compliance audit** — Grep entire codebase for `Double` in financial contexts. All money values must be `Decimal`.

- [ ] 2.15 **Integration tests** — Test ProjectionService end-to-end with mock repos: create profile + accounts → generate projections → verify output structure.

---

## Phase 3: Backend + Plaid Integration (XL)
> Deps: Phase 1
> Skills: `plaid-fintech`, `api-design`, `backend-patterns`, `python-patterns`, `python-testing`, `postgres-patterns`, `database-migrations`, `docker-patterns`, `security-review`, `coding-standards`
> Goal: FastAPI backend, Plaid account linking + transaction sync, iOS networking layer, auth.
> Note: Can run in parallel with Phase 2.

**Sprints:** 3 (Backend Scaffold, Lanes B+C) → 4 (Auth+Plaid, Lanes B+C) → 5 (iOS Networking + Plaid WKWebView)
**See sprint plan above for concurrency lanes — runs parallel with Calc Engine (Lane A)**

**Search-first (Exa) before coding:**
```
Search for existing FastAPI + Plaid integration templates or skeleton projects
Search for Python Plaid transactions/sync webhook handling patterns
Search for macOS WKWebView Plaid Link integration examples
```

### 3-PREREQ — Plaid Account Setup

- [ ] 3.0 **Sign up for Plaid** at https://dashboard.plaid.com/signup — free sandbox access, no credit card needed. Get `client_id` and `sandbox` secret. Store in `backend/.env` (never in code). Sandbox gives test institutions + fake transaction data for development.

### 3A — Backend Scaffold

Use `python-patterns` (PEP 8, type hints, pathlib) and `backend-patterns` (repository pattern, service layer).

- [x] 3.1 **Scaffold FastAPI project** at `backend/`:
  ```
  backend/
    app/
      __init__.py
      main.py            # FastAPI app factory, CORS, lifespan events
      config.py           # Pydantic Settings (env vars: DATABASE_URL, PLAID_*, CLAUDE_API_KEY, JWT_SECRET)
      database.py         # async SQLAlchemy engine + sessionmaker
      dependencies.py     # FastAPI Depends() for DB session, auth, rate limiting
      models/
        __init__.py
        user.py           # SQLAlchemy User model (id, apple_id, email, created_at)
        account.py        # mirrors iOS Account model
        transaction.py
        holding.py
        debt.py
        goal.py
        snapshot.py
      schemas/
        __init__.py
        auth.py           # AppleSignInRequest, TokenResponse, RefreshRequest
        account.py        # AccountCreate, AccountUpdate, AccountResponse
        transaction.py    # TransactionResponse, TransactionFilter
        plaid.py          # LinkTokenResponse, ExchangeTokenRequest
        sync.py           # SyncRequest, SyncResponse (with deltas)
        common.py         # APIResponse envelope, PaginatedResponse, ErrorResponse
      routers/
        __init__.py
        auth.py
        accounts.py
        transactions.py
        plaid.py
        webhooks.py
        sync.py
      services/
        __init__.py
        auth_service.py   # Apple ID token validation, JWT creation/refresh
        plaid_service.py  # Plaid client wrapper
        sync_service.py   # Delta sync logic
        account_service.py
      repositories/
        __init__.py
        base.py           # Generic CRUD repository base
        user_repository.py
        account_repository.py
        transaction_repository.py
      middleware/
        __init__.py
        auth.py           # JWT validation middleware
        rate_limiter.py   # Redis-based rate limiting
    migrations/
      env.py
      versions/
    tests/
      __init__.py
      conftest.py         # pytest fixtures: test DB, test client, auth headers
      test_auth.py
      test_accounts.py
      test_plaid.py
      test_sync.py
    requirements.txt
    Dockerfile
    docker-compose.yml    # app + postgres + redis
    .env.example
  ```

- [x] 3.2 **config.py** — Pydantic `BaseSettings` with:
  ```python
  class Settings(BaseSettings):
      database_url: str
      redis_url: str = "redis://localhost:6379"
      jwt_secret: str
      jwt_algorithm: str = "HS256"
      jwt_expire_minutes: int = 30
      plaid_client_id: str
      plaid_secret: str
      plaid_env: str = "sandbox"  # sandbox | development | production
      claude_api_key: str
      cors_origins: list[str] = ["*"]

      model_config = SettingsConfigDict(env_file=".env")
  ```

### 3B — Database Models & Migrations

Use `postgres-patterns` for data types and indexing. Use `database-migrations` for safe Alembic migrations.

- [x] 3.3 **SQLAlchemy models** — Map to iOS SwiftData models:
  ```python
  # models/user.py
  class User(Base):
      __tablename__ = "users"
      id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
      apple_id: Mapped[str] = mapped_column(unique=True, index=True)
      email: Mapped[str | None]
      created_at: Mapped[datetime] = mapped_column(default=func.now())

      accounts: Mapped[list["Account"]] = relationship(back_populates="user", cascade="all, delete-orphan")

  # models/account.py — includes plaid_access_token (encrypted), plaid_item_id
  # models/transaction.py — index on (account_id, date)
  # models/holding.py
  # models/debt.py
  # models/snapshot.py — index on (user_id, date)
  ```
  Use `Numeric(precision=19, scale=4)` for all money columns. Use `timestamptz` for all dates.

- [x] 3.4 **Alembic setup** — `alembic init migrations`, configure `env.py` for async SQLAlchemy, create initial migration with all tables.

### 3C — Auth

- [ ] 3.5 **auth_service.py** — Apple Sign-In token validation + JWT:
  ```python
  class AuthService:
      async def verify_apple_token(self, identity_token: str) -> AppleUserInfo
      # Validates Apple ID token against Apple's JWKS endpoint

      def create_access_token(self, user_id: uuid.UUID) -> str
      # JWT with user_id claim, expires in 30 min

      def create_refresh_token(self, user_id: uuid.UUID) -> str
      # JWT with longer expiry (30 days)

      def verify_token(self, token: str) -> uuid.UUID
      # Decode and validate JWT, return user_id
  ```

- [x] 3.6 **Auth router** — `POST /auth/login` (exchange Apple token for JWT), `POST /auth/refresh` (refresh JWT), `GET /auth/me` (current user info)

- [x] 3.7 **Auth middleware** — `dependencies.py` with `get_current_user` dependency that extracts and validates JWT from Authorization header. All protected routes use this. AuthMiddleware skips public paths (/health/*, /docs, /api/v1/auth/login, webhooks).

### 3D — Plaid Integration

Use `plaid-fintech` skill for Link token flows, transaction sync patterns, and error handling.

- [x] 3.8 **plaid_service.py** — Wraps `plaid-python` SDK:
  ```python
  class PlaidService:
      def __init__(self, settings: Settings):
          config = plaid.Configuration(
              host=PlaidEnvironment[settings.plaid_env],
              api_key={"clientId": settings.plaid_client_id, "secret": settings.plaid_secret}
          )
          self.client = plaid_api.PlaidApi(plaid.ApiClient(config))

      async def create_link_token(self, user_id: str) -> str
      # Products: transactions, investments, liabilities
      # Country codes: US
      # Returns link_token for iOS Plaid Link SDK

      async def exchange_public_token(self, public_token: str) -> tuple[str, str]
      # Returns (access_token, item_id)

      async def sync_transactions(self, access_token: str, cursor: str | None) -> TransactionSyncResponse
      # Uses /transactions/sync endpoint (not /get)
      # Returns added, modified, removed transactions + next cursor

      async def get_accounts(self, access_token: str) -> list[AccountBase]

      async def get_investment_holdings(self, access_token: str) -> InvestmentHoldingsResponse

      async def get_liabilities(self, access_token: str) -> LiabilitiesResponse
      # Returns student loans, credit cards, mortgages
  ```

- [x] 3.9 **Plaid router**:
  - `POST /plaid/create-link-token` — requires auth, returns `{link_token: str, expiration: str}`
  - `POST /plaid/exchange-token` — receives `{public_token: str, metadata: {...}}` from iOS after Plaid Link success. Exchanges token, stores access_token (encrypted) and item_id, triggers initial account + transaction sync.

- [x] 3.10 **Webhook handler** — `POST /webhooks/plaid`:
  ```python
  # Handles webhook types:
  # TRANSACTIONS: SYNC_UPDATES_AVAILABLE → trigger transaction sync
  # ITEM: ERROR → mark account as needing re-link
  # HOLDINGS: DEFAULT_UPDATE → trigger investment sync
  # LIABILITIES: DEFAULT_UPDATE → trigger debt sync
  # Verify webhook with Plaid webhook verification
  ```

### 3E — Sync Engine

- [ ] 3.11 **sync_service.py** — Bidirectional delta sync:
  ```python
  class SyncService:
      async def get_changes_since(self, user_id: UUID, since: datetime) -> SyncResponse:
          """Return all accounts, transactions, holdings, debts, goals
          that were created/updated/deleted since the given timestamp."""
          # Returns: { accounts: [...], transactions: [...], ..., server_timestamp: datetime }

      async def apply_client_changes(self, user_id: UUID, changes: SyncRequest) -> SyncResponse:
          """Apply changes pushed from iOS (manual accounts, goals, profile updates).
          Returns any conflicts or server-side updates."""
          # Conflict resolution: server wins for Plaid data, client wins for manual data
  ```

- [ ] 3.12 **Sync endpoints**:
  - `GET /sync?since={iso_timestamp}` — pull changes
  - `POST /sync` — push local changes (manual accounts, goals, profile updates)

### 3F — Docker

Use `docker-patterns` for multi-service compose with health checks.

- [x] 3.13 **Dockerfile** — multi-stage build:
  ```dockerfile
  FROM python:3.12-slim AS base
  # Install dependencies, copy app, run with uvicorn
  HEALTHCHECK CMD curl -f http://localhost:8000/health || exit 1
  ```

- [x] 3.14 **docker-compose.yml** — 3 services:
  ```yaml
  services:
    api:
      build: .
      ports: ["8000:8000"]
      depends_on: [db, redis]
      env_file: .env
    db:
      image: postgres:16
      volumes: [pgdata:/var/lib/postgresql/data]
      healthcheck: pg_isready
    redis:
      image: redis:7-alpine
      healthcheck: redis-cli ping
  ```

### 3G — iOS Networking Layer

Use `swift-protocol-di-testing` for protocol-based HTTP client abstraction.

- [ ] 3.15 **APIClient.swift** in `Services/Network/`:
  ```swift
  protocol APIClientProtocol {
      func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
      func upload(_ data: Data, to endpoint: Endpoint) async throws
  }

  final class APIClient: APIClientProtocol {
      private let baseURL: URL
      private let session: URLSession
      private var accessToken: String?

      // Handles: JWT injection, 401 → auto-refresh, retry with exponential backoff, response envelope unwrapping
  }
  ```

- [ ] 3.16 **Endpoint.swift** — Type-safe endpoint definitions:
  ```swift
  enum Endpoint {
      case appleSignIn(identityToken: String)
      case refreshToken(refreshToken: String)
      case createLinkToken
      case exchangeToken(publicToken: String, metadata: PlaidMetadata)
      case sync(since: Date?)
      case pushChanges(SyncRequest)
      // Each case computes: path, method, headers, body
  }
  ```

- [ ] 3.17 **AuthService.swift** — Apple Sign-In + JWT lifecycle:
  ```swift
  protocol AuthServiceProtocol {
      func signInWithApple() async throws -> User
      func refreshTokenIfNeeded() async throws
      func signOut() async throws
      var isAuthenticated: Bool { get }
  }
  ```
  Stores tokens in Keychain (not UserDefaults).

- [ ] 3.18 **PlaidLinkService.swift** — Coordinates Plaid Link via WKWebView (macOS):
  ```swift
  protocol PlaidLinkServiceProtocol {
      func createLinkToken() async throws -> String
      func handleLinkSuccess(publicToken: String, metadata: [String: Any]) async throws -> [Account]
  }

  // macOS implementation: opens Plaid Link in a WKWebView sheet
  // 1. Fetches link_token from backend
  // 2. Loads Plaid Link web URL with link_token in WKWebView
  // 3. Intercepts JavaScript postMessage for onSuccess/onExit events
  // 4. Extracts public_token from success event
  // 5. Sends public_token to backend for exchange
  // iOS port: replace with native Plaid Link iOS SDK (LinkKit)
  ```

- [ ] 3.18b **PlaidLinkWebView.swift** — NSViewRepresentable wrapping WKWebView:
  ```swift
  struct PlaidLinkWebView: NSViewRepresentable {
      let linkToken: String
      let onSuccess: (String, [String: Any]) -> Void  // (publicToken, metadata)
      let onExit: (Error?) -> Void

      // Loads: https://cdn.plaid.com/link/v2/stable/link.html?token={linkToken}
      // WKScriptMessageHandler captures window.postMessage events
      // Handles: PlaidLink.onSuccess, PlaidLink.onExit, PlaidLink.onEvent
  }
  ```

- [ ] 3.19 **SyncService.swift** — Bidirectional sync engine:
  ```swift
  protocol SyncServiceProtocol {
      func pullChanges() async throws
      func pushChanges() async throws
      func fullSync() async throws
      var lastSyncedAt: Date? { get }
  }
  // Pulls deltas from backend, upserts into SwiftData
  // Pushes local manual entries/goals to backend
  // Stores lastSyncedAt in UserDefaults
  ```

- [ ] 3.20 **Update AddAccountView** — Add "Link Account" option alongside manual entry. Tapping "Link Account" triggers PlaidLinkService flow.

### 3H — Testing

- [ ] 3.21 **Backend pytest suite** — Use `python-testing` patterns:
  - `conftest.py`: async test client fixture, test database (SQLite in-memory), mock Plaid client, mock auth
  - `test_auth.py`: verify Apple token exchange, JWT creation/validation, refresh flow, expired token handling
  - `test_plaid.py`: mock Plaid API responses, test link token creation, token exchange, transaction sync
  - `test_sync.py`: test delta sync with various change combinations, conflict resolution
  - `test_accounts.py`: CRUD operations, authorization (users can only see their own data)
  - Target: 80%+ coverage

- [ ] 3.22 **iOS networking tests** — Mock APIClient returns predefined responses. Test SyncService upsert logic. Test auth flow state machine.

- [ ] 3.23 **End-to-end Plaid sandbox test** — Use Plaid sandbox credentials: link a test institution → verify accounts appear → trigger transaction webhook → verify transactions sync to iOS.

---

## Phase 4: AI Advisory Engine (XL)
> Deps: Phase 3
> Skills: `backend-patterns`, `python-patterns`, `python-testing`, `swift-mvvm`, `swiftui-patterns`, `foundation-models-on-device`, `api-design`, `coding-standards`
> Goal: Claude API integration for narrative reports, coaching, chat, proactive alerts.

**Sprints:** 6 (AI Backend) → 7 (AI iOS Views)
**See sprint plan above for concurrency lanes**

**Search-first (Exa) before coding:**
```
Search for Claude API streaming chat integration patterns in FastAPI (SSE)
Search for financial advisor prompt engineering examples for LLMs
Search for SwiftUI streaming text / SSE chat UI implementations
```

### Hybrid AI Pattern
1. On-device calculators (Phase 2) produce raw numbers (net worth projection, debt payoff timeline, tax estimate)
2. iOS sends calculation results + user context to backend
3. Backend constructs rich prompt with financial snapshot + appropriate system prompt
4. Claude generates narrative coaching, actionable recommendations, risk warnings
5. iOS renders structured response (markdown sections, highlighted actions, charts)

Optional: Use `foundation-models-on-device` (Apple FoundationModels) for quick on-device summaries when offline or for low-latency responses.

### 4A — Backend Claude Integration

- [ ] 4.1 **claude_service.py** — Claude API wrapper:
  ```python
  class ClaudeService:
      def __init__(self, settings: Settings):
          self.client = anthropic.Anthropic(api_key=settings.claude_api_key)

      async def generate(self, system_prompt: str, user_message: str, max_tokens: int = 2000) -> str

      async def stream(self, system_prompt: str, user_message: str) -> AsyncGenerator[str, None]
      # For streaming chat responses

      async def structured_generate(self, system_prompt: str, user_message: str, schema: type[BaseModel]) -> BaseModel
      # Uses tool_use to get structured JSON responses for reports
  ```

- [ ] 4.2 **prompt_manager.py** — Template loading + context injection:
  ```python
  class PromptManager:
      def __init__(self, prompts_dir: Path):
          self.env = Environment(loader=FileSystemLoader(prompts_dir))

      def build_financial_context(self, user_data: UserFinancialSnapshot) -> str
      # Builds a structured text block with: net worth, income, debts, goals, health score, recent changes

      def render_prompt(self, template_name: str, context: dict) -> str
      # Renders Jinja2 template with financial context injected
  ```

- [ ] 4.3 **System prompts** in `app/prompts/system/`:
  - `financial_advisor.txt` — Core persona: "You are a certified financial planner acting as a personal CFO. You give specific, actionable advice based on the user's actual financial data. Be direct, quantify impact, and prioritize recommendations by financial impact. Never give generic advice — always reference their specific numbers."
  - `report_generator.txt` — Structured output: "Generate a financial briefing report. Use these sections: Executive Summary, Net Worth Update, Key Insights (3 max), Action Items (prioritized), Goal Progress, Risk Alerts. Be concise — this is a dashboard summary, not an essay."
  - `tax_advisor.txt` — Tax-specific persona with disclaimers about not being a CPA
  - `debt_strategist.txt` — Debt optimization focus

- [ ] 4.4 **Jinja2 templates** in `app/prompts/templates/`:
  - `weekly_briefing.jinja2` — Injects: net worth change, top 3 spending categories, goal progress, upcoming bills, any triggered alerts
  - `goal_coaching.jinja2` — Injects: specific goal data, progress rate, projected vs target date
  - `debt_strategy.jinja2` — Injects: all debts with rates/balances, available extra payment, investment return rate
  - `retirement_analysis.jinja2` — Injects: portfolio value, contribution rate, FIRE number, years to retirement

- [ ] 4.5 **advisory_service.py** — Orchestrates AI analysis:
  ```python
  class AdvisoryService:
      async def chat(self, user_id: UUID, message: str, conversation_id: UUID | None) -> AsyncGenerator[str, None]:
          """Stream a chat response with full financial context injected."""
          snapshot = await self._build_snapshot(user_id)
          context = self.prompt_manager.build_financial_context(snapshot)
          system = f"{ADVISOR_PROMPT}\n\nUser's Financial Data:\n{context}"
          async for chunk in self.claude.stream(system, message):
              yield chunk

      async def analyze_retirement(self, user_id: UUID) -> RetirementAnalysis
      async def analyze_tax(self, user_id: UUID) -> TaxAnalysis
      async def analyze_debt(self, user_id: UUID) -> DebtAnalysis
  ```

- [ ] 4.6 **report_service.py** — CFO briefing generation:
  ```python
  class ReportService:
      async def generate_briefing(self, user_id: UUID, period: str) -> CFOBriefing:
          """Generate weekly/monthly CFO briefing."""
          snapshot = await self._build_snapshot(user_id)
          calculations = self._run_calculations(snapshot)  # health score, net worth change, goal progress
          prompt = self.prompt_manager.render_prompt("weekly_briefing.jinja2", {
              "snapshot": snapshot,
              "calculations": calculations,
              "period": period
          })
          narrative = await self.claude.structured_generate(REPORT_PROMPT, prompt, BriefingSchema)
          return CFOBriefing(
              health_score=calculations.health_score,
              summary=narrative.summary,
              insights=narrative.insights,
              action_items=narrative.action_items,
              ...
          )
  ```

- [ ] 4.7 **alert_service.py** — Rule-based proactive alert detection:
  ```python
  class AlertService:
      async def check_alerts(self, user_id: UUID) -> list[ProactiveAlert]:
          """Run all alert rules against user's financial data."""
          rules = [
              self._check_emergency_fund_low,      # < 3 months expenses
              self._check_net_worth_milestone,      # crossed $100k, $250k, etc.
              self._check_debt_payoff_opportunity,   # rates dropped for refi
              self._check_tax_harvesting_season,     # Q4 harvesting window
              self._check_goal_off_track,            # projected miss date
              self._check_spending_spike,            # category spend > 2x average
              self._check_savings_rate_drop,         # savings rate declined
          ]
          alerts = []
          for rule in rules:
              alert = await rule(user_id)
              if alert:
                  alerts.append(alert)
          return alerts
  ```

- [ ] 4.8 **Advisory routers**:
  - `POST /advisor/chat` — streaming response (SSE), accepts `{message: str, conversation_id: UUID?}`
  - `GET /reports/briefing?period=weekly|monthly` — generate or fetch cached briefing
  - `GET /reports/health-score` — current health score with AI narrative explanation
  - `GET /alerts` — fetch active proactive alerts
  - `POST /advisor/analyze/retirement` — full retirement analysis
  - `POST /advisor/analyze/tax` — tax optimization suggestions
  - `POST /advisor/analyze/debt` — debt strategy recommendations

### 4B — iOS Advisory Models & Views

- [ ] 4.9 **New SwiftData models**:
  ```swift
  @Model class AdvisorMessage {
      @Attribute(.unique) var id: UUID
      var role: MessageRole  // enum: user, assistant
      var content: String
      var conversationId: UUID
      var createdAt: Date
  }

  @Model class CFOBriefing {
      @Attribute(.unique) var id: UUID
      var period: BriefingPeriod  // enum: weekly, monthly
      var generatedAt: Date
      var healthScore: Int
      var summaryMarkdown: String
      var keyInsights: [String]    // stored as JSON via Codable
      var actionItems: [String]
  }

  @Model class ProactiveAlert {
      @Attribute(.unique) var id: UUID
      var alertType: AlertType  // enum: emergencyFundLow, milestone, refiOpportunity, taxHarvesting, goalOffTrack, spendingSpike, savingsRateDrop
      var title: String
      var message: String
      var severity: AlertSeverity  // enum: info, warning, action
      var isRead: Bool = false
      var isDismissed: Bool = false
      var createdAt: Date
  }
  ```

- [ ] 4.10 **AdvisorChatViewModel.swift**:
  ```swift
  @Observable final class AdvisorChatViewModel {
      var messages: [AdvisorMessage] = []
      var currentInput: String = ""
      var isStreaming: Bool = false
      var conversationId: UUID = UUID()

      func sendMessage() async  // sends to backend, streams response, appends to messages
      func loadHistory() async  // loads previous messages from SwiftData
      func startNewConversation()
  }
  ```

- [ ] 4.11 **AdvisorChatView.swift** — Full chat interface:
  - ScrollView with message bubbles (user right-aligned blue, assistant left-aligned gray)
  - Markdown rendering in assistant messages (use `AttributedString` or lightweight markdown parser)
  - Streaming text animation (characters appear as they arrive via SSE)
  - Suggested prompt chips above input field
  - Input bar: text field + send button
  - Typing indicator while streaming

- [ ] 4.12 **CFOBriefingViewModel.swift**:
  ```swift
  @Observable final class CFOBriefingViewModel {
      var currentBriefing: CFOBriefing?
      var isGenerating: Bool = false

      func generateBriefing(period: BriefingPeriod) async
      func loadLatestBriefing() async
  }
  ```

- [ ] 4.13 **CFOBriefingView.swift** — Report card layout:
  - Header: period label, generation date
  - Health score ring (large, centered) with segment breakdown
  - "Executive Summary" section — rendered markdown
  - "Key Insights" — numbered list with icons
  - "Action Items" — checkbox list (tapping marks as done)
  - "Goal Progress" — mini progress bars for each active goal
  - "Risk Alerts" — warning cards if any
  - Share button → PDF export

- [ ] 4.14 **AlertsListView.swift + AlertsViewModel.swift**:
  - List of ProactiveAlert cards sorted by severity then date
  - Each card: severity icon (info=blue, warning=orange, action=red), title, message preview
  - Tap to expand full message
  - Swipe to dismiss
  - Badge count on tab bar

- [ ] 4.15 **Update MainSplitView** — Advisor and Reports sections already in sidebar. Add alert badge count to sidebar Dashboard item. Add menu bar: View > Advisor Chat (Cmd+Shift+A)

### 4C — Testing

- [ ] 4.16 **Backend advisory tests** — Mock Claude API responses. Test prompt construction includes financial context. Test structured output parsing. Test alert rule triggers.
- [ ] 4.17 **iOS advisory tests** — Mock API responses for chat/briefing/alerts. Test ViewModel state transitions. Test streaming message assembly.
- [ ] 4.18 **E2E test** — Create test user with known financial data → request briefing → verify response contains relevant numbers → verify alerts trigger for configured scenarios.

---

## Phase 5: Advanced Financial Tools (L)
> Deps: Phase 2, Phase 4
> Skills: `swift-mvvm`, `swiftui-patterns`, `tdd-workflow`, `coding-standards`
> Goal: Full retirement/FIRE suite, tax intelligence, debt strategy, insurance/risk analysis. Each tool combines deterministic on-device calculation + AI explanation via Claude.

**Sprint:** 8 — Three parallel lanes: Retirement (A), Tax (B), Debt+Insurance (C)
**See sprint plan above for concurrency lanes**

### 5A — Retirement & FIRE Planning

- [ ] 5.1 **RetirementDashboardView.swift** — Overview screen:
  - Retirement readiness score (0-100) gauge
  - Projected shortfall/surplus at retirement age
  - FIRE number display with progress bar
  - "Time to retirement" countdown
  - Navigation to sub-tools
  - "Ask AI to explain" button → sends readiness data to advisor chat

- [ ] 5.2 **FIRECalculatorView.swift** — Interactive FIRE calculator:
  - Inputs: annual expenses, portfolio value, annual savings, expected return
  - Segmented control: Lean FIRE (25x essential expenses) | Regular FIRE (25x total) | Fat FIRE (33x total)
  - Output: FIRE number, years to FIRE, required savings rate
  - Chart: portfolio growth trajectory to FIRE number intersection

- [ ] 5.3 **ContributionOptimizerView.swift** — Contribution impact simulator:
  - Current contribution amount display
  - Slider: "Increase by X%"
  - Real-time update: "Retire Y years earlier" / "Retire with $Z more"
  - 401k vs IRA vs taxable comparison table
  - AI recommendation: optimal contribution allocation

- [ ] 5.4 **SocialSecurityView.swift** — Breakeven analysis:
  - Three columns: claim at 62, claim at 67, claim at 70
  - Monthly benefit for each age
  - Breakeven chart: crossover points where delaying pays off
  - Lifetime benefit comparison at various life expectancies

- [ ] 5.5 **Extend RetirementCalculator** — Add: required minimum distribution (RMD) schedule, Social Security estimation from income history, dynamic spending rules (guardrails strategy)

### 5B — Tax Intelligence

- [ ] 5.6 **TaxDashboardView.swift** — Tax overview:
  - Estimated annual tax liability (federal + state)
  - Marginal vs effective rate display
  - Pie chart: tax breakdown by source (income, capital gains, dividends)
  - Links to optimization tools

- [ ] 5.7 **HarvestingOpportunitiesView.swift** — Tax-loss harvesting:
  - List of holdings with unrealized losses
  - Each row: security name, cost basis, current value, unrealized loss, estimated tax savings
  - Sort by largest potential savings
  - "Harvest" button → explains wash sale rules via AI
  - Seasonal reminder: optimal harvesting in Q4

- [ ] 5.8 **RothConversionView.swift** — Roth conversion ladder analysis:
  - Input: conversion amount slider
  - Output: tax cost this year, projected tax savings in retirement, net benefit
  - Multi-year projection: optimal conversion schedule across tax brackets
  - Chart: traditional vs Roth balance over time

- [ ] 5.9 **AssetLocationView.swift** — Asset location optimizer:
  - Current allocation: which assets in which account types
  - Recommendation: what should move where for tax efficiency
  - Rules: bonds/REITs → tax-advantaged, growth stocks → taxable (lower cap gains rate), international stocks → taxable (foreign tax credit)
  - Estimated annual tax savings from optimization

- [ ] 5.10 **Extend TaxCalculator** — Add: mega backdoor Roth eligibility check (plan allows after-tax + in-service conversion?), state tax bracket integration, AMT rough estimate

### 5C — Debt Strategy Intelligence

- [ ] 5.11 **DebtStrategyView.swift** — Comprehensive debt dashboard:
  - Total debt, weighted average interest rate, total minimum payments
  - Payoff comparison: Avalanche vs Snowball vs Optimized (side-by-side)
  - For each strategy: total interest paid, months to payoff, visual timeline
  - Extra payment input: "If I put $X extra/month toward debt..."
  - AI recommendation based on user's psychology + math

- [ ] 5.12 **RefinanceAnalysisView.swift** — Mortgage refinance monitor:
  - Current mortgage details: rate, balance, monthly payment, remaining months
  - "What if" refinance: new rate input, closing costs, new term
  - Break-even month calculation
  - Monthly savings, total interest savings
  - Rate drop alert threshold setting (notify when rates drop below X%)

- [ ] 5.13 **DebtVsInvestView.swift** — Pay off debt or invest calculator:
  - Input: extra monthly amount, debt rate, expected investment return
  - Side-by-side 10-year projection: scenario A (pay debt) vs scenario B (invest)
  - Net worth comparison at each year
  - Considers: tax deductibility of interest, investment tax drag
  - Clear recommendation with reasoning

### 5D — Insurance & Risk Gap Analysis

- [ ] 5.14 **InsuranceDashboardView.swift** — Risk overview:
  - Emergency fund adequacy bar (months covered vs target)
  - Life insurance coverage gap (need vs have)
  - Disability coverage gap
  - Estate planning checklist progress
  - Overall risk score

- [ ] 5.15 **LifeInsuranceCalculatorView.swift** — DIME method:
  - Inputs: outstanding debts, annual income, years to replace, mortgage balance, education fund needs, existing coverage
  - Output: total coverage needed, current gap
  - Recommendation: term vs whole, coverage amount

- [ ] 5.16 **EmergencyFundView.swift** — Emergency fund manager:
  - Current liquid savings
  - Monthly expenses (from transaction data)
  - Months covered gauge (target: 3-6 months depending on situation)
  - If below target: rebuilding plan with monthly savings recommendation
  - "Rebuild by [date]" calculator

- [ ] 5.17 **EstatePlanningChecklistView.swift** — Simple checklist:
  - [ ] Will/Trust created
  - [ ] Beneficiaries updated on all accounts
  - [ ] Power of Attorney designated
  - [ ] Healthcare directive
  - [ ] Life insurance beneficiaries current
  - [ ] Digital asset plan
  - Each item: toggle + date completed + notes
  - Stored in UserProfile or separate model

### 5E — ViewModels & Testing

- [ ] 5.18 **Create matching ViewModels** for all views above. Each ViewModel:
  - Injects relevant calculator(s) and repository(ies)
  - Exposes computed results as `@Observable` properties
  - Has an `analyze()` or `calculate()` async method
  - Has a `getAIExplanation()` async method that sends data to advisory endpoint

- [ ] 5.19 **Calculator unit tests** — Test extended calculator methods with known inputs/outputs. Verify edge cases: zero income, zero debt, negative net worth, very large numbers.

- [ ] 5.20 **Integration tests** — Test full flow: load user data → run calculation → request AI explanation → verify response makes sense for the input data.

---

## Phase 6: Polish & Launch (M)
> Deps: Phase 5
> Skills: `security-review`, `deployment-patterns`, `coding-standards`
> Goal: Production readiness — notifications, widgets, onboarding, security, App Store prep.

**Sprint:** 9 — Three parallel lanes: macOS Polish (A), iOS Port (B), Security+Launch (C)
**See sprint plan above for concurrency lanes**

- [ ] 6.1 **Push notifications** — Backend: Celery beat task runs weekly to generate briefings, sends APNs push. iOS: register for push, handle notification tap → navigate to briefing or alert.
- [ ] 6.2 **iOS widgets** (WidgetKit) — 3 widgets: Net Worth (small, shows balance + change), Health Score (small, shows score ring), Next Milestone (medium, shows closest goal + progress)
- [ ] 6.3 **Onboarding wizard** — Multi-step flow on first launch: Welcome → Profile setup (age, income, filing status) → Link first account (Plaid or manual) → Set first goal → Dashboard. Skip-able but encouraged. Stored `hasCompletedOnboarding` in UserDefaults.
- [ ] 6.4 **Biometric auth** — Face ID / Touch ID gate on app launch. Store access token in Keychain with biometric protection (`.biometryCurrentSet`). Fallback to passcode.
- [ ] 6.5 **Data export** — Export financial data as CSV (accounts, transactions, net worth history). Export CFO briefing as PDF (using UIGraphicsPDFRenderer). Share sheet integration.
- [ ] 6.6 **Accessibility audit** — VoiceOver labels on all interactive elements. Dynamic Type support on all text. Sufficient color contrast. Chart descriptions for VoiceOver.
- [ ] 6.7 **Annual Review mode** — End-of-year comprehensive analysis: yearly net worth change, total income/spending, goal progress summary, top 5 spending categories, investment performance, tax summary, prioritized action list for next year. Generated via Claude with full-year data context.
- [ ] 6.8 **Performance optimization** — Lazy loading for transaction lists (pagination). Background fetch for sync. Image caching for institution logos. SwiftData query optimization (fetch limits, batch sizes).
- [ ] 6.9 **App Store assets** — Screenshots (macOS window screenshots), app description, keywords, privacy policy, App Store Connect metadata.
- [ ] 6.10 **Security audit** — Use `security-review` skill: verify no hardcoded secrets, all API keys in env vars, Keychain for tokens, certificate pinning for API calls, Plaid access tokens encrypted at rest in backend, SQL injection prevention (parameterized queries), rate limiting on all endpoints.

### 6B — iOS Port (after macOS is stable)

- [ ] 6.11 **Add iOS target** to Xcode project. Shared source files: Models/, Repositories/, ViewModels/, Services/, Calculators/, Extensions/. Platform-specific: Views/.
- [ ] 6.12 **Create iOS MainTabView.swift** — TabView replacing sidebar. Tabs: Dashboard, Accounts, Goals, Advisor, Profile.
- [ ] 6.13 **Adapt views for iOS** — Replace macOS Table with List, replace toolbar with navigation bar buttons, replace `.sheet()` sizing for iOS, replace right-click context menus with swipe actions.
- [ ] 6.14 **Replace Plaid WKWebView with native Plaid Link iOS SDK** — Add LinkKit pod/SPM, use PlaidLinkHandler for native flow.
- [ ] 6.15 **Add iOS widgets** (WidgetKit) — Net Worth (small), Health Score (small), Next Milestone (medium).
- [ ] 6.16 **iOS-specific testing** — Run full test suite on iOS simulator, verify UI adapts correctly, test Plaid Link native flow.

---

## Verification (after each phase)

Run `/verify` with these checks:

- [ ] Run full test suite (`cmd+U` in Xcode, `pytest` for backend) — 80%+ coverage
- [ ] Build and run on simulator — no crashes, no SwiftData migration issues
- [ ] Verify MVVM separation — no business logic in Views
- [ ] For Phase 3+: test Plaid sandbox flow end-to-end
- [ ] For Phase 4+: test Claude API responses with mock financial data
- [ ] Security check: no hardcoded keys, all secrets in env vars / Keychain

Then `/code-review` before committing. If the phase introduced auth, secrets, or API endpoints, also run `/security-review`.

At end of session: `/learn` to extract reusable patterns. At end of project: `/journal` entry with architectural decisions and takeaways.
