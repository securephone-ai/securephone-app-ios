//
//  ViewController.swift
//  BlackboxSwiftTests
//
//  Created by Valerio Sebastianelli on 11/9/20.
//

import UIKit
import BlackboxCore


class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        BlackboxCore.setPwdConf("1234")
        BlackboxCore.signupDevice("1234", otp: "123", smsotp: "123")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let pwdConf = BlackboxCore.getPwdConf()
        print(pwdConf)
    }

}

