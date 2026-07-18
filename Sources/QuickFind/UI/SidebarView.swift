import SwiftUI

struct SidebarView: View {
    @ObservedObject var engine: SearchEngine

    var body: some View {
        List {
            Section("종류") {
                ForEach(SearchCategory.allCases) { category in
                    Button {
                        engine.category = category
                    } label: {
                        Label(category.label, systemImage: category.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(rowBackground(selected: engine.category == category))
                    .foregroundStyle(engine.category == category ? Color.accentColor : .primary)
                }
            }

            Section("검색 범위") {
                ForEach(SearchScope.allCases) { scope in
                    Button {
                        engine.scope = scope
                    } label: {
                        Label(scope.label, systemImage: scope.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(rowBackground(selected: engine.scope == scope))
                    .foregroundStyle(engine.scope == scope ? Color.accentColor : .primary)
                }
            }

            Section("저장공간 정리") {
                ForEach(CleanupPreset.allCases) { preset in
                    let selected = engine.cleanupPreset == preset
                    Button {
                        engine.cleanupPreset = selected ? nil : preset
                    } label: {
                        deselectableRow(
                            label: preset.label,
                            systemImage: preset.systemImage,
                            selected: selected
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(rowBackground(selected: selected))
                    .foregroundStyle(selected ? Color.accentColor : .primary)
                    .help(selected ? "클릭하면 선택이 해제됩니다" : preset.help)
                }

                Button {
                    engine.showingTrash.toggle()
                } label: {
                    deselectableRow(
                        label: "휴지통",
                        systemImage: "trash",
                        selected: engine.showingTrash
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(rowBackground(selected: engine.showingTrash))
                .foregroundStyle(engine.showingTrash ? Color.accentColor : .primary)
                .help(engine.showingTrash ? "클릭하면 선택이 해제됩니다" : "휴지통 안 파일을 보고 영구 삭제하거나 비웁니다")
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
    }

    private func rowBackground(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(selected ? Color.accentColor.opacity(0.15) : Color.clear)
    }

    /// 선택 시 우측에 ✕ 를 보여줘 "다시 클릭 = 해제"를 명시하는 행
    private func deselectableRow(label: String, systemImage: String, selected: Bool) -> some View {
        HStack {
            Label(label, systemImage: systemImage)
            Spacer()
            if selected {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}
