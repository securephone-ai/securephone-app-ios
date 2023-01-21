import UIKit
import PinLayout

class BaseFormView: UIView {
  let formScrollView = UIScrollView()
  
  init() {
    super.init(frame: .zero)
    
    formScrollView.showsVerticalScrollIndicator = false
    formScrollView.keyboardDismissMode = .onDrag
    
    formScrollView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapScrollView)))
    addSubview(formScrollView)
    
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
  }
  
  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    formScrollView.pin.all()
  }
  
  @objc
  internal func keyboardWillShow(notification: Notification) {
    guard let sizeValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
    setFormScrollView(bottomInset: sizeValue.cgRectValue.height)
  }
  
  @objc
  internal func keyboardWillHide(notification: Notification) {
    resetScrollOffset()
  }
  
  @objc
  internal func didTapScrollView() {
    endEditing(true)
    resetScrollOffset()
  }
  
  private func resetScrollOffset() {
    guard formScrollView.contentInset != .zero else { return }
    setFormScrollView(bottomInset: 0)
  }
  
  private func setFormScrollView(bottomInset: CGFloat) {
    formScrollView.contentInset = UIEdgeInsets(top: formScrollView.contentInset.top, left: 0,
                                               bottom: bottomInset, right: 0)
  }
}
