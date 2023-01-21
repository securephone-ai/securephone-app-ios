import UIKit
import SwipeCellKit
import Combine
import AVFoundation
import NextLevel

class CallsHistoryView: UITableViewController {

  var viewModel = CallsHistoryViewModel()
  private var cancellableBag = Set<AnyCancellable>()
  
  @IBOutlet weak var segmentedControl: UISegmentedControl!
  
  private let searchController = UISearchController(searchResultsController: nil)
  var isSearchBarEmpty: Bool {
    return searchController.searchBar.text?.isEmpty ?? true
  }
  
  // Keep track of the swiped cell to properly reset when edit mode change or new call is added.
  var currentSwipedCell: CallHistoryCell? = nil
  
  
  init(viewModel: CallsHistoryViewModel) {
    self.viewModel = viewModel
    super.init(style: .plain)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
}

// MARK: - Lifecycle functions
extension CallsHistoryView {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    title = "Calls".localized()
    
    searchController.searchResultsUpdater = self as UISearchResultsUpdating
    searchController.obscuresBackgroundDuringPresentation = false
    searchController.searchBar.placeholder = "Search".localized()
    navigationItem.searchController = searchController
    
    self.navigationController?.navigationBar.hideBottomLine()
    
    tableView.register(CallHistoryCell.self, forCellReuseIdentifier: CallHistoryCell.ID)
    tableView.allowsMultipleSelection = false
    tableView.delaysContentTouches = false
    
    segmentedControl.ensureiOS12Style()
    
    segmentedControl.setTitle("All".localized(), forSegmentAt: 0)
    segmentedControl.setTitle("Missed".localized(), forSegmentAt: 1)
    
    addPhoneBarButton(to: self.navigationController!)
    
    viewModel.$isEditing.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (value) in
      guard let navigation = self?.navigationController else { return }
      
      if value {
        self?.addDoneBarButton(to: navigation)
        self?.addClearBarButton(to: navigation)
      } else {
        // Reset the Cell Swipe when the edit mode has changed
        if self?.currentSwipedCell != nil {
          self?.currentSwipedCell?.hideSwipe(animated: false)
        }
        self?.addEditBarButton(to: navigation)
        self?.addPhoneBarButton(to: navigation)
      }
    }).store(in: &cancellableBag)
    
    Blackbox.shared.$callHistoryCellsViewModels.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] cellViewModels in
      guard let strongSelf = self else { return }
      strongSelf.tableView.reloadData()
    }).store(in: &cancellableBag)
    
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    title = "Calls".localized()
    navigationController?.navigationBar.prefersLargeTitles = true
    Blackbox.shared.currentViewController = self
    Blackbox.shared.fetchCallsHistoryAsync(completion: nil)
  }

}

// MARK: - Controls Actions
extension CallsHistoryView {
  
  @IBAction func indexChanged(_ sender: Any) {
    switch segmentedControl.selectedSegmentIndex
    {
    case 0:
      viewModel.showMissedCalls = false
    case 1:
      viewModel.showMissedCalls = true
    default:
      break
    }
    tableView.reloadData()
  }
  
