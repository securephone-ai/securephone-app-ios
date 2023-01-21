
import UIKit

class ChatPreferencesTableViewController: UITableViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.tableFooterView = UIView()
    tableView.backgroundColor = .systemGray6
  }
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
//    if section == 0 {
//      return 1
//    }
//    return 2
    
    return 1
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
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.accessoryType = .disclosureIndicator
    
    if indexPath.section == 0 {
      cell.textLabel?.text = "Wallpaper Library".localized()
    } else {
      cell.textLabel?.textColor = .red
      if indexPath.row == 0 {
        cell.textLabel?.text = "Clear All Chats".localized()
      } else {
        cell.textLabel?.text = "Delete All Chats".localized()
      }
    }
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    navigationController?.pushViewController(WallpaperListViewController(), animated: true)
  }
}
