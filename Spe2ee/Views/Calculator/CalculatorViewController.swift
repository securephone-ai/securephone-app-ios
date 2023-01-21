//
//  CalculatorViewController.swift
//
//  Created by Mac on 9/28/21.
//

import UIKit

protocol CalculatorVCDelegate {
    func buttonPressed(_ button: CalculatorButton)
}

class CalculatorViewController: BaseControllerCalc {
    
    @IBOutlet weak var displayView: UIView!
    @IBOutlet weak var buttonsView: ButtonsView!
    @IBOutlet weak var subDisplayTop: NSLayoutConstraint!
    
    private var selectedButton: CalculatorButton?
    
    var delegate: CalculatorVCDelegate?
    
    override func viewDidLoad() {
        buttonsView.delegate = self
        setupCustomGestures()
        super.viewDidLoad()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.roundButtons()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        addMenuObserverNotification()
    }
    override func viewWillDisappear(_ animated: Bool) {
        removeMenuObserverNotification()
    }
    
    override func actionForNumberButton(_ sender: UIButton) {
        makeButtonDeselect(sender as? CalculatorButton)
        super.actionForNumberButton(sender)
    }
    override func actionForOperatorButton(_ sender: UIButton) {
        makeButtonDeselect(sender as? CalculatorButton)
        makeButtonSelected(sender as? CalculatorButton)
        super.actionForOperatorButton(sender)
    }
    override func actionForEqualButton(_ sender: UIButton) {
        makeButtonDeselect()
        super.actionForEqualButton(sender)
    }
    override func actionForShowButton(_ sender: UIButton) {
        makeSubDisplayDropdown()
        super.actionForShowButton(sender)
    }
    override func deepClear() {
        makeButtonDeselect()
        super.deepClear()
    }
    
    func roundButtons(){
        guard let _buttonsView = self.buttonsView else {
            return
        }
        for view in _buttonsView.subviews {
            if let _stackView = view as? UIStackView {
                for subview in _stackView.subviews {
                    if let _stackViewSubView = subview as? UIStackView {
                        for _stackViewSubView2 in _stackViewSubView.subviews {
                            if let _calculatorButton = _stackViewSubView2 as? CalculatorButton, _calculatorButton.getButtonValue() != "0" {
                                _calculatorButton.layer.cornerRadius = _calculatorButton.width/2
                                _calculatorButton.layer.masksToBounds = true
                            }
                        }
                        
                    }
                }
            }
        }
    }
}
private extension CalculatorViewController {
    func makeSubDisplayDropdown() {
        subDisplay.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.subDisplayTop.constant = 20
            self.view.layoutIfNeeded()
        }
    }
    func setupCustomGestures() {
        makeLongPressibleView()
        makeSwipableView()
    }
    func makeLongPressibleView() {
        let longPress = makeLongPressAction(with: #selector(longPress(_:)))
        displayView.addGestureRecognizer(longPress)
    }
    func makeSwipableView() {
        let swipeToUp = makeSwipeAction(with: #selector(swipeUpSubDisplay(_:)))
        swipeToUp.direction = .up
        subDisplay.addGestureRecognizer(swipeToUp)
    }
    func makeButtonSelected(_ newButton: CalculatorButton?) {
        if let newbutton = newButton {
            newbutton.isSelected = true
            selectedButton = newbutton
        }
    }
    func makeButtonDeselect(_ newButton: CalculatorButton? = nil) {
        if let newbutton = newButton, newbutton == selectedButton { return }
        if let oldbutton = selectedButton {
            oldbutton.forceToDeselect()
            selectedButton = nil
        }
    }
}
// MARK: - Notification Center
private extension CalculatorViewController {
    private func removeMenuObserverNotification() {
        NotificationCenter.default.removeObserver(self)
    }
    private func addMenuObserverNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(willShowMenu), name: UIMenuController.willShowMenuNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willHideMenu), name: UIMenuController.willHideMenuNotification, object: nil)
    }
    @objc func willShowMenu() {
        mainDisplay.backgroundColor = UIColor(named: "Custom_DarkGray")
    }
    @objc func willHideMenu() {
        mainDisplay.backgroundColor = .clear
    }
}
// MARK: - Action Methods
private extension CalculatorViewController {
    func makeLongPressAction(with action: Selector?) -> UILongPressGestureRecognizer {
        return UILongPressGestureRecognizer(target: self, action: action)
    }
    func makeSwipeAction(with action: Selector?) -> UISwipeGestureRecognizer {
        return UISwipeGestureRecognizer(target: self, action: action)
    }
    @objc func swipeUpSubDisplay(_ recognizer: UISwipeGestureRecognizer) {
        if let _ = recognizer.view {
            UIView.animate(withDuration: 0.3) {
                self.subDisplayTop.constant = -150
                self.view.layoutIfNeeded()
            }
        }
    }
    @objc func longPress(_ recognizer: UIGestureRecognizer) {
        if let recognizedView = recognizer.view,
           recognizer.state == .began {
            mainDisplay.becomeFirstResponder()
            UIMenuController.shared.showMenu(from: recognizedView, rect: mainDisplay.frame)
        }
    }
}
extension CalculatorViewController: ButtonsViewDelegate {
    func sendSelectedButton(_ button: CalculatorButton) {
        var btnTitle = button.getButtonValue()
        btnTitle = btnTitle.replacingOccurrences(of: "−", with: "-")
        if ["+", "−", "÷", "×"].contains(btnTitle) {
                    selectedButton = button
        }
        self.delegate?.buttonPressed(button)
    }
}

