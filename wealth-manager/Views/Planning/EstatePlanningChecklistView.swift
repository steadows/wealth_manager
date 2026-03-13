import SwiftUI

// MARK: - EstatePlanningChecklistView

/// Estate planning checklist: toggle items via ViewModel, sorted by priority,
/// completion percentage ring, info cards, and "all critical done" state.
struct EstatePlanningChecklistView: View {

    @Bindable var viewModel: InsuranceViewModel

    // MARK: - Local estate flags (mirroring ViewModel state)

    @State private var hasWill: Bool = false
    @State private var hasTrust: Bool = false
    @State private var hasPOA: Bool = false
    @State private var hasHealthcareDirective: Bool = false
    @State private var hasBeneficiariesUpdated: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                completionRingCard
                checklistSection
                if allCriticalDone {
                    celebrationCard
                }
                infoSection
            }
            .padding()
        }
        .onAppear { syncFromChecklist() }
    }

    // MARK: - Computed

    private var sortedChecklist: [(item: String, isComplete: Bool, priority: String)] {
        let priorityOrder = ["Critical": 0, "High": 1, "Recommended": 2]
        return viewModel.estatePlanningChecklist.sorted {
            (priorityOrder[$0.priority] ?? 99) < (priorityOrder[$1.priority] ?? 99)
        }
    }

    private var completionCount: Int {
        viewModel.estatePlanningChecklist.filter(\.isComplete).count
    }

    private var completionPercent: Double {
        guard !viewModel.estatePlanningChecklist.isEmpty else { return 0 }
        return Double(completionCount) / Double(viewModel.estatePlanningChecklist.count)
    }

    private var allCriticalDone: Bool {
        viewModel.estatePlanningChecklist
            .filter { $0.priority == "Critical" }
            .allSatisfy { $0.isComplete }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Estate Planning")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Text("Ensure your wishes are documented and your family is protected")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Completion Ring

    private var completionRingCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(WMColors.glassBg, lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: completionPercent)
                    .stroke(
                        AngularGradient(
                            colors: [WMColors.glow, WMColors.primary],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: completionPercent)

                VStack(spacing: 2) {
                    Text("\(completionCount)/\(viewModel.estatePlanningChecklist.count)")
                        .font(WMTypography.subheading)
                        .foregroundStyle(WMColors.textPrimary)
                    Text("complete")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                }
            }

            Text("\(Int(completionPercent * 100))% of estate planning complete")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard()
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Checklist")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            ForEach(sortedChecklist, id: \.item) { checkItem in
                checklistRow(checkItem: checkItem)
            }
        }
    }

    private func checklistRow(checkItem: (item: String, isComplete: Bool, priority: String)) -> some View {
        let priorityColor = priorityColor(for: checkItem.priority)
        let binding = bindingForItem(checkItem.item)

        return HStack(spacing: 12) {
            Button {
                binding.wrappedValue.toggle()
                pushUpdate()
            } label: {
                Image(systemName: checkItem.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(checkItem.isComplete ? WMColors.positive : WMColors.textMuted)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(checkItem.item)
                    .font(WMTypography.body)
                    .foregroundStyle(checkItem.isComplete ? WMColors.textMuted : WMColors.textPrimary)
                    .strikethrough(checkItem.isComplete, color: WMColors.textMuted)
            }

            Spacer()

            priorityBadge(text: checkItem.priority, color: priorityColor)
        }
        .padding(14)
        .glassCard()
    }

    // MARK: - Celebration Card

    private var celebrationCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 32))
                .foregroundStyle(WMColors.glow)

            Text("Well done!")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.glow)

            Text("All critical estate planning items are complete. Your family is protected.")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(WMColors.glow.opacity(0.4), lineWidth: 1.5)
        )
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why It Matters")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            ForEach(infoItems, id: \.title) { item in
                infoCard(icon: item.icon, title: item.title, body: item.body)
            }
        }
    }

    private func infoCard(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(WMColors.glow)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
                Text(body)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Helpers

    private func priorityColor(for priority: String) -> Color {
        switch priority {
        case "Critical": return WMColors.negative
        case "High": return WMColors.glow
        default: return WMColors.textMuted
        }
    }

    private func priorityBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(WMTypography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func bindingForItem(_ item: String) -> Binding<Bool> {
        switch item {
        case "Last Will & Testament": return $hasWill
        case "Living Trust": return $hasTrust
        case "Power of Attorney": return $hasPOA
        case "Healthcare Directive": return $hasHealthcareDirective
        case "Beneficiaries Updated": return $hasBeneficiariesUpdated
        default: return .constant(false)
        }
    }

    private func pushUpdate() {
        viewModel.updateEstatePlanning(
            hasWill: hasWill,
            hasTrust: hasTrust,
            hasPOA: hasPOA,
            hasHealthcareDirective: hasHealthcareDirective,
            hasBeneficiariesUpdated: hasBeneficiariesUpdated
        )
    }

    private func syncFromChecklist() {
        for item in viewModel.estatePlanningChecklist {
            switch item.item {
            case "Last Will & Testament": hasWill = item.isComplete
            case "Living Trust": hasTrust = item.isComplete
            case "Power of Attorney": hasPOA = item.isComplete
            case "Healthcare Directive": hasHealthcareDirective = item.isComplete
            case "Beneficiaries Updated": hasBeneficiariesUpdated = item.isComplete
            default: break
            }
        }
    }

    // MARK: - Info Data

    private let infoItems: [(icon: String, title: String, body: String)] = [
        (
            icon: "doc.fill",
            title: "Last Will & Testament",
            body: "Dictates how your assets are distributed and appoints guardians for minor children."
        ),
        (
            icon: "person.fill.checkmark",
            title: "Beneficiaries",
            body: "Ensures retirement accounts and insurance policies pass directly to the right people, outside probate."
        ),
        (
            icon: "signature",
            title: "Power of Attorney",
            body: "Grants a trusted person authority to manage your financial affairs if you're incapacitated."
        ),
        (
            icon: "cross.fill",
            title: "Healthcare Directive",
            body: "Documents your medical wishes and appoints a healthcare proxy to make decisions on your behalf."
        ),
        (
            icon: "building.columns",
            title: "Living Trust",
            body: "Allows assets to transfer to heirs without probate, offering privacy and efficiency."
        ),
    ]
}
