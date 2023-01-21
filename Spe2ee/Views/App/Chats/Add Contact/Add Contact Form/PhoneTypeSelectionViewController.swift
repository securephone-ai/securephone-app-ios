import UIKit

protocol PhoneTypeSelectionViewControllerDelegate: class {
  func didSelectPhoneType(type: String)
}

class PhoneTypeSelectionViewController: UITableViewController {

  weak var delegate: PhoneTypeSelectionViewControllerDelegate?
  private var selectedType  = "mobile".localized()
  // Nav bar buttons
  var leftButtonBar = UIBarButtonItem()
  var rightButtonBar = UIBarButtonItem()
  
  init(selectedType: String) {
    super.init(nibName: nil, bundle: nil)
    self.selectedType = selectedType
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.tableView.backgroundColor = .systemGray5
    self.tableView.tableFooterView = UIView()
    self.tableView.contentInset.top = 30
    self.title = "Phone type".localized()
    
    leftButtonBar = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissView))
    rightButtonBar = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
    self.navigationItem.leftBarButtonItem = leftButtonBar
    self.navigationItem.rightBarButtonItem = rightButtonBar
  }
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 6
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    
    switch indexPath.row {
    case 0:
      cell.textLabel?.text = "mobile".localized()
      cell.accessoryType = selectedType == "mobile".localized() ? .checkmark : .none
    case 1:
      cell.textLabel?.text = "home".localized()
      cell.accessoryType = selectedType == "home".localized() ? .checkmark : .none
    case 2:
      cell.textLabel?.text = "work".localized()
      cell.accessoryType = selectedType == "work".localized() ? .checkmark : .none
    case 3:
      cell.textLabel?.text = "iPhone".localized()
      cell.accessoryType = selectedType == "iPhone".localized() ? .checkmark : .none
    case 4:
      cell.textLabel?.text = "main".localized()
      cell.accessoryType = selectedType == "main".localized() ? .checkmark : .none
    case 5:
      cell.textLabel?.text = "other".localized()
      cell.accessoryType = selectedType == "other".localized() ? .checkmark : .none
    default:
      return UITableViewCell()
    }
    
    return cell
  }
   
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if let cell = tableView.cellForRow(at: indexPath)  {
      selectedType = cell.textLabel!.text!
      tableView.reloadData()
      
      guard let delegate = self.delegate else { return }
      delegate.didSelectPhoneType(type: selectedType)
    }
    self.dismiss(animated: true, completion: nil)
  }
  
  
  @objc func dismissView() {
    self.dismiss(animated: true, completion: nil)
  }
  
  @objc func done() {
    guard let delegate = self.delegate else { return }
    delegate.didSelectPhoneType(type: selectedType)
    self.dismiss(animated: true, completion: nil)
  }
}

