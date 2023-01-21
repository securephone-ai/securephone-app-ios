import UIKit
import JGProgressHUD
import SCLAlertView

class RegistrationFailedViewController: UIViewController {
    
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
        label.text = "App Locked".localized()
        label.font = UIFont.appFontSemiBold(ofSize: 20, textStyle: .headline)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private let errorTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Registration failed too many times.".localized()
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(rootView)
        rootView.addSubview(logoImageView)
        rootView.addSubview(titleLabel)
        rootView.addSubview(errorTitleLabel)
        
        rootView.layer.insertSublayer(gradient, at: 0)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        gradient.colors = [Constants.AppMainColorGreen.cgColor, Constants.AppMainColorGreen.cgColor]
        gradient.frame = CGRect(x: 0.0, y: 0.0, width: view.frame.size.width, height: view.frame.size.height)
        
        titleLabel.sizeToFit()
        errorTitleLabel.sizeToFit()
        
        rootView.pin.left().right().height(self.view.height).bottom()
        
        logoImageView.pin.top(self.view.pin.safeArea.top + 34).height(100).left().right()
        titleLabel.pin.below(of: logoImageView, aligned: .center).marginTop(20)
        errorTitleLabel.pin.vCenter().hCenter()
        
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
    
}
