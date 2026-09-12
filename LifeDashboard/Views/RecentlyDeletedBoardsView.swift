import SwiftUI
import SwiftData

struct RecentlyDeletedBoardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Board> { $0.deletedAt != nil },
        sort: [SortDescriptor(\Board.deletedAt, order: .reverse)]
    ) private var deletedBoards: [Board]

    private let retentionDays = 30

    var body: some View {
        NavigationStack {
            List {
                if deletedBoards.isEmpty {
                    ContentUnavailableView(
                        "Nothing here",
                        systemImage: "trash",
                        description: Text("Boards you delete stay here for \(retentionDays) days before being removed for good.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(deletedBoards) { board in
                        row(for: board)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ClaudeTheme.background)
            .navigationTitle("Recently Deleted")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(ClaudeTheme.accent)
        .onAppear(perform: purgeExpired)
    }

    @ViewBuilder
    private func row(for board: Board) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(board.title)
                .font(.headline)
                .foregroundStyle(ClaudeTheme.textPrimary)
            if let deletedAt = board.deletedAt {
                Text("Deleted \(deletedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(ClaudeTheme.textSecondary)
            }
        }
        .listRowBackground(ClaudeTheme.surface)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(board)
            } label: {
                Label("Delete Permanently", systemImage: "trash.fill")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                board.deletedAt = nil
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(ClaudeTheme.accent)
        }
    }

    private func purgeExpired() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: .now) ?? .now
        for board in deletedBoards {
            if let deletedAt = board.deletedAt, deletedAt < cutoff {
                modelContext.delete(board)
            }
        }
    }
}
