import UIKit
import JGProgressHUD
import SCLAlertView
import BlackboxCore

class LoginViewController: UIViewController {
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    
    private let rootView = UIView()
    var currencyVC: CurrencyViewController!
    var password = ""
    var amount: String? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(rootView)
        addCurrencyVC()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
         
        rootView.pin.left().right().height(self.view.height).bottom()
        currencyVC?.view.pin.left().right().height(self.rootView.height).bottom()
        currencyVC?.view.layoutIfNeeded()
        currencyVC?.view.layoutSubviews()
        
    }
    
    @objc private func loginPressed() {
        guard let _ = Blackbox.shared.getPwdConfUsingPassword(password) else { return }
              
        let hud = JGProgressHUD(style: .dark)
        hud.textLabel.text = "Connecting...".localized()
        hud.show(in: self.view)
        let account = Blackbox.shared.account
        account.registerAsync { [weak self] (success, error) in
            guard let strongSelf = self else { return }
            if Blackbox.shared.account.state == .registered {
                strongSelf.initializeApp(hud: hud)
            }
        }
    }
    
    private func initializeApp(hud: JGProgressHUD) {
        let account = Blackbox.shared.account
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            hud.textLabel.text = "Fetching data...".localized()
        }
        
        account.initializeApp { (success) in
            if success {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                    hud.dismiss()
                    let storyBoard: UIStoryboard = UIStoryboard(name: "App", bundle: nil)
                    let newViewController = storyBoard.instantiateViewController(withIdentifier: "App")
                    UIApplication.shared.windows[0].rootViewController = newViewController
                }
            }
            else {
                DispatchQueue.main.async {
                    hud.dismiss()
                    if account.needUpdate {
                        UIApplication.shared.windows[0].rootViewController = NewUpdateViewController()
                    } else {
                        SCLAlertView().showError("Something went wrong while connecting to the server. Unable to login.(1002)".localized(), subTitle: "")
                    }
                }
            }
        }
    }
    
    func addCurrencyVC(){
        let storyboard = UIStoryboard(name: "App", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CurrencyViewController") as! CurrencyViewController
        vc.amount = amount
        self.addChild(vc)
        rootView.addSubview(vc.view)
        rootView.bringSubviewToFront(vc.view)
        vc.didMove(toParent: self)
        vc.delegate = self
        self.currencyVC = vc
    }
    
}

extension LoginViewController: CurrencyDelegate {
    func onValueConverted(value: String) {
        password = value
        loginPressed()
    }
}

