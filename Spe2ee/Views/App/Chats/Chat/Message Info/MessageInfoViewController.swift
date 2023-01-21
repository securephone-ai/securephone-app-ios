import UIKit
import PinLayout
import Combine


class MessageInfoViewController: UIViewController {
  
//  var chatViewModel: ChatViewModel!
  private var messageViewModel: MessageViewModel!
  private var tableHeaderView: MessageInfoTableHeader
  private var cancellable: AnyCancellable?
  private var fetchReceiptsTimer: DispatchTimer?
  private lazy var isGroup: Bool = {
    return self.messageViewModel.group != nil
  }()
  
  private var groupReceipts: [MessageReceipt] {
    get {
      return messageViewModel.groupReceipts ?? []
    } set {
      messageViewModel.groupReceipts = newValue
    }
  }
  
  private var readReceipts: [MessageReceipt] = []
  private var receivedReceipts: [MessageReceipt] = []
  
  private lazy var tableView: UITableView = {
    let table = UITableView(frame: self.view.bounds)
    table.dataSource = self
    table.delegate = self
    table.backgroundColor = .systemGray6
    table.contentInset.bottom = 10
    table.tableFooterView = UIView()
    table.register(MessageInfoCell.self, forCellReuseIdentifier: Constants.MessageInfoCell_ID)
    table.alwaysBounceVertical = false
    return table
  }()
  
  init(messageViewModel: MessageViewModel) {
    self.messageViewModel = messageViewModel
    self.tableHeaderView = MessageInfoTableHeader(messageViewModel: messageViewModel)
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.title = "Message Info".localized()
    
    view.addSubview(tableView)
    view.backgroundColor = .white

    tableView.tableHeaderView = tableHeaderView
    
    setupBinding()
    
    if isGroup {
      
      readReceipts = groupReceipts.filter { $0.dateRead != nil }
      receivedReceipts = groupReceipts.filter { $0.dateReceived != nil && $0.dateRead == nil }
      
      fetchReceiptsTimer = DispatchTimer(countdown: .milliseconds(1), repeating: .seconds(2), payload: { [weak self] in
        guard let strongSelf = self else { return }
        strongSelf.messageViewModel.group!.fetchReadReceiptsAsync(message: strongSelf.messageViewModel.message) { (receipts) in
          DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            if let receipts = receipts {
              strongSelf.groupReceipts = receipts

              for index in 0..<receipts.count {
                strongSelf.groupReceipts[index].contact = strongSelf.messageViewModel.group!.getGroupMember(registeredNumber: strongSelf.groupReceipts[index].recipient)
              }
              
              strongSelf.readReceipts = strongSelf.groupReceipts.filter { $0.dateRead != nil }
              strongSelf.receivedReceipts = strongSelf.groupReceipts.filter { $0.dateReceived != nil && $0.dateRead == nil }
              
              strongSelf.tableView.reloadData()
              
              if strongSelf.readReceipts.count == strongSelf.groupReceipts.count {
                strongSelf.fetchReceiptsTimer?.disarm()
                strongSelf.fetchReceiptsTimer = nil
              }
            }
          }
        }
      })
      fetchReceiptsTimer?.arm()
    }
  }
  
  deinit {
    fetchReceiptsTimer?.disarm()
    fetchReceiptsTimer = nil
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    
    tableView.pin.all()
  }
  
  private func setupBinding() {
    cancellable = messageViewModel.message.$checkmarkType
      .receive(on: DispatchQueue.main)
      .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
      .sink(receiveValue: { [weak self] (vaue) in
      guard let strongSelf = self else { return }
      strongSelf.tableView.reloadData()
    })
  }
  
  func formatDate(_ date: Date) -> String {
    if date.isInToday {
      return "Today".localized()
    }
    else if date.isInYesterday {
      return "Yesterday".localized()
    }
    else if date.isInCurrentWeek {
      return date.dayName()
    }
    else if date.isInCurrentYear {
      return Blackbox.shared.account.settings.calendar == .gregorian ? date.string(withFormat: "E, MMM d") : date.dateStringIslamic(withFormat: "E, MMM d")
    }
    else {
      return Blackbox.shared.account.settings.calendar == .gregorian ? date.string(withFormat: "E, MMM yyyy") : date.dateStringIslamic(withFormat: "E, MMM yyyy")
    }
  }
}


extension MessageInfoViewController: UITableViewDataSource, UITableViewDelegate {
  
