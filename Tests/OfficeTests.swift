import XCTest
@testable import DailyOfficeCore

final class OfficeTests: XCTestCase {
    @MainActor func testPersistenceAndAgentIsolation() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = OfficeStore(directory:dir)
        store.append("marketing",Message(role:"user",text:"Mensaje privado"))
        var qa = store.agent("qa"); qa.prompt = "Comprueba evidencia"; qa.memory = "Proyecto nativo"; qa.skills[0].enabled = false; store.update(qa)
        let restored = OfficeStore(directory:dir)
        XCTAssertEqual(restored.agent("marketing").messages.count,1)
        XCTAssertTrue(restored.agent("qa").messages.isEmpty)
        XCTAssertEqual(restored.agent("qa").prompt,"Comprueba evidencia")
        XCTAssertFalse(restored.instructions(restored.agent("qa")).contains("## Método de"))
        XCTAssertTrue(restored.instructions(restored.agent("qa")).contains("Proyecto nativo"))
    }
    @MainActor func testPausedAndDisabledAgentsDoNotStart() async throws {
        let store = OfficeStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        store.data.paused = true; store.send("qa",content:"No enviar")
        XCTAssertTrue(store.agent("qa").messages.isEmpty)
        do { _ = try await store.respond("qa"); XCTFail("Paused agent ran") } catch { }
        store.data.paused = false; var a = store.agent("qa"); a.enabled = false; store.update(a)
        store.send("qa",content:"No enviar"); XCTAssertTrue(store.agent("qa").messages.isEmpty)
    }
    @MainActor func testDamagedHistoryPreserved() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        try Data("damaged".utf8).write(to:dir.appendingPathComponent("office.json"))
        let store = OfficeStore(directory:dir); store.save()
        let files = try FileManager.default.contentsOfDirectory(atPath:dir.path)
        XCTAssertTrue(files.contains(where:{$0.hasPrefix("office-recovery-")}))
    }
    @MainActor func testCodexTransportAndReply() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        let executable = dir.appendingPathComponent("mock-codex")
        let script = """
        #!/usr/bin/python3
        import sys,json
        for line in sys.stdin:
            m=json.loads(line); method=m.get('method'); i=m.get('id')
            if i is None: continue
            result={}
            if method=='thread/start': result={'thread':{'id':'thread-test'}}
            print(json.dumps({'id':i,'result':result}),flush=True)
            if method=='turn/start':
                print(json.dumps({'method':'item/agentMessage/delta','params':{'delta':'Respuesta verificada'}}),flush=True)
                print(json.dumps({'method':'turn/completed','params':{'turn':{'status':'completed'}}}),flush=True)
        """
        try script.write(to:executable,atomically:true,encoding:.utf8)
        try FileManager.default.setAttributes([.posixPermissions:0o755],ofItemAtPath:executable.path)
        let store = OfficeStore(directory:dir); store.data.codexPath = executable.path
        store.append("qa",Message(role:"user",text:"Test"))
        let reply = try await store.respond("qa")
        XCTAssertEqual(reply,"Respuesta verificada")
        XCTAssertEqual(store.agent("qa").messages.last?.text,reply)
        XCTAssertFalse(store.busy.contains("qa"))
    }
}

extension OfficeTests {
    @MainActor func testCEODelegationAndSummary() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        let executable = dir.appendingPathComponent("mock-team")
        let script = """
        #!/usr/bin/python3
        import sys,json
        system=''
        for line in sys.stdin:
            m=json.loads(line);method=m.get('method');i=m.get('id');params=m.get('params',{})
            if i is None:continue
            result={}
            if method=='thread/start':
                result={'thread':{'id':'test'}};system=params.get('developerInstructions','')
            print(json.dumps({'id':i,'result':result}),flush=True)
            if method=='turn/start':
                output=json.dumps({'summary':'Revisar','tasks':[{'agent':'qa','task':'Comprueba los requisitos'}]}) if 'Devuelve SOLO JSON' in system else 'Entrega revisada'
                print(json.dumps({'method':'item/agentMessage/delta','params':{'delta':output}}),flush=True)
                print(json.dumps({'method':'turn/completed','params':{'turn':{'status':'completed'}}}),flush=True)
        """
        try script.write(to:executable,atomically:true,encoding:.utf8);try FileManager.default.setAttributes([.posixPermissions:0o755],ofItemAtPath:executable.path)
        let store = OfficeStore(directory:dir);store.data.codexPath = executable.path
        store.coordinate("Revisa el proyecto")
        for _ in 0..<100 where store.coordinating { try await Task.sleep(for:.milliseconds(100)) }
        XCTAssertFalse(store.coordinating)
        XCTAssertTrue(store.agent("qa").messages.contains { $0.text.contains("Encargo del CEO") })
        XCTAssertEqual(store.agent("ceo").messages.last?.text,"Entrega revisada")
        XCTAssertTrue(store.agent("marketing").messages.isEmpty)
    }
    func testRemotePlainHTTPRejected() async throws {
        var a = Agent.defaults[0];a.provider = "Compatible";a.model = "test";a.endpoint = "http://example.com/v1"
        do { _ = try await APIClient.reply(agent:a,system:"test",messages:[]);XCTFail("Remote HTTP accepted") }
        catch { XCTAssertTrue(error.localizedDescription.contains("HTTPS")) }
    }
}
