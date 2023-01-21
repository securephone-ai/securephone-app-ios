import UIKit
import PinLayout

class UpdatePasswordViewController: BBViewController {
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    
    private let rootView = UIView()
    var currencyVC: CurrencyViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Blackbox.shared.updatingPassword = true
        self.view.addSubview(rootView)
        addCurrencyVC()
    }
    
    func addCurrencyVC(){
        let storyboard = UIStoryboard(name: "App", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CurrencyViewController") as! CurrencyViewController
        vc.currencyViewType = .currentPasswordVerify
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
        if Blackbox.shared.isCorrectPassword(password) {
            let vc = ChooseMasterPasswordViewController()
            vc.currentPassword = password
            vc.modalPresentationStyle = .fullScreen
            
            let transition = CATransition()
            transition.duration = 0.2
            transition.type = CATransitionType.push
            transition.subtype = CATransitionSubtype.fromRight
            transition.timingFunction = CAMediaTimingFunction(name:CAMediaTimingFunctionName.easeInEaseOut)
            view.window!.layer.add(transition, forKey: kCATransition)
            present(vc, animated: false, completion: nil)
        } else {
            showAlertMessage(titleStr: "Invalid Current Password", messageStr: "Current password does not match")
        }
    }
    
}

extension UpdatePasswordViewController: CurrencyDelegate {
    func onValueConverted(value: String) {
        nextPressed(value)
    }
}



