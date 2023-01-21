import Foundation
import UIKit
import CallKit
import AVFoundation

final class CallKitProviderDelegate: NSObject, CXProviderDelegate {
  var timer: DispatchTimer?
  
  let callManager: BBCallManager
  let provider: CXProvider
  
  init(callManager: BBCallManager) {
    self.callManager = callManager
    provider = CXProvider(configuration: type(of: self).providerConfiguration)
    super.init()
    provider.setDelegate(self, queue: nil)
  }
  
  /// The app's provider configuration, representing its CallKit capabilities
  static var providerConfiguration: CXProviderConfiguration {
    let localizedName = Constants.AppName.localized()
    let providerConfiguration = CXProviderConfiguration(localizedName: localizedName)
    
    providerConfiguration.supportsVideo = true
    providerConfiguration.maximumCallsPerCallGroup = 1
    providerConfiguration.supportedHandleTypes = [.phoneNumber]
    providerConfiguration.iconTemplateImageData = #imageLiteral(resourceName: "AppIconU").pngData()
    providerConfiguration.includesCallsInRecents=false
//    providerConfiguration.ringtoneSound = "Ringtone.caf"
    
    return providerConfiguration
  }

  
  // MARK: Incoming Calls
  
  /// Use CXProvider to report the incoming call to the system
  func reportIncomingCallApplePush(uuid: UUID, hasVideo: Bool = false, completion: ((NSError?) -> Void)? = nil) {
    
    // Configure the call information data structures.
    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .phoneNumber, value: Constants.AppName)
    update.hasVideo = hasVideo
    update.supportsHolding = false
    
    // Create our call Object
    let call = BBCall(uuid: uuid)
    call.hasVideo = hasVideo
    
