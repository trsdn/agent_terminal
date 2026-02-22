import SwiftUI

struct SidebarTabRow: View {
    @Bindable var session: TerminalSession
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(nsColor: session.status.color))
                .frame(width: 6, height: 6)

            if session.isRenaming {
                TextField("Name", text: $session.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        session.isRenaming = false
                    }
                    .onAppear {
                        isTextFieldFocused = true
                    }
            } else {
                Text(session.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
