import Foundation
import SQLite3

final class TrainingDataStore {
    private let databaseURL: URL
    private let snapshotURL: URL
    private let datasetURL: URL
    private var db: OpaquePointer?

    init(projectRoot: URL) throws {
        let dataDir = projectRoot.appendingPathComponent("data", isDirectory: true)
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        databaseURL = dataDir.appendingPathComponent("training_data.sqlite3")
        snapshotURL = dataDir.appendingPathComponent("sft_annotations.done.jsonl")
        datasetURL = dataDir.appendingPathComponent("sft_train.jsonl")

        if sqlite3_open(databaseURL.path, &db) != SQLITE_OK {
            defer { sqlite3_close(db) }
            throw storeError(message: "无法打开 training SQLite 数据库。")
        }

        try executeScript(Self.schemaSQL)
        try bootstrapFromSnapshotIfNeeded()
    }

    deinit {
        sqlite3_close(db)
    }

    var databasePath: String { databaseURL.path }
    var snapshotPath: String { snapshotURL.path }
    var datasetPath: String { datasetURL.path }

    func fetchSamples(status: TrainingSampleStatus? = nil, search: String = "") throws -> [TrainingSample] {
        var sql = """
        SELECT sample_id, question, mode, annotation_guideline, contexts_json, answer,
               annotation_notes, status, source_type, created_at, updated_at, deleted_at, version
        FROM training_samples
        WHERE deleted_at IS NULL
        """
        var bindings: [SQLiteValue] = []

        if let status {
            sql += " AND status = ?"
            bindings.append(.text(status.rawValue))
        }

        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            sql += " AND (sample_id LIKE ? OR question LIKE ?)"
            let wildcard = "%\(trimmed)%"
            bindings.append(.text(wildcard))
            bindings.append(.text(wildcard))
        }

