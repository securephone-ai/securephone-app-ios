import AVFoundation
import AudioToolbox
import UIKit
import CwlUtils
import BlackboxCore

public class VoipIOAudioManager {
    var powerMeter = PowerMeter()
    var call: BBCall?
    
    // Used for OneToOne call
    let sendAudioPacketSerialQueue = DispatchQueue(label: "sendAudioPacketSerialQueue", qos: .userInteractive)
    
    // 4 Threads used for each on the contacts of the Conference Call
    let sendAudioPacketFirstContactQueue = DispatchQueue(label: "sendAudioPacketFirstContactQueue", qos: .userInteractive)
    let sendAudioPacketSecondContactQueue = DispatchQueue(label: "sendAudioPacketSecondContactQueue", qos: .userInteractive)
    let sendAudioPacketThirdContactQueue = DispatchQueue(label: "sendAudioPacketThirdContactQueue", qos: .userInteractive)
    let sendAudioPacketFourthContactQueue = DispatchQueue(label: "sendAudioPacketFourthContactQueue", qos: .userInteractive)
    
    
    var fileURL: URL!
    
    //MARK: properties
    
    var bypassState: UInt32 = 0
    
    var inputBL: AUOutputBL!
    
    static let maxIODataSize: Int = 1920
    //  var outgoingAudioBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxIODataSize)
    var outgoingAudioBuffer: UnsafeMutablePointer<UInt8>?
    var outgoingAudioBufferOffset: Int = 0
    
    // Allocate a buffer valid for 5 minutes, as soon as it is full it will be reallocated and
    // the remaining un-read bytes from the previous buffer copied over.
    let fiveMinutes = 960000 * 5
    var incomingAudioBuffer: UnsafeMutableRawPointer?
    var incomingAudioBufferReadOffset = 0
    var incomingAudioBufferSize = 0
    
    var voiceUnit: AudioUnit?
    var voiceIOFormat = CAStreamBasicDescription(mSampleRate: 48000.0,
                                                 mFormatID: kAudioFormatLinearPCM,
                                                 mFormatFlags: kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger,
                                                 mBytesPerPacket: 2,
                                                 mFramesPerPacket: 1,
                                                 mBytesPerFrame: 2,
                                                 mChannelsPerFrame: 1,
                                                 mBitsPerChannel: 16,
                                                 mReserved: 0)
    
    //MARK:- Render Callback
    private let ReadVoiceData: AURenderCallback = { inRefCon,
                                                    ioActionFlags,
                                                    inTimeStamp,
                                                    inBusNumber,
                                                    inNumberFrames,
                                                    ioData in
        
        let This = Unmanaged<VoipIOAudioManager>.fromOpaque(inRefCon).takeUnretainedValue()
        
        var bytesToRead = This.voiceIOFormat.framesToBytes(Int(inNumberFrames))
        
        guard let call = This.call else {
            memset(ioData!.pointee.mBuffers.mData, 0, bytesToRead)
            return noErr
        }
        
        // If the call has not started, return silent
        if call.isAudioStarted == false {
            memset(ioData!.pointee.mBuffers.mData, 0, bytesToRead)
            return noErr
        }
        
        // If there is no new data, return silent
        if This.incomingAudioBufferReadOffset + Int(bytesToRead) > This.incomingAudioBufferSize {
            memset(ioData!.pointee.mBuffers.mData, 0, bytesToRead)
            return noErr
        }
        
        if let outputBuffer = This.incomingAudioBuffer {
            ioData!.pointee.mBuffers.mData = outputBuffer + This.incomingAudioBufferReadOffset
            ioData!.pointee.mBuffers.mDataByteSize = UInt32(bytesToRead)
            This.incomingAudioBufferReadOffset += Int(ioData!.pointee.mBuffers.mDataByteSize)
        }
        
        return noErr
    }
    
