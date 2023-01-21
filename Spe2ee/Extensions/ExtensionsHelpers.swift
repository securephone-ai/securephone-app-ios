
import Foundation

extension DateComponents {
  
  var isToday: Bool {
    let currentComponents = Calendar.current.dateComponents([.day, .weekOfYear], from: Date())
    if day == currentComponents.day, weekOfYear == currentComponents.weekOfYear {
      return true
    } else {
      return false
    }
  }
  
  var isCurrentYear: Bool {
    let currentComponents = Calendar.current.dateComponents([.year], from: Date())
    if year == currentComponents.year {
      return true
    } else {
      return false
    }
  }

  var isCurrentWeek: Bool {
    let currentComponents = Calendar.current.dateComponents([.weekOfYear], from: Date())
    if weekOfYear == currentComponents.weekOfYear {
      return true
    } else {
      return false
    }
  }
  
}
