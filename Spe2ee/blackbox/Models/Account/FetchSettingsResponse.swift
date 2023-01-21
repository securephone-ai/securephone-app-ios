
import Foundation

/// JSON Object for **bb_get_configuration**
struct FetchSettingsResponse: BBResponse {
  let answer: String
  let message: String
  let settings: BBSettings
  
  private enum CodingKeys : String, CodingKey {
    case answer
    case message
    case calendar
    case language
    case onlineVisibility = "onlinevisibility"
    case autoDownloadPhotos = "autodownloadphotos"
    case autoDownloadAudios = "autodownloadaudio"
    case autoDownloadVideos = "autodownloadvideos"
    case autoDownloadDocuments = "autodownloaddocuments"
    case maxFileSizeMB = "maximumfilesizemb"
    case supportInAppChatNumber = "supportinappchatnumber"
    case supportInAppCallNumber = "supportinappcallnumber"
    case supportCallNumber = "supportcallnumber"
    case allowedFileType = "allowedfiletype"
    case whiteListedUrls = "urlwhitelist"
    case blackListedUrls = "urlblacklist"
    case canShareUrl = "urlsharing"
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.answer = (try? container.decode(String.self, forKey: .answer)) ?? ""
    self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
    
    let calendar = (try? container.decode(String.self, forKey: .calendar)) ?? ""
    let language = (try? container.decode(String.self, forKey: .language)) ?? ""
    let onlineVisibility = (try? container.decode(String.self, forKey: .onlineVisibility)) ?? ""
    let autoDownloadPhotos = (try? container.decode(String.self, forKey: .autoDownloadPhotos)) ?? ""
    let autoDownloadAudios = (try? container.decode(String.self, forKey: .autoDownloadAudios)) ?? ""
    let autoDownloadVideos = (try? container.decode(String.self, forKey: .autoDownloadVideos)) ?? ""
    let autoDownloadDocuments = (try? container.decode(String.self, forKey: .autoDownloadDocuments)) ?? ""
    let maxFileSizeMBString = (try? container.decode(String.self, forKey: .maxFileSizeMB)) ?? ""
    var maxFileSize = Int(maxFileSizeMBString) ?? 60
    maxFileSize = maxFileSize * 1000000
    
    let allowedFileTypeString = (try? container.decode(String.self, forKey: .allowedFileType)) ?? ""
    let allowedFileType = allowedFileTypeString.components(separatedBy: ",").filter { $0.isEmpty == false }
    
    let canShareUrlString = (try? container.decode(String.self, forKey: .canShareUrl)) ?? "Y"
    
    self.settings = BBSettings(
      calendar: calendar == "gregorian" ? .gregorian : .islamic,
      language: language,
      onlineVisibility: onlineVisibility == "Y",
      autoDownloadPhotos: BBSettings.downloadTypeStringToEnum(type: autoDownloadPhotos),
      autoDownloadAudios: BBSettings.downloadTypeStringToEnum(type: autoDownloadAudios),
      autoDownloadVideos: BBSettings.downloadTypeStringToEnum(type: autoDownloadVideos),
      autoDownloadDocuments: BBSettings.downloadTypeStringToEnum(type: autoDownloadDocuments),
      maxDownloadableFileSize: maxFileSize,
      supportInAppChatNumber: (try? container.decode(String.self, forKey: .supportInAppChatNumber)) ?? "",
      supportInAppCallNumber: (try? container.decode(String.self, forKey: .supportInAppCallNumber)) ?? "",
      supportCallNumber: (try? container.decode(String.self, forKey: .supportCallNumber)) ?? "",
      allowedFileType: allowedFileType,
      whiteListedUrls: (try? container.decode([String].self, forKey: .whiteListedUrls)) ?? [],
      blackListedUrls: (try? container.decode([String].self, forKey: .blackListedUrls)) ?? [],
      canShareUrl: canShareUrlString == "Y"
    )
    
  }
  
}
