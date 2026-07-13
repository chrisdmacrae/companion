import SwiftUI

/// An area (mirrors `domain.Area`) — only the fields this view needs.
struct Area: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let sortOrder: Int
}

/// A project within an area (mirrors `domain.Project`).
struct Project: Decodable, Identifiable, Hashable {
    let id: String
    let areaId: String
    let name: String
    let sortOrder: Int
}

/// Lists areas and the projects within each. Empty areas (no projects) can be deleted —
/// the core only permits deleting an empty area, so its projects are never orphaned.
struct AreasProjectsView: View {
    let core: CompanionCore

    @State private var areas: [Area] = []
    @State private var projects: [Project] = []
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Areas & Projects")
                    .font(.largeTitle.bold())

                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Brand.danger)
                }

                if areas.isEmpty {
                    Text("No areas yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(areas) { area in
                        areaSection(area)
                    }
                }
            }
            .padding(40)
            .frame(maxWidth: 720, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear(perform: reload)
    }

    private func areaSection(_ area: Area) -> some View {
        let items = projects(in: area)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(area.name, systemImage: "folder.fill")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Spacer()
                if items.isEmpty {
                    Button(role: .destructive) {
                        delete(area)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(Brand.danger)
                    .controlSize(.small)
                }
            }

            if items.isEmpty {
                Text("No projects").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(items) { project in
                    HStack(spacing: 10) {
                        Circle().fill(Brand.accent).frame(width: 6, height: 6)
                        Text(project.name)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 6)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: .rect(cornerRadius: 16))
    }

    private func projects(in area: Area) -> [Project] {
        projects.filter { $0.areaId == area.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func reload() {
        do {
            areas = try core.invoke("areas.list", as: [Area].self).sorted { $0.sortOrder < $1.sortOrder }
            projects = try core.invoke("projects.list", as: [Project].self)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ area: Area) {
        do {
            try core.invoke("areas.delete", args: ["id": area.id])
            reload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
