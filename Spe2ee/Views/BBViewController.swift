import Foundation


/// Base Blackbox UIViewController
class BBViewController: UIViewController {
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    Blackbox.shared.currentViewController = self
  }
}


/// Base Blackbox UITableViewController
class BBTableViewController: UITableViewController {
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    Blackbox.shared.currentViewController = self
  }
}
