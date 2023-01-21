import Foundation
import UIKit
import PinLayout
import StepSlider

protocol MessageAutoDeleteDialogDelegate: class {
  func didSelectTime(time: MessageAutoDeleteTimer)
}

enum MessageAutoDeleteTimer {
  case never
  case oneHour
  case twoHours
  case oneDay
  case twoDays
  case oneWeek
  
  func getSeconds() -> Int {
    switch self {
    case .oneHour:
      return 3600
    case .twoHours:
      return 7200
    case .oneDay:
      return 86400
    case .twoDays:
      return 172800
    case .oneWeek:
      return 604800
    case .never:
      return 0
    }
  }
  
  static func secondsToTimer(_ seconds: Int) -> MessageAutoDeleteTimer {
    switch seconds {
    case 0:
      return .never
    case 3600:
      return .oneHour
    case 7200:
      return .twoHours
    case 86400:
      return .oneDay
    case 172800:
      return .twoDays
    case 604800:
      return .oneWeek
    default:
      return .never
    }
  }
  
}

class MessageAutoDeleteDialog: UIView {
  weak var delegate: MessageAutoDeleteDialogDelegate?
  private var hasChanged: Bool = false
  
  
//  private lazy var opaqueView: UIVisualEffectView = {
//    //    let view = UIView(frame: UIScreen.main.bounds)
//    //    view.backgroundColor = UIColor(white: 0, alpha: 0.75)
//
//
//    let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.light)
//    let blurEffectView = UIVisualEffectView(effect: blurEffect)
//
//    let dismissOnTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissOpaqueBackground))
//    dismissOnTapGesture.delegate = self
//    blurEffectView.addGestureRecognizer(dismissOnTapGesture)
//    return blurEffectView
//  }()
  
