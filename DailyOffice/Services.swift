import Foundation
import AppKit
import Security

struct Vault {
    static func read(_ account: String) -> String {
        let q: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"DailyOffice",kSecAttrAccount as String:account,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var result: CFTypeRef?; guard SecItemCopyMatching(q as CFDictionary,&result) == errSecSuccess, let data = result as? Data else { return "" }
        return String(data:data,encoding:.utf8) ?? ""
    }
    static func save(_ value: String, account: String) throws {
        let q: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"DailyOffice",kSecAttrAccount as String:account]
        let result = SecItemUpdate(q as CFDictionary,[kSecValueData as String:Data(value.utf8)] as CFDictionary)
        if result == errSecItemNotFound {
            var item = q; item[kSecValueData as String] = Data(value.utf8)
            guard SecItemAdd(item as CFDictionary,nil) == errSecSuccess else { throw OfficeError(message:"No se pudo guardar la clave en el Llavero.") }; return
        }
        guard result == errSecSuccess else { throw OfficeError(message:"No se pudo actualizar el Llavero.") }
    }
    static func delete(_ account: String) throws {
        let q: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"DailyOffice",kSecAttrAccount as String:account]
        let result = SecItemDelete(q as CFDictionary)
        guard result == errSecSuccess || result == errSecItemNotFound else { throw OfficeError(message:"No se pudo cerrar la sesión local.") }
    }
}

@MainActor final class CodexConnection {
    private var process: Process?; private var input: FileHandle?; private var buffer = Data(); private var counter = 0
    private var pending: [Int:CheckedContinuation<[String:Any],Error>] = [:]
    var event: ((String,[String:Any])->Void)?
    var userInput: (([String:Any])->[String:Any])?
    var approval: ((String,[String:Any])->Bool)?
    func start(path: String) async throws {
        let p = Process(); p.executableURL = URL(fileURLWithPath:CodexLocator.resolve(path)); p.arguments = ["app-server"]
        var env = ProcessInfo.processInfo.environment; let home = FileManager.default.homeDirectoryForCurrentUser.path; env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(home)/.npm-global/bin:\(home)/.local/bin:\(home)/.bun/bin:/usr/bin:/bin:/usr/sbin:/sbin"; p.environment = env
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe(); p.standardInput = stdin; p.standardOutput = stdout; p.standardError = stderr
        input = stdin.fileHandleForWriting; process = p
        stdout.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            Task { @MainActor in self?.receive(data) }
        }
        stderr.fileHandleForReading.readabilityHandler = { h in _ = h.availableData }
        p.terminationHandler = { [weak self] _ in Task { @MainActor in self?.failAll("Codex se desconectó."); self?.event?("connection/closed",[:]) } }
        try p.run()
        _ = try await request("initialize",["clientInfo":["name":"daily_office","title":"Daily Office","version":"1.0.0"]])
        try send(["method":"initialized","params":[:]])
    }
    func request(_ method: String, _ params: [String:Any]) async throws -> [String:Any] {
        counter += 1; let id = counter
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            do { try send(["id":id,"method":method,"params":params]) } catch { pending.removeValue(forKey:id)?.resume(throwing:error) }
            Task { [weak self] in
                try? await Task.sleep(for:.seconds(45))
                self?.pending.removeValue(forKey:id)?.resume(throwing:OfficeError(message:"Codex no respondió a \(method)."))
            }
        }
    }
    private func send(_ object: [String:Any]) throws {
        guard let input else { throw OfficeError(message:"Codex no está conectado.") }
        var data = try JSONSerialization.data(withJSONObject:object); data.append(10); try input.write(contentsOf:data)
    }
    private func receive(_ data: Data) {
        buffer.append(data)
        while let end = buffer.firstIndex(of:10) {
            let line = buffer[..<end]; buffer.removeSubrange(...end)
            guard let o = try? JSONSerialization.jsonObject(with:line) as? [String:Any] else { continue }
            if let method = o["method"] as? String {
                let params = o["params"] as? [String:Any] ?? [:]
                if let id = o["id"] {
                    if method == "item/tool/requestUserInput" {
                        try? send(["id":id,"result":userInput?(params) ?? ["answers":[:]]])
                    } else if method.contains("requestApproval") {
                        let accepted = approval?(method,params) ?? false
                        try? send(["id":id,"result":["decision":accepted ? "accept" : "decline"]])
                    } else {
                        try? send(["id":id,"error":["code":-32601,"message":"Solicitud no compatible con Daily Office"]])
                    }
                } else { event?(method,params) }
            } else if let id = o["id"] as? Int, let c = pending.removeValue(forKey:id) {
                if let error = o["error"] as? [String:Any] { c.resume(throwing:OfficeError(message:error["message"] as? String ?? "Error de Codex")) }
                else { c.resume(returning:o["result"] as? [String:Any] ?? [:]) }
            }
        }
    }
    func close() { process?.terminate(); process = nil; input = nil; failAll("Conexión detenida.") }
    private func failAll(_ message: String) { let all = pending; pending.removeAll(); for c in all.values { c.resume(throwing:OfficeError(message:message)) } }
}