    //MARK:- Mic Input Callback
    private let MonitorInput: AURenderCallback = {inRefCon,
                                                  ioActionFlags,
                                                  inTimeStamp,
                                                  inBusNumber,
                                                  inNumberFrames,
                                                  ioData in
        
        let This = Unmanaged<VoipIOAudioManager>.fromOpaque(inRefCon).takeUnretainedValue()
        
        try! This.inputBL.prepare(Int(inNumberFrames))
        
        // set mData to nil, AudioUnitRender() should be allocating buffers
        var bufferList = AudioBufferList(mNumberBuffers: 1,
                                         mBuffers: AudioBuffer(mNumberChannels: UInt32(1),
                                                               mDataByteSize: 16,
                                                               mData: nil))
        
        guard let voiceUnit = This.voiceUnit else {
            loge("Input Proc - Invalid Voice Unit")
            return noErr
        }
        
        var err = AudioUnitRender(voiceUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, This.inputBL.abl!.unsafeMutablePointer)
        if err != noErr {
            loge("inputProc: error \(err)");
            return err
        }
        
        var bytesToRead = This.voiceIOFormat.framesToBytes(Int(inNumberFrames))
        
        guard let call = This.call, let outgoingAudioBuffer = This.outgoingAudioBuffer, call.isAudioStarted, let abl = This.inputBL.abl, abl.count > 0, let data = abl[0].mData else {
            return err
        }
        
        This.powerMeter.process_Int16(data.assumingMemoryBound(to: Int16.self), 1, Int(inNumberFrames))
        //      logi(This.powerMeter.averagePowerDB)
        //      logi(This.powerMeter.averagePowerLinear)
        //      logi("####")
        
        //          var uint8Ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: bytesToRead)
        //          if call.isMuted || call.isOnHold || This.powerMeter.averagePowerDB < -50 {
        //            uint8Ptr.assign(repeating: 0, count: bytesToRead)
        //          } else {
        //            uint8Ptr = data.assumingMemoryBound(to: UInt8.self)
        //          }
        
        if This.outgoingAudioBufferOffset + bytesToRead > VoipIOAudioManager.maxIODataSize {
            bytesToRead = VoipIOAudioManager.maxIODataSize - This.outgoingAudioBufferOffset
            
            // Fill the voiceData up to 320
            if call.isMuted || call.isOnHold || This.powerMeter.averagePowerDB < -50 {
                outgoingAudioBuffer.advanced(by: This.outgoingAudioBufferOffset).assign(repeating: 0, count: bytesToRead)
            }
            else {
                outgoingAudioBuffer.advanced(by: This.outgoingAudioBufferOffset).assign(from: data.assumingMemoryBound(to: UInt8.self), count: bytesToRead)
            }
            
            // Send
            if call.isConference && call.isOutgoing {
                // We are the HOST of the Conference Call
                This.sendAudioPacketToConference(call: call, audioPacket: outgoingAudioBuffer, packetSize: maxIODataSize)
            } else {
                let ass = UnsafeMutablePointer<UInt8>.allocate(capacity: maxIODataSize)
                ass.assign(from: outgoingAudioBuffer, count: maxIODataSize)
                
                This.sendAudioPacketSerialQueue.async {
                    // Copy the data to a new buffer that we'll use on a different thread
                    let ret = BlackboxCore.voiceCallSendAudio(ass)
                    ass.deallocate()
                }
            }
            
            // Reset the pointer and his offset
            outgoingAudioBuffer.assign(repeating: 0, count: VoipIOAudioManager.maxIODataSize)
            
            // Add the unsent data to the voicepointer
            if call.isMuted || call.isOnHold || This.powerMeter.averagePowerDB < -50 {
                This.outgoingAudioBufferOffset = 0
            }
            else {
                let unsendBytes = This.voiceIOFormat.framesToBytes(Int(inNumberFrames))-bytesToRead
                outgoingAudioBuffer.assign(from: data.assumingMemoryBound(to: UInt8.self).advanced(by: bytesToRead), count: unsendBytes)
                This.outgoingAudioBufferOffset = unsendBytes
            }
            
        }
        else {
            if call.isMuted || call.isOnHold || This.powerMeter.averagePowerDB < -50 {
                outgoingAudioBuffer.advanced(by: This.outgoingAudioBufferOffset).assign(repeating: 0, count: bytesToRead)
            } else {
                outgoingAudioBuffer.advanced(by: This.outgoingAudioBufferOffset).assign(from: data.assumingMemoryBound(to: UInt8.self), count: bytesToRead)
            }
            
            This.outgoingAudioBufferOffset += bytesToRead
            if This.outgoingAudioBufferOffset == VoipIOAudioManager.maxIODataSize {
                
                // Send
                if call.isConference && call.isOutgoing {
                    // We are the HOST of the Conference Call
                    This.sendAudioPacketToConference(call: call, audioPacket: outgoingAudioBuffer, packetSize: maxIODataSize)
                } else {
                    // Copy the data to a new buffer that we'll use on a different thread
                    let ass = UnsafeMutablePointer<UInt8>.allocate(capacity: maxIODataSize)
                    ass.assign(from: outgoingAudioBuffer, count: maxIODataSize)
                    This.sendAudioPacketSerialQueue.async {
                        let ret = BlackboxCore.voiceCallSendAudio(ass)
                        ass.deallocate()
                    }
                }
                
                // reset the pointer and his offset
                This.outgoingAudioBufferOffset = 0
                outgoingAudioBuffer.assign(repeating: 0, count: VoipIOAudioManager.maxIODataSize)
            }
        }
        
        // TEST
        do {
            //        var audioData = Data(bytesNoCopy: abl[0].mData!, count: Int(abl[0].mDataByteSize), deallocator: .none)
            //        try? audioData.append(fileURL: This.fileURL)
        }
        
        return err
        
    }
    
