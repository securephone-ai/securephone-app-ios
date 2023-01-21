import UIKit
import JGProgressHUD
import SCLAlertView

class NewUpdateViewController: UIViewController {
  
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
    label.text = "Update".localized()
    label.font = UIFont.appFontSemiBold(ofSize: 20, textStyle: .headline)
    label.textColor = .white
    label.textAlignment = .center
    return label
  }()
  
  private let errorTitleLabel: UILabel = {
    let label = UILabel()
    label.text = "New Version Available".localized()
    label.font = UIFont.preferredFont(forTextStyle: .footnote)
    label.adjustsFontForContentSizeCategory = true
    label.textColor = .orange
    label.textAlignment = .center
    label.isHidden = true
    return label
  }()
  
  private let infoLabel: UILabel = {
    let label = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width - 50, height: CGFloat.greatestFiniteMagnitude))
    label.font = UIFont.preferredFont(forTextStyle: .body)
    label.adjustsFontForContentSizeCategory = true
    label.text = "A new mandatory version is available. Please download and install to use the app.".localized()
    label.textColor = .white
    label.textAlignment = .center
    label.numberOfLines = 0
    return label
  }()
  
  private lazy var downloadButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Download".localized(), for: .normal)
    button.titleLabel?.font = UIFont.appFontSemiBold(ofSize: 21, textStyle: .headline)
    button.titleLabel?.adjustsFontForContentSizeCategory = true
    button.sizeToFit()
    button.frame = CGRect(x: 0, y: 0, width: button.width + 40, height: 58)
    button.cornerRadius = 25
    button.borderColor = .white
    button.borderWidth = 1.5
    button.tintColor = .white
    button.addTarget(self, action: #selector(downloadButtonPressed), for: .touchUpInside)
    return button
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.view.addSubview(rootView)
    rootView.addSubview(logoImageView)
    rootView.addSubview(titleLabel)
    rootView.addSubview(errorTitleLabel)
    rootView.addSubview(infoLabel)
    rootView.addSubview(downloadButton)
    
    rootView.layer.insertSublayer(gradient, at: 0)
    
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillAppear(animated)
    NotificationCenter.default.removeObserver(self)    
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    
    gradient.colors = [Constants.AppMainColorLight.cgColor, Constants.AppMainColorDark.cgColor]
    gradient.frame = CGRect(x: 0.0, y: 0.0, width: view.frame.size.width, height: view.frame.size.height)
    
    titleLabel.sizeToFit()
    errorTitleLabel.sizeToFit()
    infoLabel.sizeToFit()
    
    rootView.pin.left().right().height(self.view.height).bottom()
    
    logoImageView.pin.top(self.view.pin.safeArea.top + 34).height(100).left().right()
    titleLabel.pin.below(of: logoImageView, aligned: .center).marginTop(20)
    errorTitleLabel.pin.below(of: titleLabel).marginTop(40).left(8).right(8)
    infoLabel.pin.below(of: errorTitleLabel).marginTop(5).left(25).right(25)
    infoLabel.sizeToFit()
    downloadButton.sizeToFit()
    downloadButton.pin.right(40).left(40).height(58).bottom(self.view.pin.safeArea.bottom + 50)
    downloadButton.cornerRadius = downloadButton.height/2
    
  }
  
  
  @objc private func downloadButtonPressed() {
    // Download
    if let url = URL(string: Blackbox.shared.account.appUpdateUrl) {
      UIApplication.shared.open(url)
    }
  }
  
}
