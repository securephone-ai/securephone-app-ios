import Foundation
import AVFoundation
import Combine
import CwlUtils
import DifferenceKit
import BlackboxCore

enum CallStatus: Int {
    case none = 0
    case setup = 1
    case ringing = 2
    case answeredAudioOnly = 3 // This state is used for incoming Video calls received (and answered) when the phone is locked, enabling the audio only.
    case answered = 4
    case active = 5
    case hangup = 6
    case ended = 7
    
    func toString() -> String {
        switch self {
        case .none, .setup:
            return "calling".localized()
        case .ringing:
            return "ringing".localized()
        case .answered, .answeredAudioOnly, .active:
            return "answered".localized()
        case .hangup, .ended:
            return "hangup".localized()
        }
    }
    
}

struct BBCallInfo: Codable {
    var uuid: UUID
    var hasVideo: Bool
}

class BBCall {
    
    private var endCallBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var endCallBackgroundTaskTimer: DispatchTimer?
    
    private var cancellableBag = Set<AnyCancellable>()
    
    // MARK: Metadata Properties
    var dialTonePlayer: AVAudioPlayer?
    
    var ringTimer: DispatchTimer?
    
    // CallKit prop
    let uuid: UUID
    let isOutgoing: Bool
    var handle: String?
    
    // Blackbox Prop
    //  var ID: String?
    //  var contact: BBContact?
    @Published var members: [BBContact] = [BBContact]()
    
    var needPassword = false
    
