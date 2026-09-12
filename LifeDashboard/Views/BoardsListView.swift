import SwiftUI
import SwiftData
import UIKit
import PhotosUI
import QuickLook
import UniformTypeIdentifiers

struct BoardsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DeepLinkRouter.self) private var router
    @Query(
        filter: #Predicate<Board> { $0.deletedAt == nil },
        sort: \Board.order
    ) private var boards: [Board]

    private var pinnedFirstBoards: [Board] {
        boards.filter { $0.isPinned } + boards.filter { !$0.isPinned }
    }

    @State private var isAddingBoard = false
    @State private var newBoardTitle = ""
    @State private var collapsedBoardIDs: Set<UUID> = []
    @State private var newItemTextByBoard: [UUID: String] = [:]
    @State private var toggleSelection: Set<UUID> = []
    @State private var renamingBoard: Board?
    @State private var renameText = ""
    @State private var isReordering = false
    @State private var isShowingRecentlyDeleted = false
    @State private var searchText = ""

    private var displayedBoards: [Board] {
        guard !searchText.isEmpty else { return pinnedFirstBoards }
        return pinnedFirstBoards.filter { board in
            board.title.localizedCaseInsensitiveContains(searchText) ||
            (board.items ?? []).contains { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List(selection: $toggleSelection) {
                    ForEach(displayedBoards) { board in
                        boardSection(board)
                    }
                    .onMove(perform: moveBoards)
                }
                .scrollContentBackground(.hidden)
                .background(GridBackground())
                .onChange(of: router.pendingBoardUUID) { _, newValue in
                    guard let uuid = newValue else { return }
                    collapsedBoardIDs.remove(uuid)
                    searchText = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(uuid, anchor: .top)
                        }
                    }
                    router.pendingBoardUUID = nil
                }
            }
            .navigationTitle("Boards")
            .searchable(text: $searchText, prompt: "Search boards")
            .environment(\.editMode, .constant(isReordering ? .active : .inactive))
            .onChange(of: toggleSelection) { _, newSelection in
                if let tapped = newSelection.first, let board = boards.first(where: { $0.uuid == tapped }) {
                    toggleCollapsed(board)
                }
                toggleSelection = []
            }
            .toolbar {
                if isReordering {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") { isReordering = false }
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isAddingBoard = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                searchText = ""
                                isReordering = true
                            } label: {
                                Label("Reorder Boards", systemImage: "arrow.up.arrow.down")
                            }
                            Button {
                                isShowingRecentlyDeleted = true
                            } label: {
                                Label("Recently Deleted", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingRecentlyDeleted) {
                RecentlyDeletedBoardsView()
            }
            .alert("New Board", isPresented: $isAddingBoard) {
                TextField("Title", text: $newBoardTitle)
                Button("Add", action: addBoard)
                Button("Cancel", role: .cancel) { newBoardTitle = "" }
            }
            .alert("Rename Board", isPresented: renamingBoardBinding) {
                TextField("Title", text: $renameText)
                Button("Save", action: saveRename)
                Button("Cancel", role: .cancel) {}
            }
            .overlay {
                if displayedBoards.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView(
                            "No boards yet",
                            systemImage: "square.grid.2x2",
                            description: Text("Tap + to create your first board.")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func boardSection(_ board: Board) -> some View {
        Section {
            headerRow(board)

            if !isCollapsed(board) {
                ForEach(sortedItems(for: board)) { item in
                    ItemRow(item: item)
                }
                .onDelete { deleteItems(in: board, at: $0) }
                .listRowBackground(ClaudeTheme.surface)

                HStack {
                    TextField("Add a line...", text: newItemBinding(for: board), axis: .vertical)
                        .foregroundStyle(ClaudeTheme.textPrimary)
                        .onSubmit { addItem(to: board) }
                    Button {
                        addItem(to: board)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .tint(ClaudeTheme.accent)
                    .disabled(newItemBinding(for: board).wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .listRowBackground(ClaudeTheme.surfaceElevated)
            }
        }
        .listRowSeparatorTint(ClaudeTheme.border)
        .id(board.uuid)
    }

    @ViewBuilder
    private func headerRow(_ board: Board) -> some View {
        HStack {
            Image(systemName: isCollapsed(board) ? "chevron.right" : "chevron.down")
                .font(.caption)
                .foregroundStyle(ClaudeTheme.accent)
            if board.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(ClaudeTheme.accent)
            }
            Text(board.title)
                .font(.headline)
                .foregroundStyle(ClaudeTheme.textPrimary)
            Spacer()
            Text("\(itemCount(board))")
                .font(.caption)
                .foregroundStyle(ClaudeTheme.textSecondary)
        }
        .listRowBackground(ClaudeTheme.surface)
        .tag(board.uuid)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                board.deletedAt = .now
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                renameText = board.title
                renamingBoard = board
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                board.isPinned.toggle()
            } label: {
                Label(board.isPinned ? "Unpin" : "Pin", systemImage: board.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
    }

    private var renamingBoardBinding: Binding<Bool> {
        Binding(
            get: { renamingBoard != nil },
            set: { if !$0 { renamingBoard = nil } }
        )
    }

    private func saveRename() {
        guard let board = renamingBoard else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { board.title = trimmed }
        renamingBoard = nil
    }

    private func sortedItems(for board: Board) -> [BoardItem] {
        (board.items ?? []).sorted { $0.order < $1.order }
    }

    private func itemCount(_ board: Board) -> Int {
        board.items?.count ?? 0
    }

    private func isCollapsed(_ board: Board) -> Bool {
        if !searchText.isEmpty { return false }
        return collapsedBoardIDs.contains(board.uuid)
    }

    private func toggleCollapsed(_ board: Board) {
        if collapsedBoardIDs.contains(board.uuid) {
            collapsedBoardIDs.remove(board.uuid)
        } else {
            collapsedBoardIDs.insert(board.uuid)
        }
    }

    private func newItemBinding(for board: Board) -> Binding<String> {
        Binding(
            get: { newItemTextByBoard[board.uuid] ?? "" },
            set: { newItemTextByBoard[board.uuid] = $0 }
        )
    }

    private func addBoard() {
        let trimmed = newBoardTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let board = Board(title: trimmed, order: boards.count)
        modelContext.insert(board)
        newBoardTitle = ""
    }

    private func moveBoards(from source: IndexSet, to destination: Int) {
        var reordered = boards
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, board) in reordered.enumerated() {
            board.order = index
        }
    }

    private func addItem(to board: Board) {
        let binding = newItemBinding(for: board)
        let trimmed = binding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = BoardItem(text: trimmed, order: sortedItems(for: board).count)
        item.board = board
        modelContext.insert(item)
        binding.wrappedValue = ""
    }

    private func deleteItems(in board: Board, at offsets: IndexSet) {
        let items = sortedItems(for: board)
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

private struct ItemRow: View {
    @Bindable var item: BoardItem
    @State private var isShowingAttachmentOptions = false
    @State private var isShowingPhotoPicker = false
    @State private var isShowingFileImporter = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewURL: URL?

    private var attributedTextBinding: Binding<NSAttributedString> {
        Binding(
            get: {
                if let data = item.rtfData,
                   let attributed = try? NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                   ) {
                    return attributed
                }
                return NSAttributedString(
                    string: item.text,
                    attributes: [
                        .font: UIFont.preferredFont(forTextStyle: .body),
                        .foregroundColor: UIColor(ClaudeTheme.textPrimary)
                    ]
                )
            },
            set: { newValue in
                item.text = newValue.string
                item.rtfData = try? newValue.data(
                    from: NSRange(location: 0, length: newValue.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                )
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
            if let attachmentName = item.attachmentName {
                attachmentTile(name: attachmentName)
            }
        }
        .swipeActions {
            Button {
                item.isDivider.toggle()
                if item.isDivider { item.isChecklist = false }
            } label: {
                Label("Divider", systemImage: "minus")
            }
            .tint(.gray)

            Button {
                item.isChecklist.toggle()
                if item.isChecklist { item.isDivider = false }
            } label: {
                Label("Checklist", systemImage: item.isChecklist ? "list.bullet" : "checklist")
            }
            .tint(ClaudeTheme.accent)

            Button {
                isShowingAttachmentOptions = true
            } label: {
                Label("Attach", systemImage: "paperclip")
            }
            .tint(.indigo)
        }
        .confirmationDialog("Add Attachment", isPresented: $isShowingAttachmentOptions) {
            Button("Photo") { isShowingPhotoPicker = true }
            Button("File") { isShowingFileImporter = true }
            if item.attachmentName != nil {
                Button("Remove Attachment", role: .destructive, action: removeAttachment)
            }
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task { await handlePhotoSelection(newValue) }
        }
        .fileImporter(isPresented: $isShowingFileImporter, allowedContentTypes: [.item]) { result in
            handleFileImport(result)
        }
        .quickLookPreview($previewURL)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if item.isDivider {
                Text(item.text.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(ClaudeTheme.accent)
                    .tracking(0.5)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(ClaudeTheme.accent.opacity(0.4))
                            .frame(height: 1)
                            .padding(.top, -6)
                    }
            } else if item.isChecklist && item.isChecked {
                HStack {
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        item.isChecked.toggle()
                    } label: {
                        Image(systemName: "checkmark.square.fill")
                    }
                    .buttonStyle(.plain)
                    .tint(ClaudeTheme.accent)
                    Text(item.text)
                        .foregroundStyle(ClaudeTheme.textSecondary)
                        .strikethrough()
                }
            } else {
                HStack(alignment: .top) {
                    if item.isChecklist {
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            item.isChecked.toggle()
                        } label: {
                            Image(systemName: "square")
                        }
                        .buttonStyle(.plain)
                        .tint(ClaudeTheme.accent)
                        .padding(.top, 2)
                    }
                    RichTextView(attributedText: attributedTextBinding)
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentTile(name: String) -> some View {
        Button {
            if let storageName = item.attachmentStorageName {
                previewURL = AttachmentService.url(for: storageName)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(ClaudeTheme.accent)
                Text(name)
                    .font(.caption)
                    .foregroundStyle(ClaudeTheme.textPrimary)
                    .lineLimit(1)
            }
            .padding(8)
            .background(ClaudeTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func handlePhotoSelection(_ pickerItem: PhotosPickerItem?) async {
        guard let pickerItem else { return }
        guard let data = try? await pickerItem.loadTransferable(type: Data.self) else { return }
        let name = "Photo \(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).jpg"
        saveAttachment(data: data, originalName: name)
        selectedPhotoItem = nil
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        saveAttachment(data: data, originalName: url.lastPathComponent)
    }

    private func saveAttachment(data: Data, originalName: String) {
        if let oldStorageName = item.attachmentStorageName {
            AttachmentService.delete(storageName: oldStorageName)
        }
        item.attachmentStorageName = AttachmentService.save(data: data, originalName: originalName, uuid: item.uuid)
        item.attachmentName = originalName
    }

    private func removeAttachment() {
        if let storageName = item.attachmentStorageName {
            AttachmentService.delete(storageName: storageName)
        }
        item.attachmentStorageName = nil
        item.attachmentName = nil
    }
}
