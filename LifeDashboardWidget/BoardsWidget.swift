import WidgetKit
import SwiftUI
import SwiftData

struct BoardEntry: TimelineEntry {
    let date: Date
    let boards: [(uuid: UUID, title: String)]
}

struct BoardsProvider: TimelineProvider {
    func placeholder(in context: Context) -> BoardEntry {
        BoardEntry(date: .now, boards: [(UUID(), "Sample Board")])
    }

    func getSnapshot(in context: Context, completion: @escaping (BoardEntry) -> Void) {
        completion(BoardEntry(date: .now, boards: fetchBoardTitles()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BoardEntry>) -> Void) {
        let entry = BoardEntry(date: .now, boards: fetchBoardTitles())
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
        completion(timeline)
    }

    private func fetchBoardTitles() -> [(uuid: UUID, title: String)] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.uk.co.daniyalzia.LifeDashboard"
        ) else { return [] }

        let storeURL = containerURL.appendingPathComponent("LifeDashboard.sqlite")
        let schema = Schema([Board.self, BoardItem.self])
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        guard let container = try? ModelContainer(for: schema, configurations: [configuration]) else { return [] }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Board>(predicate: #Predicate { $0.deletedAt == nil })
        guard let boards = try? context.fetch(descriptor) else { return [] }

        let sorted = boards.filter { $0.isPinned } + boards.filter { !$0.isPinned }
        return sorted.map { ($0.uuid, $0.title) }
    }
}

struct BoardsWidgetEntryView: View {
    var entry: BoardsProvider.Entry
    @Environment(\.widgetFamily) private var family

    private var maxBoards: Int {
        family == .systemLarge ? 10 : 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.caption)
                    .foregroundStyle(ClaudeTheme.accent)
                Text("BOARDS")
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(ClaudeTheme.accent)
            }
            .padding(.bottom, 10)

            if entry.boards.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No boards yet")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ClaudeTheme.textPrimary)
                    Text("Create one in The Grid.")
                        .font(.caption)
                        .foregroundStyle(ClaudeTheme.textSecondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entry.boards.prefix(maxBoards).enumerated()), id: \.element.uuid) { index, board in
                        if index > 0 {
                            Rectangle()
                                .fill(ClaudeTheme.border)
                                .frame(height: 1)
                        }
                        Link(destination: URL(string: "lifedashboard://board/\(board.uuid.uuidString)")!) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.caption)
                                    .foregroundStyle(ClaudeTheme.accent)
                                    .frame(width: 14)
                                Text(board.title)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                    .foregroundStyle(ClaudeTheme.textPrimary)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(ClaudeTheme.textSecondary)
                            }
                            .padding(.vertical, 9)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            ZStack {
                ClaudeTheme.background
                Canvas { context, size in
                    var path = Path()
                    var x: CGFloat = 0
                    while x <= size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += 28
                    }
                    var y: CGFloat = 0
                    while y <= size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += 28
                    }
                    context.stroke(path, with: .color(ClaudeTheme.border.opacity(0.3)), lineWidth: 1)
                }
            }
        }
    }
}

struct BoardsWidget: Widget {
    let kind = "BoardsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BoardsProvider()) { entry in
            BoardsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Boards")
        .description("Quick links to your boards — tap a name to open it.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
