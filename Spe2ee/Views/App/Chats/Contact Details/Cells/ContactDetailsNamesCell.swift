import UIKit
import FlexLayout

class ContactDetailsNamesCell: UITableViewCell {
  static let ID = "ContactDetailsNamesCell"
  
  private var maxWidth: CGFloat {
    return UIScreen.main.bounds.width-30
  }
  
  var contact: BBContact? {
    didSet {
      guard let contact = self.contact else { return }
      
      contentView.addSubview(rootFlexContainer)
      
      rootFlexContainer.flex.direction(.column).define { (flex) in
        if !contact.prefix.isEmpty || !contact.name.isEmpty || !contact.middlename.isEmpty || !contact.surname.isEmpty || !contact.suffix.isEmpty {
          namesLabel.text = "\(contact.prefix) \(contact.name) \(contact.middlename) \(contact.surname) \(contact.suffix)"
          namesLabel.frame = CGRect(origin: .zero, size: namesLabel.sizeThatFits(CGSize(width: maxWidth, height: .infinity)))
          flex.addItem(namesLabel).height(namesLabel.frame.height)
        }
        
        if !contact.phoneticname.isEmpty || !contact.phoneticsurname.isEmpty {
          phoneticNamesLabel.text = "\(contact.phoneticname) \(contact.phoneticmiddlename) \(contact.phoneticsurname)"
          phoneticNamesLabel.sizeToFit()
          flex.addItem(phoneticNamesLabel).marginTop(3).marginLeft(4)
        }
        
        if !contact.nickname.isEmpty {
          nicknameLabel.text = "\"\(contact.nickname)\""
          nicknameLabel.sizeToFit()
          flex.addItem(nicknameLabel).marginTop(3).marginLeft(4)
        }
        
        if !contact.maidenname.isEmpty {
          maidennameLabel.text = "\(contact.maidenname)"
          maidennameLabel.sizeToFit()
          flex.addItem(maidennameLabel).marginTop(3).marginLeft(4)
        }
        
        if !contact.jobtitle.isEmpty || !contact.department.isEmpty {
          jobTitleLabel.text = "\(contact.jobtitle) - \(contact.department)"
          jobTitleLabel.sizeToFit()
          flex.addItem(jobTitleLabel).marginTop(3).marginLeft(4)
        }
       
        if !contact.companyname.isEmpty {
          companyNameLabel.text = "\(contact.companyname)"
          companyNameLabel.sizeToFit()
          flex.addItem(companyNameLabel).marginTop(3).marginLeft(4)
        }
        
        if !contact.phoneticcompanyname.isEmpty {
          phoneticCompanyNameLabel.text = "\(contact.phoneticcompanyname)"
          phoneticCompanyNameLabel.sizeToFit()
          flex.addItem(phoneticCompanyNameLabel).marginTop(4).marginLeft(4)
        }
        
      }
    }
  }
  
  private var rootFlexContainer = UIView()
  
  private lazy var namesLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 2
    label.font = UIFont.appFontSemiBold(ofSize: 19)
    return label
  }()
  
  private lazy var phoneticNamesLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 14)
    label.textColor = .systemGray
    return label
  }()
  
  private lazy var nicknameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 14)
    label.textColor = .systemGray
    return label
  }()
  
  private lazy var maidennameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 14)
    label.textColor = .systemGray
    return label
  }()
  
  private lazy var jobTitleLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 14)
    label.textColor = .systemGray
    return label
  }()
  
  private lazy var companyNameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 14)
    label.textColor = .systemGray
    return label
  }()
  
  private lazy var phoneticCompanyNameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 14)
    label.textColor = .systemGray
    return label
  }()
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    selectionStyle = .none
    contentView.backgroundColor = .white
    
    contentView.addSubview(rootFlexContainer)
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func prepareForReuse() {
    if rootFlexContainer.isDescendant(of: contentView) {
      rootFlexContainer.removeFromSuperview()
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    rootFlexContainer.pin.left(15).top(10).right(15).bottom(15)
    rootFlexContainer.flex.layout(mode: .adjustHeight)
    
  }
  
}

extension ContactDetailsNamesCell {
  static func calculateHeight(contact: BBContact) -> CGFloat {
    let rootFlexContainer = UIView()
    let maxWidth = UIScreen.main.bounds.width-30
    
    let namesLabel: UILabel = {
      let label = UILabel()
      label.numberOfLines = 2
      label.font = UIFont.appFontSemiBold(ofSize: 19)
      label.text = "\(contact.prefix) \(contact.name) \(contact.middlename) \(contact.surname) \(contact.suffix)"
      label.frame = CGRect(origin: .zero, size: label.sizeThatFits(CGSize(width: maxWidth, height: .infinity)))
      return label
    }()
    
    let phoneticNamesLabel: UILabel = {
      let label = UILabel()
      label.font = UIFont.appFont(ofSize: 13)
      label.text = "\(contact.phoneticname) \(contact.phoneticmiddlename) \(contact.phoneticsurname)"
      return label
    }()
    
    let nicknameLabel: UILabel = {
      let label = UILabel()
      label.font = UIFont.appFont(ofSize: 13)
      label.text = "\"\(contact.nickname)\""
      label.sizeToFit()
      return label
    }()
    
    let maidennameLabel: UILabel = {
      let label = UILabel()
      label.font = UIFont.appFont(ofSize: 13)
      label.text = "\(contact.maidenname)"
      label.sizeToFit()
      return label
    }()
    
    let jobTitleLabel: UILabel = {
      let label = UILabel()
      label.font = UIFont.appFont(ofSize: 13)
      label.text = "\(contact.jobtitle) - \(contact.department)"
      label.sizeToFit()
      return label
    }()
    
    let companyNameLabel: UILabel = {
      let label = UILabel()
      label.font = UIFont.appFont(ofSize: 12)
      label.text = "\(contact.companyname)"
      label.sizeToFit()
      return label
    }()
    
    let phoneticCompanyNameLabel: UILabel = {
      let label = UILabel()
      label.font = UIFont.appFont(ofSize: 12)
      label.text = "\(contact.phoneticcompanyname)"
      label.sizeToFit()
      return label
    }()
    
    
    
    rootFlexContainer.flex.direction(.column).define { (flex) in
      if !contact.prefix.isEmpty || !contact.name.isEmpty || !contact.middlename.isEmpty || !contact.surname.isEmpty || !contact.suffix.isEmpty {
        flex.addItem(namesLabel).height(namesLabel.frame.height)
      }
      
      if !contact.phoneticname.isEmpty || !contact.phoneticsurname.isEmpty {
        flex.addItem(phoneticNamesLabel).marginTop(3)
      }
      
      if !contact.nickname.isEmpty {
        flex.addItem(nicknameLabel).marginTop(3)
      }
      
      if !contact.maidenname.isEmpty {
        flex.addItem(maidennameLabel).marginTop(3)
      }
      
      if !contact.jobtitle.isEmpty || !contact.department.isEmpty {
        flex.addItem(jobTitleLabel).marginTop(3)
      }
      
      if !contact.companyname.isEmpty {
        flex.addItem(companyNameLabel).marginTop(3)
      }
      
      if !contact.phoneticcompanyname.isEmpty {
        flex.addItem(phoneticCompanyNameLabel).marginTop(3)
      }
    }
    rootFlexContainer.flex.layout(mode: .adjustHeight)
      
    return rootFlexContainer.frame.height+30
  }
}
