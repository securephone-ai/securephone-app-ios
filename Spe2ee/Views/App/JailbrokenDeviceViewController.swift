import UIKit
import JGProgressHUD
import SCLAlertView

class JailbrokenDeviceViewController: UIViewController {
  
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
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    imageView.image = UIImage(named: "logo_no_background")
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()
  
  private let titleLabel: UILabel = {
    let label = UILabel()
    label.text = "  devices".localized().capitalized
    label.font = UIFont.appFontSemiBold(ofSize: 20, textStyle: .headline)
    label.textColor = .white
    label.textAlignment = .center
    label.numberOfLines = 0
    return label
  }()
    
  private lazy var okButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("OK".localized(), for: .normal)
    button.titleLabel?.font = UIFont.appFontSemiBold(ofSize: 21, textStyle: .headline)
    button.titleLabel?.adjustsFontForContentSizeCategory = true
    button.sizeToFit()
    button.frame = CGRect(x: 0, y: 0, width: button.width + 40, height: 58)
    button.cornerRadius = 25
    button.borderColor = .white
    button.borderWidth = 1.5
    button.tintColor = .white
    button.addTarget(self, action: #selector(okButtonPressed), for: .touchUpInside)
    return button
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
        
    self.view.addSubview(rootView)
    rootView.addSubview(logoImageView)
    rootView.addSubview(titleLabel)
    rootView.addSubview(okButton)
    
    rootView.layer.insertSublayer(gradient, at: 0)
    
  }

  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    
    gradient.colors = [Constants.AppMainColorLight.cgColor, Constants.AppMainColorDark.cgColor]
    gradient.frame = CGRect(x: 0.0, y: 0.0, width: view.frame.size.width, height: view.frame.size.height)
    rootView.pin.left().right().height(self.view.height).bottom()
    
    logoImageView.pin.top(self.view.pin.safeArea.top + 34).height(100).left().right()
    titleLabel.pin.below(of: logoImageView).marginTop(30).start(20).end(20).sizeToFit(.width)
    okButton.sizeToFit()
    okButton.pin.right(40).left(40).height(58).bottom(self.view.pin.safeArea.bottom + 50)
    okButton.cornerRadius = okButton.height/2
    
  }
  
  
  @objc private func okButtonPressed() {
    exit(0)
  }
  
}
