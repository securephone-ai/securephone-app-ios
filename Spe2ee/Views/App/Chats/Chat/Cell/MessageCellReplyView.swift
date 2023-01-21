

import UIKit
import MobileCoreServices


protocol MessageCellReplyViewDelegate: class {
    func didTapReplyView(messageID: String)
}

class MessageCellReplyView: UIView {
    
    fileprivate struct Margins {
        static let right: CGFloat = 10
        static let left: CGFloat = 10
        static let top: CGFloat = 6
        static let bottom: CGFloat = 0
    }
    fileprivate let usernameLabelFont: UIFont = UIFont.appFontSemiBold(ofSize: 15)
    
    internal weak var delegate: MessageCellReplyViewDelegate?
    
    private let msgID: String
    private let contactName: String
    private let contactColor: UIColor
    private var attachmentType: MessageType = .text
    private var body: String = ""
    private var isEventAlert: Bool = false
    
    private lazy var verticalColumn: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 4, height: 0))
        view.backgroundColor = self.contactColor
        return view
    }()
    
    private lazy var replyToUserLabel: UILabel = {
        let label = UILabel()
        label.font = usernameLabelFont
        label.text = self.contactName
        label.sizeToFit()
        label.numberOfLines = 1
        return label
    }()
    
    private lazy var messageBodyLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.appFont(ofSize: 14)
        label.attributedText = self.body.getAttributedText(fontSize: 14)
        label.sizeToFit()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var fileTypeImage: UIImageView = {
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
        imageView.tintColor = .systemGray
        imageView.contentMode = .scaleAspectFit
        switch self.attachmentType {
        case .audio:
            imageView.image = UIImage(systemName: "mic.fill")
        case .contact:
            imageView.image = UIImage(systemName: "person.fill")
        case .document:
            imageView.image = UIImage(systemName: "doc.fill")
        case .location:
            imageView.image = UIImage(systemName: "mappin.and.ellipse")
        case .photo:
            imageView.image = UIImage(systemName: "camera.fill")
        case .video:
            imageView.image = UIImage(systemName: "video.fill")
        default:
            break
        }
        return imageView
    }()
    
    private lazy var fileTypeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.appFont(ofSize: 14)
        switch self.attachmentType {
        case .audio:
            label.text = "Audio".localized()
        case .contact:
            label.text = "Contact".localized()
        case .document:
            label.text = "Document".localized()
        case .location:
            label.text = "Location".localized()
        case .photo:
            label.text = "Photo".localized()
        case .video:
            label.text = "Video".localized()
        default:
            break
        }
        label.sizeToFit()
        return label
    }()
    
    init(
        msgID: String,
        contactName: String,
        body: String,
        type: MessageType,
        contactColor: UIColor?,
        isEventAlert: Bool = false
    ) {
        self.msgID = msgID
        self.contactName = contactName
        self.body = body
        self.attachmentType = type
        self.contactColor = (contactColor == nil ? UIColor.random() : contactColor)!
        self.isEventAlert = isEventAlert
        super.init(frame: .zero)
        
        addSubview(verticalColumn)
        addSubview(replyToUserLabel)
        addSubview(messageBodyLabel)
        addSubview(fileTypeImage)
        addSubview(fileTypeLabel)
        
        backgroundColor = isEventAlert ? .white : UIColor(white: 0.5, alpha: 0.2)
        layer.cornerRadius = 8
        layer.masksToBounds = true
        
        let gesture = UITapGestureRecognizer(target: self, action: #selector(replyTapped))
        gesture.numberOfTapsRequired = 1
        gesture.numberOfTouchesRequired = 1
        self.addGestureRecognizer(gesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        verticalColumn.pin.height(frame.size.height)
        performLayout() 
    }
    
    private func performLayout() {
        replyToUserLabel.pin.top(6).start(10).end(10)
        switch attachmentType {
        case .photo, .video, .audio, .contact, .document, .location:
            fileTypeImage.pin.topStart(to: replyToUserLabel.anchor.bottomStart).marginTop(4)
            fileTypeLabel.pin.centerStart(to: fileTypeImage.anchor.centerEnd).marginStart(4)
            messageBodyLabel.pin.below(of: fileTypeImage).marginTop(4).end(10).start(10).sizeToFit(.width)
        case .text:
            messageBodyLabel.pin.below(of: replyToUserLabel).marginTop(4).end(10).start(10).sizeToFit(.width)
        default:
            break
        }
    }
    
    @objc func replyTapped() {
        if let chatVC = Blackbox.shared.chatViewController, let chatViewModel = chatVC.viewModel, chatViewModel.isForwardEditing {
            return
        }
        
        UIView.animate(withDuration: 0.07, animations: {
            self.backgroundColor = self.backgroundColor!.darker()
        }) { (result) in
            UIView.animate(withDuration: 0.07, animations: {
                self.backgroundColor = self.backgroundColor!.lighter()
            }) { (result) in
                guard let delegate = self.delegate else { return }
                delegate.didTapReplyView(messageID: self.msgID)
            }
        }
    }
}

extension MessageCellReplyView {
    
    static func getSize(with maxWidth: CGFloat, body: String, messageType: MessageType = .text) -> CGSize {
        let realMaxWidth = maxWidth - Margins.left - Margins.right
        
        var finalHeight: CGFloat = 6 // margin to top
        // Username Label height
        finalHeight += UIFont.appFontSemiBold(ofSize: 15).lineHeight.rounded(.up)
        // margin to below UI element
        finalHeight += 4
        // 20 = 16 icon size + 4 bottom margin
        finalHeight += messageType == .text ? 0 : 20
        
        let textSize = body.getAttributedText(fontSize: 15)?.size(withConstrainedWidth: realMaxWidth) ?? .zero
        finalHeight += textSize.height.rounded(.up)
        // margin to bottom
        finalHeight += 6
        
        var finalWidth = Margins.left + Margins.right
        finalWidth += textSize.width
        finalWidth = finalWidth <= 100 ? 100 : finalWidth
        
        return CGSize(width: finalWidth, height: finalHeight.rounded(.up))
    }
    
}


