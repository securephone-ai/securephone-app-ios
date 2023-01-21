
import UIKit

class FakeHeaderCell: UITableViewCell {
  static let ID = "FakeHeaderCell"
  
  @IBOutlet weak var headerLabel: UILabel!
  
  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
    self.contentView.backgroundColor = .systemGray6
  }
  
  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
    
    // Configure the view for the selected state
  }
  
}
