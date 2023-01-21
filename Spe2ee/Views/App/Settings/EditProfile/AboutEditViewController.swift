

import UIKit

class AboutEditViewController: UIViewController {
  @IBOutlet weak var aboutTextView: UITextView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "About".localized()
    
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
    navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
  }
  
  @objc func save() {
    _ = aboutTextView.text
    dismiss(animated: true, completion: nil)
  }
  
  @objc func cancel() {
    dismiss(animated: true, completion: nil)
  }
}
