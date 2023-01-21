import UIKit
import JGProgressHUD
import SCLAlertView

class AccountActivationViewController: UIViewController {
  
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .portrait
  }
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  private let gradient = CAGradientLayer()
  private var keyboardHeight: CGFloat = 0.0
  private var failedAttemptsCount = 0
  
  private let rootView = UIView()
  
  private let logoImageView: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
    imageView.image = UIImage(named: "logo-green")
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()
  
  private let titleLabel: UILabel = {
    let label = UILabel()
    label.text = "Activation".localized()
    label.font = UIFont.appFontSemiBold(ofSize: 20, textStyle: .headline)
    label.textColor = .white
    label.textAlignment = .center
    return label
  }()
  
  private let activationCodeTextFields: UITextField = {
    let textField = UITextField(frame: CGRect(x: 0, y: 0, width: 100, height: 46))
    textField.backgroundColor = .white
    textField.textColor = .black
    textField.textAlignment = .center
    textField.font = UIFont.appFont(ofSize: 18, textStyle: .body)
    textField.placeholder = "Enter your activation code".localized()
    textField.cornerRadius = 23
    textField.setLeftPaddingPoints(15)
    textField.setRightPaddingPoints(15)
    return textField
  }()
  
  private let errorTitleLabel: UILabel = {
    let label = UILabel()
    label.text = "INVALID CODE".localized()
    label.font = UIFont.preferredFont(forTextStyle: .footnote)
    label.adjustsFontForContentSizeCategory = true
    label.textColor = .orange
    label.textAlignment = .center
    label.isHidden = true
    return label
  }()
  
  private let failedAttemptCountLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.preferredFont(forTextStyle: .caption1)
    label.adjustsFontForContentSizeCategory = true
    label.text = "1 \("Failed attempt. App will be locked after 3 failed attempts.".localized())"
    label.textColor = .orange
    label.textAlignment = .center
    label.isHidden = true
    label.numberOfLines = 0
    return label
  }()
  
  private lazy var nextButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Next".localized(), for: .normal)
    button.titleLabel?.font = UIFont.appFontSemiBold(ofSize: 21, textStyle: .headline)
    button.sizeToFit()
    button.frame = CGRect(x: 0, y: 0, width: button.width + 40, height: 54)
    button.cornerRadius = 25
    button.borderColor = .white
    button.borderWidth = 1.5
    button.tintColor = .white
    button.addTarget(self, action: #selector(nextPressed), for: .touchUpInside)
    return button
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.view.addSubview(rootView)
    rootView.addSubview(logoImageView)
    rootView.addSubview(titleLabel)
    rootView.addSubview(activationCodeTextFields)
    rootView.addSubview(errorTitleLabel)
    rootView.addSubview(failedAttemptCountLabel)
    rootView.addSubview(nextButton)
    
    rootView.layer.insertSublayer(gradient, at: 0)
    
    // Do any additional setup after loading the view.
//    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    
    // Hide keyboard on single tap gesture
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
    gestureRecognizer.cancelsTouchesInView = false
    gestureRecognizer.delegate = self
    rootView.addGestureRecognizer(gestureRecognizer)
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    
    gradient.colors = [Constants.AppMainColorGreen.cgColor, Constants.AppMainColorGreen.cgColor]
    gradient.frame = CGRect(x: 0.0, y: 0.0, width: view.frame.size.width, height: view.frame.size.height)
    
    titleLabel.sizeToFit()
    errorTitleLabel.sizeToFit()
    failedAttemptCountLabel.sizeToFit()
    
    rootView.pin.left().right().height(self.view.height).bottom()
    
    logoImageView.pin.top(self.view.pin.safeArea.top + 34).height(100).left().right()
    titleLabel.pin.below(of: logoImageView, aligned: .center).marginTop(20)
    activationCodeTextFields.pin.below(of: titleLabel).marginTop(15).left(25).right(25)
    errorTitleLabel.pin.below(of: activationCodeTextFields).marginTop(10).left(8).right(8)
    failedAttemptCountLabel.pin.below(of: errorTitleLabel).marginTop(5).left(25).right(25)
    nextButton.pin.below(of: failedAttemptCountLabel, aligned: .center).marginTop(15)

  }
  
  @objc private func keyboardWillChangeFrame(_ notification: Notification) {
    if let endFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
      let newHeight = UIScreen.main.bounds.height - endFrame.origin.y - self.view.safeAreaInsets.bottom
      if keyboardHeight != newHeight {
        keyboardHeight = newHeight < 0 ? 0 : newHeight
        
        self.rootView.pin.bottom(keyboardHeight > 0 ? (keyboardHeight - 70.0) : keyboardHeight)
      }
    }
  }
  
  @objc private func hideKeyboard() {
    activationCodeTextFields.resignFirstResponder()
  }
  
  @objc private func nextPressed() {
    
    UNUserNotificationCenter.current().getNotificationSettings { (settings) in
      DispatchQueue.main.async { [weak self] in
        guard let strongSelf = self else { return }
        if settings.authorizationStatus == .authorized {
          strongSelf.activationCodeTextFields.resignFirstResponder()
          if let code = strongSelf.activationCodeTextFields.text {
            let parts = code.split(separator: "-")
            if parts.count == 2 {
              let number = String(parts[0])
              let otp = String(parts[1])
              
              
              let hud = JGProgressHUD(style: .dark)
              hud.textLabel.text = "\("Connecting".localized())..."
              hud.show(in: strongSelf.view)
              
              Blackbox.shared.account.signUpAsync(number: number, otp: otp) { (result) in
                
                DispatchQueue.main.async { [weak self] in
                  guard let strongSelf = self else { return }
                  if result {
                    hud.textLabel.text = "Success!".localized()
                    
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                      hud.dismiss()
                      
                      let vc = ChooseMasterPasswordViewController()
                      vc.currentPassword = ""
                      vc.modalPresentationStyle = .fullScreen
                      
                      let transition = CATransition()
                      transition.duration = 0.2
                      transition.type = CATransitionType.push
                      transition.subtype = CATransitionSubtype.fromRight
                      transition.timingFunction = CAMediaTimingFunction(name:CAMediaTimingFunctionName.easeInEaseOut)
                      strongSelf.view.window!.layer.add(transition, forKey: kCATransition)
                      strongSelf.present(vc, animated: false, completion: nil)
                      
                    }
                  } else {
                    hud.dismiss()
                    
                    strongSelf.failedAttemptsCount += 1
                    if strongSelf.failedAttemptsCount == 3 {
                      UserDefaults.standard.set(true, forKey: "regFailed")
                      UIApplication.shared.windows[0].rootViewController = RegistrationFailedViewController()
                    } else {
                      strongSelf.errorTitleLabel.isHidden = false
                      strongSelf.failedAttemptCountLabel.isHidden = false
                      strongSelf.failedAttemptCountLabel.text = "\(strongSelf.failedAttemptsCount) \("Failed attempt. App will be locked after 3 failed attempts.".localized())"
                    }
                  }
                }
              }
            } else {
              SCLAlertView().showError("Invalid activation code format".localized(), subTitle: "Make sure the format is the following 'number-otp'".localized())
            }
          } else {
            SCLAlertView().showError("Invalid activation code".localized(), subTitle: "")
          }
          
        } else {
          AppUtility.notificationDenied(viewController: strongSelf)
        }
      }
    }
  }
  
}

extension AccountActivationViewController: UIGestureRecognizerDelegate {
  // MARK: UIGestureRecognizerDelegate methods, You need to set the delegate of the recognizer
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    if touch.view?.isDescendant(of: nextButton) == true {
      return false
    }
    return true
  }
}
