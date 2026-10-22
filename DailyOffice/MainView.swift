import SwiftUI
import AppKit

struct MainView: View {
    @ObservedObject var store: OfficeStore
    @State private var workspace = false
    var activeProject: ProjectRecord? { store.data.projects.first { $0.path == store.data.projectPath } }

    var body: some View {
        Group {
            if workspace, activeProject != nil {
                ProjectWorkspaceView(store: store) { workspace = false }
            } else {
                projectMenu
            }
        }
        .frame(width: 900, height: 600).preferredColorScheme(store.scheme)
    }

    var projectMenu: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text("Daily Office").font(.title2.weight(.semibold)); Spacer(); Button { showQuickHelp() } label: { Image(systemName: "questionmark.circle") }.buttonStyle(.plain).help("Ayuda rápida"); Button { store.showSettings?() } label: { Image(systemName: "gearshape") }.buttonStyle(.plain).help("Configuración") }
                Text("Tus proyectos").font(.caption).foregroundStyle(.secondary)
                if store.data.projects.isEmpty {
                    VStack(alignment: .leading, spacing: 10) { Image(systemName: "folder").font(.title); Text("Aún no hay proyectos").font(.headline); Text("Elige una carpeta para empezar a trabajar con tus agentes.").font(.caption).foregroundStyle(.secondary); Button("Elegir proyecto") { choose() }.buttonStyle(.borderedProminent) }.padding(.top, 35)
                } else {
                    ScrollView { VStack(spacing: 6) {
                        ForEach(store.data.projects) { project in
                            HStack(spacing: 4) {
                                Button { store.selectProject(project.path); workspace = true } label: { HStack(spacing: 10) { Image(systemName: project.path == store.data.projectPath ? "folder.fill" : "folder"); VStack(alignment: .leading) { Text(project.name).font(.headline); Text(project.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); if project.path == store.data.projectPath { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) } }.padding(12).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain)
                                Button { confirmRemove(project) } label: { Image(systemName: "trash").foregroundStyle(.secondary).padding(10) }.buttonStyle(.plain).help("Quitar de la lista")
                            }.background(project.path == store.data.projectPath ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
                        }
                    } }.padding(.top, 8)
                    Button("Añadir proyecto") { choose() }.buttonStyle(.bordered)
                }
                Spacer()
                Spacer()
            }.padding(28).frame(width: 330).background(.quaternary.opacity(0.28))
            VStack(alignment: .leading, spacing: 18) {
                if let project = activeProject {
                    HStack(alignment: .top, spacing: 16) { projectImage(project); VStack(alignment: .leading, spacing: 5) { Text(project.name).font(.title2.weight(.semibold)); Text(project.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled); Button(project.imagePath == nil ? "Añadir imagen" : "Cambiar imagen") { chooseImage(for: project) }.buttonStyle(.bordered) }; Spacer() }
                    Divider()
                    Text("Pulsa el nombre del proyecto para entrar al espacio de trabajo con tus agentes.").foregroundStyle(.secondary)
                    ActivityHeatmapView(events: store.activities)
                }
                else { ContentUnavailableView("Selecciona un proyecto", systemImage: "folder", description: Text("Los agentes compartirán esta carpeta y su contexto.")) }
            }.padding(30).frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
    @ViewBuilder func projectImage(_ project: ProjectRecord) -> some View { if let path = project.imagePath, let image = NSImage(contentsOfFile: path) { Image(nsImage: image).resizable().scaledToFill().frame(width: 150, height: 100).clipped().clipShape(RoundedRectangle(cornerRadius: 12)) } else { RoundedRectangle(cornerRadius: 12).fill(.quaternary).frame(width: 150, height: 100).overlay(Image(systemName: "photo").font(.title).foregroundStyle(.secondary)) } }
    func choose() { let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; if panel.runModal() == .OK, let url = panel.url { store.selectProject(url.path) } }
    func confirmRemove(_ project: ProjectRecord) {
        let alert = NSAlert(); alert.messageText = "¿Quitar este proyecto?"; alert.informativeText = "Se quitará \(project.name) de Daily Office, pero no se borrarán sus archivos. Escribe ELIMINAR para confirmar."; let field = NSTextField(string: ""); field.frame.size = NSSize(width: 260, height: 24); alert.accessoryView = field; alert.addButton(withTitle: "Quitar proyecto"); alert.addButton(withTitle: "Cancelar")
        if alert.runModal() == .alertFirstButtonReturn && field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "ELIMINAR" { store.removeProject(project.id) }
    }
    func chooseImage(for project: ProjectRecord) { let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.canChooseFiles = true; panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]; if panel.runModal() == .OK, let url = panel.url { store.setProjectImage(url.path, for: project.id) } }
}

struct ActivityHeatmapView: View {
    let events: [ActivityEvent]
    private let calendar = Calendar.current
    private let days = 84

    var counts: [Int] {
        let start = calendar.startOfDay(for: Date()).addingTimeInterval(-Double(days - 1) * 86_400)
        var result = Array(repeating: 0, count: days)
        for event in events {
            let eventDay = calendar.startOfDay(for: event.date)
            let index = calendar.dateComponents([.day], from: start, to: eventDay).day ?? -1
            if index >= 0 && index < days { result[index] += 1 }
        }
        return result
    }

