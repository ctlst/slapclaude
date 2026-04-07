import AppKit
import AVFoundation
import CoreAudio
import Foundation

// Detects slaps by listening for sharp audio transients via the built-in microphone.
// Pins the input to the built-in mic so headphones don't redirect to a weaker mic.
final class AudioSlapDetector {
    var onSlap: (() -> Void)?
    var sensitivity: Sensitivity = .medium

    private var engine: AVAudioEngine?
    private var configChangeObserver: Any?
    private var baseline: Float = 0.0
    private var lastSlapTime: Date = .distantPast
    private let debounce: TimeInterval = 0.6
    private let emaAlpha: Float = 0.05

    func requestPermissionAndStart(completion: @escaping (Bool) -> Void) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
                log("Mic permission granted: \(granted)")
                if granted { self?.startEngine() }
                completion(granted)
            }
        }
    }

    func stop() {
        if let obs = configChangeObserver {
            NotificationCenter.default.removeObserver(obs)
            configChangeObserver = nil
        }
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }

    var permissionStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    // MARK: - Private

    private func startEngine() {
        let eng = AVAudioEngine()

        // Pin to built-in mic using the Swift AUAudioUnit API (safer than C AudioUnit API).
        if let deviceID = builtInMicDeviceID() {
            do {
                try eng.inputNode.auAudioUnit.setDeviceID(deviceID)
                log("Pinned built-in mic device id=\(deviceID)")
            } catch {
                log("Could not pin built-in mic: \(error)")
            }
        } else {
            log("Built-in mic not found — using system default")
        }

        let format = eng.inputNode.inputFormat(forBus: 0)
        log("Audio format: \(format.sampleRate)Hz \(format.channelCount)ch")

        eng.inputNode.installTap(onBus: 0, bufferSize: 128, format: format) { [weak self] buffer, _ in
            self?.process(buffer)
        }

        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: eng,
            queue: .main
        ) { [weak self] _ in
            log("Audio route changed — restarting engine")
            // Async so we're not restarting from within the notification itself.
            DispatchQueue.main.async { self?.stop(); self?.startEngine() }
        }

        do {
            try eng.start()
            engine = eng
            log("Audio engine started OK")
        } catch {
            log("Audio engine failed: \(error)")
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }

        var sum: Float = 0
        for i in 0..<count { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(count))

        let spike = rms - baseline

        if spike > sensitivity.audioThreshold {
            let now = Date()
            if now.timeIntervalSince(lastSlapTime) > debounce {
                lastSlapTime = now
                log("SLAP DETECTED")
                DispatchQueue.main.async { self.onSlap?() }
            }
        }

        if spike < sensitivity.audioThreshold {
            baseline = emaAlpha * rms + (1 - emaAlpha) * baseline
        }
    }

    // MARK: - Find built-in mic via CoreAudio

    private func builtInMicDeviceID() -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return nil }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return nil }

        for id in ids {
            var inputAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain)
            var inputSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(id, &inputAddr, 0, nil, &inputSize)
            guard inputSize > 0 else { continue }

            var transportAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var transport: UInt32 = 0
            var transportSize = UInt32(MemoryLayout<UInt32>.size)
            AudioObjectGetPropertyData(id, &transportAddr, 0, nil, &transportSize, &transport)

            if transport == kAudioDeviceTransportTypeBuiltIn { return id }
        }
        return nil
    }
}
