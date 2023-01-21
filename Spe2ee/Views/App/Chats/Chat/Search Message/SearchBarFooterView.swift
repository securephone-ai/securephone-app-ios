import Foundation
import Combine


public class SearchBarFooterView: UIView {
  
  let selectedIndexChanged = PassthroughSubject<IndexPath, Never>()
  
  var indexPaths: [IndexPath] = [] {
    didSet {
      selectedIndexPath = indexPaths.reversed().first
    }
  }
  var selectedIndexPath: IndexPath? {
    didSet {
      
      DispatchQueue.main.async { [weak self] in
        guard let strongSelf = self else { return }
        if let selectedIndexPath = strongSelf.selectedIndexPath {
          strongSelf.selectedIndexChanged.send(selectedIndexPath)
          
          strongSelf.lookUpButton.isEnabled = true
          strongSelf.lookDownButton.isEnabled = true
          
          let reversedPaths = strongSelf.indexPaths.reversed()
          for (index, indexPath) in reversedPaths.enumerated() where indexPath == selectedIndexPath {
            strongSelf.selectedPathDetailLabel.text = "\(index+1) of \(strongSelf.indexPaths.count) matches"
            
            if let lastIndex = reversedPaths.last, strongSelf.selectedIndexPath == lastIndex {
              strongSelf.lookUpButton.isEnabled = false
            } else if let firstIndex = reversedPaths.first, strongSelf.selectedIndexPath == firstIndex {
              strongSelf.lookDownButton.isEnabled = false
            }
            
          }
        } else {
          strongSelf.selectedPathDetailLabel.text = ""
        }
        strongSelf.setNeedsLayout()
        strongSelf.layoutIfNeeded()
        
      }
    }
  }
  
  lazy var lookUpButton: UIButton = {
    let button = UIButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 38, height: 38)
    let config = UIImage.SymbolConfiguration(pointSize: 23, weight: UIImage.SymbolWeight.light)
    button.setImage(UIImage(systemName: "chevron.up", withConfiguration: config), for: .normal)
    button.addTarget(self, action: #selector(lookUpButtonPressed), for: .touchUpInside)
    return button
  }()
  
  lazy var lookDownButton: UIButton = {
    let button = UIButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 38, height: 38)
    let config = UIImage.SymbolConfiguration(pointSize: 23, weight: UIImage.SymbolWeight.light)
    button.setImage(UIImage(systemName: "chevron.down", withConfiguration: config), for: .normal)
    button.addTarget(self, action: #selector(lookDownButtonPressed), for: .touchUpInside)
    return button
  }()
  
  var selectedPathDetailLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 17)
    label.textColor = .gray
    label.adjustsFontForContentSizeCategory = true
    label.text = "A"
    label.frame = CGRect(x: 0, y: 0, width: 0, height: label.requiredHeight)
    label.text = ""
    return label
  }()
  
  init() {
    super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: Blackbox.shared.defaultFooterHeight))
    backgroundColor = .systemGray6
    addSubview(selectedPathDetailLabel)
    addSubview(lookUpButton)
    addSubview(lookDownButton)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    selectedPathDetailLabel.sizeToFit()
    
    lookUpButton.pin.left(14).top(4)
    lookDownButton.pin.centerLeft(to: lookUpButton.anchor.centerRight).marginLeft(20)
    selectedPathDetailLabel.pin.vCenter(to: lookUpButton.edge.vCenter).hCenter()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  @objc func lookUpButtonPressed() {
    if indexPaths.isEmpty == false {
      let reversedPaths = indexPaths.reversed()
      guard let lastIndex = reversedPaths.last else { return }
      
      for (index, indexPath) in reversedPaths.enumerated() where indexPath == selectedIndexPath && selectedIndexPath != lastIndex {
        selectedIndexPath = reversedPaths[offset: index+1]
        break
      }
    }
  }
  
  @objc func lookDownButtonPressed() {
    if indexPaths.isEmpty == false {
      let reversedPaths = indexPaths.reversed()
      guard let firstIndex = reversedPaths.first else { return }
      
      for (index, indexPath) in reversedPaths.enumerated() where indexPath == selectedIndexPath && selectedIndexPath != firstIndex {
        selectedIndexPath = reversedPaths[offset: index-1]
        break
      }
    }
  }
  
}
