import SwiftUI
import UniformTypeIdentifiers
import WebKit
import AppKit

struct ProjectPreview: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> WKWebView { WKWebView(frame: .zero) }
    func updateNSView(_ view: WKWebView, context: Context) {
        if url.isFileURL { view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent()) }
        else { view.load(URLRequest(url: url)) }
    }
}

struct Avatar: View {
    var agent: Agent; var size: CGFloat = 44
    var body: some View {
        Canvas { context, dimensions in
            let scale = min(dimensions.width, dimensions.height) / 100
            context.scaleBy(x:scale,y:scale)
            let ink = Color(red:0.14,green:0.16,blue:0.19)
            let tint = agent.color
            func ellipse(_ x: CGFloat,_ y: CGFloat,_ w: CGFloat,_ h: CGFloat,_ color: Color) {
                context.fill(Path(ellipseIn:CGRect(x:x,y:y,width:w,height:h)),with:.color(color))
            }
            func line(_ points: [CGPoint],_ color: Color,_ width: CGFloat = 3) {
                var path = Path(); if let first = points.first { path.move(to:first); for point in points.dropFirst() { path.addLine(to:point) } }
                context.stroke(path,with:.color(color),style:StrokeStyle(lineWidth:width,lineCap:.round,lineJoin:.round))
            }
            func body(_ rect: CGRect,_ radius: CGFloat) {
                let path = Path(roundedRect:rect,cornerRadius:radius)
                context.fill(path,with:.color(tint.opacity(0.9)))
                context.stroke(path,with:.color(tint),lineWidth:1.4)
            }
            ellipse(22,88,56,5,tint.opacity(0.14))
            switch agent.id {
            case "ceo":
                // A calm round creature with three small crown-like ears.
                line([CGPoint(x:32,y:32),CGPoint(x:29,y:16),CGPoint(x:42,y:25),CGPoint(x:50,y:12),CGPoint(x:58,y:25),CGPoint(x:71,y:16),CGPoint(x:68,y:32)],tint,7)
                body(CGRect(x:20,y:28,width:60,height:58),24)
                ellipse(26,79,16,12,tint); ellipse(58,79,16,12,tint)
            case "marketing":
                // Long expressive ears and a warm, slightly asymmetric face.
                var ear = Path(); ear.move(to:CGPoint(x:24,y:40)); ear.addQuadCurve(to:CGPoint(x:23,y:12),control:CGPoint(x:7,y:7)); ear.addQuadCurve(to:CGPoint(x:40,y:35),control:CGPoint(x:41,y:12)); context.fill(ear,with:.color(tint))
                var other = Path(); other.move(to:CGPoint(x:60,y:35)); other.addQuadCurve(to:CGPoint(x:85,y:17),control:CGPoint(x:76,y:3)); other.addQuadCurve(to:CGPoint(x:76,y:44),control:CGPoint(x:91,y:34)); context.fill(other,with:.color(tint))
                body(CGRect(x:18,y:30,width:64,height:56),25)
                ellipse(28,80,14,10,tint); ellipse(58,80,14,10,tint)
            case "developer":
                // A small square robot with a single antenna and glasses.
                line([CGPoint(x:50,y:28),CGPoint(x:50,y:15)],tint,4); ellipse(45,8,10,10,tint)
                body(CGRect(x:18,y:28,width:64,height:55),17)
                ellipse(10,44,9,20,tint); ellipse(81,44,9,20,tint)
                body(CGRect(x:28,y:78,width:14,height:12),4); body(CGRect(x:58,y:78,width:14,height:12),4)
            case "creative":
                // A soft five-lobed little star.
                var star = Path()
                star.move(to:CGPoint(x:50,y:13))
                star.addCurve(to:CGPoint(x:66,y:33),control1:CGPoint(x:61,y:8),control2:CGPoint(x:61,y:29))
                star.addCurve(to:CGPoint(x:88,y:44),control1:CGPoint(x:98,y:24),control2:CGPoint(x:98,y:38))
                star.addCurve(to:CGPoint(x:76,y:65),control1:CGPoint(x:80,y:51),control2:CGPoint(x:73,y:53))
                star.addCurve(to:CGPoint(x:64,y:85),control1:CGPoint(x:87,y:93),control2:CGPoint(x:72,y:96))
                star.addCurve(to:CGPoint(x:40,y:82),control1:CGPoint(x:55,y:73),control2:CGPoint(x:51,y:73))
                star.addCurve(to:CGPoint(x:24,y:66),control1:CGPoint(x:18,y:103),control2:CGPoint(x:14,y:86))
                star.addCurve(to:CGPoint(x:14,y:44),control1:CGPoint(x:29,y:54),control2:CGPoint(x:24,y:52))
                star.addCurve(to:CGPoint(x:35,y:34),control1:CGPoint(x:0,y:26),control2:CGPoint(x:25,y:28))
                star.addQuadCurve(to:CGPoint(x:50,y:13),control:CGPoint(x:42,y:29))
                context.fill(star,with:.color(tint.opacity(0.92)))
            case "qa":
                // A watchful frog: eye bumps and a tiny check on its belly.
                ellipse(19,21,28,31,tint); ellipse(53,21,28,31,tint)
                body(CGRect(x:17,y:36,width:66,height:49),22)
                ellipse(21,78,20,12,tint); ellipse(59,78,20,12,tint)
            default:
                // A rounded cloud with a tilted beret.
                ellipse(19,35,34,40,tint); ellipse(48,30,34,46,tint)
                body(CGRect(x:23,y:40,width:54,height:45),21)
                var hat = Path(); hat.addEllipse(in:CGRect(x:24,y:22,width:54,height:19)); context.fill(hat,with:.color(tint.opacity(0.7)))
                line([CGPoint(x:52,y:24),CGPoint(x:57,y:16)],tint,5)
                ellipse(29,79,13,11,tint); ellipse(58,79,13,11,tint)
            }
            let eyesY: CGFloat = agent.id == "qa" ? 37 : 49
            let left: CGFloat = 36, right: CGFloat = 64
            if agent.id == "developer" {
                for x in [CGFloat(24),CGFloat(54)] { let p = Path(roundedRect:CGRect(x:x,y:42,width:23,height:19),cornerRadius:7); context.fill(p,with:.color(.white.opacity(0.55))); context.stroke(p,with:.color(ink.opacity(0.75)),lineWidth:2) }
                line([CGPoint(x:47,y:49),CGPoint(x:54,y:49)],ink,2)
            }
            ellipse(left-3,eyesY,6,9,ink); ellipse(right-3,eyesY,6,9,ink)
            ellipse(left-1,eyesY+1,2,2,.white.opacity(0.8)); ellipse(right-1,eyesY+1,2,2,.white.opacity(0.8))
            ellipse(24,62,10,5,.white.opacity(0.24)); ellipse(66,62,10,5,.white.opacity(0.24))
            var smile = Path(); smile.move(to:CGPoint(x:44,y:65)); smile.addQuadCurve(to:CGPoint(x:56,y:65),control:CGPoint(x:50,y:72)); context.stroke(smile,with:.color(ink.opacity(0.8)),style:StrokeStyle(lineWidth:2.4,lineCap:.round))
            if agent.id == "qa" { line([CGPoint(x:44,y:77),CGPoint(x:48,y:81),CGPoint(x:56,y:73)],.white.opacity(0.8),2.5) }
            if agent.id == "ceo" { line([CGPoint(x:43,y:78),CGPoint(x:50,y:82),CGPoint(x:57,y:78)],.white.opacity(0.6),2.5) }
        }.frame(width:size,height:size).accessibilityLabel("Criatura de \(agent.name)")
    }
}
struct DockView: View {
    @ObservedObject var store: OfficeStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    @State private var collapse: Task<Void,Never>?
    var avatarSize: CGFloat { store.data.dockSize == "Extra chico" ? 32 : store.data.dockSize == "Compacto" ? 42 : store.data.dockSize == "Grande" ? 64 : 52 }
    var dockWidth: CGFloat { store.data.dockSize == "Extra chico" ? 380 : store.data.dockSize == "Compacto" ? 450 : store.data.dockSize == "Grande" ? 620 : 520 }
    var dockHeight: CGFloat { store.data.dockSize == "Extra chico" ? 112 : store.data.dockSize == "Compacto" ? 140 : store.data.dockSize == "Grande" ? 210 : 175 }
    var body: some View {
        VStack(spacing:0) {
            if expanded {
                VStack(spacing: store.data.dockSize == "Extra chico" ? 4 : 8) {
                if !store.data.projectPath.isEmpty { Text("Proyecto: " + URL(fileURLWithPath: store.data.projectPath).lastPathComponent).font(.caption2.weight(.semibold)).lineLimit(1).help(store.data.projectPath) }
                HStack(spacing: store.data.dockSize == "Compacto" ? 5 : 8) {
                    ForEach(store.data.agents) { a in
                        Button { store.openChat?(a.id) } label: {
                            VStack(spacing:5) { Avatar(agent:a,size:avatarSize).overlay(alignment:.bottomTrailing) { if store.busy.contains(a.id) { ProgressView().controlSize(.mini).padding(3).background(.regularMaterial,in:Circle()) } }; Text(a.name == "Desarrollador" ? "Dev" : a.name).font(.system(size: store.data.dockSize == "Compacto" ? 9 : 10,weight:.medium)) }
                        }.buttonStyle(.plain).opacity(a.enabled ? 1 : 0.35)
                            .help("Abrir \(a.name). Arrastra hacia arriba para separar.")
                            .simultaneousGesture(DragGesture(minimumDistance:12).onEnded { if $0.translation.height < -20 { store.openChat?(a.id) } })
                    }
                    Divider().frame(height:34)
                    VStack(spacing:13) {
                        Button { store.pause() } label: { Image(systemName:store.data.paused ? "play.fill" : "pause.fill") }.help(store.data.paused ? "Activar equipo" : "Pausar equipo")
                        Button { store.showSettings?() } label: { Image(systemName:"slider.horizontal.3") }.help("Configuración")
                    }.buttonStyle(.plain).foregroundStyle(.secondary)
                }.padding(store.data.dockSize == "Extra chico" ? 7 : 14)
                }.padding(store.data.dockSize == "Extra chico" ? 4 : 8).background(.regularMaterial,in:RoundedRectangle(cornerRadius:24))
                    .overlay(RoundedRectangle(cornerRadius:24).strokeBorder(.primary.opacity(0.08)))
                    .shadow(color:.black.opacity(0.12),radius:20,y:7).transition(.move(edge:.bottom).combined(with:.opacity))
            }
            HStack(spacing:5) {
                ForEach(store.data.agents) { agent in Circle().fill(agent.color).frame(width:5,height:5) }
            }.padding(.horizontal, store.data.dockSize == "Extra chico" ? 8 : 14).padding(.vertical, store.data.dockSize == "Extra chico" ? 5 : 8)
                .background(.regularMaterial,in:Capsule())
                .overlay(Capsule().strokeBorder(.primary.opacity(0.08)))
                .padding(.top,7).padding(.bottom,8)
                .accessibilityLabel("Mostrar los siete agentes")
        }.frame(width:dockWidth,height:dockHeight,alignment:.bottom)
            .contentShape(Rectangle())
            .onHover { inside in
                collapse?.cancel()
                if inside { withAnimation(reduceMotion ? nil : .spring(response:0.3,dampingFraction:0.85)) { expanded = true } }
                else { collapse = Task { try? await Task.sleep(for:.milliseconds(550)); if !Task.isCancelled { withAnimation { expanded = false } } } }
            }.preferredColorScheme(store.scheme)
    }
}
struct ChatView: View {
    @ObservedObject var store: OfficeStore; let id: String
    @State private var draft = ""; @State private var attachment: String?; @State private var team = false
    @State private var capturing = false
    var a: Agent { store.agent(id) }
    var body: some View {
        VStack(spacing:0) {
            HStack(spacing:12) {
                Avatar(agent:a,size:36)
                VStack(alignment:.leading,spacing:3) { Text(a.name).font(.headline); Text(store.status[id] ?? (a.enabled ? a.provider : "Desactivado")).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Toggle("Activo",isOn:Binding(get:{ a.enabled },set:{ value in var edited = a; edited.enabled = value; store.update(edited); if !value { store.stop(id) } })).toggleStyle(.switch).controlSize(.mini).labelsHidden().help("Activar agente")
                Button { store.showSettings?() } label: { Image(systemName:"slider.horizontal.3") }.buttonStyle(.plain).help("Configurar agentes")
            }.padding(20)
            Divider()
            if store.busy.contains(id) {
                HStack(spacing:9) {
                    ProgressView().controlSize(.small)
                    Text("\(a.name) está trabajando") .font(.caption.weight(.semibold))
                    Text(store.status[id] ?? "Analizando proyecto…").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Detener") { store.stop(id) }.font(.caption)
                }.padding(.horizontal,20).padding(.vertical,10).background(a.color.opacity(0.10))
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:22) {
                        if a.messages.isEmpty {
                            VStack(alignment:.leading,spacing:15) {
                                Avatar(agent:a,size:56)
                                Text(a.specialty).font(.system(size:15)).foregroundStyle(.secondary).lineSpacing(4)
                                Button("Revisa lo que hay en mi pantalla") { draft = "Mira mi pantalla y revisa si este diseño es adecuado para el proyecto."; capture() }.buttonStyle(.bordered)
                            }.padding(.top,42).padding(.bottom,30)
                        }
                        ForEach(a.messages) { m in
                            VStack(alignment:.leading,spacing:8) {
                                HStack { Text(m.role == "user" ? "Tú" : m.role == "assistant" ? a.name : "Actividad").font(.caption.weight(.semibold)); Spacer(); Text(m.date,style:.time).font(.caption2).foregroundStyle(.tertiary) }
                                if let path = m.image, let image = NSImage(contentsOfFile:path) { Image(nsImage:image).resizable().scaledToFit().frame(maxHeight:220).clipShape(RoundedRectangle(cornerRadius:10)) }
                                if m.text.isEmpty { ProgressView().controlSize(.small) }
                                else { Text(m.text).font(.system(size:14)).textSelection(.enabled).lineSpacing(4).foregroundStyle(m.role == "system" ? .secondary : .primary) }
                            }.padding(m.role == "user" ? 14 : 0).frame(maxWidth:.infinity,alignment:.leading)
                                .background(m.role == "user" ? a.color.opacity(0.07) : .clear,in:RoundedRectangle(cornerRadius:14)).id(m.id)
                        }
                        Color.clear.frame(height:1).id("end")
                    }.padding(22)
                }.onChange(of:a.messages.last?.text) { _,_ in proxy.scrollTo("end",anchor:.bottom) }.onChange(of:a.messages.count) { _,_ in proxy.scrollTo("end",anchor:.bottom) }
            }
            if store.data.paused { Text("Equipo pausado").font(.caption).foregroundStyle(.secondary).padding(6) }
            VStack(spacing:9) {
                if let attachment { HStack { Image(systemName:"photo"); Text(URL(fileURLWithPath:attachment).lastPathComponent).lineLimit(1).font(.caption); Spacer(); Button { self.attachment = nil } label: { Image(systemName:"xmark") }.buttonStyle(.plain) } }
                TextField("Mensaje a \(a.name)…",text:$draft,axis:.vertical).textFieldStyle(.plain).lineLimit(2...7)
                HStack {
                    Button { capture() } label: { Image(systemName:"viewfinder") }.help("Capturar pantalla o ventana").disabled(capturing)
                    Button { attach() } label: { Image(systemName:"paperclip") }.help("Adjuntar imagen PNG")
                    if id == "ceo" { Toggle("Delegar al equipo",isOn:$team).font(.caption).toggleStyle(.checkbox) }
                    Spacer()
                    if store.busy.contains(id) || (id == "ceo" && store.coordinating) { Button { store.stop(id) } label: { Image(systemName:"stop.fill") }.help("Detener") }
                    else { Button(action:send) { Image(systemName:"arrow.up").fontWeight(.semibold).frame(width:24,height:24) }.buttonStyle(.borderedProminent).tint(a.color).keyboardShortcut(.return,modifiers:.command).disabled((draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && attachment == nil) || !a.enabled || store.data.paused) }
                }.buttonStyle(.borderless)
            }.padding(14).background(.quaternary.opacity(0.4),in:RoundedRectangle(cornerRadius:16)).padding(16)
                .onDrop(of: [UTType.fileURL.identifier, UTType.png.identifier, UTType.jpeg.identifier], isTargeted: nil) { providers in
                    handleDrop(providers); return true
                }
        }.frame(minWidth:390,minHeight:450).background(.background).preferredColorScheme(store.scheme)
    }
    func send() { let value = draft.isEmpty ? "Analiza esta imagen." : draft; if team && id == "ceo" { if attachment != nil { store.notice = "Envía la captura primero al CEO con la delegación desactivada."; return }; store.coordinate(value) } else { store.send(id,content:value,image:attachment) }; draft = ""; attachment = nil }
    func capture() { capturing = true; Task { defer { capturing = false }; do { attachment = try await store.capture() } catch { store.notice = error.localizedDescription } } }
    func attach() { let p = NSOpenPanel(); p.allowedContentTypes = [.png]; if p.runModal() == .OK, let url = p.url { do { let dest = store.directory.appendingPathComponent("image-\(UUID().uuidString).png"); try FileManager.default.copyItem(at:url,to:dest); attachment = dest.path } catch { store.notice = error.localizedDescription } } }
    func handleDrop(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        let types = provider.registeredTypeIdentifiers
        if let fileType = types.first(where: { $0 == UTType.fileURL.identifier }) {
            provider.loadDataRepresentation(forTypeIdentifier: fileType) { data, _ in
                guard let data, let url = URL(dataRepresentation: data, relativeTo: nil), ["png","jpg","jpeg"].contains(url.pathExtension.lowercased()) else { return }
                copyDropped(url)
            }
        } else {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { data, _ in
                guard let data else { return }
                let url = store.directory.appendingPathComponent("drop-\(UUID().uuidString).png")
                do { try data.write(to:url); DispatchQueue.main.async { attachment = url.path } } catch { }
            }
        }
    }
    func copyDropped(_ url: URL) {
        do { let dest = store.directory.appendingPathComponent("drop-\(UUID().uuidString).\(url.pathExtension)"); try FileManager.default.copyItem(at:url,to:dest); DispatchQueue.main.async { attachment = dest.path } } catch { DispatchQueue.main.async { store.notice = error.localizedDescription } }
    }
}

