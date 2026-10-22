import SwiftUI

struct Skill: Codable, Identifiable, Equatable {
    var id = UUID(); var name: String; var content: String; var source: String; var enabled = true
}
struct Message: Codable, Identifiable {
    var id = UUID(); var role: String; var text: String; var date = Date(); var image: String? = nil
}
struct Agent: Codable, Identifiable {
    var id: String; var name: String; var symbol: String; var hex: String; var specialty: String
    var enabled = true; var provider = "Codex"; var model = ""; var endpoint = ""
    // Configuración opcional para conservar historiales creados antes de separar Cerebro y Constructor.
    var brainProvider: String? = "Codex"; var brainModel: String? = ""; var brainEndpoint: String? = ""; var credentialScope: String? = nil
    var prompt = ""; var memory = ""; var skills: [Skill] = []; var messages: [Message] = []
    var vision = true; var allowWrites = false
    var color: Color { Color(nsColor: NSColor(srgbRed: Double(Int(hex.prefix(2), radix: 16) ?? 0)/255, green: Double(Int(hex.dropFirst(2).prefix(2), radix: 16) ?? 0)/255, blue: Double(Int(hex.suffix(2), radix: 16) ?? 0)/255, alpha: 1)) }
    static var defaults: [Agent] {
        let specs = [
            ("ceo","CEO","point.3.connected.trianglepath.dotted","777780","Coordina objetivos, divide tareas, asigna especialistas y evalúa entregas con criterios verificables."),
            ("marketing","Marketing","megaphone","D88C41","Investiga audiencia y competencia, redacta contenido, define posicionamiento, campañas y métricas. No inventes datos ni publiques sin autorización."),
            ("developer","Desarrollador","chevron.left.forwardslash.chevron.right","598ACC","Construye software mantenible. Especialista en Swift, SwiftUI, AppKit, concurrencia, almacenamiento e integración de APIs. Verifica cambios con compilación y pruebas relevantes."),
            ("creative","Creativo","wand.and.stars","C97676","Programa prototipos, animaciones e interacciones expresivas y accesibles. Respeta la identidad visual del proyecto y reduce movimiento cuando corresponda."),
            ("qa","Chequeador","checkmark.shield","699C82","Revisa requisitos, código, accesibilidad, seguridad y regresiones. Reporta evidencias, pasos de reproducción y severidad. No declares pruebas aprobadas sin ejecutarlas."),
            ("design","Diseñador","square.on.circle","9A85BD","Diseña navegación, tipografía, composición y sistemas visuales. Analiza capturas y propone mejoras concretas. Para macOS usa convenciones nativas y accesibilidad."),
            ("writer","Redactor","doc.richtext","C86A8B","Escribe y edita documentos, propuestas, informes, guiones y textos listos para PDF. Organiza ideas, adapta la voz y revisa claridad, tono, gramática y consistencia.")
        ]
        return specs.map { id,name,symbol,hex,specialty in
            var a = Agent(id:id,name:name,symbol:symbol,hex:hex,specialty:specialty)
            a.skills = [Skill(name:"Método de \(name)",content: specialty + "\nAntes de actuar identifica el objetivo y las restricciones. Entrega resultados concretos y señala incertidumbres. Revisa el resultado contra el pedido. Usa español salvo que se solicite otro idioma.",source:"Daily Office · 1.0")]
            if id == "writer" { a.skills.append(Skill(name:"Escritura documental",content:"Redacta con voz natural, precisa y original. Antes de escribir identifica audiencia, propósito, tono, extensión y formato. Usa títulos informativos, párrafos con ritmo variado y transiciones claras. Evita frases genéricas, repeticiones y afirmaciones sin fuente. Para informes y PDFs separa resumen, desarrollo, conclusiones y referencias; marca los datos que deban verificarse. No prometas evadir detectores ni imites la voz de una persona real: busca calidad, trazabilidad y una voz coherente.",source:"Daily Office · Escritura")) }
            return a
        }
    }
}
struct OfficeData: Codable {
    var agents = Agent.defaults; var theme = "Automático"; var projectPath = ""; var context = ""
    var bundledSkillsVersion: Int? = nil
    var dockSize = "Normal"
    var dockEnabled = true
    var projects: [ProjectRecord] = []
    var paused = false; var openAgents: [String] = []; var codexPath = CodexLocator.detect()
}
struct ProjectRecord: Codable, Identifiable, Equatable {
    var id = UUID(); var name: String; var path: String; var lastOpened = Date(); var imagePath: String?
}
enum CodexLocator {
    /// Lugares habituales de la CLI de Codex: Homebrew (Apple Silicon e Intel), npm global y carpetas de usuario.
    static var candidates: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["/opt/homebrew/bin/codex", "/usr/local/bin/codex", "\(home)/.npm-global/bin/codex", "\(home)/.local/bin/codex", "\(home)/.bun/bin/codex"]
    }
    static func detect() -> String {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? candidates[0]
    }
    /// Si la ruta guardada ya no existe (por ejemplo, la de una instalación anterior), busca otra.
    static func resolve(_ saved: String) -> String {
        FileManager.default.isExecutableFile(atPath: saved) ? saved : detect()
    }
}
struct OfficeError: LocalizedError { var message: String; var errorDescription: String? { message } }
struct Delegation: Codable { var agent: String; var task: String }
struct CEOPlan: Codable { var summary: String; var tasks: [Delegation] }
struct ActivityEvent: Identifiable {
    let id = UUID(); let date = Date(); let agent: String; let kind: String; let detail: String
}