        sql += " ORDER BY CAST(SUBSTR(sample_id, 5) AS INTEGER) DESC, updated_at DESC"
        let rows = try query(sql, bindings: bindings)
        return try rows.map(Self.sample(from:))
    }

    func createSample() throws -> TrainingSample {
        let timestamp = Self.utcNow()
        let sampleID = try nextSampleID()
        let sample = TrainingSample(
            sampleID: sampleID,
            question: "",
            mode: .groundedAnswer,
            annotationGuideline: TrainingSample.annotationGuidelineTemplate,
            contexts: [],
            answer: "",
            annotationNotes: "",
            status: .draft,
            sourceType: "manual",
            createdAt: timestamp,
            updatedAt: timestamp,
            deletedAt: nil,
            version: 1
        )
        try saveSample(sample, isNew: true)
        return sample
    }

    func duplicateSample(sampleID: String) throws -> TrainingSample {
        let original = try fetchSample(sampleID: sampleID)
        var duplicate = original
        let timestamp = Self.utcNow()
        duplicate = TrainingSample(
            sampleID: try nextSampleID(),
            question: original.question,
            mode: original.mode,
            annotationGuideline: original.annotationGuideline,
            contexts: original.contexts,
            answer: original.answer,
            annotationNotes: original.annotationNotes,
            status: .draft,
            sourceType: "duplicate",
            createdAt: timestamp,
            updatedAt: timestamp,
            deletedAt: nil,
            version: 1
        )
        try saveSample(duplicate, isNew: true)
        return duplicate
    }

    func fetchSample(sampleID: String) throws -> TrainingSample {
        let rows = try query(
            """
            SELECT sample_id, question, mode, annotation_guideline, contexts_json, answer,
                   annotation_notes, status, source_type, created_at, updated_at, deleted_at, version
            FROM training_samples
            WHERE sample_id = ? AND deleted_at IS NULL
            LIMIT 1
            """,
            bindings: [.text(sampleID)]
        )

        guard let row = rows.first else {
            throw storeError(message: "找不到样本 \(sampleID)。")
        }
        return try Self.sample(from: row)
    }

    func saveSample(_ sample: TrainingSample, isNew: Bool = false) throws {
        let timestamp = Self.utcNow()
        let contextsData = try JSONEncoder().encode(sample.contexts)
        guard let contextsJSON = String(data: contextsData, encoding: .utf8) else {
            throw storeError(message: "无法序列化 contexts。")
        }

        if isNew {
            try execute(
                """
                INSERT INTO training_samples (
                    sample_id, question, mode, annotation_guideline, contexts_json, answer,
                    annotation_notes, status, source_type, created_at, updated_at, deleted_at, version
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?)
                """,
                bindings: [
                    .text(sample.sampleID),
                    .text(sample.question),
                    .text(sample.mode.rawValue),
                    .text(sample.annotationGuideline),
                    .text(contextsJSON),
                    .text(sample.answer),
                    .text(sample.annotationNotes),
                    .text(sample.status.rawValue),
                    .text(sample.sourceType),
                    .text(sample.createdAt),
                    .text(timestamp),
                    .int(Int64(sample.version)),
                ]
            )
        } else {
            try execute(
                """
                UPDATE training_samples
                SET question = ?, mode = ?, annotation_guideline = ?, contexts_json = ?,
                    answer = ?, annotation_notes = ?, status = ?, updated_at = ?,
                    deleted_at = NULL, version = version + 1
                WHERE sample_id = ?
                """,
                bindings: [
                    .text(sample.question),
                    .text(sample.mode.rawValue),
                    .text(sample.annotationGuideline),
                    .text(contextsJSON),
                    .text(sample.answer),
                    .text(sample.annotationNotes),
                    .text(sample.status.rawValue),
                    .text(timestamp),
                    .text(sample.sampleID),
                ]
            )
        }
    }

    func softDeleteSample(sampleID: String) throws {
        try execute(
            "UPDATE training_samples SET deleted_at = ?, updated_at = ? WHERE sample_id = ?",
            bindings: [.text(Self.utcNow()), .text(Self.utcNow()), .text(sampleID)]
        )
    }

    private func nextSampleID() throws -> String {
        let rows = try query(
            """
            SELECT COALESCE(MAX(CAST(SUBSTR(sample_id, 5) AS INTEGER)), 0) AS next_value
            FROM training_samples
            WHERE sample_id LIKE 'sft-%'
            """
        )
        let current = rows.first?["next_value"] as? Int64 ?? 0
        return String(format: "sft-%04d", current + 1)
    }

    private func bootstrapFromSnapshotIfNeeded() throws {
        let rows = try query("SELECT COUNT(*) AS row_count FROM training_samples")
        let count = rows.first?["row_count"] as? Int64 ?? 0
        guard count == 0, FileManager.default.fileExists(atPath: snapshotURL.path) else {
            return
        }

        let decoder = JSONDecoder()
        let timestamp = Self.utcNow()
        let content = try String(contentsOf: snapshotURL, encoding: .utf8)
        for line in content.split(whereSeparator: \.isNewline) {
            let data = Data(line.utf8)
            let snapshot = try decoder.decode(TrainingSnapshotRow.self, from: data)
            let sample = TrainingSample(
                sampleID: snapshot.sampleID,
                question: snapshot.question,
                mode: snapshot.mode,
                annotationGuideline: snapshot.annotationGuideline,
                contexts: snapshot.contexts,
                answer: snapshot.answer,
                annotationNotes: snapshot.annotationNotes,
                status: snapshot.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .draft : .done,
                sourceType: "snapshot_import",
                createdAt: timestamp,
                updatedAt: timestamp,
                deletedAt: nil,
                version: 1
            )
            try saveSample(sample, isNew: true)
        }
    }

    private func executeScript(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errorPointer) != SQLITE_OK {
            let message = errorPointer.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_free(errorPointer)
            throw storeError(message: message)
        }
    }

    private func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE else {
            throw storeError(message: sqliteMessage())
        }
    }

    private func query(_ sql: String, bindings: [SQLiteValue] = []) throws -> [[String: Any?]] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)

        var output: [[String: Any?]] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                var row: [String: Any?] = [:]
                for index in 0..<sqlite3_column_count(statement) {
                    let name = String(cString: sqlite3_column_name(statement, index))
                    row[name] = Self.columnValue(statement: statement, index: index)
                }
                output.append(row)
            } else if result == SQLITE_DONE {
                break
            } else {
                throw storeError(message: sqliteMessage())
            }
        }

        return output
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw storeError(message: sqliteMessage())
        }
        return statement
    }

    private func bind(_ bindings: [SQLiteValue], to statement: OpaquePointer?) throws {
        for (index, binding) in bindings.enumerated() {
            let parameterIndex = Int32(index + 1)
            let result: Int32
            switch binding {
            case .text(let value):
                result = sqlite3_bind_text(statement, parameterIndex, value, -1, SQLITE_TRANSIENT)
            case .int(let value):
                result = sqlite3_bind_int64(statement, parameterIndex, value)
            case .null:
                result = sqlite3_bind_null(statement, parameterIndex)
            }

            guard result == SQLITE_OK else {
                throw storeError(message: sqliteMessage())
            }
        }
    }

    private func sqliteMessage() -> String {
        String(cString: sqlite3_errmsg(db))
    }

    private func storeError(message: String) -> NSError {
        NSError(domain: "TrainingDataStore", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func sample(from row: [String: Any?]) throws -> TrainingSample {
        let contextsJSON = row["contexts_json"] as? String ?? "[]"
        let contextsData = Data(contextsJSON.utf8)
        let contexts = try JSONDecoder().decode([TrainingContext].self, from: contextsData)

        return TrainingSample(
            sampleID: row["sample_id"] as? String ?? "",
            question: row["question"] as? String ?? "",
            mode: TrainingSampleMode(rawValue: row["mode"] as? String ?? "") ?? .groundedAnswer,
            annotationGuideline: row["annotation_guideline"] as? String ?? "",
            contexts: contexts,
            answer: row["answer"] as? String ?? "",
            annotationNotes: row["annotation_notes"] as? String ?? "",
            status: TrainingSampleStatus(rawValue: row["status"] as? String ?? "") ?? .draft,
            sourceType: row["source_type"] as? String ?? "manual",
            createdAt: row["created_at"] as? String ?? "",
            updatedAt: row["updated_at"] as? String ?? "",
            deletedAt: row["deleted_at"] as? String,
            version: Int(row["version"] as? Int64 ?? 1)
        )
    }

    private static func columnValue(statement: OpaquePointer?, index: Int32) -> Any? {
        let type = sqlite3_column_type(statement, index)
        switch type {
        case SQLITE_INTEGER:
            return sqlite3_column_int64(statement, index)
        case SQLITE_TEXT:
            guard let value = sqlite3_column_text(statement, index) else { return nil }
            return String(cString: value)
        case SQLITE_NULL:
            return nil
        default:
            guard let value = sqlite3_column_text(statement, index) else { return nil }
            return String(cString: value)
        }
    }

    private static func utcNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static let schemaSQL = """
    CREATE TABLE IF NOT EXISTS training_samples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sample_id TEXT NOT NULL UNIQUE,
        question TEXT NOT NULL,
        mode TEXT NOT NULL,
        annotation_guideline TEXT NOT NULL DEFAULT '',
        contexts_json TEXT NOT NULL DEFAULT '[]',
        answer TEXT NOT NULL DEFAULT '',
        annotation_notes TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'draft',
        source_type TEXT NOT NULL DEFAULT 'manual',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        version INTEGER NOT NULL DEFAULT 1,
        CHECK (mode IN ('grounded_answer', 'insufficient_evidence', 'risk_routing')),
        CHECK (status IN ('draft', 'done', 'archived'))
    );

    CREATE INDEX IF NOT EXISTS idx_training_samples_active
    ON training_samples(deleted_at, status, updated_at);
    """
}

private enum SQLiteValue {
    case text(String)
    case int(Int64)
    case null
}

private struct TrainingSnapshotRow: Codable {
    let sampleID: String
    let question: String
    let mode: TrainingSampleMode
    let annotationGuideline: String
    let contexts: [TrainingContext]
    let answer: String
    let annotationNotes: String

    enum CodingKeys: String, CodingKey {
        case sampleID = "sample_id"
        case question
        case mode
        case annotationGuideline = "annotation_guideline"
        case contexts
        case answer
        case annotationNotes = "annotation_notes"
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
