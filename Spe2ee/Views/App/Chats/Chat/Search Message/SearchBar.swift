import Foundation
import Combine


public class SearchBar: UIView {
  private let application = UIApplication.shared
  
  private var statusBarFrame: CGRect {
    return self.application.statusBarFrame
  }
  
  /// Calculate the nav bar height if present
//  private var navigationBarHeight: CGFloat {
//    return (view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0) +
//      (self.navigationController?.navigationBar.frame.height ?? 0.0)
//  }
  
  private lazy var searchBar: UISearchBar = {
    let searchBar = UISearchBar()
    searchBar.backgroundImage = UIImage()
    searchBar.delegate = self
    return searchBar
  }()
  
  let searchString = PassthroughSubject<String, Never>()
  let isActive = PassthroughSubject<Bool, Never>()
  
  private lazy var cancelButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Cancel".localized(), for: .normal)
    button.addTarget(self, action: #selector(cancelButtonPressed), for: .touchUpInside)
    button.titleLabel?.font = UIFont.appFont(ofSize: 16)
    button.titleLabel?.adjustsFontForContentSizeCategory = true
    button.sizeToFit()
    return button
  }()
  
  init() {
    super.init(frame: CGRect(x: 0, y: 20, width: UIScreen.main.bounds.size.width, height: 44))
    addSubview(searchBar)
    addSubview(cancelButton)
    self.backgroundColor = Constants.NavBarBackground
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    pin.top(statusBarFrame.size.height).left().right()
    cancelButton.pin.vCenter().right(14)
    searchBar.pin.centerRight(to: cancelButton.anchor.centerLeft).marginRight(8).left(14).height(38)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public func show() {
    self.alpha = 1
    AppUtility.getLastVisibleWindow().addSubview(self)
//    searchBar.becomeFirstResponder()
    isActive.send(true)
  }
  
  public func setFirstResponder() {
    searchBar.becomeFirstResponder()
  }
  
  public func dismiss() {
    isActive.send(false)
    UIView.animate(withDuration: 0.2, animations: {
      self.alpha = 0
    }) { (_) in
      self.searchBar.textField?.text = ""
      self.removeFromSuperview()
    }
    searchBar.resignFirstResponder()
  }
  
  @objc func cancelButtonPressed() {
    dismiss()
  }
  
  public func hideKeyboard() {
    searchBar.resignFirstResponder()
  }
  
}

extension SearchBar: UISearchBarDelegate {
  public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    searchString.send(searchText)
  }
}
