
import UIKit

class WallpaperCell: UICollectionViewCell {
  static let ID = "WallpaperCell_ID"
  
  var wallpaperImageView = UIImageView()
  private var blinkView: UIView = {
    let view = UIView()
    view.backgroundColor = .black
    view.alpha = 0
    return view
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    contentView.addSubview(wallpaperImageView)
    contentView.addSubview(blinkView)
    
    let tapGesture = UILongPressGestureRecognizer(target: self, action: #selector(blink(_:)))
    tapGesture.minimumPressDuration = 0
    tapGesture.delegate = self
    wallpaperImageView.isUserInteractionEnabled = true
    wallpaperImageView.addGestureRecognizer(tapGesture)
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    wallpaperImageView.pin.all(10)
    blinkView.pin.all(10)
  }
  
  @objc private func blink(_ gesture: UITapGestureRecognizer) {
    switch gesture.state {
    case .began:
      UIView.animate(withDuration: 0.1) {
        self.blinkView.alpha = 0.2
      }
    case .ended:
      UIView.animate(withDuration: 0.1) {
        self.blinkView.alpha = 0
      }
      
      guard let vc = self.findViewController() as? WallpaperListViewController else { return }
      guard let indexPath = self.indexPath else { return }
      
      vc.navigationController?.pushViewController(WallpaperPreviewPagerViewController(wallpapersNames: vc.wallpaperNames, selectedIndex: indexPath.row))
    default:
      break
    }
  }
  
}

extension WallpaperCell: UIGestureRecognizerDelegate {
  
}