    func sendAudioPacketToConference(call: BBCall, audioPacket: UnsafeMutablePointer<UInt8>, packetSize: Int) {
        
        let packetCopy = UnsafeMutablePointer<UInt8>.allocate(capacity: packetSize)
        packetCopy.assign(from: audioPacket, count: packetSize)
        
        // Change the following to false to use a Single BlackboxCore.conferenceCallSendAudio
        let sendToMany = false
        if sendToMany {
            // Deallocate the packetCopy only after we send the packet to every contact (with status answered).
            let maxSendsCount = call.members.reduce(into: Int(0)) {
                if $1.callInfo.callStatus == .answeredAudioOnly || $1.callInfo.callStatus == .answered || $1.callInfo.callStatus == .active {
                    $0 += 1
                }
            }
            if maxSendsCount == 0 {
                packetCopy.deallocate()
                return
            }
            
            func sendPacket(packet: UnsafeMutablePointer<UInt8>, session: Int) {
                let _ = BlackboxCore.conferenceCallSendAudio(packetCopy, sessionId: session)
                sendsCount += 1
                if sendsCount == maxSendsCount {
                    packet.deallocate()
                }
            }
            
            var sendsCount = 0
            for contact in call.members where contact.callInfo.callStatus == .answeredAudioOnly || contact.callInfo.callStatus == .answered || contact.callInfo.callStatus == .active {
                if let session = contact.callInfo.callSession {
                    if session == 0 {
                        sendAudioPacketFirstContactQueue.async {
                            sendPacket(packet: packetCopy, session: session)
                        }
                    }
                    else if session == 1 {
                        sendAudioPacketSecondContactQueue.async {
                            sendPacket(packet: packetCopy, session: session)
                        }
                    }
                    else if session == 2 {
                        sendAudioPacketThirdContactQueue.async {
                            sendPacket(packet: packetCopy, session: session)
                        }
                    }
                    else if session == 3 {
                        sendAudioPacketFourthContactQueue.async {
                            sendPacket(packet: packetCopy, session: session)
                        }
                    }
                }
            }
        }
        else {
            sendAudioPacketSerialQueue.async {
                if let contact = call.members.first(where: { (contact) -> Bool in
                    return contact.callInfo.callStatus == .answered && contact.callInfo.isAudioReceiveStarted && contact.callInfo.callSession != nil
                }) {
                    if let session = contact.callInfo.callSession {
                        //            print("Send to \(contact.getName()) (\(contact.registeredNumber)) with SessionNumber = \(session)")
                        let _ = BlackboxCore.conferenceCallSendAudio(packetCopy, sessionId: session)
                    }
                    packetCopy.deallocate()
                }
            }
        }
    }
    
