import Foundation

@MainActor
protocol DJIwphonePeerConnection: AnyObject {
    func close()
}

@MainActor
final class CallMediaCoordinator {
    private let audio: DJIwphoneAudioSessionControlling
    private let peer: DJIwphonePeerConnection
    private var activeCallID: String?
    private var started = false

    init(audio: DJIwphoneAudioSessionControlling, peer: DJIwphonePeerConnection) {
        self.audio = audio
        self.peer = peer
    }

    func start(callID: String) throws {
        guard activeCallID == nil else { return }
        try audio.activate()
        activeCallID = callID
        started = true
    }

    func stop(callID: String) {
        guard activeCallID == callID, started else { return }
        peer.close()
        audio.deactivate()
        activeCallID = nil
        started = false
    }

    func fail(callID: String) {
        stop(callID: callID)
    }
}
