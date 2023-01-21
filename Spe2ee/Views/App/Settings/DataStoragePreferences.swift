import UIKit
import JGProgressHUD
import BlackboxCore

class DataStoragePreferences: UITableViewController {
    
    @IBOutlet weak var photosAutoDownloadTypeLabel: UILabel!
    @IBOutlet weak var audiosAutoDownloadTypeLabel: UILabel!
    @IBOutlet weak var videosAutoDownloadTypeLabel: UILabel!
    @IBOutlet weak var documentsAutoDownloadTypeLabel: UILabel!
    
    let fakeRows = [0, 5, 6, 8]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = .systemGray6
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let blackbox = Blackbox.shared
        photosAutoDownloadTypeLabel.text = blackbox.account.settings.autoDownloadPhotos.toString()
        audiosAutoDownloadTypeLabel.text = blackbox.account.settings.autoDownloadAudios.toString()
        videosAutoDownloadTypeLabel.text = blackbox.account.settings.autoDownloadVideos.toString()
        documentsAutoDownloadTypeLabel.text = blackbox.account.settings.autoDownloadDocuments.toString()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 12
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.row {
        case 1:
            let vc = MediaAutoDownloadSelection(mediaType: .photos)
            navigationController?.pushViewController(vc, animated: true)
        case 2:
            let vc = MediaAutoDownloadSelection(mediaType: .audio)
            navigationController?.pushViewController(vc, animated: true)
        case 3:
            let vc = MediaAutoDownloadSelection(mediaType: .videos)
            navigationController?.pushViewController(vc, animated: true)
        case 4:
            let vc = MediaAutoDownloadSelection(mediaType: .documents)
            navigationController?.pushViewController(vc, animated: true)
        case 5:
            resetMediaAutoDownloadSettings()
        case 10:
            let storyboard = UIStoryboard(name: "NetworkUsage", bundle: nil)
            let vc = storyboard.instantiateViewController(identifier: "NetworkUsage") as! NetworkUsage
            navigationController?.pushViewController(vc, animated: true)
        default:
            return
        }
    }
    
    private func resetMediaAutoDownloadSettings() {
        let hud = JGProgressHUD(style: .dark)
        hud.show(in: AppUtility.getLastVisibleWindow())
        
        DispatchQueue.global(qos: .background).async {
            let blackbox = Blackbox.shared
            guard let jsonString = BlackboxCore.accountSetSettings(blackbox.account.settings.calendar.toString().lowercased(),
                                                                   language: blackbox.account.settings.language,
                                                                   onlineVisibility: blackbox.account.settings.onlineVisibility,
                                                                   autoDownloadPhotos: WifiCellular,
                                                                   autoDownloadAudios: WifiCellular,
                                                                   autoDownloadVideos: WifiCellular,
                                                                   autoDownloadDocuments: WifiCellular) else {
                DispatchQueue.main.async {
                    hud.dismiss()
                }
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }
                    if response.isSuccess() {
                        logi("Settings succesfully changed")
                        blackbox.account.settings.autoDownloadAudios = .wifiCellular
                        blackbox.account.settings.autoDownloadPhotos = .wifiCellular
                        blackbox.account.settings.autoDownloadVideos = .wifiCellular
                        blackbox.account.settings.autoDownloadDocuments = .wifiCellular
                        
                        strongSelf.photosAutoDownloadTypeLabel.text = blackbox.account.settings.autoDownloadPhotos.toString()
                        strongSelf.audiosAutoDownloadTypeLabel.text = blackbox.account.settings.autoDownloadAudios.toString()
                        strongSelf.videosAutoDownloadTypeLabel.text = blackbox.account.settings.autoDownloadVideos.toString()
                        strongSelf.documentsAutoDownloadTypeLabel.text = blackbox.account.settings.autoDownloadDocuments.toString()
                        
                    } else {
                        loge("Settings change Failed")
                    }
                    hud.dismiss()
                }
            } catch {
                loge(error)
                DispatchQueue.main.async {
                    hud.dismiss()
                }
            }
        }
    }
    
}


