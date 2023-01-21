import UIKit
import JGProgressHUD
import SCLAlertView

class AppStartViewController: UIViewController {
  
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .portrait
  }
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .darkContent
  }
  
  private let gradient = CAGradientLayer()
  
  private let rootView = UIView()
  
  private let activityIndicatorView: UIActivityIndicatorView = {
    let view = UIActivityIndicatorView(style: .large)
    view.color = .white
    view.startAnimating()
    return view
  }()
  
  private let logoImageView: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    imageView.image = UIImage(named: "logo_no_background")
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()
  
  private let titleLabel: UILabel = {
    let label = UILabel()
    label.text = Constants.AppName.uppercased()
    label.font = UIFont.appFontSemiBold(ofSize: 20, textStyle: .headline)
    label.textColor = .white
    label.textAlignment = .center
    return label
  }()
  
  private lazy var versionLabel: UILabel = {
    let label = UILabel()
    label.text = Bundle.main.releaseVersionNumber
    label.font = UIFont.preferredFont(forTextStyle: .footnote)
    label.adjustsFontForContentSizeCategory = true
    label.textColor = .white
    label.textAlignment = .center
    label.sizeToFit()
    return label
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(rootView)
    rootView.addSubview(logoImageView)
    rootView.addSubview(titleLabel)
    rootView.addSubview(versionLabel)
    rootView.addSubview(activityIndicatorView)
    rootView.layer.insertSublayer(gradient, at: 0)
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    register()
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    gradient.colors = [Constants.AppMainColorLight.cgColor, Constants.AppMainColorDark.cgColor]
    gradient.frame = CGRect(x: 0.0, y: 0.0, width: view.frame.size.width, height: view.frame.size.height)
    
    titleLabel.sizeToFit()
    
    rootView.pin.left().right().height(self.view.height).bottom()
    logoImageView.pin.top(self.view.pin.safeArea.top + 80).height(100).left().right()
    titleLabel.pin.bottom(self.view.pin.safeArea.bottom+60).left().right()
    versionLabel.pin.below(of: titleLabel).left().right().marginTop(1)
    activityIndicatorView.pin.hCenter().vCenter()
  }

  private func register() {
    // Success
    let blackbox = Blackbox.shared
    AppUtility.benchmark("registerAsync benchmark") { (finish) in
      blackbox.account.registerAsync { (success, error) in
        finish()
        if success {
          blackbox.account.initializeApp { (success) in            
            if success {
              DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                let storyBoard: UIStoryboard = UIStoryboard(name: "App", bundle: nil)
                let newViewController = storyBoard.instantiateViewController(withIdentifier: "App")
                UIApplication.shared.windows[0].rootViewController = newViewController
              }
            }
            else {
              DispatchQueue.main.async {
                if blackbox.account.needUpdate {
                  UIApplication.shared.windows[0].rootViewController = NewUpdateViewController()
                } else {
                  SCLAlertView().showError("Error".localized(), subTitle: "Something went wrong while connecting to the server. Please close the app and try again.".localized())
                }
              }
            }
            
          }
        } else {
          // TODO: Show error
          logw("AppStartViewController - registerAsync Failed")
          sleep(2) // retry in 2 seconds
          self.register()
        }
      }
    }

  }
}

