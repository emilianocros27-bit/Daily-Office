import SwiftUI
import AppKit

@MainActor final class OfficeStore: ObservableObject {
    @Published var data: OfficeData { didSet { save() } }
    @Published var busy: Set<String> = []
    @Published var status: [String:String] = [:]
    @Published var notice: String?
    @Published var models: [String] = []
    @Published var account = "Sin comprobar"
    @Published var runStatus = ""
    @Published var localhostCommand = ""
    @Published var runURL: URL?
    @Published var repositoryURL: URL?
    @Published var activities: [ActivityEvent] = []
    private var projectProcess: Process?
    private var serverCheckTask: Task<Void, Never>?
    var isProjectRunning: Bool { projectProcess != nil }
    var canPreviewHTML: Bool { runURL?.isFileURL == true || runURL?.scheme == "http" }
    var openChat: ((String)->Void)?; var showDock: (()->Void)?; var hideDock: (()->Void)?; var showSettings: (()->Void)?
    private var jobs: [String:Task<Void,Never>] = [:]
    private var connections: [String:CodexConnection] = [:]
    @Published var coordinating = false
    private var teamTask: Task<Void,Never>?
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("DailyOffice")
        let file = self.directory.appendingPathComponent("office.json")
        if let bytes = try? Data(contentsOf:file), let decoded = try? JSONDecoder().decode(OfficeData.self,from:bytes) { data = decoded }
        else { data = OfficeData(); if FileManager.default.fileExists(atPath:file.path) { try? FileManager.default.copyItem(at:file,to:self.directory.appendingPathComponent("office-recovery-\(UUID().uuidString).json")); notice = "No se pudo leer el historial. Se conservó una copia de recuperación." } }
        try? FileManager.default.createDirectory(at:self.directory,withIntermediateDirectories:true)
        for defaultAgent in Agent.defaults where !data.agents.contains(where: { $0.id == defaultAgent.id }) { data.agents.append(defaultAgent) }
        if data.bundledSkillsVersion != 1, let url = Bundle.main.url(forResource:"DefaultSkills",withExtension:"json"), let bytes = try? Data(contentsOf:url), let skills = try? JSONDecoder().decode([String:[Skill]].self,from:bytes) {
            data.bundledSkillsVersion = 1
            for index in data.agents.indices {
                for skill in skills[data.agents[index].id] ?? [] where !data.agents[index].skills.contains(where: { $0.source == skill.source && $0.name == skill.name }) { data.agents[index].skills.append(skill) }
            }
        }
        refreshProjectPreview()
    }
    func save() {
        do { let bytes = try JSONEncoder().encode(data); try bytes.write(to:directory.appendingPathComponent("office.json"),options:.atomic) }
        catch { notice = "No se pudo guardar: \(error.localizedDescription)" }
    }
    func selectProject(_ path: String) {
        data.projectPath = path
        let name = URL(fileURLWithPath: path).lastPathComponent
        if let i = data.projects.firstIndex(where: { $0.path == path }) { data.projects[i].lastOpened = Date(); data.projects[i].name = name }
        else { data.projects.insert(ProjectRecord(name:name, path:path), at:0) }
        data.projects.sort { $0.lastOpened > $1.lastOpened }
        refreshProjectPreview()
    }
    func removeProject(_ id: UUID) {
        guard let project = data.projects.first(where: { $0.id == id }) else { return }
        data.projects.removeAll { $0.id == id }
        if data.projectPath == project.path { data.projectPath = ""; runURL = nil }
    }
    func setProjectImage(_ path: String, for id: UUID) {
        if let i = data.projects.firstIndex(where: { $0.id == id }) { data.projects[i].imagePath = path }
    }
    func agent(_ id: String) -> Agent { data.agents.first { $0.id == id } ?? data.agents[0] }
    func update(_ a: Agent) { if let i = data.agents.firstIndex(where:{$0.id == a.id}) { data.agents[i] = a; if !a.enabled { stop(a.id) } } }
    func activity(_ agent: String, _ kind: String, _ detail: String) {
        activities.append(ActivityEvent(agent: agent, kind: kind, detail: detail))
        if activities.count > 200 { activities.removeFirst(activities.count - 200) }
    }
    func refreshProjectPreview() {
        guard !data.projectPath.isEmpty else { runURL = nil; return }
        let root = URL(fileURLWithPath: data.projectPath, isDirectory: true)
        let directFiles = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        if let index = directFiles.first(where: { $0.lastPathComponent == "index.html" }) { runURL = index }
        else if let html = directFiles.first(where: { $0.pathExtension.lowercased() == "html" }) { runURL = html }
        else { runURL = nil }
    }
    func append(_ id: String, _ m: Message) { if let i = data.agents.firstIndex(where:{$0.id == id}) { data.agents[i].messages.append(m) } }
    func text(_ id: String, message: UUID, _ value: String, append: Bool = false) {
        guard let a = data.agents.firstIndex(where:{$0.id == id}), let m = data.agents[a].messages.firstIndex(where:{$0.id == message}) else { return }
        if append { data.agents[a].messages[m].text += value } else { data.agents[a].messages[m].text = value }
    }
    var scheme: ColorScheme? { data.theme == "Claro" ? .light : data.theme == "Oscuro" ? .dark : nil }
    func instructions(_ a: Agent) -> String {
        """
        Eres \(a.name), especialista de Daily Office. \(a.specialty)
        Responde en español, con resultados concretos y sin texto de relleno. No inventes acciones, pruebas ni acceso a herramientas.
        Las API externas solo permiten conversación y análisis de imágenes en esta versión; no ejecutes ni afirmes ejecutar herramientas si no están disponibles.
        Si el proyecto contiene project.godot, Assets o ProjectSettings, trátalo como videojuego. Para cambios solicitados en un videojuego inspecciona primero la escena, materiales, prefabs y scripts relevantes, modifica los archivos reales y verifica el diff antes de responder. Si no tienes permiso de escritura o no encuentras el recurso, dilo explícitamente y no afirmes que el cambio se hizo.
        Proyecto: \(data.projectPath)
        Contexto compartido: \(data.context)
        Cuando recibas una imagen adjunta, analízala directamente. No digas que no tienes acceso a la pantalla si la imagen está incluida en el mensaje.
        Memoria del agente: \(a.memory)
        Cerebro configurado: \(a.brainProvider ?? "Codex") / \(a.brainModel ?? "predeterminado"). Usa el Cerebro para razonar, planear y revisar; usa el Constructor para ejecutar el trabajo pesado.
        Instrucciones permanentes del usuario: \(a.prompt)
        Recursos de las skills integradas: \(Bundle.main.resourceURL?.appendingPathComponent("Skills").path ?? "Skills")
        Skills activas:
        \(a.skills.filter(\.enabled).map { "## \($0.name)\n\($0.content)" }.joined(separator:"\n\n"))
        """
    }
    func send(_ id: String, content: String, image: String? = nil) {
        guard !busy.contains(id), !data.paused, agent(id).enabled else { return }
        append(id,Message(role:"user",text:content,image:image))
        jobs[id] = Task { do { _ = try await respond(id) } catch { append(id,Message(role:"system",text:error is CancellationError ? "Trabajo detenido." : error.localizedDescription)) }; jobs[id] = nil }
    }
    func respond(_ id: String, extra: String = "") async throws -> String {
        guard !busy.contains(id), !data.paused, agent(id).enabled else { throw OfficeError(message:"\(agent(id).name) no está disponible.") }
        if agent(id).allowWrites && busy.contains(where: { agent($0).allowWrites }) { throw OfficeError(message:"Otro agente está editando el proyecto. Espera a que termine para evitar cambios simultáneos.") }
        busy.insert(id); status[id] = "Trabajando"
        defer { busy.remove(id); status[id] = nil; connections[id]?.close(); connections[id] = nil }
        let a = agent(id), history = a.messages
        let response = Message(role:"assistant",text:""); append(id,response)
        do {
            let result: String
            if id == "ceo", let brain = brainVersion(a), brain.provider != "Codex" { result = try await APIClient.reply(agent:brain,system:instructions(a) + extra,messages:history); try Task.checkCancellation(); text(id,message:response.id,result) }
            else if a.provider == "Codex" { result = try await codexReply(a,history:history,system:instructions(a) + extra,messageID:response.id) }
            else { result = try await APIClient.reply(agent:a,system:instructions(a) + extra,messages:history); try Task.checkCancellation(); text(id,message:response.id,result) }
            return result
        } catch { text(id,message:response.id,"Respuesta interrumpida. " + error.localizedDescription); throw error }
    }
    private func brainVersion(_ agent: Agent) -> Agent? {
        guard let provider = agent.brainProvider, !provider.isEmpty, provider != "Codex", let model = agent.brainModel, !model.isEmpty else { return nil }
        var copy = agent; copy.provider = provider == "Claude" ? "Anthropic" : provider == "API" ? "Compatible" : provider; copy.model = model; copy.endpoint = agent.brainEndpoint ?? ""; copy.allowWrites = false; copy.credentialScope = "brain"
        return copy
    }
    private func codexReply(_ a: Agent, history: [Message], system: String, messageID: UUID) async throws -> String {
        let c = CodexConnection(); connections[a.id] = c
        c.userInput = { [weak self] params in
            var answers: [String:Any] = [:]
            for question in params["questions"] as? [[String:Any]] ?? [] {
                guard let id = question["id"] as? String else { continue }
                let alert = NSAlert(); alert.messageText = question["header"] as? String ?? a.name
                let options = question["options"] as? [[String:Any]] ?? []
                alert.informativeText = (question["question"] as? String ?? "") + "\n" + options.compactMap { opt in (opt["label"] as? String).map { $0 + ": " + (opt["description"] as? String ?? "") } }.joined(separator:"\n")
                let field: NSTextField = question["isSecret"] as? Bool == true ? NSSecureTextField(frame:NSRect(x:0,y:0,width:360,height:26)) : NSTextField(frame:NSRect(x:0,y:0,width:360,height:26))
                alert.accessoryView = field; alert.addButton(withTitle:"Responder"); alert.addButton(withTitle:"Omitir")
                NSApp.activate(ignoringOtherApps:true)
                let value = alert.runModal() == .alertFirstButtonReturn ? field.stringValue : "Sin respuesta; continúa solo si no dependes de ella."
                answers[id] = ["answers":[value]]
                self?.append(a.id,Message(role:"system",text:(question["question"] as? String ?? "Pregunta") + "\n" + (question["isSecret"] as? Bool == true ? "Respuesta privada enviada" : value)))
            }
            return ["answers":answers]
        }
        c.approval = { [weak self] method,params in
            guard let self, !self.data.paused else { return false }
            let alert = NSAlert(); alert.messageText = "\(a.name) solicita permiso"
            alert.informativeText = (params["command"] as? String) ?? (params["reason"] as? String) ?? method
            alert.addButton(withTitle:"Permitir una vez"); alert.addButton(withTitle:"Rechazar")
            NSApp.activate(ignoringOtherApps:true); return alert.runModal() == .alertFirstButtonReturn
        }
        try await c.start(path:data.codexPath)
        try Task.checkCancellation()
        var params: [String:Any] = ["cwd":data.projectPath.isEmpty ? directory.path : data.projectPath,"developerInstructions":system,"approvalPolicy":"on-request","sandbox":a.allowWrites ? "workspace-write" : "read-only","ephemeral":true]
        if !a.model.isEmpty { params["model"] = a.model }
        let started = try await c.request("thread/start",params)
        guard let thread = started["thread"] as? [String:Any], let threadID = thread["id"] as? String else { throw OfficeError(message:"Codex no creó la conversación.") }
        let transcript = history.filter { $0.role == "user" || $0.role == "assistant" }.map { "\($0.role): \($0.text)" }.joined(separator:"\n\n")
        var inputs: [[String:Any]] = [["type":"text","text":"Historial de esta conversación. Responde al último mensaje del usuario:\n\(transcript)"]]
        if let path = history.last?.image { guard a.vision else { throw OfficeError(message:"Este agente tiene desactivada la visión.") }; inputs.append(["type":"localImage","path":path]) }
            let result = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (done: CheckedContinuation<String,Error>) in
                var finished = false; var output = ""
                func finish(_ result: Result<String,Error>) { guard !finished else { return }; finished = true; done.resume(with:result) }
                c.event = { [weak self] method,p in
                    if method == "item/started", let item = p["item"] as? [String:Any] {
                        let type = item["type"] as? String ?? "Actividad"
                        let detail = (item["command"] as? String) ?? (item["name"] as? String) ?? (item["query"] as? String) ?? "Inició una actividad"
                        self?.activity(a.name, type, detail)
                    }
                    if method == "item/agentMessage/delta", let delta = p["delta"] as? String { output += delta; self?.text(a.id,message:messageID,delta,append:true) }
                    if method.localizedCaseInsensitiveContains("fileChange"), let changes = p["changes"] as? [[String:Any]] {
                        for change in changes {
                            let path = change["path"] as? String ?? "archivo"
                            let diff = change["diff"] as? String ?? ""
                            let added = diff.split(separator:"\n").filter { $0.hasPrefix("+") && !$0.hasPrefix("+++") }.count
                            let removed = diff.split(separator:"\n").filter { $0.hasPrefix("-") && !$0.hasPrefix("---") }.count
                            self?.activity(a.name, "Archivo", "\(path) · +\(added) / -\(removed) líneas")
                        }
                    }
                    if method == "item/started", let item = p["item"] as? [String:Any] { self?.status[a.id] = item["type"] as? String ?? "Trabajando" }
                    if method == "connection/closed" { finish(.failure(OfficeError(message:"Codex se desconectó antes de terminar."))) }
                    if method == "item/completed", let item = p["item"] as? [String:Any], item["type"] as? String == "agentMessage", let final = item["text"] as? String, output.isEmpty { output = final; self?.text(a.id,message:messageID,final) }
                    if method == "turn/completed" {
                        let turn = p["turn"] as? [String:Any] ?? [:]
                        if turn["status"] as? String == "failed" { let e = turn["error"] as? [String:Any]; finish(.failure(OfficeError(message:e?["message"] as? String ?? "El turno falló."))) }
                        else { finish(.success(output)) }
                    }
                }
                Task {
                    do { _ = try await c.request("turn/start",["threadId":threadID,"input":inputs]) }
                    catch { finish(.failure(error)) }
                }
                Task {
                    while !finished {
                        try? await Task.sleep(for:.milliseconds(200))
                        if self.jobs[a.id]?.isCancelled == true || self.data.paused || !self.agent(a.id).enabled || self.connections[a.id] == nil { finish(.failure(CancellationError())); break }
                    }
                }
                Task { try? await Task.sleep(for:.seconds(600)); finish(.failure(OfficeError(message:"Se alcanzó el límite de 10 minutos. Puedes continuar con otro mensaje."))) }
            }
        } onCancel: { Task { @MainActor in c.close() } }
        recordGitDiff(for: a)
        return result
    }
    private func recordGitDiff(for agent: Agent) {
        guard !data.projectPath.isEmpty else { return }
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/git"); p.arguments = ["-C", data.projectPath, "diff", "--numstat"]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        do { try p.run(); p.waitUntilExit() } catch { return }
        guard p.terminationStatus == 0, let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else { return }
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 2).map(String.init)
            if parts.count == 3 { activity(agent.name, "Cambio", "\(parts[2]) · +\(parts[0]) / -\(parts[1]) líneas") }
        }
    }
    func stop(_ id: String) {
        if id == "ceo" { teamTask?.cancel(); for member in Array(connections.keys) where member != "ceo" { connections[member]?.close(); connections[member] = nil } }
        jobs[id]?.cancel(); connections[id]?.close(); connections[id] = nil
    }
    func stopProject() {
        serverCheckTask?.cancel(); serverCheckTask = nil
        projectProcess?.terminate(); projectProcess = nil
        runStatus = "Proyecto detenido"
    }
    func showLocalhostCommand() {
        guard !data.projectPath.isEmpty else { notice = "Elige primero la carpeta del proyecto."; return }
        let root = URL(fileURLWithPath: data.projectPath, isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        let port = freeLocalhostPort()
        let command: String
        if files.contains("package.json") {
            command = "cd \(shellQuote(root.path)) && npm run dev -- --host 127.0.0.1"
        } else if files.contains("manage.py") {
            command = "cd \(shellQuote(root.path)) && python3 manage.py runserver 127.0.0.1:\(port)"
        } else if files.contains("index.html") || files.contains(where: { $0.lowercased().hasSuffix(".html") }) {
            command = "cd \(shellQuote(root.path)) && python3 -m http.server \(port) --bind 127.0.0.1"
        } else {
            notice = "No encontré index.html, package.json ni manage.py para levantar localhost."; return
        }
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        localhostCommand = command
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(command, forType: .string)
        var error: NSDictionary?
        NSAppleScript(source: "tell application \"Terminal\" to do script \"\(escaped)\"")?.executeAndReturnError(&error)
        runStatus = "Comando enviado a Terminal"
        activity("Sistema", "Terminal", command)
    }
    private func freeLocalhostPort() -> Int {
        for port in 8000..<8020 {
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof"); p.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN"]
            let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
            try? p.run(); p.waitUntilExit()
            if pipe.fileHandleForReading.readDataToEndOfFile().isEmpty { return port }
        }
        return 8000
    }
    private func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    func runProject() {
        guard !data.projectPath.isEmpty else { notice = "Elige primero la carpeta del proyecto."; return }
        guard projectProcess == nil else { stopProject(); return }
        let root = URL(fileURLWithPath: data.projectPath, isDirectory: true)
        refreshProjectPreview()
        repositoryURL = gitRemoteURL(at: root)
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.path) else { notice = "La carpeta del proyecto ya no existe."; return }
        let files = (try? fm.contentsOfDirectory(atPath: root.path)) ?? []
        let nested = (fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])?.compactMap { $0 as? URL }.filter { $0.pathComponents.count <= root.pathComponents.count + 3 } ?? [])
        let projectFiles = files.map { root.appendingPathComponent($0) } + nested
        let hasPackage = projectFiles.contains { $0.lastPathComponent == "package.json" }
        let hasIndex = files.contains("index.html") || files.contains { $0.lowercased().hasSuffix(".html") }
        let hasPython = projectFiles.contains { $0.lastPathComponent == "manage.py" || $0.pathExtension == "py" }
        let hasXcode = projectFiles.contains { $0.pathExtension == "xcodeproj" || $0.pathExtension == "xcworkspace" }
        let hasGodot = projectFiles.contains { $0.lastPathComponent == "project.godot" }
        let hasUnity = projectFiles.contains { $0.lastPathComponent == "ProjectSettings" || $0.lastPathComponent == "Assets" }
        let launchRoot: URL = projectFiles.first(where: { $0.lastPathComponent == "package.json" || $0.lastPathComponent == "index.html" || $0.lastPathComponent == "manage.py" })?.deletingLastPathComponent() ?? root
        let port = freeLocalhostPort()
        let command: (String,[String],String)?
        if hasPackage {
            let packageURL = launchRoot.appendingPathComponent("package.json")
            let package = (try? Data(contentsOf: packageURL)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String:Any] }
            let scripts = package?["scripts"] as? [String:Any]
            let script = scripts?["dev"] != nil ? "dev" : (scripts?["start"] != nil ? "start" : nil)
            guard let script else { notice = "Encontré package.json, pero no tiene scripts dev o start."; return }
            command = ("/usr/bin/env", ["npm","run",script,"--","--host","127.0.0.1"], "npm run \(script)")
        }
        else if hasIndex { command = ("/usr/bin/python3", ["-m","http.server","\(port)","--bind","127.0.0.1"], "web estática") }
        else if hasPython && files.contains("manage.py") { command = ("/usr/bin/python3", ["manage.py","runserver","127.0.0.1:\(port)"], "Django") }
        else if hasXcode { command = ("/usr/bin/open", ["-a","Xcode",root.path], "Xcode") }
        else if hasGodot { command = ("/usr/bin/open", ["-a","Godot",root.path], "Godot") }
        else if hasUnity { command = ("/usr/bin/open", ["-a","Unity Hub",root.path], "Unity") }
        else { notice = "No reconocí un proyecto ejecutable. Busca package.json, manage.py o un proyecto de Xcode."; return }
        let p = Process(); p.executableURL = URL(fileURLWithPath: command!.0); p.arguments = command!.1; p.currentDirectoryURL = launchRoot
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        projectProcess = p; runStatus = "Iniciando \(command!.2)…"; runURL = nil
        activity("Sistema", "Proyecto", "Iniciando \(command!.2) en \(launchRoot.path)")
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = String(data: handle.availableData, encoding: .utf8) ?? ""
            guard !chunk.isEmpty else { return }
            Task { @MainActor in
                let pattern = #"https?://(?:localhost|127\.0\.0\.1):\d+"#
                if let range = chunk.range(of: pattern, options: .regularExpression), let url = URL(string:String(chunk[range])) { self?.runURL = url; self?.runStatus = "Proyecto ejecutándose"; self?.activity("Sistema", "Servidor", url.absoluteString) }
                if chunk.count < 1000 { self?.activity("Sistema", "Salida", chunk.trimmingCharacters(in: .whitespacesAndNewlines)) }
            }
        }
        p.terminationHandler = { [weak self] _ in Task { @MainActor in self?.serverCheckTask?.cancel(); self?.serverCheckTask = nil; self?.projectProcess = nil; if self?.runURL == nil { self?.runStatus = "El proyecto terminó" } } }
        do {
            try p.run()
            if hasIndex {
                serverCheckTask = Task { [weak self] in
                    for _ in 0..<12 {
                        if Task.isCancelled { return }
                        try? await Task.sleep(for: .milliseconds(250))
                        guard let self else { return }
                        do {
                            let (_, response) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)")!)
                            if let http = response as? HTTPURLResponse, (200...499).contains(http.statusCode) {
                                await MainActor.run { self.runStatus = "Servidor activo · http://127.0.0.1:\(port)"; self.activity("Sistema", "Servidor", "http://127.0.0.1:\(port)") }
                                return
                            }
                        } catch { }
                    }
                    await MainActor.run { if self?.projectProcess != nil { self?.runStatus = "No respondió en el puerto \(port). Revisa la salida del proyecto." } }
                }
            }
        } catch { projectProcess = nil; runStatus = ""; notice = "No se pudo iniciar: \(error.localizedDescription)" }
        append("ceo", Message(role:"system", text:"Proyecto iniciado: \(command!.2). La app mostrará el enlace cuando el servidor lo anuncie."))
    }
    private func gitRemoteURL(at root: URL) -> URL? {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/git"); p.arguments = ["-C", root.path, "remote", "get-url", "origin"]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        do { try p.run(); p.waitUntilExit() } catch { return nil }
        guard p.terminationStatus == 0, let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if raw.hasPrefix("git@github.com:") { return URL(string: "https://github.com/" + raw.dropFirst("git@github.com:".count).replacingOccurrences(of: ".git", with: "")) }
        return URL(string: raw.replacingOccurrences(of: ".git", with: ""))
    }
    func pause() { data.paused.toggle(); if data.paused { teamTask?.cancel(); for id in busy { stop(id) } } }
    func coordinate(_ objective: String) {
        guard teamTask == nil, !data.paused else { return }
        append("ceo",Message(role:"user",text:objective))
        coordinating = true
        teamTask = Task {
            defer { teamTask = nil; coordinating = false }
            do {
                let enabled = data.agents.filter { $0.enabled && $0.id != "ceo" }.map { "\($0.id): \($0.specialty)" }.joined(separator:"\n")
                let raw = try await respond("ceo",extra:"\nPlanifica esta petición para el equipo. Devuelve SOLO JSON sin markdown: {\"summary\":\"resumen\",\"tasks\":[{\"agent\":\"id\",\"task\":\"instrucción autosuficiente\"}]}. Máximo 5 tareas. Especialistas habilitados:\n\(enabled)")
                let cleaned = raw.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:"```json",with:"").replacingOccurrences(of:"```",with:"")
                let plan = try JSONDecoder().decode(CEOPlan.self,from:Data(cleaned.utf8))
                guard plan.tasks.count <= 5, plan.tasks.allSatisfy({ t in data.agents.contains { $0.id == t.agent && $0.id != "ceo" && $0.enabled } }) else { throw OfficeError(message:"El CEO propuso una asignación inválida. Ajusta la petición.") }
                append("ceo",Message(role:"system",text:plan.summary))
                var reports: [String] = []
                for task in plan.tasks {
                    try Task.checkCancellation()
                    guard !data.paused else { throw CancellationError() }
                    append("ceo",Message(role:"system",text:"Asignado a \(agent(task.agent).name): \(task.task)"))
                    append(task.agent,Message(role:"user",text:"Encargo del CEO: \(task.task)"))
                    do { let result = try await respond(task.agent); reports.append("\(agent(task.agent).name):\n\(result)") }
                    catch { if Task.isCancelled { throw CancellationError() }; reports.append("\(agent(task.agent).name): error \(error.localizedDescription)") }
                }
                try Task.checkCancellation()
                append("ceo",Message(role:"user",text:"Resultados del equipo:\n" + reports.joined(separator:"\n\n") + "\nEvalúa lo entregado, señala pendientes y responde al objetivo original."))
                _ = try await respond("ceo")
            } catch { append("ceo",Message(role:"system",text:"Coordinación detenida: \(error.localizedDescription)")) }
        }
    }
    func checkConnection() async {
        let c = CodexConnection(); defer { c.close() }
        do {
            try await c.start(path:data.codexPath)
            let r = try await c.request("account/read",[:]); let a = r["account"] as? [String:Any]
            account = a?["type"] as? String ?? "Inicia sesión en Codex"
            let list = try await c.request("model/list",[:]); models = (list["data"] as? [[String:Any]] ?? []).compactMap { $0["model"] as? String }
        } catch { account = error.localizedDescription }
    }
    func capture() async throws -> String? {
        // The system interactive screenshot tool handles region/window selection and screen permission.
        let url = directory.appendingPathComponent("capture-\(UUID().uuidString).png")
        let p = Process(); p.executableURL = URL(fileURLWithPath:"/usr/sbin/screencapture"); p.arguments = ["-i","-x",url.path]
        try p.run()
        await Task.detached { p.waitUntilExit() }.value
        return FileManager.default.fileExists(atPath:url.path) ? url.path : nil
    }
}