    /// Perfom specific action based on the status
    @Published private(set) var status: CallStatus {
        didSet {
            switch status {
            case .ringing:
                if isOutgoing, let player = self.dialTonePlayer, !player.isPlaying {
                    player.play()
                }
            case .answeredAudioOnly:
                // Mainly used for video Calls.
                // This status will be called 100% of the time if this is an Incoming call.
                // While for Outgoing calls, this staus may be overwritten by "answer" before checkVideoCallStatusAsync is able to fetch it (it runs once every second).
                // So we startAudioIfNeeded also during the "Answer" status.
                if hasVideo && self.needPassword == false {
                    startAudioIfNeeded(routeToSpeaker: false)
                }
                if isOutgoing, let player = self.dialTonePlayer {
                    player.stop()
                }
            case .answered:
                answered = true
                if isOutgoing == false {
                    ringTimer?.disarm()
                    ringTimer = nil
                }
                
                if isOutgoing, let player = self.dialTonePlayer {
                    player.stop()
                }
                
                if self.needPassword == false {
                    if self.hasVideo {
                        startAudioIfNeeded(routeToSpeaker: hasVideo)
                    } else {
                        startAudioIfNeeded(routeToSpeaker: isSpeaker)
                    }
                }
                
            //        if self.needPassword == false && self.hasVideo == false {
            //          startAudio(routeToSpeaker: hasVideo)
            //        }
            
            case .hangup:
                for contact in members {
                    contact.callInfo.callStatus = .none
                }
                
                hasStartedConnectingDidChange = nil
                hasConnectedDidChange = nil
                
                let blackbox = Blackbox.shared
                
                // Stop audio
                if blackbox.callManager.calls.count == 1 {
                    blackbox.voipAudioManager.stopIOAudio()
                }
                
                
                if isOutgoing == false {
                    ringTimer?.disarm()
                    ringTimer = nil
                }
                
                endCallBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "End Call Background Task", expirationHandler: {
                    self.endBackgroundTask()
                })
                
                // Start the timer that will end the background task after 25 seconds
                endCallBackgroundTaskTimer?.disarm()
                endCallBackgroundTaskTimer?.arm()
                
                DispatchQueue.main.async {
                    UIDevice.current.isProximityMonitoringEnabled = false
                }
                
                // Hang-up the call
                if hasVideo {
                    blackbox.endVideoCallAsync(self) { [weak self] (_) in
                        guard let strongSelf = self else {
                            self?.endBackgroundTask()
                            return
                        }
                        if strongSelf.status != .ended {
                            strongSelf.status = .ended
                        }
                        strongSelf.endBackgroundTask()
                    }
                }
                else {
                    endCall {  [weak self] (_) in
                        guard let strongSelf = self else {
                            self?.endBackgroundTask()
                            return
                        }
                        if strongSelf.status != .ended {
                            strongSelf.status = .ended
                        }
                        strongSelf.endBackgroundTask()
                    }
                }
                // CallKit End-Call transaction
                blackbox.callManager.end(call: self)
                
                if isOutgoing, isEndCallUserInitiated == false, let player = self.dialTonePlayer {
                    player.stop()
                    if answered == false {
                        let dialTone = Bundle.main.url(forResource: "busy_signal", withExtension: "mp3")!
                        do {
                            dialTonePlayer = try AVAudioPlayer(contentsOf: dialTone)
                            dialTonePlayer?.numberOfLoops = 1
                            dialTonePlayer?.play()
                            
                            if let callVC = blackbox.callViewController, let callView = callVC.callView {
                                DispatchQueue.main.async {
                                    callView.callStateLabel.text = "No Answer...".localized()
                                }
                            }
                        } catch {
                            loge(error)
                        }
                    }
                }
            case .ended:
                endDate = Date()
            default:
                break
            }
        }
    }
    
    var isIOAudioStarted = false
    var isAudioStarted: Bool {
        return status == .answeredAudioOnly || status == .answered || status == .active
    }
    var isStarted: Bool {
        return status == .answered || status == .active
    }
    var isConference = false
    
    var isEndCallUserInitiated = false
    
    private(set) var answered = false
    
    // MARK: Call State Properties
    var connectingDate: Date? {
        didSet {
            hasStartedConnectingDidChange?()
        }
    }
    var connectDate: Date? {
        didSet {
            hasConnectedDidChange?()
        }
    }
    var endDate: Date?
    var isOnHold = false
    @Published var isMuted = false
    @Published var isSpeaker = false
    @Published var hasVideo = false
    
    // MARK: State change callback blocks
    
    var hasStartedConnectingDidChange: (() -> Void)?
    var hasConnectedDidChange: (() -> Void)?
    
    // MARK: Derived Properties
    
    var hasStartedConnecting: Bool {
        get {
            return connectingDate != nil
        }
        set {
            connectingDate = newValue ? Date() : nil
        }
    }
    var hasConnected: Bool {
        get {
            return connectDate != nil
        }
        set {
            connectDate = newValue ? Date() : nil
        }
    }
    var duration: TimeInterval {
        guard let connectDate = connectDate else {
            return 0
        }
        
        return Date().timeIntervalSince(connectDate)
    }
    
    private var callInfoRetryCount = 0
    // this is a flag to keep track if one of the 2 calls has failed alrady.
    // if both failed, the last one will remove the call from the callmanager list
    private var callInfosFailed = false
    
    init(uuid: UUID, isOutgoing: Bool = false) {
        self.uuid = uuid
        self.isOutgoing = isOutgoing
        self.status = .none
        
        if isOutgoing {
            // Setup the sound fx player
            // loops the playing of sound effects
            // this is an AAC, Stereo, 44.100 kHz file
            let dialTone = Bundle.main.url(forResource: "dial_tone", withExtension: "mp3")!
            do {
                dialTonePlayer = try AVAudioPlayer(contentsOf: dialTone)
                dialTonePlayer!.numberOfLoops = -1
            } catch {
                loge(error)
            }
        } else {
            ringTimer = DispatchTimer(countdown: .seconds(45), payload: {
                if self.isStarted == false {
                    self.ringTimer?.disarm()
                    self.ringTimer = nil
                    self.endCall()
                }
            })
            ringTimer?.arm()
        }
        
        endCallBackgroundTaskTimer = DispatchTimer(countdown: .seconds(29), payload: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.endBackgroundTask()
        })
    }
    
    deinit {
        ringTimer?.disarm()
        ringTimer = nil
        logi("BBCall has been deinitialized")
        Blackbox.shared.fetchCallsHistoryAsync(completion: nil)
    }
    
    // MARK: Actions
    
    /// Get  Call info on a background thread and set call status to setup on success
    /// - Parameter block: completion block --> return true if success, otherwise return false.
    func getInfo(completion block: ((Bool)->Void)? = nil) {
        let blackbox = Blackbox.shared
        
        // Get the call object from the Blackbox service
        if hasVideo == false {
            blackbox.getCallInfoAsync(call: self) { [weak self] (success) in
                guard let strongSelf = self else { return }
                if success {
                    if strongSelf.status != .setup {
                        strongSelf.status = .setup
                    }
                    strongSelf.checkCallStatusAsync()
                    block?(true)
                } else {
                    if strongSelf.callInfoRetryCount <= 4 {
                        strongSelf.callInfoRetryCount += 1
                        strongSelf.callInfosFailed = false
                        strongSelf.getInfo(completion: block)
                    } else {
                        strongSelf.endCall()
                        block?(false)
                    }
                }
            }
        } else {
            // Check if this is a video call
            blackbox.getVideoCallInfoAsync(call: self) { [weak self] (success) in
                guard let strongSelf = self else { return }
                if success {
                    if strongSelf.status != .setup {
                        strongSelf.status = .setup
                    }
                    strongSelf.checkVideoCallStatusAsync()
                    block?(true)
                } else {
                    if strongSelf.callInfoRetryCount <= 4 {
                        strongSelf.callInfoRetryCount += 1
                        strongSelf.callInfosFailed = false
                        strongSelf.getInfo(completion: block)
                    } else {
                        strongSelf.endCall()
                        block?(false)
                    }
                }
            }
        }
    }
    
    /// Start a new call
    /// - Parameter block: completion block --> return true if success, otherwise return false.
    func startCall(completion block: ((_ success: Bool) -> Void)?) {
        // restore the contacts call status to .none before starting the call
        for contact in members {
            contact.callInfo.callStatus = .none
        }
        if isConference {
            startConferenceCall(completion: block)
        } else {
            startOneToOneCall(completion: block)
        }
    }
    
    /// Answer an incoming call
    /// - Parameter completion: completion block --> return true if success, otherwise return false.
    func answerCall(completion: ((_ success: Bool) -> Void)?) {
        self.hasStartedConnecting = true
        Blackbox.shared.answerCallAsync(self) { (success) in
            if success {
                self.hasConnected = true
                completion?(true)
            } else {
                // Signal to the system that the action has failed.
                completion?(false)
            }
        }
    }
    
    /// Prepare the voip Audio manager to reproduce the seleted call audio
    func startAudioIfNeeded(routeToSpeaker: Bool) {
        if isIOAudioStarted == false {
            isIOAudioStarted = true
            isSpeaker = routeToSpeaker
            
            // Start unit input and output audio process
            Blackbox.shared.voipAudioManager.startIOAudio(call: self, routeToSpeaker: routeToSpeaker) { [weak self] (success) in
                guard let strongSelf = self else { return }
                // fetch incoming audio data from the server
                if strongSelf.isConference {
                    strongSelf.fetchConferenceAudioPacketsAsync()
                } else {
                    strongSelf.fetchOneToOneAudioPacketAsync()
                }
            }
        }
        else if hasVideo {
            isSpeaker = true
        }
    }
    
    /// Hang-Up the call
    func endCall(userInitiated: Bool = false) {
        if status.rawValue < CallStatus.hangup.rawValue {
            isEndCallUserInitiated = userInitiated
            status = .hangup
        }
    }
    
    /// Hang-Up the call on a background thread
    /// - Parameter block: completion block --> return true if success, otherwise return false.
    private func endCall(completion block: ((_ success: Bool) -> Void)?) {
        if isConference {
            Blackbox.shared.endConferenceCallAsync(self, completion: block)
        } else {
            Blackbox.shared.endCallAsync(self, completion: block)
        }
    }
    
    /// Function used to end the bacgground task and do some cleaning operation
    private func endBackgroundTask() {
        if endCallBackgroundTask != .invalid {
            //      logi("End Call background task - Ended")
            UIApplication.shared.endBackgroundTask(endCallBackgroundTask)
            endCallBackgroundTask = .invalid
            endCallBackgroundTaskTimer?.disarm()
            endCallBackgroundTaskTimer = nil
        }
    }
    
}

