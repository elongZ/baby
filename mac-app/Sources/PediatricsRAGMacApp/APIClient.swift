import Foundation

struct APIClient {
    let baseURL: URL

    func health() async throws -> HealthResponse {
        let (data, response) = try await URLSession.shared.data(from: baseURL.appending(path: "health"))
        try validate(response: response, data: data)
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }

    func ask(_ request: AskRequest) async throws -> AskResponse {
        var components = URLComponents(url: baseURL.appending(path: "ask"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            .init(name: "question", value: request.question),
            .init(name: "top_k", value: String(request.topK)),
            .init(name: "retrieve_k", value: String(request.retrieveK)),
            .init(name: "relevance_threshold", value: String(format: "%.2f", request.relevanceThreshold)),
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(AskResponse.self, from: data)
    }

    func documents() async throws -> [DocumentRecord] {
        let (data, response) = try await URLSession.shared.data(from: baseURL.appending(path: "admin/documents"))
        try validate(response: response, data: data)
        return try JSONDecoder().decode(DocumentsResponse.self, from: data).documents
    }

    func indexStatus() async throws -> VectorIndexStatus {
        let (data, response) = try await URLSession.shared.data(from: baseURL.appending(path: "admin/index/status"))
        try validate(response: response, data: data)
        return try JSONDecoder().decode(VectorIndexStatus.self, from: data)
    }

    func importDocument(sourcePath: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: "admin/documents/import"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ImportDocumentRequest(sourcePath: sourcePath))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    func deleteDocument(id: String) async throws {
        guard let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: baseURL.appending(path: "admin/documents/\(encoded)"))
        request.httpMethod = "DELETE"
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    func replaceDocument(id: String, sourcePath: String) async throws {
        guard let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: baseURL.appending(path: "admin/documents/\(encoded)/replace"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ReplaceDocumentRequest(sourcePath: sourcePath))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    func rebuildIndex() async throws -> VectorIndexStatus {
        var request = URLRequest(url: baseURL.appending(path: "admin/index/rebuild"))
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(VectorIndexStatus.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "unknown error"
            throw NSError(domain: "PediatricsRAGMacApp", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: body
            ])
        }
    }
}
