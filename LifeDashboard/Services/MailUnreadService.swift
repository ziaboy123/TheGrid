import Foundation
import Network

enum MailUnreadError: LocalizedError {
    case connectionFailed
    case loginFailed
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .connectionFailed: return "Couldn't connect to the mail server."
        case .loginFailed: return "Login failed — check the email and app password."
        case .unexpectedResponse: return "Got an unexpected response from the mail server."
        }
    }
}

/// A hand-rolled IMAP client that does exactly one thing: log in and ask for
/// the unread count via STATUS. Deliberately not a full mail library — the
/// app needs one IMAP verb, not a client's worth of protocol surface.
actor MailUnreadService {
    func fetchUnreadCount(email: String, appPassword: String, provider: MailProvider) async throws -> Int {
        guard let port = NWEndpoint.Port(rawValue: provider.imapPort) else {
            throw MailUnreadError.connectionFailed
        }
        let connection = NWConnection(
            host: NWEndpoint.Host(provider.imapHost),
            port: port,
            using: .tls
        )
        connection.start(queue: .global(qos: .userInitiated))
        defer { connection.cancel() }

        try await waitForReady(connection)
        _ = try await receiveChunk(connection) // server greeting

        try await send(connection, "a1 LOGIN \(quote(email)) \(quote(appPassword))\r\n")
        let loginResponse = try await readUntilTagged(connection, tag: "a1")
        guard loginResponse.contains("a1 OK") else { throw MailUnreadError.loginFailed }

        try await send(connection, "a2 STATUS INBOX (UNSEEN)\r\n")
        let statusResponse = try await readUntilTagged(connection, tag: "a2")
        guard statusResponse.contains("a2 OK"), let count = Self.parseUnseenCount(from: statusResponse) else {
            throw MailUnreadError.unexpectedResponse
        }

        try? await send(connection, "a3 LOGOUT\r\n")
        return count
    }

    private func quote(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private func waitForReady(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                // The handler stays installed for the connection's whole lifetime and
                // fires on every later transition too (e.g. our own .cancel() at the
                // end of fetchUnreadCount) — only the FIRST relevant transition may
                // resume this continuation, so clear the handler immediately.
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    continuation.resume()
                case .failed(let error):
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                case .cancelled:
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: MailUnreadError.connectionFailed)
                default:
                    break
                }
            }
        }
    }

    private func send(_ connection: NWConnection, _ text: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: text.data(using: .utf8), completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func readUntilTagged(_ connection: NWConnection, tag: String) async throws -> String {
        var buffer = ""
        while !buffer.contains("\(tag) OK") && !buffer.contains("\(tag) NO") && !buffer.contains("\(tag) BAD") {
            buffer += try await receiveChunk(connection)
        }
        return buffer
    }

    private func receiveChunk(_ connection: NWConnection) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, let text = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: MailUnreadError.unexpectedResponse)
                    return
                }
                continuation.resume(returning: text)
            }
        }
    }

    private static func parseUnseenCount(from response: String) -> Int? {
        guard let range = response.range(of: "UNSEEN") else { return nil }
        var digits = ""
        for char in response[range.upperBound...] {
            if char.isNumber {
                digits.append(char)
            } else if !digits.isEmpty {
                break
            } else if char != " " {
                break
            }
        }
        return Int(digits)
    }
}