// MARK: - OneToOne Call Functions
extension BBCall {
    
    /// Start OneToOne call
    /// - Parameter completion: completion block --> return true if success, otherwise return false.
    private func startOneToOneCall(completion: ((_ success: Bool) -> Void)?) {
        Blackbox.shared.startCallAsync(self) { [weak self] (result, errorMessage) in
            guard let strongSelf = self else { return }
            if let result = result, result {
                completion?(true)
                strongSelf.hasStartedConnecting = true
                strongSelf.checkCallStatusAsync()
            } else {
                // Signal to the system that the action has failed.
                completion?(false)
            }
        }
    }
    
    /// Fetch audio using BlackboxCore.voiceCallGetAudio on a background thread with high priority.
    /// Update the Blackbox.shared.voipAudioManager incomingAudioBuffer, incomingAudioBufferSize and incomingAudioBufferReadOffset
    private func fetchOneToOneAudioPacketAsync() {
        let callUUID = self.uuid
        DispatchQueue.global(qos: .userInteractive).async {
            let blackbox = Blackbox.shared
            var exitLoop = false
            while exitLoop == false, let call = blackbox.callManager.callWithUUID(uuid: callUUID), call.status.rawValue < CallStatus.hangup.rawValue {
                if call.isAudioStarted {
                    // retrieve the data
                    let voipAudioManager = blackbox.voipAudioManager
                    
                    guard let incomingAudioBuffer = BlackboxCore.voiceCallGetAudio({ (errorCode) in
                        exitLoop = true
                        if errorCode == -1 {
                            logi("Audio - Timed-out")
                        }
                        else if errorCode == -2 {
                            logi("Audio - Hang Up")
                        }
                    }), let outputBuffer = voipAudioManager.incomingAudioBuffer else {
                        continue
                    }
                    
                    // Data Available
                    if voipAudioManager.incomingAudioBufferSize + VoipIOAudioManager.maxIODataSize > voipAudioManager.fiveMinutes {
                        // Reallocate a and start from the reading offset
                        // Take the remaining bytes to reproduce
                        let buffer = UnsafeMutableRawPointer.allocate(byteCount: voipAudioManager.fiveMinutes, alignment: 0)
                        let newSize = voipAudioManager.incomingAudioBufferSize - voipAudioManager.incomingAudioBufferReadOffset
                        let newPtr = outputBuffer.advanced(by: voipAudioManager.incomingAudioBufferReadOffset)
                        buffer.copyMemory(from: newPtr, byteCount: newSize)
                        
                        voipAudioManager.incomingAudioBufferReadOffset = 0
                        voipAudioManager.incomingAudioBufferSize = newSize
                        voipAudioManager.incomingAudioBuffer  = buffer
                    }
                    else {
                        guard let audioBuffer = incomingAudioBuffer.withUnsafeBytes({ (rawBufferPointer) -> UnsafeRawPointer? in
                            return rawBufferPointer.baseAddress
                        }) else {
                            continue
                        }
                        
                        // Just append the data to the end
                        outputBuffer
                            .advanced(by: voipAudioManager.incomingAudioBufferSize)
                            .copyMemory(from: audioBuffer, byteCount: VoipIOAudioManager.maxIODataSize)
                        voipAudioManager.incomingAudioBufferSize += VoipIOAudioManager.maxIODataSize
                    }
                }
            }
        }
    }
    
