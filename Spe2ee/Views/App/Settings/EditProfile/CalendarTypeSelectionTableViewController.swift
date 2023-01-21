import UIKit
import JGProgressHUD
import BlackboxCore



class CalendarTypeSelectionTableViewController: UITableViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.backgroundColor = .systemGray6
    tableView.tableFooterView = UIView()
  }
  
  // MARK: - Table view data source
  
  
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 34
  }
  
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let view = UIView()
    view.isUserInteractionEnabled = false
    return view
  }
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
    return 2
  }
  
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    if indexPath.row == 0 {
      cell.textLabel?.text = CalendarType.gregorian.toString()
      cell.accessoryType = Blackbox.shared.account.settings.calendar == .gregorian ? .checkmark : .none
    } else {
      cell.textLabel?.text = CalendarType.islamic.toString()
      cell.accessoryType = Blackbox.shared.account.settings.calendar == .islamic ? .checkmark : .none
    }
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    
    let blackbox = Blackbox.shared
    if indexPath.row == 0 && blackbox.account.settings.calendar == .gregorian {
      return
    }
    if indexPath.row == 1 && blackbox.account.settings.calendar == .islamic {
      return
    }
    blackbox.account.settings.calendar = indexPath.row == 0 ? .gregorian : .islamic
    
    tableView.reloadData()
    
    let hud = JGProgressHUD(style: .dark)
    hud.show(in: AppUtility.getLastVisibleWindow())
    
    DispatchQueue.global(qos: .background).async {
        let blackbox = Blackbox.shared
        guard let jsonString = BlackboxCore.accountSetSettings(blackbox.account.settings.calendar.toString().lowercased(),
                                                               language: blackbox.account.settings.language,
                                                               onlineVisibility: blackbox.account.settings.onlineVisibility,
                                                               autoDownloadPhotos: AutoDownload(UInt32(blackbox.account.settings.autoDownloadPhotos.toInt())),
                                                               autoDownloadAudios: AutoDownload(UInt32(blackbox.account.settings.autoDownloadAudios.toInt())),
                                                               autoDownloadVideos: AutoDownload(UInt32(blackbox.account.settings.autoDownloadVideos.toInt())),
                                                               autoDownloadDocuments: AutoDownload(UInt32(blackbox.account.settings.autoDownloadDocuments.toInt()))) else {
            DispatchQueue.main.async {
                hud.dismiss()
            }
            return
        }
        
        logPrettyJsonString(jsonString)
        
        DispatchQueue.main.async {
            do {
                let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    logi("Settings succesfully changed")
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
  
}

