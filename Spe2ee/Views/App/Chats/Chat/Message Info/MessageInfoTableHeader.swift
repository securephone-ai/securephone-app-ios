import Foundation
import PinLayout
import SwifterSwift
import MapKit
import AudioToolbox


class MessageInfoTableHeader: UIView {
  
  private var messageViewModel: MessageViewModel
  private lazy var tableView: UITableView = {
    let table = UITableView()
    table.isScrollEnabled = false
    table.delegate = self
    table.dataSource = self
    table.separatorStyle = .none
    table.backgroundColor = .clear
    table.contentInset.bottom = 8
    table.register(MessageCell.self, forCellReuseIdentifier: Constants.MessageCell_ID)
    table.register(MessageCellText.self, forCellReuseIdentifier: Constants.MessageCellText_ID)
    table.register(MessageCellLocation.self, forCellReuseIdentifier: Constants.MessageCellLocation_ID)
    table.register(MessageCellAudio.self, forCellReuseIdentifier: Constants.MessageCellAudio_ID)
    table.register(MessageCellDocument.self, forCellReuseIdentifier: Constants.MessageCellDocument_ID)
    table.register(MessageCellSystem.self, forCellReuseIdentifier: Constants.MessageCellSystem_ID)
    table.register(MessagesSectionHeader.self, forHeaderFooterViewReuseIdentifier: Constants.MessagesSectionHeader_ID)
    return table
  }()
  
  private let backgroundImage: UIImageView = {
    var image: UIImage?
    if let imgName = UserDefaults.standard.string(forKey: "chat_wallpaper") {
      image = UIImage(named: imgName)
    } else {
      image = UIImage(named: "Wallpaper_5")
    }
    let imageView = UIImageView(image: image)
    imageView.contentMode = .scaleAspectFill
    return imageView
  }()
  
  init(messageViewModel: MessageViewModel) {
    self.messageViewModel = messageViewModel
    super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: 30 + self.messageViewModel.cellHeight + 20))
    
    addSubview(backgroundImage)
    addSubview(tableView)
    clipsToBounds = true
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    backgroundImage.pin.all()
    tableView.pin.all()
    
//    sectionView.pin.top().left().right()
//    cellView.pin.below(of: sectionView, aligned: .center)
  }
}

extension MessageInfoTableHeader: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 40
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return messageViewModel.cellHeight
  }
  
  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: Constants.MessagesSectionHeader_ID) as? MessagesSectionHeader else { return UIView()}
    header.labelBackgroundView.alpha = 1
    
    if messageViewModel.message.dateSent.isInToday {
      header.titleLabel.text = "Today".localized()
    }
    else if  messageViewModel.message.dateSent.isInYesterday {
      header.titleLabel.text = "Yesterday".localized()
    }
    else if messageViewModel.message.dateSent.isInCurrentWeek {
      header.titleLabel.text = messageViewModel.message.dateSent.dayName()
    }
    else if messageViewModel.message.dateSent.isInCurrentYear {
      header.titleLabel.text = Blackbox.shared.account.settings.calendar == .gregorian ? messageViewModel.message.dateSent.string(withFormat: "E, MMM d") : messageViewModel.message.dateSent.dateStringIslamic(withFormat: "E, MMM d")
    }
    else {
      header.titleLabel.text = Blackbox.shared.account.settings.calendar == .gregorian ? messageViewModel.message.dateSent.string(withFormat: "E, MMM yyyy") : messageViewModel.message.dateSent.dateStringIslamic(withFormat: "E, MMM yyyy")
    }
    
    return header
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
      return 1
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch messageViewModel.message.type {
    case .text, .alertCopy, .alertForward, .alertDelete:
      if messageViewModel.message.isAlertMessage {
        let cell = MessageCellText()
        cell.viewModel = messageViewModel
        return cell
      }
      if let cell = tableView.dequeueReusableCell(withIdentifier: Constants.MessageCellText_ID, for: indexPath) as? MessageCellText {
        cell.viewModel = messageViewModel
        return cell
      }
    case .photo, .video:
      if let cell = tableView.dequeueReusableCell(withIdentifier: Constants.MessageCell_ID, for: indexPath) as? MessageCell {
        cell.viewModel = messageViewModel
        return cell
      }
    case .location:
      if let cell = tableView.dequeueReusableCell(withIdentifier: Constants.MessageCellLocation_ID, for: indexPath) as? MessageCellLocation {
        cell.viewModel = messageViewModel
        return cell
      }
    case .audio:
      if let cell = tableView.dequeueReusableCell(withIdentifier: Constants.MessageCellAudio_ID, for: indexPath) as? MessageCellAudio {
        cell.viewModel = messageViewModel
        return cell
      }
    case .document(_):
      if let cell = tableView.dequeueReusableCell(withIdentifier: Constants.MessageCellDocument_ID, for: indexPath) as? MessageCellDocument {
        cell.viewModel = messageViewModel
        return cell
      }
    default:
      break
    }
    return UITableViewCell()
  }
}