    /// Update the OneToOne call status every 500ms and update
    private func checkCallStatusAsync() {
        let callUUID = self.uuid
        DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 1) {
            let blackbox = Blackbox.shared
            let decoder = JSONDecoder()
            while let call = blackbox.callManager.callWithUUID(uuid: callUUID),
                  call.status.rawValue < CallStatus.hangup.rawValue,
                  let contact = call.members.first,
                  let callId = contact.callInfo.callID,
                  let jsonString = BlackboxCore.voiceCallGetStatus(callId) {
                
                do {
                    let response = try decoder.decode(CallStatusResponse.self, from: jsonString.data(using: .utf8)!)
                    DispatchQueue.main.async {
                        if response.isSuccess() {
                            
                            // check every member of the conference call Field to see if there is more then 1 Contact in this call.
                            // Show the table if contacts > 1
                            // Show avatar if contacts == 1
                            if call.members.count > 0,
                               let conferenceMembersStatus = response.conferenceMembersStatus,
                               conferenceMembersStatus.count > 0,
                               let firstMember = conferenceMembersStatus.first {
                                
                                var members: [BBContact] = call.members.filter { $0.registeredNumber == firstMember.callerID }
                                let blackbox = Blackbox.shared
                                for memberStatus in conferenceMembersStatus where memberStatus.calledID != blackbox.account.registeredNumber {
                                    if let contact = blackbox.getContact(registeredNumber: memberStatus.calledID) {
                                        contact.callInfo.callStatus = memberStatus.status
                                        members.append(contact)
                                    } else if let contact = blackbox.getTemporaryContact(registeredNumber: memberStatus.calledID) {
                                        contact.callInfo.callStatus = memberStatus.status
                                        members.append(contact)
                                    }
                                }
                                
                                let changeset = StagedChangeset(source: call.members, target: members)
                                if changeset.isEmpty == false {
                                    // Something has changed. Update the members list
                                    call.members = members
                                }
                            }
                            
                            logi("CALLID = \(call.uuid) Status-> \(response.status)")
                            
                            // Set the Call Status
                            switch response.status {
                            case "setup":
                                if call.status.rawValue < CallStatus.setup.rawValue {
                                    call.status = .setup
                                }
                                if contact.callInfo.callStatus.rawValue < CallStatus.setup.rawValue {
                                    contact.callInfo.callStatus = .setup
                                }
                            case "ringing":
                                if call.status.rawValue < CallStatus.ringing.rawValue {
                                    call.status = .ringing
                                }
                                if contact.callInfo.callStatus.rawValue < CallStatus.ringing.rawValue {
                                    contact.callInfo.callStatus = .ringing
                                }
                            case "answered":
                                if call.status.rawValue < CallStatus.answered.rawValue {
                                    call.hasConnected = true
                                    call.status = .answered
                                }
                                if contact.callInfo.callStatus.rawValue < CallStatus.answered.rawValue {
                                    contact.callInfo.callStatus = .answered
                                }
                            case "hangup":
                                call.status = .hangup
                            default:
                                call.status = .none
                            }
                            
                            // Fetch members..
                            //                if let membersStatus = response.conferenceMembersStatus {
                            //
                            //                }
                            
                        } else {
                            call.status = .none
                        }
                    }
                } catch {
                    loge(error)
                }
                // Wait 1 seconds before checking the status again.
                usleep(500000)
            }
        }
    }
    
}