  func addEditBarButton(to navigation: UINavigationController) {
    let edit = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(startEditMode))
    navigation.navigationBar.topItem?.leftBarButtonItem = edit
  }
  
  func addDoneBarButton(to navigation: UINavigationController) {
    let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(stopEditMode))
    navigation.navigationBar.topItem?.leftBarButtonItem = done
  }
  
  func addPhoneBarButton(to navigation: UINavigationController) {
    let menuBtn = UIButton(type: .custom)
    menuBtn.setImage(UIImage(named:"start_conference_call")?.withRenderingMode(.alwaysTemplate), for: .normal)
    menuBtn.addTarget(self, action: #selector(startConferenceCall), for: .touchUpInside)
    menuBtn.tintColor = .link
    

    let menuBarItem = UIBarButtonItem(customView: menuBtn)
    menuBarItem.tintColor = .link
    menuBarItem.customView?.widthAnchor.constraint(equalToConstant: 30).isActive = true
    menuBarItem.customView?.heightAnchor.constraint(equalToConstant: 24).isActive = true
    
    self.navigationItem.rightBarButtonItems = [menuBarItem]
  }
  
  func addClearBarButton(to navigation: UINavigationController) {
    let clear = UIBarButtonItem(title: "Clear".localized(), style: .plain, target: self, action: #selector(clearCallHistory))
    navigation.navigationBar.topItem?.rightBarButtonItem = clear
  }
  
  @objc func startEditMode() {
    viewModel.isEditing = true
  }
  
  @objc func stopEditMode() {
    viewModel.isEditing = false
    
    if currentSwipedCell != nil {
      currentSwipedCell?.hideSwipe(animated: true)
    }
  }
 
  @objc func clearCallHistory() {
    let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    
    let clearCallsAction = UIAlertAction(title: "Clear Call History".localized(), style: .destructive) { _ in
      self.viewModel.deleteAllCalls()
      self.viewModel.isEditing = false
      self.tableView.reloadData()
    }
    
    let cancel = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
    alertController.addAction(clearCallsAction)
    alertController.addAction(cancel)
    
    present(alertController, animated: true, completion: nil)
  }
  
  @objc func startCall() {
    logi("Start Call")
  }
  
  @objc func startConferenceCall() {
    logi("Start Call")
    let contacts = Blackbox.shared.contactsSections.reduce(into: [BBContact]()) {
      $0.append(contentsOf: $1.contacts)
    }
    let vc = ConferenceCallContactsSelectionViewController(contacts: contacts)
    vc.delegate = self
    self.present(vc, animated: true, completion: nil)
  }
}

 // MARK: - Table view data source & delegate
extension CallsHistoryView {
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
    return viewModel.getCalls().count
  }
  
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 64
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if let cell = tableView.dequeueReusableCell(withIdentifier: CallHistoryCell.ID, for: indexPath) as? CallHistoryCell, viewModel.getCalls().count > indexPath.row {
      cell.viewModel = viewModel.getCalls()[indexPath.row]
      cell.delegate = self // SwipeTableViewCellDelegate
      return cell
    }
    
    return UITableViewCell()
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    
    let callViewModel = self.viewModel.getCall(row: indexPath.row)
    if let contact = callViewModel.contact {
      if let firstCall = callViewModel.callGroup.calls.first {
        if firstCall.type == .video {
          if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized {
            Blackbox.shared.callManager.startCall(contact: contact, video: true)
          } else {
            NextLevel.requestAuthorization(forMediaType: AVMediaType.video) { (mediaType, status) in
              if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
                  Blackbox.shared.callManager.startCall(contact: contact, video: true)
                }
              } else if status == .notAuthorized {
                // gracefully handle when audio/video is not authorized
                AppUtility.camDenied(viewController: self)
              }
            }
          }
        } else {
          Blackbox.shared.callManager.startCall(contact: contact)
        }
      }
      
    }
  }

}

// MARK: - Table Filter
extension CallsHistoryView: UISearchResultsUpdating {
  
  func updateSearchResults(for searchController: UISearchController) {
    let searchBar = searchController.searchBar
    filterContentForSearchText(searchBar.text!)
  }
  
  func filterContentForSearchText(_ searchText: String) {
    viewModel.filterCalls(using: searchText)
    tableView.reloadData()
  }

}

// MARK: - Table Swipe Cell delegate
extension CallsHistoryView: SwipeTableViewCellDelegate {
  func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> [SwipeAction]? {
    let call = viewModel.getCalls()[indexPath.row]
    
    guard !viewModel.isEditing || call.deleteRequest else { return nil }
    guard orientation == .right else { return nil }
    guard let navigation = navigationController else { return nil }
    
    let deleteAction = SwipeAction(style: .destructive, title: "Delete".localized()) { [weak self] action, indexPath in
      action.fulfill(with: .reset)
      guard let strongSelf = self else { return }
      strongSelf.viewModel.deleteCall(callHistoryCellViewModel: call)
      strongSelf.tableView.safeDeleteRows(at: [indexPath], with: .automatic)
      
      if (strongSelf.viewModel.isEditing) == false {
        strongSelf.addEditBarButton(to: navigation)
      } else if strongSelf.viewModel.getCalls().count == 0 {
        strongSelf.viewModel.isEditing = false
      }
      
    }
    
    addDoneBarButton(to: navigation)
    currentSwipedCell = tableView.cellForRow(at: indexPath) as? CallHistoryCell
    
    return [deleteAction]
  }
  
  func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?, for orientation: SwipeActionsOrientation) {
    guard let navigation = navigationController else { return }
    if !viewModel.isEditing {
      addEditBarButton(to: navigation)
    }
    currentSwipedCell = nil
  }
  
  func tableView(_ tableView: UITableView, editActionsOptionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> SwipeOptions {
    var options = SwipeOptions()
    options.transitionStyle = .border
    options.expansionStyle = .fill
    return options
  }
}


extension CallsHistoryView: ConferenceCallContactsSelectionViewControllerDelegate {
  func didSelectContacts(contacts: [BBContact]) {
    if contacts.isEmpty == false {
      Blackbox.shared.callManager.startConferenceCall(contacts: contacts)
    }
  }
}
