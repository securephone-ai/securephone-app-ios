

import Foundation
import UIKit


class ContactsPickerView: UIView {
  private var keyboardHeight = CGFloat()
  var selectionScrollViewHeight = CGFloat.zero
  
  /// Lazy var for table view
  open fileprivate(set) lazy var searchBar: UISearchBar = {
    
    let searchBar:UISearchBar = UISearchBar()
    //searchBar.translatesAutoresizingMaskIntoConstraints = false
    return searchBar
    
  }()
  
  /// Lazy view that represent a selection scrollview
  open fileprivate(set) lazy var selectionScrollView: UICollectionView = {
    
    //Build layout
    let layout = UICollectionViewFlowLayout()
    layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    layout.scrollDirection = UICollectionView.ScrollDirection.horizontal
    layout.minimumInteritemSpacing = 0
    layout.minimumLineSpacing = 0
    
    //Build collectin view
    let selected = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
    selected.backgroundColor = ContactsPickerConfig.selectorStyle.backgroundColor
    return selected
    
  }()
  
  /// Lazy var for table view
  open fileprivate(set) lazy var tableView: UITableView = {
    let tableView:UITableView = UITableView()
    tableView.backgroundColor = ContactsPickerConfig.tableStyle.backgroundColor
    tableView.showsVerticalScrollIndicator = false
    tableView.showsHorizontalScrollIndicator = false
    // Hide keyboard on single tap gesture
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
    gestureRecognizer.cancelsTouchesInView = false
    tableView.addGestureRecognizer(gestureRecognizer)
    
    return tableView
  }()

  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  init() {
    super.init(frame: .zero)
    backgroundColor = ContactsPickerConfig.mainBackground
    addSubview(searchBar)
    addSubview(selectionScrollView)
    addSubview(tableView)
    
//    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
  }
  
  override func layoutSubviews() {
    searchBar.pin.top(pin.safeArea.top).left().right().height(60)
    selectionScrollView.pin.height(selectionScrollViewHeight).below(of: searchBar).left().right()
    tableView.pin.below(of: selectionScrollView).bottom(self.pin.safeArea.bottom).left().right()
  }
  
  @objc func hideKeyboard() {
    searchBar.textField?.resignFirstResponder()
  }
  
  
  @objc
  internal func keyboardWillShow(notification: Notification) {
    guard let sizeValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
    setTableView(bottomInset: sizeValue.cgRectValue.height)
  }
  
  @objc
  internal func keyboardWillHide(notification: Notification) {
    resetScrollOffset()
  }
  
  private func resetScrollOffset() {
    guard tableView.contentInset != .zero else { return }
    setTableView(bottomInset: 0)
  }
  
  private func setTableView(bottomInset: CGFloat) {
    tableView.contentInset = UIEdgeInsets(top: tableView.contentInset.top, left: 0, bottom: bottomInset + 8, right: 0)
  }
  
//  @objc private func keyboardWillChangeFrame(_ notification: Notification) {
//    if AppUtility.isAppInForeground() {
//      if let endFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
//        let newHeight = UIScreen.main.bounds.height - endFrame.origin.y - safeAreaInsets.bottom
//        if keyboardHeight != newHeight {
//          keyboardHeight = newHeight < 0 ? 0 : newHeight
//
//          tableView.pin.top().bottom(keyboardHeight)
////          tableView.contentInset.top = keyboardHeight
//        }
//      }
//    }
//  }
  
  
}

