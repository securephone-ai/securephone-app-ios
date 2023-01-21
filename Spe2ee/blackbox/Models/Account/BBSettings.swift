import Foundation

enum AutoDownloadType {
  case never
  case wifi
  case wifiCellular
  
  func toString() -> String {
    switch self {
    case .never:
      return "Never".localized()
    case .wifi:
      return "Wi-Fi".localized()
    case .wifiCellular:
      return "Wi-Fi and Cellular".localized()
    }
  }
  
  func toApiValue() -> String {
    switch self {
    case .never:
      return "2".localized()
    case .wifi:
      return "1".localized()
    case .wifiCellular:
      return "0".localized()
    }
  }
    
    func toInt() -> Int {
        switch self {
        case .never:
            return 2
        case .wifi:
            return 1
        case .wifiCellular:
            return 0
        }
    }
}

enum CalendarType {
  case gregorian
  case islamic
  
  func toString() -> String {
    self == .gregorian ? "Gregorian".localized() : "Islamic".localized()
  }
}

/// Account settings 
struct BBSettings {
  var calendar: CalendarType = AppUtility.isArabic ? .islamic : .gregorian
  var language: String = AppUtility.isArabic ? "ar" : "en"
  var onlineVisibility: Bool = false
  var autoDownloadPhotos: AutoDownloadType = .wifiCellular
  var autoDownloadAudios: AutoDownloadType = .wifiCellular
  var autoDownloadVideos: AutoDownloadType = .wifiCellular
  var autoDownloadDocuments: AutoDownloadType = .wifiCellular
  var maxDownloadableFileSize: Int = 60 * 1000000 // bytes
  var supportInAppChatNumber: String = ""
  var supportInAppCallNumber: String = ""
  var supportCallNumber: String = ""
  var contactNotificationSoundName: String = ""
  var groupNotificationSoundName: String = ""
  var allowedFileType: [String] = []
  var whiteListedUrls: [String] = []
  var blackListedUrls: [String] = []
  var canShareUrl: Bool = true
  
  static func downloadTypeStringToEnum(type: String) -> AutoDownloadType {
    if type == "1" {
      return .wifi
    } else if type == "2" {
      return .never
    }
    return .wifiCellular
  }
}
