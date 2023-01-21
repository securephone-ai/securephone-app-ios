//
//  CommonMethods.swift
//  Calc
//
//  Created by Aakash on 12/08/2022.
//  Copyright © 2022 Kryptotel fz llc. All rights reserved.
//

import UIKit

func showLoader(view: UIView) -> UIActivityIndicatorView {
    let spinner = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 40, height:40))
    spinner.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    spinner.layer.cornerRadius = 3.0
    spinner.clipsToBounds = true
    spinner.hidesWhenStopped = true
    spinner.style = UIActivityIndicatorView.Style.medium
    spinner.center = view.center
    view.addSubview(spinner)
    spinner.startAnimating()
    UIApplication.shared.beginIgnoringInteractionEvents()
    return spinner
}

extension UIActivityIndicatorView {

    func dismissLoader() {
        self.stopAnimating()
        UIApplication.shared.endIgnoringInteractionEvents()
    }

}


extension UIViewController {
    func showAlertMessage(titleStr:String, messageStr:String) {
        let alert = UIAlertController(title: titleStr, message: messageStr, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "OK", style: .cancel) { (alert) in
            self.dismiss(animated: true, completion: nil)
        }
        alert.addAction(alertAction)
        self.present(alert, animated: true, completion: nil)
    }

}
