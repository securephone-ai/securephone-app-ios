
import Foundation

extension Date {
  func isEqual(to date: Date, toGranularity component: Calendar.Component, in calendar: Calendar = .current) -> Bool {
    calendar.isDate(self, equalTo: date, toGranularity: component)
  }
  
  func isInSameYear (date: Date) -> Bool { isEqual(to: date, toGranularity: .year) }
  func isInSameMonth(date: Date) -> Bool { isEqual(to: date, toGranularity: .month) }
  func isInSameDay  (date: Date) -> Bool { isEqual(to: date, toGranularity: .day) }
  func isInSameWeek (date: Date) -> Bool { isEqual(to: date, toGranularity: .weekOfYear) }
  
  func inSameDayAs(date: Date) -> Bool {
    let calendar = Calendar.current
    return calendar.isDate(self, inSameDayAs: date)
  }
  
  func epochConversion(from: TimeZone, to: TimeZone) -> Date {
    let delta = TimeInterval(to.secondsFromGMT(for: self) - from.secondsFromGMT(for: self))
    return addingTimeInterval(delta)
  }
  
  func convert(from initTimeZone: TimeZone, to targetTimeZone: TimeZone) -> Date {
    let delta = TimeInterval(targetTimeZone.secondsFromGMT(for: self) - initTimeZone.secondsFromGMT(for: self))
    return addingTimeInterval(delta)
  }
  
  func dateToIslamicCalendarComponents() -> DateComponents? {
    let islamic = NSCalendar(identifier: NSCalendar.Identifier.islamicUmmAlQura)
    return islamic?.components(NSCalendar.Unit(rawValue: UInt.max), from: self)
  }
  
  func timeString12Hour() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "h:mm a"
    dateFormatter.amSymbol = "AM".localized()
    dateFormatter.pmSymbol = "PM".localized()
    return dateFormatter.string(from: self)
  }
  
  func dateStringIslamic(withFormat format: String) -> String {
    if let islamicComponents = self.dateToIslamicCalendarComponents(),
      let year = islamicComponents.year,
      let month = islamicComponents.month,
      let day = islamicComponents.day {
      return "\(year)/\(month)/\(day)"
    }
    // fallback
    return self.string(withFormat: format)
  }
  
}
