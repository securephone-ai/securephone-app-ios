import Foundation
import DifferenceKit

/// Call History View Model. Connect the Model (data) and the View
class CallHistoryCellViewModel: Hashable, Differentiable {
  
  var callGroup: BBCallsHistoryGroup!
  
  var contact: BBContact? {
    return callGroup.contact
  }
  var contacts: [BBContact]? {
    return callGroup.contacts
  }
  var totalCalls: Int {
    return callGroup.calls.count
  }
  
  lazy var callDate: String  = {
    if callGroup.date.isInToday {
      return callGroup.date.timeString12Hour()
    } else if callGroup.date.isInYesterday {
      return "Yesterday".localized()
    } else if callGroup.date.isInCurrentWeek {
      return callGroup.date.dayName()
    } else {
      return Blackbox.shared.account.settings.calendar == .gregorian ? callGroup.date.string(withFormat: "dd/MM/yy") : callGroup.date.dateStringIslamic(withFormat: "dd/MM/yy")
    }
  }()
  
  /// Delete/Swipe request initiated from the Delete Button Icon present on the cell.
  /// Used as a Flag to show the Swipe action even during Edit Mode.
  var deleteRequest = false
  @Published var isEditing = false
  
  init(callGroup: BBCallsHistoryGroup) {
    self.callGroup = callGroup
  }
  
  static func == (lhs: CallHistoryCellViewModel, rhs: CallHistoryCellViewModel) -> Bool {
    return lhs.callGroup == rhs.callGroup
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(callGroup)
  }

}