  private lazy var rootView: UIVisualEffectView = {
//    let view = UIView()
//    view.layer.masksToBounds = true
//    let dismissOnTapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissAndSet))
//    dismissOnTapGesture.delegate = self
//    view.addGestureRecognizer(dismissOnTapGesture)
    
    //
    
    let blurEffectView = UIVisualEffectView(effect: nil)
    blurEffectView.layer.masksToBounds = true
    let dismissOnTapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissAndSet))
    dismissOnTapGesture.delegate = self
    blurEffectView.addGestureRecognizer(dismissOnTapGesture)
    return blurEffectView
  }()
  
  private var dialogView: UIView = {
    let view = UIView(frame: CGRect(x: 30, y: UIScreen.main.bounds.size.height, width: UIScreen.main.bounds.size.width - 60, height: 255))
    view.layer.masksToBounds = true
    return view
  }()
  
  private var sliderParentView: UIView = {
    let view = UIView()
    view.layer.cornerRadius = 12
    view.layer.masksToBounds = true
    view.backgroundColor = .white
    return view
  }()
  
  private var sliderBackgroundView: UIView = {
    let view = UIView()
    view.layer.masksToBounds = true
    view.backgroundColor = UIColor.init(white: 0.8, alpha: 1)
    return view
  }()
  
  private lazy var slider: StepSlider = {
    let slider = StepSlider(frame: CGRect(x: 30, y: 100, width: UIScreen.main.bounds.size.width-60, height: 44))
    slider.maxCount = 6
    slider.index = 0
    slider.labels = ["1 hour".localized(), "2 hours".localized(), "1 day".localized(), "2 days".localized(), "1 week".localized(), "Never".localized()]
    slider.labelColor = .black
//    slider.labelFont = UIFont.appFont(ofSize: 13, textStyle: .footnote)
    slider.labelFont = UIFont.systemFont(ofSize: 14)
    slider.addTarget(self, action: #selector(sliderIndexChanged), for: .valueChanged)
    return slider
  }()
  
  private var titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    label.text = "Please set self-disappearing time.".localized()
    label.textColor = .black
    label.sizeToFit()
    label.font = UIFont.systemFont(ofSize: 20)
    label.adjustsFontForContentSizeCategory = true
    label.textAlignment = .center
    return label
  }()
  
  private lazy var setButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Set".localized(), for: .normal)
    button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
    button.backgroundColor = .white
    button.tintColor = .link
    button.layer.cornerRadius = 12
    button.addTarget(self, action: #selector(setButtonPressed), for: .touchUpInside)
    return button
  }()
  
  private lazy var cancelButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Cancel", for: .normal)
    button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
    button.backgroundColor = .white
    button.tintColor = .link
    button.layer.cornerRadius = 12
    button.addTarget(self, action: #selector(dismissView), for: .touchUpInside)
    return button
  }()
  
  deinit {
    logi("MessageAutoDeleteDialog deinitialized")
  }
  
  init() {
    super.init(frame: UIScreen.main.bounds)
    //    super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width - 80, height: 250))
    
    addSubview(rootView)
    rootView.contentView.addSubview(dialogView)
    dialogView.addSubview(sliderParentView)
    dialogView.addSubview(cancelButton)
//    dialogView.addSubview(setButton)
    sliderParentView.addSubview(titleLabel)
    sliderParentView.addSubview(sliderBackgroundView)
    sliderBackgroundView.addSubview(slider)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    rootView.pin.all()
    dialogView.pin.bottom(pin.safeArea.bottom + 30)
    sliderParentView.pin.top().height(170).left().right()
//    setButton.pin.below(of: sliderParentView).marginTop(15).left().right().height(55)
    cancelButton.pin.below(of: sliderParentView).marginTop(10).left().right().height(55)
    
    titleLabel.pin.top(20).left(10).right(10).sizeToFit(.width)
    
    sliderBackgroundView.pin.height(90).left().right().bottom()
    slider.pin.left(20).right(20).top(10)
    
  }
  
  @objc private func dismissView() {
    UIView.animate(withDuration: 0.2, animations: {
      self.dialogView.pin.bottom(-UIScreen.main.bounds.size.height)
      self.rootView.effect = nil
    }) { (result) in
      self.slider.setIndex(0, animated: false)
      self.hasChanged = false
      self.removeFromSuperview()
    }
  }
  
  @objc private func dismissAndSet() {
    setTimer()
    dismissView()
  }
  
  @objc private func sliderIndexChanged() {
    hasChanged = true
  }
  
}

extension MessageAutoDeleteDialog: UIGestureRecognizerDelegate {
  
  override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    if dialogView.frame.contains(gestureRecognizer.location(in: self)) {
      return false
    }
    return true
  }
  
  func show(initialValue timer: MessageAutoDeleteTimer = .never) {
    slider.setIndex(timerToIndex(timer), animated: false)
    hasChanged = false
    
    AppUtility.getLastVisibleWindow().addSubview(self)
    UIView.animate(withDuration: 0.2) {
      self.rootView.effect = UIBlurEffect(style: UIBlurEffect.Style.light)
      self.dialogView.pin.bottom(self.pin.safeArea.bottom + 30)
    }
  }
  
  @objc private func setButtonPressed() {
    setTimer()
    dismissView()
  }
  
  private func setTimer() {
    if hasChanged, let delegate = delegate {
      delegate.didSelectTime(time: indexToTimer())
    }
  }
  
  private func timerToIndex(_ startingTime: MessageAutoDeleteTimer) -> UInt {
    switch startingTime {
    case .oneHour:
      return 0
    case .twoHours:
      return 1
    case .oneDay:
      return 2
    case .twoDays:
      return 3
    case .oneWeek:
      return 4
    case .never:
      return 5
    }
  }
  
  private func indexToTimer() -> MessageAutoDeleteTimer {
    switch slider.index {
    case 0:
      return .oneHour
    case 1:
      return .twoHours
    case 2:
      return .oneDay
    case 3:
      return .twoDays
    case 4:
      return .oneWeek
    case 5:
      return .never
    default:
      return .never
    }
  }
}