struct APIClient {
    static func reply(agent: Agent, system: String, messages: [Message]) async throws -> String {
        let key = Vault.read(agent.credentialScope == "brain" ? "\(agent.id).brain" : agent.id)
        guard !agent.model.isEmpty else { throw OfficeError(message:"Elige un modelo en la configuración del agente.") }
        let anthropic = agent.provider == "Anthropic"
        let base = agent.endpoint.isEmpty ? (anthropic ? "https://api.anthropic.com/v1" : agent.provider == "NVIDIA" ? "https://integrate.api.nvidia.com/v1" : agent.provider == "xAI" ? "https://api.x.ai/v1" : agent.provider == "Gemini" ? "https://generativelanguage.googleapis.com/v1beta/openai" : "https://api.openai.com/v1") : agent.endpoint
        guard let url = URL(string:base.trimmingCharacters(in:CharacterSet(charactersIn:"/")) + (anthropic ? "/messages" : "/chat/completions")), ["https","http"].contains(url.scheme ?? "") else { throw OfficeError(message:"Endpoint inválido.") }
        if url.scheme == "http" && !["localhost","127.0.0.1","::1"].contains(url.host ?? "") { throw OfficeError(message:"Usa HTTPS para conexiones remotas.") }
        var request = URLRequest(url:url); request.httpMethod = "POST"; request.timeoutInterval = 180
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        if anthropic { request.setValue(key,forHTTPHeaderField:"x-api-key"); request.setValue("2023-06-01",forHTTPHeaderField:"anthropic-version") }
        else if !key.isEmpty { request.setValue("Bearer \(key)",forHTTPHeaderField:"Authorization") }
        var rows: [[String:Any]] = []
        if !anthropic { rows.append(["role":"system","content":system]) }
        for m in messages where m.role == "user" || m.role == "assistant" {
            var content: [[String:Any]] = [["type":"text","text":m.text.isEmpty ? "Analiza esta imagen." : m.text]]
            if let image = m.image, let data = try? Data(contentsOf:URL(fileURLWithPath:image)) {
                guard agent.vision else { throw OfficeError(message:"Activa un modelo con visión para analizar la captura.") }
                let b64 = data.base64EncodedString()
                content.append(anthropic ? ["type":"image","source":["type":"base64","media_type":"image/png","data":b64]] : ["type":"image_url","image_url":["url":"data:image/png;base64,\(b64)"]])
            }
            rows.append(["role":m.role,"content":content])
        }
        var body: [String:Any] = ["model":agent.model,"messages":rows]
        if anthropic { body["system"] = system; body["max_tokens"] = 8192 }
        request.httpBody = try JSONSerialization.data(withJSONObject:body)
        let (data,response) = try await URLSession.shared.data(for:request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let json = try? JSONSerialization.jsonObject(with:data) as? [String:Any]
            let detail = (json?["error"] as? [String:Any])?["message"] as? String ?? String(data:data,encoding:.utf8)?.prefix(500).description ?? "Sin respuesta"
            throw OfficeError(message:"Proveedor: \(detail)")
        }
        let json = try JSONSerialization.jsonObject(with:data) as? [String:Any] ?? [:]
        if anthropic { return (json["content"] as? [[String:Any]] ?? []).compactMap { $0["text"] as? String }.joined(separator:"\n") }
        guard let choices = json["choices"] as? [[String:Any]], let message = choices.first?["message"] as? [String:Any], let content = message["content"] as? String else { throw OfficeError(message:"El proveedor no devolvió texto compatible.") }
        return content
    }
}
