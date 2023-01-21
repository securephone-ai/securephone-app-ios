// This class is used to keep track of the calls list and
// act as a CXTransaction Manager.

import Foundation
import CallKit
import Combine

final class BBCallManager: NSObject {
  let callController = CXCallController()
  @Published private(set) var calls: [BBCall] = [BBCall]()
  
  // MARK: Actions
  private func requestTransaction(_ transaction: CXTransaction, action: String = "") {
    callController.request(transaction) { error in
      if let error = error {
        loge("Error requesting transaction: \(error)")
      } else {
        logi("Requested transaction \(action) successfully")
      }
    }
  }
  
  func startConferenceCall(contacts: [BBContact], video: Bool = false) {
    // clean up any previous call status for each contact
    for contact in contacts {
      contact.callInfo.callStatus = .none
    }
    
    let call = BBCall(uuid: UUID(), isOutgoing: true)
    call.members = contacts
    call.isConference = true
    addCall(call)
    
    let startCallAction = CXStartCallAction(call: call.uuid, handle: CXHandle(type: .phoneNumber,
                                                                              value: call.isConference ? "Conference" : call.members.first?.registeredNumber ?? ""))
    
    startCallAction.isVideo = video
    
    let transaction = CXTransaction()
    transaction.addAction(startCallAction)
    
    requestTransaction(transaction, action: "startCall")
  }
  
  func startCall(contact: BBContact, video: Bool = false) {
    let call = BBCall(uuid: UUID(), isOutgoing: true)
    call.members = [contact]
    call.isConference = false
    addCall(call)
    
    print("call uuid \(call.uuid) and number is \(contact.registeredNumber)")
    
    let startCallAction = CXStartCallAction(call: call.uuid,
                                            handle: CXHandle(type: .phoneNumber, value: contact.registeredNumber))
    
    startCallAction.isVideo = video
    
    let transaction = CXTransaction()
    transaction.addAction(startCallAction)
    
    requestTransaction(transaction, action: "startCall")
  }
  
  func end(call: BBCall) {
    if let call = callWithUUID(uuid: call.uuid) {
      let endCallAction = CXEndCallAction(call: call.uuid)
      let transaction = CXTransaction()
      transaction.addAction(endCallAction)
      
      requestTransaction(transaction, action: "endCall")
    }
  }
  
  func setHeld(call: BBCall, onHold: Bool) {
    let setHeldCallAction = CXSetHeldCallAction(call: call.uuid, onHold: onHold)
    let transaction = CXTransaction()
    transaction.addAction(setHeldCallAction)
    
    requestTransaction(transaction, action: "holdCall")
  }
  
  func setMute(call: BBCall, isMuted: Bool) {
    let setMuteCallAction = CXSetMutedCallAction(call: call.uuid, muted: isMuted)
    let transaction = CXTransaction()
    transaction.addAction(setMuteCallAction)
    
    requestTransaction(transaction, action: "muteCall")
  }
  
  // MARK: Call Management
  
  func callWithUUID(uuid: UUID) -> BBCall? {
    guard let index = calls.firstIndex(where: { $0.uuid == uuid }) else {
      return nil
    }
    return calls[index]
  }
  
  /// Add the call to the calls list
  /// - Parameter call: The call to add
  func addCall(_ call: BBCall) {
    guard !calls.contains(where: { call.uuid == $0.uuid }) else { return }
    calls.append(call)
  }
  
  func removeCall(_ call: BBCall) {
    calls = calls.filter { $0.uuid != call.uuid}
  }
  
  func getActiveCall() -> BBCall? {
    guard let index = calls.firstIndex(where: { !$0.isOnHold }) else {
      return nil
    }
    return calls[index]
  }
  
}
