import UIKit
import DeviceKit



class StorageUsageTableViewController: UITableViewController {

  private lazy var spaceUsed: Double = {
    return appSizeInMegaBytes() / 1_000
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.backgroundColor = .systemGray6
    tableView.register(StorageCell.self, forCellReuseIdentifier: StorageCell.ID)
    tableView.tableFooterView = UIView()
  }
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
    return 2
  }
  
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 34
  }
  
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let view = UIView()
    view.isUserInteractionEnabled = false
    return view
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: StorageCell.ID) as! StorageCell
    if indexPath.row == 0 {
      cell.descriptionLabel.text = "App size".localized()
      
      if spaceUsed < 1 {
        let space = (spaceUsed * 1000).rounded(toPlaces: 1)
        cell.detailLabel.text = "\(space) MB"
      } else {
        let space = spaceUsed.rounded(toPlaces: 1)
        cell.detailLabel.text = "\(space) GB"
      }
    } else {
      cell.descriptionLabel.text = "Available space".localized()
      if let volumeAvailableCapacityForImportantUsage = Device.volumeAvailableCapacityForImportantUsage {
        cell.detailLabel.text = "\( ceill((Double(volumeAvailableCapacityForImportantUsage) / 1_000_000_000))) GB"
      } else {
        cell.detailLabel.text = "-- / --"
      }
    }
    return cell
  }
  
  private func appSizeInMegaBytes() -> Float64 { // approximate value
    
    // create list of directories
    var paths = [Bundle.main.bundlePath] // main bundle
    let docDirDomain = FileManager.SearchPathDirectory.documentDirectory
    let docDirs = NSSearchPathForDirectoriesInDomains(docDirDomain, .userDomainMask, true)
    if let docDir = docDirs.first {
      paths.append(docDir) // documents directory
    }
    let libDirDomain = FileManager.SearchPathDirectory.libraryDirectory
    let libDirs = NSSearchPathForDirectoriesInDomains(libDirDomain, .userDomainMask, true)
    if let libDir = libDirs.first {
      paths.append(libDir) // library directory
    }
    paths.append(NSTemporaryDirectory() as String) // temp directory
    
    
    // combine sizes
    var totalSize: Float64 = 0
    for path in paths {
      if let size = bytesIn(directory: path) {
        totalSize += size
      }
    }
    return totalSize / 1000000 // megabytes
  }
  
  private func bytesIn(directory: String) -> Float64? {
    let fm = FileManager.default
    guard let subdirectories = try? fm.subpathsOfDirectory(atPath: directory) as NSArray else {
      return nil
    }
    let enumerator = subdirectories.objectEnumerator()
    var size: UInt64 = 0
    while let fileName = enumerator.nextObject() as? String {
      do {
        let fileDictionary = try fm.attributesOfItem(atPath: directory.appending("/" + fileName)) as NSDictionary
        size += fileDictionary.fileSize()
      } catch let err {
        loge("err getting attributes of file \(fileName): \(err.localizedDescription)")
      }
    }
    return Float64(size)
  }
  
}