struct SettingsView: View {
    @ObservedObject var store: OfficeStore
    @State private var selection = "general"; @State private var key = ""; @State private var brainKey = ""; @State private var saved = false; @State private var brainSaved = false; @State private var chatMode = false
    @State private var globalBrainProvider = "Codex"; @State private var globalBrainModel = ""; @State private var globalBrainEndpoint = ""; @State private var globalBrainKey = ""
    @State private var globalConstructorProvider = "Codex"; @State private var globalConstructorModel = ""; @State private var globalConstructorEndpoint = ""; @State private var globalConstructorKey = ""
    var body: some View {
        HStack(spacing:0) {
            VStack(alignment:.leading,spacing:6) {
                Text("Daily Office").font(.title3.weight(.semibold)).padding(.bottom,20).padding(.top,10)
                nav("general","General","slider.horizontal.3")
                Divider().padding(.vertical,10)
                ForEach(store.data.agents) { a in nav(a.id,a.name,a.symbol) }
                Spacer()
            }.padding(18).frame(width:185).background(.quaternary.opacity(0.3))
            Divider()
            Group {
                if selection != "general" && chatMode { ChatView(store:store,id:selection) }
                else { ScrollView { VStack(alignment:.leading,spacing:22) { if selection == "general" { general } else { agentSettings } }.padding(28).frame(maxWidth:.infinity,alignment:.leading) } }
            }
        }.frame(width:800,height:660).preferredColorScheme(store.scheme)
            .onAppear { loadGlobalSettings() }
            .onChange(of:selection) { _,value in key = Vault.read(value); brainKey = Vault.read("\(value).brain"); saved = false; brainSaved = false; chatMode = false }
    }
    func nav(_ id: String,_ title: String,_ icon: String) -> some View { Button { selection = id } label: { Label(title,systemImage:icon).font(.system(size:13,weight:selection == id ? .semibold : .regular)).frame(maxWidth:.infinity,alignment:.leading).padding(10).background(selection == id ? Color.primary.opacity(0.07) : .clear,in:RoundedRectangle(cornerRadius:9)) }.buttonStyle(.plain) }
    func loadGlobalSettings() {
        guard let a = store.data.agents.first else { return }
        globalBrainProvider = a.brainProvider ?? "Codex"; globalBrainModel = a.brainModel ?? ""; globalBrainEndpoint = a.brainEndpoint ?? ""; globalBrainKey = Vault.read("\(a.id).brain")
        globalConstructorProvider = a.provider; globalConstructorModel = a.model; globalConstructorEndpoint = a.endpoint; globalConstructorKey = Vault.read(a.id)
    }
    func applyGlobalBrain() {
        for var a in store.data.agents { a.brainProvider = globalBrainProvider; a.brainModel = globalBrainModel; a.brainEndpoint = globalBrainEndpoint; store.update(a); if !globalBrainKey.isEmpty { try? Vault.save(globalBrainKey, account: "\(a.id).brain") } }
        store.notice = "Cerebro aplicado a todos los agentes."
    }
    func applyGlobalConstructor() {
        for var a in store.data.agents { a.provider = globalConstructorProvider; a.model = globalConstructorModel; a.endpoint = globalConstructorEndpoint; store.update(a); if !globalConstructorKey.isEmpty { try? Vault.save(globalConstructorKey, account: a.id) } }
        store.notice = "Constructor aplicado a todos los agentes."
    }
    var general: some View {
        VStack(alignment:.leading,spacing:20) {
            Text("General").font(.title2.weight(.semibold))
            Picker("Apariencia",selection:$store.data.theme) { ForEach(["Claro","Oscuro","Automático"],id:\.self) { Text($0) } }.pickerStyle(.segmented)
            HStack { Picker("Tamaño del dock",selection:$store.data.dockSize) { ForEach(["Extra chico","Compacto","Normal","Grande"],id:\.self) { Text($0) } }.pickerStyle(.segmented); Toggle("Dock activo", isOn: $store.data.dockEnabled).toggleStyle(.switch).onChange(of: store.data.dockEnabled) { _, enabled in if enabled { store.showDock?() } else { store.hideDock?() } } }
            GroupBox("Ayuda rápida") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Proyecto → elige una carpeta. Agente → abre su chat. Cerebro → decide y revisa. Constructor → ejecuta el trabajo pesado.").font(.caption).foregroundStyle(.secondary)
                    Text("Daily Office es local y de código abierto: puedes usar Codex o tus propias APIs.").font(.caption).foregroundStyle(.secondary)
                    Button("Ver guía completa") { showQuickHelp() }.buttonStyle(.bordered)
                }.padding(8)
            }
            GroupBox("Proveedores y modelos") {
                VStack(alignment:.leading,spacing:8) {
                    Text("Cada agente puede usar un proveedor y modelo distinto. Las claves se guardan en el Llavero de macOS.").font(.caption).foregroundStyle(.secondary)
                    ForEach(store.data.agents) { a in HStack { Avatar(agent:a,size:24); Text(a.name); Spacer(); Text(a.provider); Text(a.model.isEmpty ? "Predeterminado" : a.model).foregroundStyle(.secondary) }.font(.caption) }
                }.padding(8)
            }
            GroupBox("Configuración global") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configura una vez y aplica a los siete agentes. Los cambios individuales siguen disponibles en cada agente.").font(.caption).foregroundStyle(.secondary)
                    Text("Cerebro").font(.headline)
                    Picker("Cerebro", selection: $globalBrainProvider) { ForEach(["Codex", "Claude", "Gemini", "OpenAI", "xAI", "API"], id: \.self) { Text($0) } }
                    TextField("Modelo del Cerebro (opcional)", text: $globalBrainModel)
                    if globalBrainProvider != "Codex" {
                        TextField("Endpoint del Cerebro (opcional)", text: $globalBrainEndpoint)
                        SecureField("API key del Cerebro", text: $globalBrainKey)
                        if globalBrainProvider == "xAI" { Button("Abrir consola xAI") { NSWorkspace.shared.open(URL(string: "https://console.x.ai")!) }.buttonStyle(.bordered) }
                    }
                    Button("Aplicar Cerebro a todos") { applyGlobalBrain() }.buttonStyle(.borderedProminent)
                    Divider()
                    Text("Constructor").font(.headline)
                    Picker("Constructor", selection: $globalConstructorProvider) { ForEach(["Codex", "OpenAI", "Anthropic", "NVIDIA", "API", "Compatible"], id: \.self) { Text($0) } }
                    TextField("Modelo del Constructor (opcional)", text: $globalConstructorModel)
                    if globalConstructorProvider != "Codex" {
                        TextField("Endpoint del Constructor (opcional)", text: $globalConstructorEndpoint)
                        SecureField("API key del Constructor", text: $globalConstructorKey)
                    }
                    Button("Aplicar Constructor a todos") { applyGlobalConstructor() }.buttonStyle(.bordered)
                }.padding(8)
            }
            GroupBox("Codex") {
                VStack(alignment:.leading,spacing:10) {
                    TextField("Ruta de Codex",text:$store.data.codexPath)
                    HStack { Text(store.account).font(.caption).foregroundStyle(.secondary); Spacer(); Button("Comprobar conexión") { Task { await store.checkConnection() } } }
                    Text("Usa la sesión local de Codex. Si no has iniciado sesión, ejecuta codex login en Terminal.").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }.padding(8)
            }
            HStack { Button(store.data.paused ? "Activar equipo" : "Pausar equipo") { store.pause() }; Button("Mostrar dock") { store.showDock?() } }
            GroupBox("Actividad del equipo") {
                if store.activities.isEmpty { Text("Aún no hay actividad. Cuando un agente trabaje verás aquí sus archivos, comandos, búsquedas web y respuestas.").font(.caption).foregroundStyle(.secondary).padding(8) }
                else { VStack(alignment:.leading,spacing:8) { ForEach(store.activities.suffix(12)) { event in HStack(alignment:.top,spacing:8) { Text(event.agent).font(.caption.weight(.semibold)).frame(width:80,alignment:.leading); Text(event.kind).font(.caption).foregroundStyle(.secondary).frame(width:75,alignment:.leading); Text(event.detail).font(.caption).lineLimit(2); Spacer(); Text(event.date,style:.time).font(.caption2).foregroundStyle(.tertiary) } } }.padding(8).frame(maxWidth:.infinity,alignment:.leading) }
            }
            Button("Exportar respaldo") { let p = NSSavePanel(); p.nameFieldStringValue = "DailyOffice-backup.json"; if p.runModal() == .OK, let url = p.url { do { try JSONEncoder().encode(store.data).write(to:url) } catch { store.notice = error.localizedDescription } } }
            Text("El respaldo contiene chats y configuración. Las claves permanecen en el Llavero; las capturas se guardan localmente en Application Support/DailyOffice.").font(.caption).foregroundStyle(.secondary)
        }
    }
    func binding<T>(_ keyPath: WritableKeyPath<Agent,T>) -> Binding<T> { Binding(get:{ store.agent(selection)[keyPath:keyPath] },set:{ value in var a = store.agent(selection); a[keyPath:keyPath] = value; store.update(a) }) }
    func brainProviderBinding() -> Binding<String> { Binding(get:{ store.agent(selection).brainProvider ?? "Codex" },set:{ value in var a = store.agent(selection); a.brainProvider = value; store.update(a) }) }
    func brainBinding(_ keyPath: WritableKeyPath<Agent,String?>) -> Binding<String> { Binding(get:{ store.agent(selection)[keyPath:keyPath] ?? "" },set:{ value in var a = store.agent(selection); a[keyPath:keyPath] = value; store.update(a) }) }
    var agentSettings: some View {
        let a = store.agent(selection)
        return VStack(alignment:.leading,spacing:18) {
            HStack { Avatar(agent:a); VStack(alignment:.leading,spacing:3) { Text(a.name).font(.title2.weight(.semibold)); Text(chatMode ? "Conversación" : "Configuración").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button(chatMode ? "Configuración" : "Abrir chat") { chatMode.toggle() }.buttonStyle(.borderedProminent).tint(a.color); Toggle("Activo",isOn:binding(\.enabled)).toggleStyle(.switch) }
            GroupBox("Cerebro") {
                VStack(alignment:.leading,spacing:10) {
                    Text("Planea, razona y revisa. El Cerebro no modifica archivos directamente; sus instrucciones pasan al Constructor.").font(.caption).foregroundStyle(.secondary)
                    Picker("Cerebro",selection:brainProviderBinding()) { ForEach(["Codex","Claude","Gemini","OpenAI","xAI","API"],id:\.self) { Text($0) } }
                    TextField("Modelo del cerebro (opcional)",text:brainBinding(\.brainModel))
                    Text("Escribe aquí el nombre exacto del modelo de tu proveedor. Con Codex vacío se usa su modelo predeterminado.").font(.caption).foregroundStyle(.secondary)
                    if brainProviderBinding().wrappedValue != "Codex" { TextField("Endpoint del cerebro (opcional)",text:brainBinding(\.brainEndpoint)); HStack { SecureField("API key del cerebro",text:$brainKey); Button(brainSaved ? "Guardada" : "Guardar") { do { try Vault.save(brainKey,account:"\(selection).brain"); brainSaved = true } catch { store.notice = error.localizedDescription } } }; if brainProviderBinding().wrappedValue == "xAI" { Button("Abrir consola xAI") { NSWorkspace.shared.open(URL(string: "https://console.x.ai")!) }.buttonStyle(.bordered) } }
                }.padding(8)
            }
            GroupBox("Constructor") {
                VStack(alignment:.leading,spacing:10) {
            Text("Ejecuta el trabajo pesado: código, archivos, pruebas y cambios del proyecto.").font(.caption).foregroundStyle(.secondary)
            Picker("Proveedor",selection:binding(\.provider)) { ForEach(["Codex","OpenAI","Anthropic","NVIDIA","API","Compatible"],id:\.self) { Text($0) } }
            TextField(a.provider == "Codex" ? "Modelo (vacío: predeterminado de Codex)" : "Identificador del modelo",text:binding(\.model))
            if a.provider == "Codex" && !store.models.isEmpty { Menu("Modelos disponibles") { ForEach(store.models,id:\.self) { model in Button(model) { binding(\.model).wrappedValue = model } } } }
            if a.provider != "Codex" {
                TextField("URL base del proveedor (incluye /v1)",text:binding(\.endpoint))
                HStack { SecureField("Clave de API",text:$key); Button(saved ? "Guardada" : "Guardar clave") { do { try Vault.save(key,account:selection); saved = true } catch { store.notice = error.localizedDescription } } }
                Text("Conexión de chat e imágenes. La ejecución de herramientas está disponible mediante Codex.").font(.caption).foregroundStyle(.secondary)
            }
            Toggle("El modelo acepta imágenes",isOn:binding(\.vision))
            if a.provider == "Codex" { Toggle("Permitir cambios en la carpeta del proyecto",isOn:binding(\.allowWrites)) }
                }.padding(8)
            }
            editor("Instrucciones permanentes",text:binding(\.prompt),height:90)
            editor("Memoria",text:binding(\.memory),height:65)
            HStack { Text("Skills").font(.headline); Spacer(); Button("Añadir SKILL.md") { importSkill() } }
            ForEach(a.skills) { skill in
                VStack(alignment:.leading,spacing:7) {
                    HStack { Toggle(skill.name,isOn:Binding(get:{ store.agent(selection).skills.first(where:{$0.id == skill.id})?.enabled ?? false },set:{ v in var a = store.agent(selection); if let i = a.skills.firstIndex(where:{$0.id == skill.id}) { a.skills[i].enabled = v; store.update(a) } })); Spacer(); Button { var a = store.agent(selection); a.skills.removeAll { $0.id == skill.id }; store.update(a) } label: { Image(systemName:"trash") }.buttonStyle(.borderless) }
                    Text(skill.source).font(.caption2).foregroundStyle(.secondary)
                    DisclosureGroup("Instrucciones") { Text(skill.content).font(.caption).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }
                }.padding(12).background(.quaternary.opacity(0.4),in:RoundedRectangle(cornerRadius:10))
            }
        }.textFieldStyle(.roundedBorder)
    }
    func editor(_ name: String,text: Binding<String>,height: CGFloat) -> some View { VStack(alignment:.leading,spacing:8) { Text(name).font(.headline); TextEditor(text:text).font(.body).frame(height:height).padding(6).overlay(RoundedRectangle(cornerRadius:8).stroke(.quaternary)) } }
    func importSkill() {
        let p = NSOpenPanel(); p.allowedContentTypes = [.plainText,.text]; if p.runModal() == .OK, let url = p.url {
            do { let text = try String(contentsOf:url,encoding:.utf8); guard text.utf8.count < 100_000 else { throw OfficeError(message:"La skill supera 100 KB.") }
                let alert = NSAlert(); alert.messageText = "Añadir skill"; alert.informativeText = "\(url.lastPathComponent)\n\nSe importarán sus instrucciones. Los scripts y recursos externos no se ejecutan ni instalan automáticamente."; alert.addButton(withTitle:"Añadir"); alert.addButton(withTitle:"Cancelar")
                if alert.runModal() == .alertFirstButtonReturn { var a = store.agent(selection); a.skills.append(Skill(name:url.deletingLastPathComponent().lastPathComponent,content:text,source:url.path)); store.update(a) }
            } catch { store.notice = error.localizedDescription }
        }
    }
}