  func numberOfSections(in tableView: UITableView) -> Int {
    if isGroup == false {
      return 1
    } else {
      if groupReceipts.count == 0 {
        return 2
      } else {
        if readReceipts.count == groupReceipts.count {
          return 1
        } else {
          return 2
        }
      }
    }
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if isGroup == false {
      return 2
    } else {
      if groupReceipts.count == 0 {
        return 1
      } else {
        if readReceipts.count == groupReceipts.count {
          return readReceipts.count
        } else {
          if section == 0 {
            return readReceipts.count == 0 ? 1 : readReceipts.count
          } else {
            return receivedReceipts.count == 0 ? 1 : receivedReceipts.count
          }
        }
      }
    }
  }
  
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    if isGroup {
      return 40
    }
    return 30
  }
  
  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    if isGroup == false {
      return UIView()
    } else {
      
      let view = UIView()
      view.frame = CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 30)
      
      let imageView = UIImageView(frame: CGRect(x: 20, y: 0, width: 16, height: 16))
      imageView.contentMode = .scaleAspectFit
      imageView.image = section == 0 ? UIImage(named: "receipt_read") : UIImage(named: "receipt_received")
      
      let label = UILabel()
      label.text = section == 0 ? "READ BY".localized() : "RECEIVED BY".localized()
      label.font = UIFont.appFont(ofSize: 14)
      label.sizeToFit()
      
      view.addSubview(imageView)
      view.addSubview(label)
      
      imageView.pin.bottom(-2)
      label.pin.right(of: imageView, aligned: .center).marginLeft(6)
      return view
    }
  }
 
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if let cell = tableView.dequeueReusableCell(withIdentifier: Constants.MessageInfoCell_ID, for: indexPath) as? MessageInfoCell {
      cell.isGroup = isGroup
      if isGroup == false {
        cell.leftImageView.contentMode = .scaleAspectFit
        if indexPath.row == 0 {
          cell.leftImageView.image = UIImage(named: "receipt_read")
          cell.contentLabel.text = "Read".localized()
          if messageViewModel.message.dateRead != nil {
            cell.timeLabel.isHidden = false
            cell.dateLabel.isHidden = false
            cell.pendingImageView.isHidden = true
            cell.timeLabel.text = messageViewModel.message.dateRead!.timeString12Hour()
            cell.dateLabel.text = formatDate(messageViewModel.message.dateRead!)
          } else {
            cell.timeLabel.isHidden = true
            cell.dateLabel.isHidden = true
            cell.pendingImageView.isHidden = false
            cell.timeLabel.text = nil
            cell.dateLabel.text = nil
          }
        } else {
          cell.leftImageView.image = UIImage(named: "receipt_received")
          cell.contentLabel.text = "Delivered".localized()
          if messageViewModel.message.dateReceived != nil {
            cell.timeLabel.isHidden = false
            cell.dateLabel.isHidden = false
            cell.pendingImageView.isHidden = true
            cell.timeLabel.text = messageViewModel.message.dateReceived!.timeString12Hour()
            cell.dateLabel.text = formatDate(messageViewModel.message.dateReceived!)
          } else {
            cell.timeLabel.isHidden = true
            cell.dateLabel.isHidden = true
            cell.pendingImageView.isHidden = false
            cell.timeLabel.text = nil
            cell.dateLabel.text = nil
          }
        }
      } else {
        cell.leftImageView.contentMode = .scaleAspectFill
        if groupReceipts.count == 0 {
          cell.pendingImageView.isHidden = false
          
          cell.timeLabel.isHidden = true
          cell.dateLabel.isHidden = true
          cell.leftImageView.isHidden = true
          cell.contentLabel.isHidden = true
        } else {
          if indexPath.section == 0 {
            if readReceipts.count == 0 {
              cell.pendingImageView.isHidden = false
              
              cell.timeLabel.isHidden = true
              cell.dateLabel.isHidden = true
              cell.leftImageView.isHidden = true
              cell.contentLabel.isHidden = true
            } else {
              
              cell.pendingImageView.isHidden = true
              
              cell.timeLabel.isHidden = false
              cell.dateLabel.isHidden = false
              cell.leftImageView.isHidden = false
              cell.contentLabel.isHidden = false
              
              if indexPath.row < readReceipts.count {
                let receipt = readReceipts[indexPath.row]
                
                if let contact = receipt.contact {
                  cell.contentLabel.text = contact.getName()
                  if let photoPath = contact.profilePhotoPath, let image = UIImage.fromPath(photoPath) {
                    cell.leftImageView.image = image
                  } else {
                    cell.leftImageView.image = UIImage(named: "avatar_profile.png")
                  }
                } else {
                  cell.contentLabel.text = receipt.recipient
                  cell.leftImageView.image = UIImage(named: "avatar_profile.png")
                }
                
                cell.timeLabel.text = receipt.dateRead!.timeString12Hour()
                cell.dateLabel.text = formatDate(receipt.dateRead!)
                
              } else {
                return UITableViewCell()
              }
            }
          } else {
            if receivedReceipts.count == 0 {
              cell.pendingImageView.isHidden = false
              
              cell.timeLabel.isHidden = true
              cell.dateLabel.isHidden = true
              cell.leftImageView.isHidden = true
              cell.contentLabel.isHidden = true
            } else {
              
              cell.pendingImageView.isHidden = true
              
              cell.timeLabel.isHidden = false
              cell.dateLabel.isHidden = false
              cell.leftImageView.isHidden = false
              cell.contentLabel.isHidden = false
              
              if indexPath.row < receivedReceipts.count {
                let receipt = receivedReceipts[indexPath.row]
                
                if let contact = receipt.contact {
                  cell.contentLabel.text = contact.getName()
                  if let photoPath = contact.profilePhotoPath, let image = UIImage.fromPath(photoPath) {
                    cell.leftImageView.image = image
                  } else {
                    cell.leftImageView.image = UIImage(named: "avatar_profile")
                  }
                } else {
                  cell.contentLabel.text = receipt.recipient
                  cell.leftImageView.image = UIImage(named: "avatar_profile")
                }
                
                cell.timeLabel.text = receipt.dateReceived!.timeString12Hour()
                cell.dateLabel.text = formatDate(receipt.dateReceived!)
                
              } else {
                return UITableViewCell()
              }
            }
          }
        }
      }
      
      
      
      cell.contentLabel.sizeToFit()
      cell.dateLabel.sizeToFit()
      cell.timeLabel.sizeToFit()
      return cell
    }
    return UITableViewCell()
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: false)
  }
  
}
