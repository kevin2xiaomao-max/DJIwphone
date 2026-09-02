import Foundation

enum GatewayAudioEventType: String, Codable, Sendable {
    case incoming = "call.incoming"
    case ringing = "call.ringing"
    case answered = "call.answered"
    case ended = "call.ended"
    case start = "audio.session.start"
    case ready = "audio.session.ready"
    case error = "audio.session.error"
    case stop = "audio.session.stop"
}

struct GatewayAudioPacket: Codable, Equatable, Sendable {
    let sessionID: String
    let sequence: UInt64
    let timestampNanoseconds: UInt64
    let sampleRate: Int
    let channels: Int
    let pcmBase64: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id", sequence
        case timestampNanoseconds = "timestamp_ns"
        case sampleRate = "sample_rate", channels
        case pcmBase64 = "pcm_base64"
    }
}
