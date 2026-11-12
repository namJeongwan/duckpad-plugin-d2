import Foundation

@MainActor final class D2Connection {
    private var connection: NSXPCConnection?
    private var pending: D2Continuation?
    private var timer: Task<Void, Never>?
    func render(_ request: D2Request) async throws -> Data {
        try Task.checkCancellation()
        close()
        let frame = try JSONEncoder().encode(request)
        guard frame.count <= D2Request.maximumFrameBytes else { throw NSError(domain: "D2", code: 1) }
        let app = Bundle.main.bundleURL
        let helper = app.appendingPathComponent("Contents/XPCServices/DuckpadNativeInstaller.xpc")
        let connection = NSXPCConnection(serviceName: NativeInstallerXPC.identifier)
        connection.setCodeSigningRequirement(try NativeInstallerXPC.requirement(for: helper, matchingSignerOf: app))
        connection.remoteObjectInterface = NSXPCInterface(with: DuckpadNativeInstallerProtocol.self)
        self.connection = connection
        defer { if self.connection === connection { close() } }
        return try await withCheckedThrowingContinuation { continuation in
            let reply = D2Continuation(continuation)
            pending = reply
            connection.invalidationHandler = { reply.finish(.failure(CancellationError())) }
            connection.interruptionHandler = { reply.finish(.failure(CancellationError())) }
            connection.resume()
            timer = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(300)) } catch { return }
                if self?.pending === reply { reply.finish(.failure(DiagramFailure("timeout"))); self?.close() }
            }
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in reply.finish(.failure(error)) }) as? DuckpadNativeInstallerProtocol else {
                reply.finish(.failure(NSError(domain: "D2", code: 2))); return
            }
            proxy.renderD2(frame) { data, error in
                if let data { reply.finish(.success(data)) }
                else {
                    var code = "renderFailed", detail = ""
                    if let error, let bytes = error.data(using: .utf8), let payload = try? JSONDecoder().decode([String: String].self, from: bytes) {
                        code = payload["code"] ?? code; detail = payload["detail"] ?? ""
                    } else if let error { code = error }
                    reply.finish(.failure(DiagramFailure(code, detail)))
                }
            }
        }
    }
    func close() { timer?.cancel(); timer = nil; pending?.finish(.failure(CancellationError())); pending = nil; connection?.invalidate(); connection = nil }
}
