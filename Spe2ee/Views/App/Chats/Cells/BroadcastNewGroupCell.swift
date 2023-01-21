
import UIKit

class BroadcastNewGroupCell: UITableViewCell {
  static let ID = "BroadcastNewGroupCell"
  
  @IBOutlet weak var newGroupBtn: UIButton!
  
  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
    newGroupBtn.setTitle("New Group".localized(), for: .normal)
    newGroupBtn.titleLabel?.adjustsFontForContentSizeCategory = true
  }
  
  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
    
    // Configure the view for the selected state
  }
  
  @IBAction func broadcastClick(_ sender: Any) {
  
  }
  
  @IBAction func newGroupClick(_ sender: Any) {
  
  }
}

