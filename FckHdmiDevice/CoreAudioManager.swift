import Foundation
import CoreAudio
import AudioToolbox

struct AudioDevice {
    let id: AudioDeviceID
    let name: String
    let isInput: Bool
    let isOutput: Bool
    let isDefault: Bool
}

class CoreAudioManager {

    func getOutputDevices() -> [AudioDevice] {
        return getDevices(isInput: false)
    }

    func getInputDevices() -> [AudioDevice] {
        return getDevices(isInput: true)
    }

    func setDefaultOutput(_ deviceID: AudioDeviceID) {
        setDefaultDevice(deviceID, isInput: false)
    }

    func setDefaultInput(_ deviceID: AudioDeviceID) {
        setDefaultDevice(deviceID, isInput: true)
    }

    // MARK: - Internals

    private func getDevices(isInput: Bool) -> [AudioDevice] {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )

        // device id list size
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                       &address, 0, nil, &size)

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array(repeating: AudioDeviceID(0), count: count)

        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                   &address, 0, nil, &size, &deviceIDs)

        // find default device
        let defaultDevice = getDefaultDevice(isInput: isInput)

        var list: [AudioDevice] = []

        for id in deviceIDs {
            if let dev = buildDevice(id, isInput: isInput, defaultID: defaultDevice) {
                list.append(dev)
            }
        }

        return list
    }

    private func buildDevice(_ id: AudioDeviceID,
                             isInput: Bool,
                             defaultID: AudioDeviceID) -> AudioDevice? {

        // name
        var name: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)

        var addrName = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )

        if AudioObjectGetPropertyData(id, &addrName, 0, nil, &nameSize, &name) != noErr {
            return nil
        }

        let hasOutput = deviceHasStreams(id, scope: kAudioDevicePropertyScopeOutput)
        let hasInput = deviceHasStreams(id, scope: kAudioDevicePropertyScopeInput)

        if isInput && !hasInput { return nil }
        if !isInput && !hasOutput { return nil }

        return AudioDevice(id: id,
                           name: name as String,
                           isInput: hasInput,
                           isOutput: hasOutput,
                           isDefault: id == defaultID)
    }

    private func deviceHasStreams(_ id: AudioDeviceID,
                                  scope: AudioObjectPropertyScope) -> Bool {

        var size: UInt32 = 0
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: 0
        )

        let status = AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size)
        return (status == noErr && size > 0)
    }

    private func getDefaultDevice(isInput: Bool) -> AudioDeviceID {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        var addr = AudioObjectPropertyAddress(
            mSelector: isInput ?
                kAudioHardwarePropertyDefaultInputDevice :
                kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr, 0, nil, &size, &id
        )

        return id
    }

    private func setDefaultDevice(_ id: AudioDeviceID, isInput: Bool) {
        var dev = id
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        var addr = AudioObjectPropertyAddress(
            mSelector: isInput ?
                kAudioHardwarePropertyDefaultInputDevice :
                kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )

        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                   &addr, 0, nil, size, &dev)
    }
}
