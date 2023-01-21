
import UIKit

class NetworkUsage: UITableViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    title = "Network Usage".localized()
    
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
    return 22
  }
  
}