    // Report the call to CallKit, and let it display the call UI.
    self.provider.reportNewIncomingCall(with: uuid, update: update) { error in
      if error == nil {
        /*
         Only add incoming call to the app's list of calls if the call was allowed (i.e. there was no error)
         since calls may be "denied" for various legitimate reasons. See CXErrorCodeIncomingCallError.
         */
        self.callManager.addCall(call)
      }
      
      // Asynchronously register with the telephony server and
      // process the call. Report updates to CallKit as needed.
      let blackbox = Blackbox.shared
      if blackbox.account.state == .registered {
        call.getInfo { (_) in
          DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            // Update the call informations
            strongSelf.provider.reportCall(with: call.uuid, updated: strongSelf.getUpdatedCallInfo(call))
            completion?(error as NSError?)
          }
        }
      }
      else {
        UserDefaults.standard.set(object: BBCallInfo(uuid: uuid, hasVideo: hasVideo), forKey: "callinc")
        
        if blackbox.isPwdConfValid() {
        
          blackbox.account.registerAsync(completion: nil)
          
          blackbox.account.stateDidChange = {
            if blackbox.account.state == .registered {
              call.getInfo { (_) in
                DispatchQueue.main.async { [weak self] in
                  guard let strongSelf = self else { return }
                  // Update the call informations
                  strongSelf.provider.reportCall(with: call.uuid, updated: strongSelf.getUpdatedCallInfo(call))
                  completion?(error as NSError?)
                }
              }
            }
          }
          
          completion?(error as NSError?)
        }
        else {
          // In this case we must ask the user the Master Password before he can answer the call.
          call.needPassword = true
          completion?(error as NSError?)
        }
      }
    }
  }
  
  func getUpdatedCallInfo(_ call: BBCall) -> CXCallUpdate {
    // Update the call
    let update = CXCallUpdate()
    let name =  call.isConference ? "Conference call" : call.members[0].getName()
    update.remoteHandle = CXHandle(type: .phoneNumber, value: name)
    update.hasVideo = call.hasVideo
    update.supportsHolding = false
    update.localizedCallerName = call.isConference ? "Conference call" : call.members[0].getName()
    
    return update
  }
  
  func reportIncomingCallInternalPush(uuid: UUID, hasVideo: Bool = false) {
    // Create our call Object
    let call = BBCall(uuid: uuid)
    call.hasVideo = hasVideo
    
    call.getInfo { (success) in
      if success {
        DispatchQueue.main.async { [weak self] in
          guard let strongSelf = self else { return }
          // Report the call to CallKit, and let it display the call UI.
          strongSelf.provider.reportNewIncomingCall(with: uuid, update:  strongSelf.getUpdatedCallInfo(call)) { error in
            if error == nil {
              /*
               Only add incoming call to the app's list of calls if the call was allowed (i.e. there was no error)
               since calls may be "denied" for various legitimate reasons. See CXErrorCodeIncomingCallError.
               */
              strongSelf.callManager.addCall(call)
            }
          }
        }
      }
    }
  }

  func providerDidReset(_ provider: CXProvider) {
    logi("Provider did reset")
    /*
     End any ongoing calls if the provider resets, and remove them from the app's list of calls,
     since they are no longer valid.
     */
  }
  
  var outgoingCall: BBCall?
  func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
    guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
      action.fail()
      return
    }
    
    logi("CXStartCallAction \(call.uuid)")
    
    outgoingCall = call
    if let call = outgoingCall {
      call.handle = action.handle.value
      call.hasVideo = action.isVideo
      
      /*
       Configure the audio session, but do not start call audio here, since it must be done once
       the audio session has been activated by the system after having its priority elevated.
       */
      // https://forums.developer.apple.com/thread/64544
      // we can't configure the audio session here for the case of launching it from locked screen
      // instead, we have to pre-heat the AVAudioSession by configuring as early as possible, didActivate do not get called otherwise
      // please look for  * pre-heat the AVAudioSession *
      configureAudioSession()
      
      /*
       Set callback blocks for significant events in the call's lifecycle, so that the CXProvider may be updated
       to reflect the updated state.
       */
      call.hasStartedConnectingDidChange = { [weak self] in
        guard let strongSelf = self else { return }
        strongSelf.provider.reportOutgoingCall(with: call.uuid, startedConnectingAt: call.connectingDate)
        
        // Update the call
        let update = CXCallUpdate()
        update.supportsHolding = false
        
        // Update the call informations
        strongSelf.provider.reportCall(with: call.uuid, updated: update)
        
      }
      call.hasConnectedDidChange = { [weak self] in
        guard let strongSelf = self else { return }
        strongSelf.provider.reportOutgoingCall(with: call.uuid, connectedAt: call.connectDate)
      }
      self.outgoingCall = call
      
      openCallViewController(call, completion: nil)
    }
    
    // Signal to the system that the action has been successfully performed.
    action.fulfill()
    
