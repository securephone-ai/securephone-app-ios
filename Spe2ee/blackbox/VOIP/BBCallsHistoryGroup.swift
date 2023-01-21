import Foundation
import DifferenceKit


struct BBCallsHistoryGroup: Hashable, Differentiable {
  var differenceIdentifier: Self {
    return self
  }
  
  var calls: [BBCallHistory] = [] 
  var direction: BBCallDirection
  var date: Date {
    return calls.last!.dateSetup
  }
  var type: BBCallType
  var contact: BBContact? = nil
  var contacts: [BBContact]? = nil
  
  init(calls: [BBCallHistory], direction: BBCallDirection, type: BBCallType, contact: BBContact) {
    self.calls = calls
    self.direction = direction

    self.type = type
    self.contact = contact
  }
  
  init(calls: [BBCallHistory], direction: BBCallDirection, type: BBCallType, contacts: [BBContact]) {
    self.calls = calls
    self.direction = direction
    self.type = type
    self.contacts = contacts
  }
  
  static func == (lhs: BBCallsHistoryGroup, rhs: BBCallsHistoryGroup) -> Bool {
    return lhs.calls == rhs.calls
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(calls)
  }
}
