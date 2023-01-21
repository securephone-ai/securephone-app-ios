import UIKit
import JGProgressHUD
import BlackboxCore

public enum MediaType {
  case photos
  case audio
  case videos
  case documents
}

class MediaAutoDownloadSelection: UITableViewController {
  
  public var mediaType: MediaType!
  
  init(mediaType: MediaType) {
    self.mediaType = mediaType
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard let mediaType = self.mediaType else {
      dismiss(animated: true, completion: nil)
      return
    }
    
    switch mediaType {
    case .photos:
      title = "Photos".localized()
    case .audio:
      title = "Audio".localized()
    case .videos:
      title = "Videos".localized()
    case .documents:
      title = "Documents".localized()
    }
    
    tableView.tableFooterView = UIView()
    tableView.backgroundColor = .systemGray6
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MediaCell")
  }
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 3
  }
  
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 44
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "MediaCell", for: indexPath)
    switch indexPath.row {
    case 0:
      cell.textLabel?.text = "Never".localized()
      cell.accessoryType = getAccessoryType(downloadType: .never)
    case 1:
      cell.textLabel?.text = "Wi-Fi".localized()
      cell.accessoryType = getAccessoryType(downloadType: .wifi)
    case 2:
      cell.textLabel?.text = "Wi-Fi and Cellular".localized()
      cell.accessoryType = getAccessoryType(downloadType: .wifiCellular)
    default:
      cell.textLabel?.text = "Hello".localized()
    }
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let cell = tableView.cellForRow(at: indexPath)
    cell?.accessoryType = .checkmark
    
    for index in 0...2 where index != indexPath.row {
      let item = tableView.cellForRow(at: IndexPath(row: index, section: 0))
      item?.accessoryType = .none
    }
    
    let hud = JGProgressHUD(style: .dark)
    hud.show(in: AppUtility.getLastVisibleWindow())

    DispatchQueue.global(qos: .background).async { [weak self] in
      guard let strongSelf = self else { return }
      
        // default WifiCellular
        var value: UInt32 = 0
        if indexPath.row == 0 {
            // Never
            value = 2
        }
        else if indexPath.row == 1 {
            // Wifi
            value = 1
        }
        
        let autoDownload = AutoDownload(rawValue: value)
        
        let blackbox = Blackbox.shared
        
        let autoDownloadPhotos = strongSelf.mediaType == .photos ?
            autoDownload : AutoDownload(rawValue: UInt32(blackbox.account.settings.autoDownloadPhotos.toApiValue())!)
        let autoDownloadAudios = strongSelf.mediaType == .photos ?
            autoDownload : AutoDownload(rawValue: UInt32(blackbox.account.settings.autoDownloadAudios.toApiValue())!)
        let autoDownloadVideos = strongSelf.mediaType == .photos ?
            autoDownload : AutoDownload(rawValue: UInt32(blackbox.account.settings.autoDownloadVideos.toApiValue())!)
        let autoDownloadDocuments = strongSelf.mediaType == .photos ?
            autoDownload : AutoDownload(rawValue: UInt32(blackbox.account.settings.autoDownloadDocuments.toApiValue())!)
        
        
        guard let jsonString = BlackboxCore.accountSetSettings(blackbox.account.settings.calendar.toString().lowercased(),
                                                               language: blackbox.account.settings.language,
                                                               onlineVisibility: blackbox.account.settings.onlineVisibility,
                                                               autoDownloadPhotos: autoDownloadPhotos,
                                                               autoDownloadAudios: autoDownloadAudios,
                                                               autoDownloadVideos: autoDownloadVideos,
                                                               autoDownloadDocuments: autoDownloadDocuments) else {
            DispatchQueue.main.async {
                hud.dismiss()
            }
            return
        }
        
        logPrettyJsonString(jsonString)
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            do {
                let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    logi("Settings succesfully changed")
                    
                    switch strongSelf.mediaType {
                    case .photos:
                        if indexPath.row == 0 {
                            blackbox.account.settings.autoDownloadPhotos = .never
                        } else if indexPath.row == 1 {
                            blackbox.account.settings.autoDownloadPhotos = .wifi
                        } else {
                            blackbox.account.settings.autoDownloadPhotos = .wifiCellular
                        }
                    case .audio:
                        if indexPath.row == 0 {
                            blackbox.account.settings.autoDownloadAudios = .never
                        } else if indexPath.row == 1 {
                            blackbox.account.settings.autoDownloadAudios = .wifi
                        } else {
                            blackbox.account.settings.autoDownloadAudios = .wifiCellular
                        }
                    case .videos:
                        if indexPath.row == 0 {
                            blackbox.account.settings.autoDownloadVideos = .never
                        } else if indexPath.row == 1 {
                            blackbox.account.settings.autoDownloadVideos = .wifi
                        } else {
                            blackbox.account.settings.autoDownloadVideos = .wifiCellular
                        }
                    case .documents:
                        if indexPath.row == 0 {
                            blackbox.account.settings.autoDownloadDocuments = .never
                        } else if indexPath.row == 1 {
                            blackbox.account.settings.autoDownloadDocuments = .wifi
                        } else {
                            blackbox.account.settings.autoDownloadDocuments = .wifiCellular
                        }
                    default:
                        break
                    }
                    
                } else {
                    loge("Settings change Failed")
                }
            } catch {
                loge(error)
            }
            
            hud.dismiss()
        }
    }
  }
  
  private func getAccessoryType(downloadType: AutoDownloadType) -> UITableViewCell.AccessoryType {
    switch mediaType {
    case .audio:
      return Blackbox.shared.account.settings.autoDownloadAudios == downloadType ? .checkmark : .none
    case .videos:
      return Blackbox.shared.account.settings.autoDownloadVideos == downloadType ? .checkmark : .none
    case .photos:
      return Blackbox.shared.account.settings.autoDownloadPhotos == downloadType ? .checkmark : .none
    case .documents:
      return Blackbox.shared.account.settings.autoDownloadDocuments == downloadType ? .checkmark : .none
    default:
      return .none
    }
  }
  
}
