import AVFoundation

@MainActor
protocol DJIwphoneAudioSessionControlling: AnyObject {
    func activate() throws
    func deactivate()
}

@MainActor
final class DefaultDJIwphoneAudioSession: DJIwphoneAudioSessionControlling {
    func activate() throws {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
        try audio.setActive(true)
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
