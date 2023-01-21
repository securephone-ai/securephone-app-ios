import UIKit
import PinLayout

protocol NotificationViewDelegate: class {
  func didTapNotification(object: Any?)
}

public final class MessageNotification {
  private var notification = NotificationView()
  public static let shared = MessageNotification()
  
  public func show(title: String, message: NSAttributedString?, image: UIImage?, object: Any? = nil, dismissAfter delay: Double = 4.0, completion block: ((Any?)->Void)?) {
    notification.object = object
    notification.show(title: title, message: message, image: image, dismissAfter: delay)
    notification.tap = { object in
      block?(object)
      self.notification.dismiss()
    }
  }
}

private class NotificationView: UIView {
  
  private var slideUpStartingPoint: CGFloat = .zero
  
  /// Object that you can store and pass back when the user tap the notification view.
  var object: Any? = nil
  
  var tap: ((Any?) -> Void)?
  
  weak var delegate: NotificationViewDelegate?
  
  lazy var dismissWorkItem: DispatchWorkItem = DispatchWorkItem {
    self.dismiss()
  }
  
  private var pan: UIPanGestureRecognizer!
  
  private lazy var initialViewHeight: CGFloat = {
    self.pin.safeArea.top + 86
  }()
  
  private let userImageView: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 54, height: 54))
    imageView.layer.cornerRadius = 27
    imageView.layer.masksToBounds = true
    imageView.contentMode = .scaleAspectFill
    imageView.backgroundColor = .green
    return imageView
  }()
  
  private let userLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 20, weight: .medium)
    label.textColor = .white
    label.text = "A"
    label.sizeToFit()
    label.text = ""
    return label
  }()
  
  private let messageLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 17)
    label.textColor = .white
    label.text = "A"
    label.sizeToFit()
    label.text = ""
    return label
  }()
  
  private lazy var bottomView: UIView = {
    let view = UIView(frame: CGRect(x: 0, y: self.frame.size.height/2, width: self.frame.size.width, height: self.frame.size.height/2))
    view.alpha = 0
    return view
  }()
  
  private let dividerView: UIView = {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: 0.5))
    view.backgroundColor = .white
    return view
  }()
  
  private let textView: UITextView = {
    let textView = UITextView()
    textView.backgroundColor = .systemGray4
    textView.textColor = .white
    textView.layer.cornerRadius = 4
    return textView
  }()
  
  private let sendButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Send", for: .normal)
    button.tintColor = .white
    button.sizeToFit()
    return button
  }()
  
  private let pinView: UIView = {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 35, height: 4))
    view.backgroundColor = .white
    view.layer.cornerRadius = 2
    return view
  }()
  
  deinit {
    print("Notification View deinitialized")
  }
  
  init() {
    super.init(frame: CGRect(x: 0, y: -150, width: UIScreen.main.bounds.size.width, height: 86))
    
    backgroundColor = UIColor.init(white: 0, alpha: 0.8)
    
    addSubview(bottomView)
    bottomView.addSubview(dividerView)
    bottomView.addSubview(textView)
    bottomView.addSubview(sendButton)
    addSubview(userImageView)
    addSubview(userLabel)
    addSubview(messageLabel)
    addSubview(pinView)
    
    pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
    pan.delegate = self
    addGestureRecognizer(pan)
    
    let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
    tap.delegate = self
    addGestureRecognizer(tap)
    
    layer.name = "NotificationViewLayer"
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    pin.height(initialViewHeight)
    
    pinView.pin.bottom(2).hCenter()
    
    bottomView.pin.bottomCenter()
    dividerView.pin.top().start().end()
    sendButton.pin.vCenter().end(2)
    textView.pin.left(of: sendButton).start(4).top(4).bottom(4)
    
    userImageView.pin.vCenter().start(14)
    userLabel.pin.after(of: userImageView, aligned: .top).marginStart(10).marginTop(4).end(14)
    messageLabel.pin.after(of: userImageView, aligned: .bottom).marginBottom(3).marginStart(10).end(14)
    
  }
  
  @objc func onPan(_ pan: UIPanGestureRecognizer) {
    switch pan.state {
    case .began:
      dismissWorkItem.cancel()
      let point = pan.translation(in: self)
      slideUpStartingPoint = point.y
    case .changed:
      let point = pan.translation(in: self)
      if point.y < 0 {
        pin.top(point.y)
      }
    case .ended:
      let point = pan.translation(in: self)
      if point.y < -10 {
        dismiss()
      } else {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
          self.dismiss()
        }
      }
    default:
      break
    }
  }
  
  @objc func viewTapped() {
    
    tap?(object)
    
    //    print("tapped")
    //    guard let delegate = self.delegate else { return }
    //    delegate.didTapNotification(object: object)
  }
}

// MARK: - UIGestureRecognizerDelegate
extension NotificationView: UIGestureRecognizerDelegate {
  override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
}

extension NotificationView {
  
  fileprivate func show(title: String, message: NSAttributedString?, image: UIImage?, dismissAfter delay: Double = 4.0) {
    Vibration.light.vibrate()
    
    /// Just update the labels and restart the timer
    for window in UIApplication.shared.windows {
      for view in window.subviews {
        if view.layer.name == "NotificationViewLayer", let notView = view as? NotificationView {
          // Update
          notView.userLabel.text = title
          notView.messageLabel.attributedText = message
          notView.userImageView.image = image
          notView.dismissWorkItem.cancel()
          notView.dismissWorkItem = DispatchWorkItem {
            notView.dismiss()
          }
          if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay, execute: notView.dismissWorkItem)
          }
          return
        }
      }
    }
    
    userLabel.text = title
    messageLabel.attributedText = message
    userImageView.image = image
    
    getLastVisibleWindow().addSubview(self)
    
    UIView.animate(withDuration: 0.2) {
      self.pin.top()
    }
    
    if delay > 0 {
      dismissWorkItem.cancel()
      dismissWorkItem = DispatchWorkItem {
        self.dismiss()
      }
      
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay, execute: dismissWorkItem)
    }
  }
  
  fileprivate func update(title: String, message: String) {
    userLabel.text = title
    messageLabel.text = message
  }
  
  fileprivate func dismiss() {
    UIView.animate(withDuration: 0.2, animations: {
      self.pin.top(-self.frame.size.height)
    }) { (_) in
      self.removeFromSuperview()
      if self.dismissWorkItem.isCancelled == false {
        self.dismissWorkItem.cancel()
      }
    }
  }
  
  private func getLastVisibleWindow() -> UIWindow {
    let windows = UIApplication.shared.windows
    if let window = windows.reversed().first(where: { (window) -> Bool in
      // WE check for window.subviews[0].subviews[0].frame.origin. because sometimes the keyboard windows remain open but Out of screen the screen.
      return window.isHidden == false && window.subviews.count > 0 && window.subviews[0].subviews.count > 0 && window.subviews[0].subviews[0].frame.origin.y < UIScreen.main.bounds.size.height
    }) {
      return window
    } else {
      return windows[0]
    }
  }
  
}