// MARK: - Conference Call Functions
extension BBCall {
    
    /// Remove a specifc contact from the call on a background thread
    /// - Parameters:
    ///   - contact: The contact to remove
    ///   - block: completion block --> return true if success, otherwise return false.
    func endCallWith(contact: BBContact, completion block: ((Bool)->Void)? = nil) {
        
        if members.contains(where: { (cnt) -> Bool in
            cnt.registeredNumber == contact.registeredNumber
        }), let session = contact.callInfo.callSession {
            DispatchQueue.global(qos: .background).async {
                guard let callID = contact.callInfo.callID,
                      let jsonString = BlackboxCore.conferenceCallEnd(callID, sessionId: session) else {
                    block?(false)
                    return
                }
                logPrettyJsonString(jsonString)
                
                do {
                    let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                    
                    if response.isSuccess() {
                        self.removeAndHangupCallFor(contact: contact)
                        block?(true)
                    } else {
                        block?(false)
                    }
                } catch {
                    loge(error)
                    block?(false)
                }
            }
        }
    }
    
    /// Start the conference call on a background thread
    /// - Parameter completion: completion block --> return true if success, otherwise return false.
    private func startConferenceCall(completion: ((_ success: Bool) -> Void)?) {
        Blackbox.shared.startConferenceCallAsync(self) { [weak self] (success) in
            guard let strongSelf = self else { return }
            if success {
                completion?(true)
                strongSelf.hasStartedConnecting = true
                strongSelf.checkConferenceCallStatusAsync()
            } else {
                completion?(false)
            }
        }
    }
    
    
    /// Fetch the conference audio on a background thread.
    /// The session used is the first session who ansewred and will switch to the next one if the current contact owning the session hang-up the call
    /// Update the Blackbox.shared.voipAudioManager incomingAudioBuffer, incomingAudioBufferSize and incomingAudioBufferReadOffset
    private func fetchConferenceAudioPacketsAsync() {
        // Thread used to get fetch the audio packets from the first contact that has answered the call and has performed
        // a successfull first BlackboxCore.conferenceGetAudioSession (isAudioReceiveStarted flag set to true)
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let strongSelf = self else { return }
            
            // As long as there is valid member that satisfy every condition, we'll try to fetch data from it.
            while strongSelf.members.count > 0 && strongSelf.status.rawValue < CallStatus.hangup.rawValue {
                
                // Get the first contact with a valid isAudioReceiveStarted flag (true)
                if let contact = strongSelf.members.first(where: { (contact) -> Bool in
                    return contact.callInfo.callStatus == .answered && contact.callInfo.isAudioReceiveStarted && contact.callInfo.callSession != nil
                }) {
                    
                    logi("Conference Call - Audio fetch started from contact: \(contact.getName())")
                    
                    // Loop until this user has a valid callStatus and use the his returned packet from BlackboxCore.conferenceGetAudioSession to fill the audio buffer.
                    // if the user hand-up the call, the below loop will exit and the upper loop will try to look for another Contact with isAudioReceiveStarted flag set to true
                    var exitLoop = false
                    while exitLoop == false &&
                            strongSelf.status.rawValue < CallStatus.hangup.rawValue &&
                            contact.callInfo.callStatus.rawValue < CallStatus.hangup.rawValue {
                        
                        if contact.callInfo.callStatus == .answeredAudioOnly || contact.callInfo.callStatus == .answered || contact.callInfo.callStatus == .active {
                            // retrieve the data
                            let voipAudioManager = Blackbox.shared.voipAudioManager
                            
                            guard let incomingAudioBuffer = BlackboxCore.conferenceGetAudioSession(contact.callInfo.callSession!, errorBlock: { (errorCode) in
                                exitLoop = true
                                if errorCode == -1 {
                                    logi("Conference Call \(contact.getName()) Audio - Timed-out")
                                }
                                else if errorCode == -2 {
                                    logi("Conference Call \(contact.getName()) Audio - Hang Up")
                                }
                            }), let outputBuffer = voipAudioManager.incomingAudioBuffer else {
                                continue
                            }
                            
                            // Data Available
                            if voipAudioManager.incomingAudioBufferSize + VoipIOAudioManager.maxIODataSize > voipAudioManager.fiveMinutes {
                                // Reallocate a and start from the reading offset
                                // Take the remaining bytes to reproduce
                                let buffer = UnsafeMutableRawPointer.allocate(byteCount: voipAudioManager.fiveMinutes, alignment: 0)
                                let newSize = voipAudioManager.incomingAudioBufferSize - voipAudioManager.incomingAudioBufferReadOffset
                                let newPtr = outputBuffer.advanced(by: voipAudioManager.incomingAudioBufferReadOffset)
                                buffer.copyMemory(from: newPtr, byteCount: newSize)
                                
                                voipAudioManager.incomingAudioBufferReadOffset = 0
                                voipAudioManager.incomingAudioBufferSize = newSize
                                voipAudioManager.incomingAudioBuffer  = buffer
                            } else {
                                guard let audioBuffer = incomingAudioBuffer.withUnsafeBytes({ (rawBufferPointer) -> UnsafeRawPointer? in
                                    return rawBufferPointer.baseAddress
                                }) else {
                                    continue
                                }
                                
                                // Just append the data to the end
                                outputBuffer
                                    .advanced(by: voipAudioManager.incomingAudioBufferSize)
                                    .copyMemory(from: audioBuffer, byteCount: VoipIOAudioManager.maxIODataSize)
                                
                                voipAudioManager.incomingAudioBufferSize += VoipIOAudioManager.maxIODataSize
                            }
                            
                        }
                    }
                    
                    logi("Conference Call - Audio fetch stopped from contact: \(contact.getName())")
                    
                }
                
                // Wait 10ms seconds before checking the status again.
                usleep(100000)
            }
            
        }
        
