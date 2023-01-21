import UIKit
import JGProgressHUD
import SCLAlertView
import BlackboxCore

class ConfirmMasterPasswordViewController: UIViewController {
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    
    private var masterPassword: String!
    private var currentPassword: String!
    private let rootView = UIView()
    
    var currencyVC: CurrencyViewController!
    
    init(currentPassword: String, password: String) {
        self.masterPassword = password
        self.currentPassword = currentPassword
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
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
    
    func addCurrencyVC(){
        let storyboard = UIStoryboard(name: "App", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CurrencyViewController") as! CurrencyViewController
        vc.currencyViewType = .changePasswordVerify
        self.addChild(vc)
        rootView.addSubview(vc.view)
        rootView.bringSubviewToFront(vc.view)
        vc.didMove(toParent: self)
        vc.delegate = self
        self.currencyVC = vc
    }
    
    private func setPasswordPressed(_ password: String) {
        guard masterPassword == password else {
            showAlertMessage(titleStr: "Invalid Confirm Password", messageStr: "Confirm password does not match")
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                if settings.authorizationStatus == .authorized {
                    
                    let hud = JGProgressHUD(style: .dark)
                    hud.textLabel.text = "\("Setting Master Password".localized())..."
                    hud.show(in: strongSelf.view)
                    
                    if let pwdConf = Blackbox.shared.pwdConf {
                        // encrypt the pwdConf using the master password
                        guard BlackboxCore.encryptPwdConf(pwdConf, key: strongSelf.masterPassword) else {
                            hud.dismiss()
                            return
                        }
                        
                        do {
                            
                            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                            let path = paths[0].appendingPathComponent("&#39.cfg")
                            try "".write(to: path, atomically: true, encoding: .utf8)
                            // Reset the PasswordChange value
                            UserDefaults.standard.set(false, forKey: "PasswordChange")
                            
                            // Register Presence
                            let account = Blackbox.shared.account
                            account.registerAsync { (success, error) in
                                if success {
                                    strongSelf.initializeApp(hud: hud)
                                } else {
                                    DispatchQueue.main.async {
                                        hud.dismiss()
                                        if let error = error, error == .invalidPushToken || error == .invalidVoipToken {
                                            let appearance = SCLAlertView.SCLAppearance(
                                                showCloseButton: false
                                            )
                                            let alert = SCLAlertView(appearance: appearance)
                                            alert.addButton("OK".localized()) {
                                                hud.show(in: strongSelf.view)
                                                account.registerAsync(checkTokens: false) { (success, registrationError) in
                                                    if success {
                                                        strongSelf.initializeApp(hud: hud)
                                                    } else {
                                                        DispatchQueue.main.async {
                                                            hud.dismiss()
                                                        }
                                                    }
                                                }
                                            }
                                            alert.showWarning("Push notification problem", subTitle: "For some unknown reasons we were unable to retrieve the Notification Tokens used for Apple Background Push notification. We will continue the registration, but background notification will not work. Usually the problem fix itself by rebooting the phone or after few hours (with app closed).".localized())
                                        }
                                        else {
                                            SCLAlertView().showSuccess("Configuration completed, please CLOSE the app and open it again.".localized(), subTitle: "")
                                        }
                                    }
                                }
                            }
                        } catch {
                            loge(error)
                            DispatchQueue.main.async {
                                hud.dismiss()
                            }
                        }
                    }
                }
                else {
                    AppUtility.notificationDenied(viewController: strongSelf)
                }
            }
        }
    }
    
    private func initializeApp(hud: JGProgressHUD) {
        let account = Blackbox.shared.account
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            hud.textLabel.text = "\("Fetching data".localized())..."
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
                    }
                    else {
                        SCLAlertView().showError("Something went wrong while connecting to the server. Unable to login.(1005)".localized(), subTitle: "")
                    }
                }
            }
        }
        
    }
    
}

extension ConfirmMasterPasswordViewController: CurrencyDelegate {
    func onValueConverted(value: String) {
        if Blackbox.shared.updatingPassword {
            if masterPassword == value {
                let error = Blackbox.shared.updateAccountPassword(currentPwd:currentPassword,
                                                                  newPwd: masterPassword,
                                                                  confirmPwd: value)
                if let error = error {
                    logi(error)
                    showAlertMessage(titleStr: "Invalid", messageStr: error)
                } else {
                    let hud = JGProgressHUD(style: .dark)
                    hud.textLabel.text = "Success".localized()
                    hud.indicatorView = JGProgressHUDSuccessIndicatorView()
                    hud.show(in: AppUtility.getLastVisibleWindow())
                    hud.dismiss(afterDelay: 3)
                    Blackbox.shared.updatingPassword = false
                    popToViewController()
                }
            }
            return
        } else {
            setPasswordPressed(value)
        }
    }
    
    func popToViewController() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            AppUtility.getLastVisibleWindow().rootViewController?.dismiss(animated: true)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            (UIApplication.shared.visibleViewController as? UINavigationController)?.popViewController(animated: true)
        }
        
    }
}
