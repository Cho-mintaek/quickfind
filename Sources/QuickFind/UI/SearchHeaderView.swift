import SwiftUI

struct SearchHeaderView: View {
    @ObservedObject var engine: SearchEngine
    @FocusState.Binding var searchFocused: Bool
    /// 사이드바가 없는 분할 패널에서 범위·종류를 고를 수 있는 컴팩트 피커 표시
    var showsFilterPickers: Bool = false
    let requestEmptyTrash: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField(
                    engine.showingTrash ? "휴지통에서 이름으로 필터" : "파일 이름으로 검색",
                    text: $engine.queryText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .regular))
                .focused($searchFocused)

                if engine.isSearching {
                    ProgressView()
                        .controlSize(.small)
                }

                if !engine.queryText.isEmpty {
                    Button {
                        engine.queryText = ""
                        searchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("검색어 지우기")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                searchFocused ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.1),
                                lineWidth: searchFocused ? 1.5 : 1
                            )
                    )
            )

            HStack(spacing: 12) {
                if engine.showingTrash {
                    Button(role: .destructive) {
                        requestEmptyTrash()
                    } label: {
                        Label("휴지통 비우기", systemImage: "trash.slash")
                            .font(.system(size: 12))
                    }
                    .tint(.red)
                    .controlSize(.small)
                    .disabled(engine.results.isEmpty && !engine.trashAccessDenied)
                } else {
                    // 분할 패널(피커 표시)에서는 좁은 폭에 맞춰 라벨을 줄인다
                    Toggle(isOn: $engine.searchContents) {
                        Label(
                            showsFilterPickers ? "내용" : "파일 내용 포함",
                            systemImage: "doc.text.magnifyingglass"
                        )
                        .font(.system(size: 12))
                    }
                    .toggleStyle(.checkbox)
                    .fixedSize()
                    .help("파일 이름뿐 아니라 문서 내부 텍스트에서도 검색합니다")
                }

                if showsFilterPickers {
                    // labelsHidden: 선택된 값만 표시해 좁은 패널에서도 한 줄 유지
                    Picker("범위", selection: $engine.scope) {
                        ForEach(SearchScope.allCases) { scope in
                            Label(scope.label, systemImage: scope.systemImage).tag(scope)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .labelsHidden()
                    .fixedSize()
                    .help("검색 범위")

                    Picker("종류", selection: $engine.category) {
                        ForEach(SearchCategory.allCases) { category in
                            Label(category.label, systemImage: category.systemImage).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .labelsHidden()
                    .fixedSize()
                    .help("파일 종류")
                }

                Spacer(minLength: 8)

                Picker(selection: $engine.sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                } label: {
                    Label("정렬", systemImage: "arrow.up.arrow.down")
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .labelsHidden()
                .fixedSize()
                .help("정렬 기준")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
}