        // We start a different thread for each member of the call to initialize the Blackbox audio merging (and internal thread) by performing a single BlackboxCore.conferenceGetAudioSession
        // as soon as the call is answered by the member. If succeed, we exit from our thread.
        for contact in members where contact.callInfo.callSession != nil {
            listenToContactCallStatusChange(contact)
        }
    }
    
    /// Add a new Contact to the conference call on a background thread
    /// - Parameters:
    ///   - contacts: The cotnact to add
    ///   - block: completion block --> return true if success, otherwise return false.
    func addMembersToConferenceCall(contacts: [BBContact], completion block: ((_ addedContacts: [BBContact]?, _ failedContacts: [BBContact]?)->Void)?) {
        if members.count >= 4 {
            logw("Conference call if full")
            block?(nil, nil)
            return
        }
        // restore the contacts call status to .none before starting the call
        for contact in members {
            contact.callInfo.callStatus = .none
        }
        for contact in contacts {
            contact.callInfo.callStatus = .none
        }
        
        Blackbox.shared.appendContactsToConferenceAsync(self, contacts: contacts) { [weak self] (addedContacts, failedContacts) in
            guard let strongSelf = self else { return }
            if let addedContacts = addedContacts {
                // we'll add the listener only if the call is already answered by someone because a
                // listener will be already added to every contact when someone answer the call.
                if strongSelf.isAudioStarted {
                    for contact in addedContacts {
                        strongSelf.listenToContactCallStatusChange(contact)
                    }
                }
            }
            block?(addedContacts, failedContacts)
        }
    }
    
    /// Return the members names separeted by a comma
    ///
    ///     "Nick, Lisa, Jhon"
    ///
    /// - Returns:
    func getMembersName() -> String {
        var names = ""
        for (index, member) in members.enumerated() {
            let name = member.getName()
            if index == 0 {
                names = name
            } else {
                names = "\(names), \(name)"
            }
        }
        return names
    }
    
    /// Fetch the first packet for each contact of the call
    /// - Parameter contact: the contact
    private func fetchConferenceContactAudioPacketsAsync(contact: BBContact) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let strongSelf = self else { return }
            
            // Say to the blackbox that a we want to marge this contact audio
            BlackboxCore.conferenceCallSetSession(contact.callInfo.callSession!)
            var exitLoop = false
            while exitLoop == false &&
                    contact.callInfo.callStatus.rawValue < CallStatus.hangup.rawValue &&
                    strongSelf.status.rawValue < CallStatus.hangup.rawValue   {
                
                guard let _ = BlackboxCore.conferenceGetAudioSession(contact.callInfo.callSession!, errorBlock: { (errorCode) in
                    exitLoop = true
                    if errorCode == -1 {
                        logi("Audio - Timed-out")
                    }
                    else if errorCode == -2 {
                        logi("Audio - Hang Up")
                    }
                }) else {
                    continue
                }
                
                // Here we just make sure the call is succesfull to set the Flag isAudioReceiveStarted to true.
                // If we are not receiving audio from any contact we'll make this one the next one that we'll use.
                
                // If exitLoop is TRUE, this thread will exit as soon as the first BlackboxCore.conferenceGetAudioSession is succesfull for this contact.
                // If is FALSE, this thread will keep calling BlackboxCore.conferenceGetAudioSession as long as no member of the conference has the isAudioReceiveStarted. In that case this contact will be
                // the one we'll use to fetch the audio packets (and exit from this loop).
                let test = true
                if test {
                    if let contactIndex = strongSelf.members.firstIndex(where: { (contact) -> Bool in
                        return contact.callInfo.callStatus == .answered && contact.callInfo.isAudioReceiveStarted && contact.callInfo.callSession != nil
                    }), contactIndex != 0 {
                        strongSelf.members.removeAll(contact)
                        strongSelf.members.insert(contact, at: 0)
                    }
                    contact.callInfo.isAudioReceiveStarted = true
                    return
                }
                else {
                    if strongSelf.members.contains(where: { (_contact) -> Bool in
                        return _contact.callInfo.isAudioReceiveStarted
                    }) == false {
                        logi("Audio fetch will switch to session \(contact.callInfo.callSession!)")
                        contact.callInfo.isAudioReceiveStarted = true
                        return
                    }
                }
            }
        }
    }
    
    
    /// Listen when the contact call is answered and then start to fetch the first packet and set the session
    /// - Parameter contact: contact
    private func listenToContactCallStatusChange(_ contact: BBContact) {
        contact.callInfo.$callStatus.filter {
            if $0 == .answeredAudioOnly || $0 == .answered || $0 == .active {
                return true
            }
            return false
        }.sink { [weak self] (status) in
            guard let strongSelf = self else { return }
            strongSelf.fetchConferenceContactAudioPacketsAsync(contact: contact)
        }.store(in: &cancellableBag)
        
    }
    
    /// Update the conference call status property based on each contact status.
    private func setConferenceCallStatus() {
        var setupCount = 0
        var ringingCount = 0
        var answeredCount = 0
        for member in members {
            if member.callInfo.callStatus == .setup {
                setupCount += 1
            } else if member.callInfo.callStatus == .ringing {
                ringingCount += 1
            } else if member.callInfo.callStatus == .answered || member.callInfo.callStatus == .active || member.callInfo.callStatus == .answeredAudioOnly {
                answeredCount += 1
            }
        }
        
        if answeredCount > 0 {
            if status.rawValue < CallStatus.answered.rawValue {
                hasConnected = true
                status = .answered
            }
        } else if ringingCount > 0 {
            if status != .ringing {
                status = .ringing
            }
        } else {
            status = .setup
        }
    }
    
    /// Update each contact status every 750ms
    private func checkConferenceCallStatusAsync() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else { return }
            let decoder = JSONDecoder()
            
            while strongSelf.status.rawValue < CallStatus.hangup.rawValue {
                
                let pwdConfPtr = Blackbox.getPwdConfPointer()
                
                defer {
                    pwdConfPtr?.deallocate()
                }
                
                for (index, contact) in strongSelf.members.enumerated() {
                    guard let callId = contact.callInfo.callID,
                          let jsonString = BlackboxCore.conferenceCallGetStatus(callId, sessionId: index)else {
                        continue
                    }
                    do {
                        
                        let response = try decoder.decode(CallStatusResponse.self, from: jsonString.data(using: .utf8)!)
                        DispatchQueue.main.async {
                            if response.isSuccess() {
                                //                logi("\(contact.getName()) audio call with ID: \(contact.callInfo.callID!) status: \(response.status)")
                                
                                switch response.status {
                                case "setup":
                                    //                  if strongSelf.status.rawValue < CallStatus.setup.rawValue {
                                    //                    strongSelf.status = .setup
                                    //                  }
                                    if contact.callInfo.callStatus.rawValue < CallStatus.setup.rawValue {
                                        contact.callInfo.callStatus = .setup
                                        logi("\(contact.getName()) audio call with ID: \(contact.callInfo.callID!) status: \(response.status)")
                                    }
                                    strongSelf.setConferenceCallStatus()
                                case "ringing":
                                    //                  if strongSelf.status.rawValue < CallStatus.ringing.rawValue {
                                    //                    strongSelf.status = .ringing
                                    //                  }
                                    if contact.callInfo.callStatus.rawValue < CallStatus.ringing.rawValue {
                                        contact.callInfo.callStatus = .ringing
                                        logi("\(contact.getName()) audio call with ID: \(contact.callInfo.callID!) status: \(response.status)")
                                    }
                                    strongSelf.setConferenceCallStatus()
                                case "answered":
                                    //                  if strongSelf.status.rawValue < CallStatus.answered.rawValue {
                                    //                    strongSelf.hasConnected = true
                                    //                    strongSelf.status = .answered
                                    //                  }
                                    if contact.callInfo.callStatus.rawValue < CallStatus.answered.rawValue {
                                        contact.callInfo.callStatus = .answered
                                        logi("\(contact.getName()) audio call with ID: \(contact.callInfo.callID!) status: \(response.status)")
                                    }
                                    strongSelf.setConferenceCallStatus()
                                case "hangup":
                                    logi("\(contact.getName()) audio call with ID: \(contact.callInfo.callID!) status: \(response.status)")
                                    strongSelf.removeAndHangupCallFor(contact: contact)
                                default:
                                    strongSelf.status = .none
                                    contact.callInfo.callStatus = .none
                                }
                            } else {
                                strongSelf.status = .none
                                contact.callInfo.callStatus = .none
                            }
                        }
                    } catch {
                        loge(error)
                    }
                    // Wait 750ms before checking the status again.
                    usleep(750000)
                }
            }
        }
    }
    
    
    /// Set the contact status to hangup, remove it from the members list and HangUp the call if there are no more Contacts presents
    /// - Parameter contact: the contact to remove
    private func removeAndHangupCallFor(contact: BBContact) {
        contact.callInfo.callStatus = .hangup
        members = members.filter { $0.registeredNumber != contact.registeredNumber }
        
        if members.count == 0 {
            status = .hangup
        }
    }
    
}

