//
//  CurrencyViewController.swift
//  Calc
//
//

import UIKit


protocol CurrencyDelegate {
    func onValueConverted(value: String)
}

enum CurrencyViewType {
    case login
    case currentPasswordVerify
    case changePassword
    case changePasswordVerify
}

class CurrencyViewController: UIViewController {
    
    private var selectedCurrency: ConversionCurrencyData?
    private var selectedConversionDetails = ConversionDetails()
    
    @IBOutlet weak var imgLeftCurrency: UIImageView!
    @IBOutlet weak var lblLeftCurrency: UILabel!
    @IBOutlet weak var imgRightCurrency: UIImageView!
    @IBOutlet weak var lblRightCurrency: UILabel!
    @IBOutlet weak var inputField: UITextField!
    @IBOutlet weak var outputField: UILabel!
    
    @IBOutlet weak var convertBtn: UIButton!
    @IBOutlet weak var outputBottomLbl: UILabel!
    
    @IBOutlet weak var titleLbl: UILabel!
    
    var delegate: CurrencyDelegate?
    var currencyViewType: CurrencyViewType = .login
    
    static var firstCurrency: String = "USD"
    static var secondCurrency: String = "EUR"
    var amount: String? = nil
    
    // MARK: - IBActions
    @IBAction func btnReplaceAction(_ sender: Any) {
        revertCurrencies(mainImg: imgLeftCurrency.image, mainCur: lblLeftCurrency.text, mainAmt: inputField.text)
    }

    @IBAction func btnEqualAction(_ sender: Any) {
        inputField.resignFirstResponder()
        if inputField.text!.isEmpty { return }
        guard let conversionData = getConversionData() else {return}
        getApiEcbConvertRates(data: conversionData)
    }

    @IBAction func btnFromAction(_ sender: Any) {
        selectedConversionDetails.amount = inputField.text
        selectedConversionDetails.source = "left"
        self.performSegue(withIdentifier: "currencies", sender: self)
    }

    @IBAction func btnToAction(_ sender: Any) {
        selectedConversionDetails.amount = inputField.text
        selectedConversionDetails.source = "right"
        self.performSegue(withIdentifier: "currencies", sender: self)
    }
    

    func initialData() {
        setFromCurrencyData(img: UIImage(named: CurrencyViewController.firstCurrency.lowercased()), curIso: CurrencyViewController.firstCurrency, amount: amount)
        setToCurrencyData(img: UIImage(named: CurrencyViewController.secondCurrency.lowercased()), curIso: CurrencyViewController.secondCurrency, amount: "0.00")
    }

    func getConversionData() -> ConversionData? {
        guard
            let amount = inputField.text,
            let fromCur = lblLeftCurrency.text,
            let toCur = lblRightCurrency.text
            else { return nil }
        let conversionData = ConversionData(fromCurrency: fromCur,
                                            toCurrency: toCur,
                                            convertDate: "",
                                            fromAmount: Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0.0)
        return conversionData
    }

    func revertCurrencies(mainImg: UIImage?, mainCur: String?, mainAmt: String?) {
        imgLeftCurrency.image = imgRightCurrency.image
        lblLeftCurrency.text = lblRightCurrency.text
        inputField.text = outputField.text
        imgRightCurrency.image = mainImg
        lblRightCurrency.text = mainCur
        outputField.text = mainAmt!.isEmpty ? "0.00" : mainAmt
    }

    func setFromCurrencyData(img: UIImage?, curIso: String, amount: String?, setAmount: Bool = true) {
        imgLeftCurrency.image = img
        lblLeftCurrency.text = curIso
        if setAmount {
            inputField.text = amount
        }
    }

    func setToCurrencyData(img: UIImage?, curIso: String, amount: String, setAmount: Bool = true) {
        imgRightCurrency.image = img
        lblRightCurrency.text = curIso
        if setAmount {
            outputField.text = amount
        }
    }

    func getApiEcbConvertRates(data: ConversionData) {
        delegate?.onValueConverted(value: "\(data.fromCurrency!)\(data.fromAmount!)\(data.toCurrency!)")
        
        if currencyViewType != .login { return }
        
        CurrencyViewController.firstCurrency = data.fromCurrency!
        CurrencyViewController.secondCurrency = data.toCurrency!
        
        let spinner = showLoader(view: self.view)
        let callUri = createConvertRatesUri(fromCur: data.fromCurrency!, date: data.convertDate!, amount: data.fromAmount!, toCur: data.toCurrency!)
        DispatchQueue.main.async {
            ApiService.shared.fetchApiData(urlString: callUri) { (rates: RatesDetailModel?, error: ErrorModel?) in
                if let error = error {
                    spinner.dismissLoader()
                    self.showAlertMessage(titleStr: "Error", messageStr: error.message!)
                }
                spinner.dismissLoader()
                guard let rates = rates else { return }
                
                let amount: Double = Double(self.inputField.text!) ?? 0.0
                self.outputField.text = String(format: "%.2f", amount * rates.rates.value)
            }
        }
    }

    func createConvertRatesUri(fromCur: String, date: String, amount: Double, toCur: String) -> String {
        return "\(Routes.convertRatesUri)&base_currency=\(fromCur)&amount=\(amount)&date=\(date)&currencies=\(toCur)"
    }

    // MARK: - Navigation
    // ------------------
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "currencies" {
            guard let selectCurrencyViewController = segue.destination as? SelectCurrencyViewController else {return}
            selectCurrencyViewController.selectedCurrency.details = self.selectedConversionDetails
        }
    }

    @IBAction func unwindFromCurrenciesList(_ segue: UIStoryboardSegue) {
        if let currenciesVC = segue.source as? SelectCurrencyViewController {
            let data = currenciesVC.selectedCurrency
            guard let source = data.details?.source, let amount = data.details?.amount, let currency = data.currency else { return }
            if source == "left" {
                setFromCurrencyData(img: UIImage(named: currency.symbol.lowercased()), curIso: currency.symbol, amount: amount, setAmount: false)
            } else {
                setToCurrencyData(img: UIImage(named: currency.symbol.lowercased()), curIso: currency.symbol, amount: amount, setAmount: false)
            }
            
            outputField.text = "0.00"
        }
    }
    
    @IBAction func onDoneInput(_ sender: Any) {
        inputField.resignFirstResponder()
    }
    

    // MARK: - View Controller Lifecycle
    // ---------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        initialData()
        
        // Hide keyboard on single tap gesture
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        gestureRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(gestureRecognizer)
        
        switch currencyViewType {
        case .login:
            break
        case .currentPasswordVerify:
            outputBottomLbl.isHidden = true
            outputField.isHidden = true
            convertBtn.setTitle("Next".localized(), for: .normal)
            titleLbl.text = "Enter Current Master Password"
        case .changePassword:
            outputBottomLbl.isHidden = true
            outputField.isHidden = true
            convertBtn.setTitle("Next".localized(), for: .normal)
            titleLbl.text = "Choose a Master Password"
        case .changePasswordVerify:
            outputBottomLbl.isHidden = true
            outputField.isHidden = true
            convertBtn.setTitle("Set Master Password".localized(), for: .normal)
            titleLbl.text = "Verify Master Password"
        }
    }
    
    @objc private func hideKeyboard() {
      inputField.resignFirstResponder()
    }

}
