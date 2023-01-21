
import UIKit
import Contacts
import PinLayout

class ContactsPickerViewController: UIViewController {
  
  /// Contacts Picker Reference
  public var contactsPicker: ContactsPicker?
  
  /// Screen total with
  public var totalWidth:CGFloat{
    get{
      return UIScreen.main.bounds.width
    }
  }
  
  /// Screen total height
  public var totalHeight:CGFloat{
    get{
      return UIScreen.main.bounds.height
    }
  }
  
  // Nav bar buttons
  var leftButtonBar   : UIBarButtonItem?
  var rightButtonBar  : UIBarButtonItem = UIBarButtonItem()
  
  // Searched string
  var searchString  = ""
  
  // Flag
  var presentedModally = false
  
  open fileprivate(set) lazy var contentView: ContactsPickerView = {
    let view = ContactsPickerView()
    view.tableView.delegate = self
    view.tableView.dataSource = self
    view.tableView.register(ContactsPickerTableCell.self, forCellReuseIdentifier: ContactsPickerTableCell.ID)
    view.selectionScrollView.delegate = self
    view.selectionScrollView.dataSource = self
    view.selectionScrollView.register(ContactsPickerHeaderCollectionCell.self,
                                      forCellWithReuseIdentifier: ContactsPickerHeaderCollectionCell.ID)
    view.searchBar.delegate = self
    return view
  }()
  
  /// Array of selected items
  open var selectedItems: [ContactItem] = [ContactItem]() {
    didSet {
      //Reset button navigation bar
      rightButtonBar.title = "\(ContactsPickerConfig.doneString) (\(self.selectedItems.count))"
      self.navigationItem.rightBarButtonItem?.isEnabled = (self.selectedItems.count > 0)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.title = ContactsPickerConfig.viewTitle
    self.view.backgroundColor = ContactsPickerConfig.mainBackground
    self.modalPresentationStyle = .fullScreen
    
    rightButtonBar.isEnabled = false
    leftButtonBar = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissSelector))
    leftButtonBar!.isEnabled = true
    self.navigationItem.leftBarButtonItem = leftButtonBar
    self.navigationItem.rightBarButtonItem = rightButtonBar
    
    rightButtonBar.action = #selector(selectionDidEnd)
    rightButtonBar.target = self
    
    guard let contactsPicker = contactsPicker else { return }
    if (contactsPicker.initialSelected.count > 0) {
      //self.selectionScrollView.reloadData()
      self.contentView.selectionScrollView.reloadData()
      rightButtonBar.isEnabled = true
      rightButtonBar.title = "\(ContactsPickerConfig.doneString) (\(contactsPicker.initialSelected.count))"
      
      contentView.selectionScrollView.isHidden = contactsPicker.initialSelected.count <= 0
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.contentView.tableView.reloadData()
  }
  
  override func loadView() {
    view = contentView
  }
  
}

extension ContactsPickerViewController {
  /// Selector for left button
  @objc public func dismissSelector() {
    if presentedModally {
      self.dismiss(animated: true, completion: nil)
    } else {
      self.navigationController?.popViewController(animated: true)
    }
    
    guard let contactsPicker = contactsPicker else { return }
    contactsPicker.delegate?.didCloseSwiftMultiSelect()
  }
  
  /// Selector for right button
  @objc public func selectionDidEnd() {
    guard let contactsPicker = contactsPicker else { return }
    contactsPicker.delegate?.didSelect(items: self.selectedItems)
    self.dismiss(animated: true, completion: nil)
  }
}

// MARK: Search bar delegate
extension ContactsPickerViewController: UISearchBarDelegate {
  
}

// MARK: Shared functions
extension ContactsPickerViewController {
  /// Toggle de selection view
  ///
  /// - Parameter show: true show scroller, false hide the scroller
  func toggleSelectionScrollView(show:Bool) {
    UIView.animate(withDuration: 0.2, animations: {
      self.contentView.selectionScrollView.isHidden = !show
    })
  }
  
  /// Function to change accessoryType for passed index
  ///
  /// - Parameters:
  ///   - row: index of row
  ///   - selected: true = chechmark, false = none
  func reloadCellState(row: Int, selected:Bool){
    if let cell = self.contentView.tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? ContactsPickerTableCell {
      cell.accessoryType = (selected) ? .checkmark : .none
    }
  }
  
  func updateSelectionScrollViewHeight() {
    self.contentView.selectionScrollViewHeight = selectedItems.count == 0 ? CGFloat.zero : 84
    UIView.animate(withDuration: 0.2) {
      self.contentView.setNeedsLayout()
      self.contentView.layoutIfNeeded()
    }
  }
}
