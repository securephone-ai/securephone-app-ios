import UIKit

class ArchiveChatCell: UITableViewCell {
  static let ID = "ArchiveChatCell"
  
  @IBOutlet weak var archivedChatsCountLabel: UILabel!
  @IBOutlet weak var archiveChatLabel: UILabel!
  
  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
    archiveChatLabel.text = "Archived Chats".localized()
  }
  
  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
    
    // Configure the view for the selected state
  }
  
}