// MARK: - Video Call Functions
extension BBCall {
    
    /// Start video call on a background thread
    /// - Parameter completion: completion block --> return true if success, otherwise return false.
    func startVideoCall(completion: ((_ success: Bool) -> Void)?) {
        Blackbox.shared.startVideoCallAsync(self) { [weak self] (result, errorMessage) in
            guard let strongSelf = self else { return }
            if let result = result, result {
                strongSelf.hasStartedConnecting = true
                strongSelf.checkVideoCallStatusAsync()
                completion?(true)
            } else {
                // Signal to the system that the action has failed.
                completion?(false)
            }
        }
    }
    
    /// Answer an incoming Video call on a background thread
    /// - Parameters:
    ///   - audioOnly: if answer from background only the audio will start
    ///   - completion: completion block --> return true if success, otherwise return false.
    func answerVideoCall(audioOnly: Bool = true, completion: ((_ success: Bool) -> Void)?) {
        hasStartedConnecting = true
        
        Blackbox.shared.answerVideoCallAsync(self, audioOnly: audioOnly) { (success) in
            if success {
                self.hasConnected = true
                if audioOnly {
                    if self.status.rawValue < CallStatus.answeredAudioOnly.rawValue {
                        self.status = .answeredAudioOnly
                    }
                } else {
                    if self.status.rawValue < CallStatus.answered.rawValue {
                        self.status = .answered
                    }
                }
                completion?(true)
            } else {
                // Signal to the system that the action has failed.
                completion?(false)
            }
        }
    }
    
