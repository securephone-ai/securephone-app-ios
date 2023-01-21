import UIKit
import QuickLook
import PinLayout
import WebKit
import CryptoKit
import BlackboxCore

class DocsPreviewViewController: BBViewController {
    
    private var leftButtonBar = UIBarButtonItem()
    private var rightButtonBar = UIBarButtonItem()
    private var tmpUrl: URL!
    private let previewController = QLPreviewController()
    private let webView = WKWebView()
    
    private lazy var waterMarkLabel: UILabel = {
        let sideSize = UIScreen.main.bounds.size.height > UIScreen.main.bounds.size.width ? UIScreen.main.bounds.size.height * 1.5 : UIScreen.main.bounds.size.width * 1.5
        let label = UILabel(frame: CGRect(x: -sideSize/2, y: -sideSize/2, width: sideSize, height: sideSize*2))
        label.isUserInteractionEnabled = false
        label.textColor = .gray
        label.alpha = 0.30
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 18)
        label.adjustsFontForContentSizeCategory = true
        
        let inputString = "\(Blackbox.shared.account.registeredNumber ?? "")51e3eb37471db46a4c4f9472deb594d4a56ceae0a163728aa45b6a06ed1d43cb"
        let inputData = Data(inputString.utf8)
        let hashed = SHA256.hash(data: inputData)
        let hashString = hashed.compactMap { String(format: "%02x", $0) }.joined()
        if let hash = hashString.slicing(from: 0, length: 16) {
            var finalStr = "Top Secret \(hash) #Calc"
            for _ in 1..<120 {
                finalStr = "\(finalStr) # Top Secret \(hash) #Calc"
            }
            label.text = "\(finalStr)"
        }
        
        label.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 5)
        label.isHidden = true
        return label
    }()
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        imageView.image = UIImage(named: "logo-green")
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.alpha = 0.15
        return imageView
    }()
    
    init(docUrl: URL, key: String, pathExtension: String = "") {
        let url = docUrl.deletingPathExtension()
        tmpUrl = url.appendingPathExtension(pathExtension)
        
        if !key.isEmpty,
           let data = AppUtility.decryptFile(docUrl.path, key: key.base64Decoded ?? "") {
            do {
                try data.write(to: tmpUrl)
            } catch {
                loge(error)
            }
        } else {
            do {
                try FileManager.default.copyItem(at: docUrl, to: tmpUrl)
            } catch {
                loge(error)
            }
        }
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = rightButtonBar
        
        previewController.dataSource = self
        previewController.delegate = self
        
        view.addSubview(webView)
        view.addSubview(waterMarkLabel)
        view.addSubview(logoImageView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        webView.loadFileURL(tmpUrl, allowingReadAccessTo: tmpUrl)
        //waterMarkLabel.isHidden = false
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        waterMarkLabel.isHidden = true
        
        do {
            try FileManager.default.removeItem(at: tmpUrl)
        } catch {
            loge(error)
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        webView.pin.all()
        logoImageView.pin.center()
        waterMarkLabel.pin.vCenter().hCenter()
    }
    
    @objc func printDoc() {
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Confidential"
        printInfo.outputType = .general
        
        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        printController.showsNumberOfCopies = false
        printController.printingItem = tmpUrl
        printController.present(animated: true, completionHandler: nil)
    }
    
    @objc func dismissView() {
        NotificationCenter.default.removeObserver(self)
        do {
            try FileManager.default.removeItem(at: tmpUrl)
        } catch {
            loge(error)
        }
        
        dismiss(animated: true, completion: nil)
        
    }
}


extension DocsPreviewViewController: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    
    func previewControllerWillDismiss(_ controller: QLPreviewController) {
        do {
            try FileManager.default.removeItem(at: tmpUrl)
        } catch {
            loge(error)
        }
    }
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return tmpUrl as QLPreviewItem
    }
    
}
