import WidgetKit
import SwiftUI

/// Widget bundle entry point that registers all Wealth Manager widgets.
@main
struct WealthManagerWidgetBundle: WidgetBundle {
    var body: some Widget {
        NetWorthWidget()
        HealthScoreWidget()
        MilestoneWidget()
    }
}