    /// Update the call status every 750ms
    private func checkVideoCallStatusAsync() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else { return }
            
            let decoder = JSONDecoder()
            while strongSelf.status.rawValue < CallStatus.hangup.rawValue {
                // Wait 750ms seconds before checking the status again.
                usleep(750000)
                
                guard let contact = strongSelf.members.first,
                      let callId = contact.callInfo.callID,
                      let jsonString = BlackboxCore.videoCallGetStatus(callId) else {
                    continue
                }
                do {
                    let response = try decoder.decode(CallStatusResponse.self, from: jsonString.data(using: .utf8)!)
                    if response.isSuccess() {
                        
                        logi("video call status: \(response.status)")
                        
                        switch response.status {
                        case "setup":
                            if strongSelf.status != .setup && strongSelf.status.rawValue < CallStatus.hangup.rawValue {
                                strongSelf.status = .setup
                            }
                        case "ringing":
                            if strongSelf.status != .ringing && strongSelf.status.rawValue < CallStatus.hangup.rawValue {
                                strongSelf.status = .ringing
                            }
                        case "answeredA":
                            if strongSelf.status != .answeredAudioOnly && strongSelf.status.rawValue < CallStatus.answered.rawValue {
                                strongSelf.hasConnected = true
                                strongSelf.status = .answeredAudioOnly
                            }
                        case "answered":
                            if strongSelf.status != .answered && strongSelf.status.rawValue < CallStatus.active.rawValue {
                                strongSelf.hasConnected = true
                                strongSelf.status = .answered
                            }
                        case "active":
                            if strongSelf.status != .active && strongSelf.status.rawValue < CallStatus.hangup.rawValue {
                                strongSelf.status = .active
                            }
                        case "hangup":
                            strongSelf.status = .hangup
                        default:
                            strongSelf.status = .none
                        }
                    } else {
                        strongSelf.status = .none
                    }
                } catch {
                    loge(error)
                }
                
            }
        }
    }
    
}