//    // Create the call object
//    outgoingCall = BBCall(uuid: action.callUUID, isOutgoing: true)
//    if let call = outgoingCall {
//      call.handle = action.handle.value
//      call.hasVideo = action.isVideo
//
//      // retrieve the contact from the handle value (contact registeredNumber)
//      if let contact = Blackbox.shared.getContact(registeredNumber: action.handle.value) {
//        call.members = [contact]
//      }
//      else if let contact = Blackbox.shared.getTemporaryContact(registeredNumber: action.handle.value) {
//        call.members = [contact]
//      }
//      else {
//        action.fail()
//      }
//
//      /*
//       Configure the audio session, but do not start call audio here, since it must be done once
//       the audio session has been activated by the system after having its priority elevated.
//       */
//      // https://forums.developer.apple.com/thread/64544
//      // we can't configure the audio session here for the case of launching it from locked screen
//      // instead, we have to pre-heat the AVAudioSession by configuring as early as possible, didActivate do not get called otherwise
//      // please look for  * pre-heat the AVAudioSession *
//      configureAudioSession()
//
//      /*
//       Set callback blocks for significant events in the call's lifecycle, so that the CXProvider may be updated
//       to reflect the updated state.
//       */
//      call.hasStartedConnectingDidChange = { [weak self] in
//        self?.provider.reportOutgoingCall(with: call.uuid, startedConnectingAt: call.connectingDate)
//      }
//      call.hasConnectedDidChange = { [weak self] in
//        self?.provider.reportOutgoingCall(with: call.uuid, connectedAt: call.connectDate)
//      }
//      self.outgoingCall = call
//
//      openCallViewController(call, completion: nil)
//    }
//
//    // Signal to the system that the action has been successfully performed.
//    action.fulfill()
  }
  
  var answerCall: BBCall?
  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    // Retrieve the SpeakerboxCall instance corresponding to the action's call UUID
    guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
      action.fail()
      return
    }
    
    logi("CXAnswerCallAction \(call.uuid)")
 
    /*
     Configure the audio session, but do not start call audio here, since it must be done once
     the audio session has been activated by the system after having its priority elevated.
     */
    
    // https://forums.developer.apple.com/thread/64544
    // we can't configure the audio session here for the case of launching it from locked screen
    // instead, we have to pre-heat the AVAudioSession by configuring as early as possible, didActivate do not get called otherwise
    // please look for  * pre-heat the AVAudioSession *
    configureAudioSession()
    
    answerCall = call
    
    
    self.timer = DispatchTimer(countdown: .milliseconds(250), repeating: .milliseconds(250)) {
      if call.status.rawValue >= CallStatus.hangup.rawValue {
        self.timer?.disarm()
        self.timer = nil
        return
      }
      self.openCallViewController(call, isOutgoing: false) { (success) in
        if success {
          self.timer?.disarm()
          self.timer = nil
        }
      }
    }
    self.timer?.arm()
    
    // Signal to the system that the action has been successfully performed.
    action.fulfill()
  }
  
  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    // Retrieve the SpeakerboxCall instance corresponding to the action's call UUID
    guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
      action.fail()
      return
    }
    
    logi("CXEndCallAction \(call.uuid)")
    
    if call.status == .ringing {
      // The call has been closed from the CallKit, probably when 2 call where done simultaneously and the user pressed the button "End & Accept"
      call.endCall(userInitiated: true)
    }
    else {
      call.endCall(userInitiated: false)
    }
    
    // Remove the ended call from the app's list of calls.
    callManager.removeCall(call)
    outgoingCall = nil
    answerCall = nil
    // Disarm the timer and set to nil
    timer?.disarm()
    timer = nil
    
    // Signal to the system that the action has been successfully performed.
    action.fulfill()
  }
  
  func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
    // Retrieve the SpeakerboxCall instance corresponding to the action's call UUID
    guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
      action.fail()
      return
    }
    
    logi("CXSetHeldCallAction \(call.uuid)")
    
    // Update the BBCall's underlying hold state.
    call.isOnHold = action.isOnHold
    
    // Stop or start audio in response to holding or unholding the call.
    call.isMuted = call.isOnHold
    
    // If the call hold state has been removed then mute and hold all the other calls.
    if !action.isOnHold {
      callManager.calls.filter { (call) -> Bool in
        call.uuid != action.uuid
      }.forEach { (call) in
        call.isOnHold = true
        call.isMuted = true
      }
    }
    
    // Signal to the system that the action has been successfully performed.
    action.fulfill()
  }
  
  func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    logi("CXSetMutedCallAction")
    // Retrieve the SpeakerboxCall instance corresponding to the action's call UUID
    guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
      action.fail()
      return
    }
    
    logi(action.isMuted)
    call.isMuted = action.isMuted
    
    // Signal to the system that the action has been successfully performed.
    action.fulfill()
  }
  
  func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
    logi("Timed out")
    
    // React to the action timeout if necessary, such as showing an error UI.
    /*
     Restart any non-call related audio now that the app's audio session has been
     de-activated after having its priority restored to normal.
     */
    if outgoingCall?.isOnHold ?? false || answerCall?.isOnHold ?? false {
      logi("Call is on hold. Do not terminate any call")
      return
    }

    if let call = outgoingCall {
      call.endCall(userInitiated: false)
      callManager.removeCall(call)
    } else if let call = answerCall {
      call.endCall(userInitiated: false)
      callManager.removeCall(call)
    }
    outgoingCall = nil
    answerCall = nil
    
    action.fulfill()
  }
  
  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    logi("didActivate audioSession")
    if let call = outgoingCall {
      if call.hasConnected {
        //configureAudioSession()
        // See more details on how this works in the OTDefaultAudioDevice.m method handleInterruptionEvent
        sendFakeAudioInterruptionNotificationToStartAudioResources()
        return
      }
      
      if call.hasVideo {
        call.startVideoCall { [weak self] (success) in
          guard let strongSelf = self else { return }
          if success {
            strongSelf.callManager.addCall(call)
          }
        }
      } else {
        call.startCall { [weak self] (success) in
          guard let strongSelf = self else { return }
          if success {
            strongSelf.callManager.addCall(call)
          }
        }
      }
    }

    if let call = answerCall {
      // If we are returning from a hold state
      if call.hasConnected {
        //configureAudioSession()
        // See more details on how this works in the OTDefaultAudioDevice.m method handleInterruptionEvent
        sendFakeAudioInterruptionNotificationToStartAudioResources();
        return
      }
      
      
      if call.needPassword == false {
        DispatchQueue.global().async {
          while true {
            if call.status.rawValue >= CallStatus.hangup.rawValue {
              break
            }
            if call.members.first != nil {
              if call.hasVideo {
                call.answerVideoCall(audioOnly: true, completion: nil)
              } else {
                call.answerCall(completion: nil)
              }
              break
            }
            // Wait 500ms seconds before trying again
            usleep(500000)
          }
        }
      }
    }
    
  }
  
  func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    logi("didDeactivate audioSession")
    
    /*
     Restart any non-call related audio now that the app's audio session has been
     de-activated after having its priority restored to normal.
     */
    if outgoingCall?.isOnHold ?? false || answerCall?.isOnHold ?? false {
      logi("Call is on hold. Do not terminate any call")
      return
    }
    
    if let call = outgoingCall {
      call.endCall(userInitiated: false)
      callManager.removeCall(call)
    } else if let call = answerCall {
      call.endCall(userInitiated: false)
      callManager.removeCall(call)
    }
    outgoingCall = nil
    answerCall = nil
  }
  
  func sendFakeAudioInterruptionNotificationToStartAudioResources() {
    var userInfo = Dictionary<AnyHashable, Any>()
    let interrupttioEndedRaw = AVAudioSession.InterruptionType.ended.rawValue
    userInfo[AVAudioSessionInterruptionTypeKey] = interrupttioEndedRaw
    NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: self, userInfo: userInfo)
  }
  
  func configureAudioSession() {
    // See https://forums.developer.apple.com/thread/64544
    let session = AVAudioSession.sharedInstance()
    do {
      // See https://forums.developer.apple.com/thread/64544
      try session.setCategory(.playAndRecord, mode: .voiceChat)
      try session.setMode(.voiceChat)
      try session.setPreferredSampleRate(48000)
      try session.setPreferredIOBufferDuration(0.005)
      try session.setActive(true)
    } catch {
      loge(error)
    }
  }
  
  func openCallViewController(_ call: BBCall, isOutgoing: Bool = true, completion block:((Bool)->Void)?) {
    AppUtility.isAppInForeground { result in
      if result, let currentView = Blackbox.shared.currentViewController, Blackbox.shared.callViewController == nil {
        let viewController = CallViewController(call: call)
        // Show the Call View
        viewController.modalTransitionStyle = .crossDissolve
        viewController.modalPresentationStyle = .fullScreen
        currentView.present(viewController, animated: true, completion: nil)
        Blackbox.shared.callViewController = viewController
        block?(true)
      } else {
        block?(false)
      }
    }
  }
  
}
