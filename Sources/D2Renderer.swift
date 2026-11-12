import Foundation

@MainActor final class D2Renderer: DiagramRendering {
    let hasRuntimeSettings = true
    private let connection = D2Connection()
    private let web = DiagramWebRenderer()
    func render(_ source: String, dark: Bool, runtimePath: String, install: Bool) async throws -> DiagramRender {
        let svg = try await connection.render(.init(source: source, executablePath: runtimePath, install: install, dark: dark))
        guard let text = String(data: svg, encoding: .utf8) else { throw DiagramFailure("renderFailed") }
        return try await web.render(kind: "svg", source: text, dark: dark)
    }
    func cancel() { connection.close(); web.cancel() }
}

@MainActor func makeDiagramPlugin(host: DuckpadHost, config: [String: String]) -> DiagramPlugin {
    DiagramPlugin(host: host, config: config, definition: .init(name: "D2", fileExtensions: ["d2"], sample: "client -> server: Ready"), renderer: D2Renderer())
}
