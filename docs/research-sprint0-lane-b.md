# Sprint 0 Lane B Research Findings

## 1. macOS Finance App UI Patterns

### Reference Projects Found
- **PegaseUIData** (github.com/thierryH91200) — macOS SwiftUI finance app for managing/visualizing financial transactions. Uses NavigationSplitView.
- **CryptoTrackMultiPlatformSwiftUI** — Multi-platform crypto portfolio tracker using MVVM + Combine. macOS 13+, iOS 16+.
- **ThreeColumnLayoutFramework** — Reusable three-column layout framework for macOS SwiftUI apps. Published Sep 2025.

### Key Patterns
- Finance apps consistently use **sidebar for navigation categories** (accounts, portfolio, reports) with **list column for items** and **detail column for data-rich views**
- Heavy use of **macOS Table** (not List) for transaction views — sortable columns are expected
- Toolbar buttons for primary actions (add, refresh, export)
- Dark themes common in finance/trading apps (aligns with our Holographic JARVIS aesthetic)

---

## 2. NavigationSplitView Three-Column Patterns

### Standard Three-Column Setup
```swift
@State private var visibility = NavigationSplitViewVisibility.all
@State private var selectedSection: AppSection?
@State private var selectedItem: ItemType?

NavigationSplitView(columnVisibility: $visibility) {
    // Sidebar — navigation categories
    List(selection: $selectedSection) {
        ForEach(AppSection.allCases) { section in
            Label(section.label, systemImage: section.icon)
                .tag(section)
        }
    }
    .navigationTitle("Wealth Manager")
} content: {
    // Content — context-dependent list
    if let section = selectedSection {
        // Show accounts list, goals list, etc. based on section
    }
} detail: {
    // Detail — selected item view
    if let item = selectedItem {
        // Show account detail, goal detail, etc.
    } else {
        Text("Select an item")
            .foregroundColor(.secondary)
    }
}
```

### Hybrid Approach (for Inspector Panels)
When you need a right-side inspector (like Xcode), use:
```swift
NavigationSplitView {
    // Sidebar
} detail: {
    HSplitView {
        // Main content
        if inspectorVisible {
            // Inspector panel
        }
    }
}
```
Our app uses standard three-column, not the hybrid approach.

### Column Width Control
- `.navigationSplitViewColumnWidth(min:ideal:max:)` works on sidebar and content columns
- Detail column width is automatic (fills remaining space)
- Sidebar typical: `min: 200, ideal: 220, max: 300`
- Content column typical: `min: 250, ideal: 280, max: 400`

### Selection State Management
- Use `List(selection: $binding)` for automatic keyboard nav (arrow keys work free)
- Always provide empty state placeholder when selection is nil
- Never nest NavigationSplitView inside NavigationStack at root level

---

## 3. SwiftUI macOS-Specific Patterns

### Sortable Table (macOS 12+)
```swift
@State private var sortOrder = [KeyPathComparator(\Transaction.date, order: .reverse)]

Table(transactions, sortOrder: $sortOrder) {
    TableColumn("Date", value: \.date) { Text($0.date, style: .date) }
    TableColumn("Merchant", value: \.merchantName) { Text($0.merchantName ?? "") }
    TableColumn("Category", value: \.category.displayName)
    TableColumn("Amount", value: \.amount) { CurrencyText(amount: $0.amount) }
}
.onChange(of: sortOrder) { transactions.sort(using: $0) }
```

### Menu Bar Commands + Keyboard Shortcuts
```swift
WindowGroup { MainSplitView() }
    .commands {
        CommandMenu("Wealth") {
            Button("New Account") { /* action */ }
                .keyboardShortcut("N")
            Button("Refresh All") { /* action */ }
                .keyboardShortcut("R")
            Divider()
            Button("Export Data") { /* action */ }
                .keyboardShortcut("E", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .sidebar) {
            Button("Toggle Sidebar") { /* action */ }
                .keyboardShortcut("S", modifiers: [.command, .control])
        }
    }
```

### Toolbar on macOS
```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button(action: addAccount) {
            Label("Link Account", systemImage: "plus")
        }
    }
    ToolbarItem(placement: .automatic) {
        Button(action: refresh) {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }
}
```

### @Observable + @MainActor (iOS 17+ / macOS 14+)
```swift
@Observable
@MainActor
final class DashboardViewModel {
    var netWorth: Decimal = 0
    var isLoading = false
    // ...
}

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    // Use @State with @Observable, NOT @StateObject
}
```

### Glass Effect Pattern (iOS 26+ / macOS)
```swift
// Conditional glass with fallback
extension View {
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}
```

For our "Holographic JARVIS" theme on macOS 15+, we'll use custom glass modifiers:
- `backdrop-filter: blur(25px)` equivalent via `.ultraThinMaterial` or custom `NSVisualEffectView`
- Custom colors from design system tokens (not system materials)
- 1px luminous borders via overlay strokes

---

## 4. Architectural Decisions for Wealth Manager

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Navigation | Standard three-column NavigationSplitView | Matches Apple Mail/Finder pattern; no inspector needed |
| Table vs List | macOS `Table` for transactions | Sortable columns, native macOS feel |
| State | `@Observable` + `@MainActor` | Modern pattern, thread-safe, cleaner than Combine |
| Glass styling | Custom ViewModifier with design tokens | Our theme is custom (not system material) |
| Column widths | Sidebar 220px ideal, Content 280px ideal | Finance apps need wide content columns |
| Keyboard shortcuts | Cmd+1-8 for nav, Cmd+N add, Cmd+R refresh | Standard macOS conventions |
| Menu bar | Custom "Wealth" command menu | App-specific actions exposed in menu bar |