    init() {
        // we don't do anything special in the route change notification
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRouteChange),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: AVAudioSession.sharedInstance())
    }
    
    private func setupIOUnit(session: AVAudioSession) {
        // Now setup the voice unit
        let renderProc = AURenderCallbackStruct(inputProc: ReadVoiceData, inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        let inputProc = AURenderCallbackStruct(inputProc: MonitorInput, inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        
        // we will use the same format for playing the sample voice audio and capturing the voice processor input
        let result = setupOutputUnit(inputProc, renderProc, &voiceUnit, &voiceIOFormat)
        if result != noErr {
            loge("ERROR SETTING UP VOICE UNIT: \(result)")
        }
        
        inputBL = AUOutputBL(voiceIOFormat)
        bypassState = 0
    }
    
    func setAudioOutputPort(port: AVAudioSession.PortOverride) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            if port == .speaker {
                //        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, policy: .default, options: .defaultToSpeaker)
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, policy: .default, options: AVAudioSession.CategoryOptions(rawValue: AVAudioSession.CategoryOptions.allowBluetooth.rawValue | AVAudioSession.CategoryOptions.allowBluetoothA2DP.rawValue | AVAudioSession.CategoryOptions.defaultToSpeaker.rawValue))
                UIDevice.current.isProximityMonitoringEnabled = false
            } else {
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: AVAudioSession.CategoryOptions(rawValue: AVAudioSession.CategoryOptions.allowBluetooth.rawValue | AVAudioSession.CategoryOptions.allowBluetoothA2DP.rawValue))
                UIDevice.current.isProximityMonitoringEnabled = true
            }
            try audioSession.setActive(true)
            
            //      if port == .speaker {
            //        try audioSession.overrideOutputAudioPort(port)
            //        UIDevice.current.isProximityMonitoringEnabled = false
            //      } else {
            //        try audioSession.overrideOutputAudioPort(port)
            //        UIDevice.current.isProximityMonitoringEnabled = true
            //      }
            
        } catch {
            loge(error)
        }
    }
    
    //MARK:- AVAudioSession Notifications
    
    // we just print out the results for informational purposes
    @objc func handleInterruption(_ notification: Notification) {
        let theInterruptionType = notification.userInfo![AVAudioSessionInterruptionTypeKey] as! UInt
        logi("Session interrupted > --- \(theInterruptionType == AVAudioSession.InterruptionType.began.rawValue ? "Begin Interruption" : "End Interruption") ---")
        
        if theInterruptionType == AVAudioSession.InterruptionType.began.rawValue {
            // your audio session is deactivated automatically when your app is interrupted
            // perform any other tasks required to handled being interrupted
            
            // turn off the playback elements
        }
        
        if theInterruptionType == AVAudioSession.InterruptionType.ended.rawValue {
            // make sure to activate the session, it does not get activated for you automatically
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                logi("AVAudioSession set active failed with error: \(error)")
            }
            
            // perform any other tasks to have the app start up after an interruption
            // ....
            
            // Synchronize bypass state
            let result = AudioUnitSetProperty(voiceUnit!, kAUVoiceIOProperty_BypassVoiceProcessing, kAudioUnitScope_Global, 1, &bypassState, UInt32(MemoryLayout.size(ofValue: bypassState)))
            if result != noErr {
                loge("Error setting voice unit bypass: \(result)")
            }
            
            AudioOutputUnitStart(voiceUnit!)
        }
    }
    
    // we just print out the results for informational purposes
    @objc func handleRouteChange(_ notification: Notification) {
        //    let reasonValue = notification.userInfo![AVAudioSessionRouteChangeReasonKey] as! UInt
        //    let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        //    let routeDescription = notification.userInfo![AVAudioSessionRouteChangePreviousRouteKey] as! AVAudioSessionRouteDescription
        //
        //    logi("Route change:")
        //    switch reason {
        //    case .newDeviceAvailable?:
        //      logi("     NewDeviceAvailable")
        //    case .oldDeviceUnavailable?:
        //      logi("     OldDeviceUnavailable")
        //    case .categoryChange?:
        //      logi("     CategoryChange")
        //      logi(" New Category: \(AVAudioSession.sharedInstance().category)")
        //    case .override?:
        //      logi("     Override")
        //    case .wakeFromSleep?:
        //      logi("     WakeFromSleep")
        //    case .noSuitableRouteForCategory?:
        //      logi("     NoSuitableRouteForCategory")
        //    case .routeConfigurationChange?:
        //      logi("    RouteConfigurationChange")
        //    case .unknown?:
        //      logi("     Reason Unknown")
        //    default:
        //      logi("     Reason Really Unknown")
        //      logi("           Reason Value \(reasonValue)")
        //    }
        //
        //    logi("Previous route:")
        //    logi("\(routeDescription)")
        //
        //    logi("Current route:")
        //    logi("\(AVAudioSession.sharedInstance().currentRoute)")
        
    }
    
    // reset the world!
    // see https://developer.apple.com/library/content/qa/qa1749/_index.html
    @objc func handleMediaServicesWereReset(_ notification: Notification) {
        logw("Media services have reset - ouch!")
        
        //    self.resetIOUnit()
        //    self.setupIOUnit()
    }
    
    //MARK:-
    
    deinit {
        if voiceUnit != nil {
            AudioComponentInstanceDispose(voiceUnit!)
            voiceUnit = nil
        }
        
        // we don't do anything special in the route change notification
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupOutputUnit(_ inInputProc: AURenderCallbackStruct,
                         _ inRenderProc: AURenderCallbackStruct,
                         _ outUnit: inout AudioUnit?,
                         _ voiceIOFormat: inout AudioStreamBasicDescription) -> OSStatus {
        enum SetupOutputUnitError: Error {
            case endWithResult(String, OSStatus)
            case end(String)
        }
        
        var result = noErr
        
        // Open the output unit
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,               // type
            componentSubType: kAudioUnitSubType_VoiceProcessingIO, // subType
            componentManufacturer: kAudioUnitManufacturer_Apple,        // manufacturer
            componentFlags: 0,
            componentFlagsMask: 0)                              // flags
        
        do {
            guard let comp = AudioComponentFindNext(nil, &desc) else {
                throw SetupOutputUnitError.end("no AudioComponent found")
            }
            
            // Create voice unit using the provided component description
            result = AudioComponentInstanceNew(comp, &outUnit)
            guard result == noErr, let outUnit = outUnit else {
                throw SetupOutputUnitError.endWithResult("couldn't open the audio unit", result)
            }
            
            var one: UInt32 = 1
            result = AudioUnitSetProperty(outUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, UInt32(MemoryLayout.size(ofValue: one)))
            guard result == noErr else {
                throw SetupOutputUnitError.end("couldn't enable input on the audio unit")
            }
            
            var inputProc = inInputProc
            result = AudioUnitSetProperty(outUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &inputProc, UInt32(MemoryLayout.size(ofValue: inputProc)))
            guard result == noErr else {
                throw SetupOutputUnitError.end("couldn't set audio unit input proc")
            }
            
            var renderProc = inRenderProc
            result = AudioUnitSetProperty(outUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &renderProc, UInt32(MemoryLayout.size(ofValue: renderProc)))
            guard result == noErr else {
                throw SetupOutputUnitError.end("couldn't set audio render callback")
            }
            
            result = AudioUnitSetProperty(outUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &voiceIOFormat, UInt32(MemoryLayout.size(ofValue: voiceIOFormat)))
            guard result == noErr else {
                throw SetupOutputUnitError.end("couldn't set the audio unit's output format")
            }
            
            result = AudioUnitSetProperty(outUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &voiceIOFormat, UInt32(MemoryLayout.size(ofValue: voiceIOFormat)))
            guard result == noErr else {
                throw SetupOutputUnitError.end("couldn't set the audio unit's input client format")
            }
            
            result = AudioUnitInitialize(outUnit)
            guard result == noErr else {
                throw SetupOutputUnitError.end("couldn't initialize the audio unit")
            }
            
        } catch let SetupOutputUnitError.endWithResult(message, result) {
            logi("\(message): \(result)")
        } catch let SetupOutputUnitError.end(message) {
            logi(message)
        } catch {
            loge("unknonw error: \(error)")
        }
        return result
    }
    
    func stopIOAudio() {
        if let voiceUnit = self.voiceUnit {
            let result = AudioOutputUnitStop(voiceUnit)
            if result != noErr {
                loge("ERROR STOPPING VOICE UNIT: \(result)")
            }
            loge("Voice Unit Stopped")
            self.voiceUnit = nil
        }
        call = nil
        incomingAudioBuffer?.deallocate()
        outgoingAudioBuffer?.deallocate()
        
        incomingAudioBuffer = nil
        outgoingAudioBuffer = nil
    }
    
}

