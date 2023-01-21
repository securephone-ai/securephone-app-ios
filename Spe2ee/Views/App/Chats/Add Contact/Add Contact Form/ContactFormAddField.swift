
import Foundation
import UIKit

protocol ContactFormAddFieldDelegate: class {
  func didAddField(field: String)
}

class ContactFormAddField: UITableViewController {
  weak var delegate: ContactFormAddFieldDelegate?
  
  var viewModel: AddNewContactViewModel
  var items: [Int: [String]] = [Int: [String]]()
  var sections = 1
  
  var isNameSectionVisible = false
  var isJobSectionVisible = false
  
  // Nav bar buttons
  var leftButtonBar = UIBarButtonItem()
  
  init(viewModel: AddNewContactViewModel) {
    self.viewModel = viewModel
    
    if !viewModel.isPrefixVisible || !viewModel.isPhoneticNameVisible || !viewModel.isMiddlenameVisible || !viewModel.isPhoneticMiddlenameVisible ||
      !viewModel.isPhoneticSurnameVisible || !viewModel.isMaidennameVisible || !viewModel.isSuffixVisible || !viewModel.isNicknameVisible {
      sections += 1
      isNameSectionVisible = true
    }
    
    if !viewModel.isJobtitleVisible || !viewModel.isDepartmentVisible || !viewModel.isPhoneticCompanyNameVisible {
      sections += 1
      isJobSectionVisible = true
    }
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.tableFooterView = UIView()
    tableView.backgroundColor = .systemGray5
    tableView.contentInset.top = 30
    
    leftButtonBar = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissView))
    self.navigationItem.leftBarButtonItem = leftButtonBar
    
    if isNameSectionVisible {
      if !viewModel.isPrefixVisible {
        addItem(to: 0, item: "Prefix".localized())
      }
      if !viewModel.isPhoneticNameVisible {
        addItem(to: 0, item: "Phonetic first name".localized())
      }
      if !viewModel.isMiddlenameVisible {
        addItem(to: 0, item: "Middle name".localized())
      }
      if !viewModel.isPhoneticMiddlenameVisible {
        addItem(to: 0, item: "Phonetic middle name".localized())
      }
      if !viewModel.isPhoneticSurnameVisible {
        addItem(to: 0, item: "Phonetic last name".localized())
      }
      if !viewModel.isMaidennameVisible {
        addItem(to: 0, item: "Maiden name".localized())
      }
      if !viewModel.isSuffixVisible {
        addItem(to: 0, item: "Suffix".localized())
      }
      if !viewModel.isNicknameVisible {
        addItem(to: 0, item: "Nickname".localized())
      }
    }
    
    if isJobSectionVisible {
      let section = isNameSectionVisible ? 1 : 0
      if !viewModel.isJobtitleVisible {
        addItem(to: section, item: "Job title".localized())
      }
      if !viewModel.isDepartmentVisible {
        addItem(to: section, item: "Department".localized())
      }
      if !viewModel.isPhoneticCompanyNameVisible {
        addItem(to: section, item: "Phonetic company name".localized())
      }
    }
    
    // Add always present field
    addItem(to: sections-1, item: "Phone".localized())
    addItem(to: sections-1, item: "Email".localized())
    addItem(to: sections-1, item: "Address".localized())
    addItem(to: sections-1, item: "URL".localized())
    if !viewModel.isBirthdayVisible {
      addItem(to: sections-1, item: "Birthday".localized())
    }
    addItem(to: sections-1, item: "Date".localized())
    addItem(to: sections-1, item: "Social profile".localized())
    addItem(to: sections-1, item: "Instant message".localized())
  }
  
  @objc func dismissView() {
    dismiss(animated: true, completion: nil)
  }
  
  func addItem(to section: Int, item: String) {
    if var _ = self.items[section] {
      self.items[section]?.append(item)
    } else {
      self.items[section] = [item]
    }
  }
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return sections
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if let items = self.items[section] {
      return items.count
    }
    return 0
  }
  
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return section > 0 ? 30 : 0
  }
  
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    if section == 0 {
      return nil
    }
    let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 30))
    view.backgroundColor = .systemGray5
    return view
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let items = self.items[indexPath.section] else {
      return UITableViewCell()
    }
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.textLabel!.text = items[indexPath.row]
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard let delegate = self.delegate else { return }
    if let cell = tableView.cellForRow(at: indexPath) {
      delegate.didAddField(field: cell.textLabel!.text!)
    }
    
    dismissView()
  }
  
  
}


