
import UIKit
import JGProgressHUD

class AboutTableViewController: UITableViewController {
  
  private let cellIdentifier = "AboutCell"
  
  var statusOptions: [String] = ["Available",
                                 "At Meeting",
                                 "On an international trip",
                                 "On a domestic trip",
                                 "Out of service",
                                 "On personal time"]
    
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
    tableView.register(UINib(nibName: "FakeHeaderCell", bundle: nil), forCellReuseIdentifier: FakeHeaderCell.ID)
    
    tableView.tableFooterView = UIView()
    tableView.backgroundColor = .systemGray6
  }

}

// MARK: - Table view data source
extension AboutTableViewController {
  
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    if indexPath.row == 0 {
      return 55
    }
    return UILabel(text: "A", style: .body).requiredHeight + 22
  }
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
    return statusOptions.count + 1
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
  
    if indexPath.row == 0 {
      let cell = tableView.dequeueReusableCell(withIdentifier: FakeHeaderCell.ID, for: indexPath) as! FakeHeaderCell
      cell.headerLabel.text = "Select your about".localized().uppercased()
      cell.selectionStyle = .none
      return cell
    } else {
      let cell = tableView.dequeueReusableCell(withIdentifier: "AboutCell", for: indexPath)
      cell.accessoryType = Blackbox.shared.account.statusMessage == statusOptions[indexPath.row-1] ? .checkmark : .none
      cell.textLabel?.text = statusOptions[indexPath.row-1].localized()
      return cell
    }
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if indexPath.row > 0 {
      let hud = JGProgressHUD(style: .dark)
      hud.show(in: AppUtility.getLastVisibleWindow())
      
      Blackbox.shared.account.setStatus(status: statusOptions[indexPath.row-1]) { (success) in
        DispatchQueue.main.async { [weak self] in
          guard let strongSelf = self else { return }
          hud.dismiss()
          if success {
            strongSelf.tableView.reloadData()
          }
        }
      }
    }
  }
  

  
}