extension VoipIOAudioManager {
    
    func startIOAudio(call: BBCall, routeToSpeaker: Bool = false, completion block: ((Bool)->Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.call = call
            
            strongSelf.prepare(routeToSpeaker: routeToSpeaker)
            
            if let voiceUnit = strongSelf.voiceUnit {
                let result = AudioOutputUnitStart(voiceUnit)
                if result != noErr {
                    loge("ERROR STARTING VOICE UNIT: \(result)")
                    block?(false)
                } else {
                    block?(true)
                }
            } else {
                block?(false)
            }
        }
    }
    
    private func prepare(routeToSpeaker: Bool = false) {
        let audioSession = AVAudioSession.sharedInstance()
        
        // Reset incoming audio buffers
        incomingAudioBuffer = UnsafeMutableRawPointer.allocate(byteCount: fiveMinutes, alignment: 0)
        incomingAudioBufferReadOffset = 0
        incomingAudioBufferSize = 0
        
        // Reset outgoing audio buffer
        //    outgoingAudioBuffer.assign(repeating: 0, count: VoipIOAudioManager.maxIODataSize)
        outgoingAudioBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: VoipIOAudioManager.maxIODataSize)
        outgoingAudioBufferOffset = 0
        
        do {
            // See https://forums.developer.apple.com/thread/64544
            if routeToSpeaker {
                //        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, policy: .default, options: .defaultToSpeaker)
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, policy: .default, options: AVAudioSession.CategoryOptions(rawValue: AVAudioSession.CategoryOptions.allowBluetooth.rawValue | AVAudioSession.CategoryOptions.allowBluetoothA2DP.rawValue | AVAudioSession.CategoryOptions.defaultToSpeaker.rawValue))
                UIDevice.current.isProximityMonitoringEnabled = false
            } else {
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: AVAudioSession.CategoryOptions(rawValue: AVAudioSession.CategoryOptions.allowBluetooth.rawValue | AVAudioSession.CategoryOptions.allowBluetoothA2DP.rawValue))
                UIDevice.current.isProximityMonitoringEnabled = true
            }
            try audioSession.setMode(.voiceChat)
            try audioSession.setPreferredSampleRate(48000)
            try audioSession.setPreferredIOBufferDuration(0.005)
            try audioSession.setActive(true)
        } catch {
            loge(error)
        }
        
        setupIOUnit(session: audioSession)
    }
}


private extension PThreadMutex {
    func sync_same_file<R>(f: () throws -> R) rethrows -> R {
        pthread_mutex_lock(&underlyingMutex)
        defer { pthread_mutex_unlock(&underlyingMutex) }
        return try f()
    }
}