    var body: some View {
        let values = counts
        let total = values.reduce(0, +)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Actividad del equipo", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer()
                Text("Últimos 84 días · \(total) eventos")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: Array(repeating: GridItem(.fixed(11), spacing: 4), count: 7), spacing: 4) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(for: value))
                            .frame(width: 11, height: 11)
                            .help("\(value) \(value == 1 ? "evento" : "eventos")")
                    }
                }
                .padding(.vertical, 3)
            }
            HStack(spacing: 6) {
                Text("Menos").font(.caption2).foregroundStyle(.secondary)
                ForEach(0..<5, id: \.self) { level in RoundedRectangle(cornerRadius: 2).fill(color(for: level * 2)).frame(width: 11, height: 11) }
                Text("Más").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
    }

    func color(for count: Int) -> Color {
        switch count {
        case 0: return .secondary.opacity(0.12)
        case 1...2: return .accentColor.opacity(0.28)
        case 3...5: return .accentColor.opacity(0.5)
        case 6...9: return .accentColor.opacity(0.72)
        default: return .accentColor
        }
    }
}

func showQuickHelp() {
    let alert = NSAlert(); alert.messageText = "Ayuda rápida de Daily Office"; alert.informativeText = "1. Añade una carpeta desde ‘Añadir proyecto’.\n\n2. Pulsa el proyecto para entrar al espacio de trabajo.\n\n3. Elige un agente en la columna izquierda para chatear.\n\n4. Cerebro planea y revisa; Constructor escribe código y modifica archivos.\n\n5. Para usar una API, elige el proveedor, modelo y guarda su clave en Configuración.\n\nLas capturas se pueden adjuntar con el clip o arrastrándolas al chat."; alert.addButton(withTitle: "Entendido"); alert.runModal()
}

struct ProjectWorkspaceView: View {
    @ObservedObject var store: OfficeStore
    var goBack: () -> Void
    @State private var selectedAgent: String?
    var project: ProjectRecord? { store.data.projects.first { $0.path == store.data.projectPath } }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack { Button { goBack() } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain); Text("Daily Office").font(.title3.weight(.semibold)); Spacer() }
                    .padding(.bottom, 18)
                Button { } label: { Label("General", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9)) }.buttonStyle(.plain)
                Divider().padding(.vertical, 8)
                ForEach(store.data.agents) { agent in
                    Button { selectedAgent = agent.id } label: { HStack(spacing: 10) { Avatar(agent: agent, size: 30); Text(agent.name); Spacer(); if store.busy.contains(agent.id) { ProgressView().controlSize(.small) } }.frame(maxWidth: .infinity, alignment: .leading).padding(8).background(selectedAgent == agent.id ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 9)) }.buttonStyle(.plain)
                }
                Spacer()
            }.padding(18).frame(width: 235).background(.quaternary.opacity(0.28))
            Divider()
            if let selectedAgent { ChatView(store: store, id: selectedAgent) } else { ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let project {
                        HStack(alignment: .top, spacing: 16) { projectImage(project); VStack(alignment: .leading, spacing: 5) { Text(project.name).font(.title2.weight(.semibold)); Text(project.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled); Button(project.imagePath == nil ? "Añadir imagen" : "Cambiar imagen") { chooseImage(for: project) }.buttonStyle(.bordered) }; Spacer() }
                        Divider()
                        Text("Vista previa").font(.headline)
                        if let preview = store.runURL { ProjectPreview(url: preview).frame(minHeight: 280).clipShape(RoundedRectangle(cornerRadius: 12)); Link("Abrir en navegador", destination: preview) }
                        else { RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.85)).frame(height: 220).overlay(alignment: .topLeading) { VStack(alignment: .leading, spacing: 8) { Image(systemName: "play.rectangle").font(.title2); Text("No hay un archivo HTML aquí").font(.headline); Text("La vista previa aparece con index.html o un archivo .html en la carpeta.").font(.caption).foregroundStyle(.secondary) }.padding(20).foregroundStyle(.white.opacity(0.86)) } }
                        Text("Contexto compartido").font(.headline)
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $store.data.context).frame(height: 110).scrollContentBackground(.hidden).padding(10)
                            if store.data.context.isEmpty { Text("Escribe aquí el contexto que compartirán todos los agentes…").foregroundStyle(.secondary).padding(.top, 17).padding(.leading, 15).allowsHitTesting(false) }
                        }.background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary.opacity(0.3)))
                        HStack { Button(store.isProjectRunning ? "Detener proyecto" : "Ejecutar proyecto") { store.runProject() }; Button("Mostrar comandos localhost") { store.showLocalhostCommand() }; if !store.runStatus.isEmpty { Text(store.runStatus).font(.caption).foregroundStyle(.secondary) } }
                        if !store.localhostCommand.isEmpty { HStack { Text(store.localhostCommand).font(.system(.caption, design: .monospaced)).textSelection(.enabled).lineLimit(2); Spacer(); Button("Copiar") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(store.localhostCommand, forType: .string) }.buttonStyle(.bordered) }.padding(10).background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8)) }
                        Text(store.busy.isEmpty ? "Equipo disponible" : "Trabajando: " + store.busy.map { store.agent($0).name }.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(30).frame(maxWidth: .infinity, alignment: .topLeading)
            } }
        }
    }
    @ViewBuilder func projectImage(_ project: ProjectRecord) -> some View { if let path = project.imagePath, let image = NSImage(contentsOfFile: path) { Image(nsImage: image).resizable().scaledToFill().frame(width: 150, height: 100).clipped().clipShape(RoundedRectangle(cornerRadius: 12)) } else { RoundedRectangle(cornerRadius: 12).fill(.quaternary).frame(width: 150, height: 100).overlay(Image(systemName: "photo").font(.title).foregroundStyle(.secondary)) } }
    func chooseImage(for project: ProjectRecord) { let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.canChooseFiles = true; panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]; if panel.runModal() == .OK, let url = panel.url { store.setProjectImage(url.path, for: project.id) } }
}
