import UIKit

class ChooseMasterPasswordViewController: UIViewController {
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    
    private let rootView = UIView()
    var currencyVC: CurrencyViewController!
    var currentPassword: String!
   
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(rootView)
        addCurrencyVC()
    }
    
    func addCurrencyVC(){
        let storyboard = UIStoryboard(name: "App", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CurrencyViewController") as! CurrencyViewController
        vc.currencyViewType = .changePassword
        self.addChild(vc)
        rootView.addSubview(vc.view)
        rootView.bringSubviewToFront(vc.view)
        vc.didMove(toParent: self)
        vc.delegate = self
        self.currencyVC = vc
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
         
        rootView.pin.left().right().height(self.view.height).bottom()
        currencyVC?.view.pin.left().right().height(self.rootView.height).bottom()
        currencyVC?.view.layoutIfNeeded()
        currencyVC?.view.layoutSubviews()
        
    }
    
    private func nextPressed(_ password: String) {
        
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                if settings.authorizationStatus == .authorized {
                    let vc = ConfirmMasterPasswordViewController(currentPassword: strongSelf.currentPassword, password: password)
                    vc.modalPresentationStyle = .fullScreen
                    let transition = CATransition()
                    transition.duration = 0.2
                    transition.type = CATransitionType.push
                    transition.subtype = CATransitionSubtype.fromRight
                    transition.timingFunction = CAMediaTimingFunction(name:CAMediaTimingFunctionName.easeInEaseOut)
                    strongSelf.view.window!.layer.add(transition, forKey: kCATransition)
                    strongSelf.present(vc, animated: false, completion: nil)
                } else {
                    AppUtility.notificationDenied(viewController: strongSelf)
                }
            }
        }
    }
}

extension ChooseMasterPasswordViewController: CurrencyDelegate {
    func onValueConverted(value: String) {
        nextPressed(value)
    }
}

