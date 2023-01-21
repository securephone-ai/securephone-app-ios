import Combine
import UIKit
import FlexLayout
import PinLayout

class FormNamesCell: UITableViewCell {
  static let ID = "FormNamesCell"
  
  private var rootFlexContainer = UIView()
  var cancellableBag = Set<AnyCancellable>()
  
  var viewModel: AddNewContactViewModel? {
    didSet {
      guard let viewModel = self.viewModel else { return }
      
      contentView.addSubview(rootFlexContainer)
      
      
      let contact = viewModel.contact
      
      rootFlexContainer.flex.direction(.column).define { (flex) in
        if viewModel.isPrefixVisible {
          prefix.textField.text = contact.prefix
          addItem(flex: flex, item: prefix)
          prefix.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.prefix, on: contact).store(in: &cancellableBag)
        }
        
        firstName.textField.text = contact.name
        addItem(flex: flex, item: firstName)
        
        firstName.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.name, on: contact).store(in: &cancellableBag)
        
        if viewModel.isPhoneticNameVisible {
          phoneticFirstName.textField.text = contact.phoneticname
          addItem(flex: flex, item: phoneticFirstName)
          phoneticFirstName.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.phoneticname, on: contact).store(in: &cancellableBag)
        }
        if viewModel.isMiddlenameVisible {
          middleName.textField.text = contact.middlename
          addItem(flex: flex, item: middleName)
          middleName.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.middlename, on: contact).store(in: &cancellableBag)
        }
        if viewModel.isPhoneticMiddlenameVisible {
          phoneticMiddleName.textField.text = contact.phoneticmiddlename
          addItem(flex: flex, item: phoneticMiddleName)
          phoneticMiddleName.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.phoneticmiddlename, on: contact).store(in: &cancellableBag)
        }
        
        lastName.textField.text = contact.surname
        addItem(flex: flex, item: lastName)
        lastName.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.surname, on: contact).store(in: &cancellableBag)
        
        if viewModel.isPhoneticSurnameVisible {
          phoneticLastName.textField.text = contact.phoneticsurname
          addItem(flex: flex, item: phoneticLastName)
          phoneticLastName.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.phoneticsurname, on: contact).store(in: &cancellableBag)
        }
        if viewModel.isMaidennameVisible {
          maidenName.textField.text = contact.maidenname
          addItem(flex: flex, item: maidenName)
          maidenName.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.maidenname, on: contact).store(in: &cancellableBag)
        }
        if viewModel.isSuffixVisible {
          suffix.textField.text = contact.suffix
          addItem(flex: flex, item: suffix)
          suffix.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.suffix, on: contact).store(in: &cancellableBag)
        }
        if viewModel.isNicknameVisible {
          nickname.textField.text = contact.nickname
          addItem(flex: flex, item: nickname)
          nickname.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.nickname, on: contact).store(in: &cancellableBag)
        }
        // remove the last separator from the view
        let view = flex.view?.subviews.reversed()[0]
        view?.removeFromSuperview()
      }
    }
  }

  private var title: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontSemiBold(ofSize: 16) 
    label.text = "Name".localized()
    label.sizeToFit()
    return label
  }()
  
  public lazy var prefix: CancellableTextField = {
    let textView = CancellableTextField()
    textView.textField.placeholder = "Prefix".localized()
    return textView
  }()
  
  public var firstName: CancellableTextField = {
    let textView = CancellableTextField()
    textView.textField.placeholder = "First name".localized()
    return textView
  }()
  
  public lazy var phoneticFirstName: CancellableTextField = {
    let textView = CancellableTextField()
    textView.textField.placeholder = "Phonetic first name".localized()
    return textView
  }()
  
  public lazy var middleName: CancellableTextField = {
    let textView = CancellableTextField()
    textView.textField.placeholder = "Middle name".localized()
    return textView
  }()
  
  public lazy var phoneticMiddleName: CancellableTextField = {
    let textView = CancellableTextField()
    textView.textField.placeholder = "Phonetic middle name".localized()
    return textView
  }()
  
  public lazy var lastName: CancellableTextField = {
    let textView = CancellableTextField()
    textView.textField.placeholder = "Last name".localized()
    return textView
  }()
  
  public lazy var phoneticLastName: CancellableTextField = {
    let textView = CancellableTextField()
    textView.textField.placeholder = "Phonetic last name".localized()
    return textView
  }()
  
  public lazy var maidenName: CancellableTextField = {
    let textView = CancellableTextField()
    textView.textField.placeholder = "Maiden name".localized()
    return textView
  }()
  
  public lazy var suffix: CancellableTextField = {
    let textView = CancellableTextField()
    textView.textField.placeholder = "Suffix".localized()
    return textView
  }()
  
  public lazy var nickname: CancellableTextField = {
    let textView = CancellableTextField()
    textView.textField.placeholder = "Nickname".localized()
    return textView
  }()
  
  override func prepareForReuse() {
    super.prepareForReuse()
    
    cancellableBag.cancellAndRemoveAll()
    
    if rootFlexContainer.isDescendant(of: contentView) {
      rootFlexContainer.removeFromSuperview()
      rootFlexContainer = UIView()
    }
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    selectionStyle = .none
    contentView.backgroundColor = .white
    
    contentView.addSubview(title)

     
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    title.pin.left(18).width(18%).top(30)
    rootFlexContainer.pin.right(of: title).marginLeft(50).top(15).right().bottom()
    rootFlexContainer.flex.layout(mode: .adjustHeight)
  }

}


extension FormNamesCell {
  private func addSeparator(flex: Flex) {
    // Separator
    flex.addItem().height(0.3).backgroundColor(.systemGray4)
  }
  
  private func addItem(flex: Flex, item: UIView) {
    flex.addItem(item).height(50).width(100%)
    addSeparator(flex: flex)
  }
}


extension FormNamesCell {
  static func calculateHeight(viewModel: AddNewContactViewModel) -> CGFloat {
    let rootFlexContainer = UIView()
    
    let title: UILabel = {
      let label = UILabel()
      label.font = UIFont.appFontSemiBold(ofSize: 16)
      label.text = "Name".localized()
      label.sizeToFit()
      return label
    }()
    
    let prefix: CancellableTextField = {
      let textView = CancellableTextField()
      textView.textField.placeholder = "Prefix".localized()
      textView.isHidden = true
      return textView
    }()
    
    let firstName: CancellableTextField = {
      let textView = CancellableTextField()
      textView.textField.placeholder = "First name".localized()
      return textView
    }()
    
    let phoneticFirstName: CancellableTextField = {
      let textView = CancellableTextField()
      textView.textField.placeholder = "Phonetic first name".localized()
      textView.isHidden = true
      return textView
    }()
    
    let middleName: CancellableTextField = {
      let textView = CancellableTextField()
      textView.textField.placeholder = "Middle name".localized()
      textView.isHidden = true
      return textView
    }()
    
    let phoneticMiddleName: CancellableTextField = {
      let textView = CancellableTextField()
      textView.textField.placeholder = "Phonetic middle name".localized()
      textView.isHidden = true
      return textView
    }()
    
    let lastName: CancellableTextField = {
      let textView = CancellableTextField()
      textView.textField.placeholder = "Last name".localized()
      return textView
    }()
    
    let phoneticLastName: CancellableTextField = {
      let textView = CancellableTextField()
      textView.textField.placeholder = "Phonetic last name".localized()
      textView.isHidden = true
      return textView
    }()
    
    let maidenName: CancellableTextField = {
      let textView = CancellableTextField()
      textView.textField.placeholder = "Maiden name".localized()
      textView.isHidden = true
      return textView
    }()
    
    let suffix: CancellableTextField = {
      let textView = CancellableTextField()
      textView.textField.placeholder = "Suffix".localized()
      textView.isHidden = true
      return textView
    }()
    
    let nickname: CancellableTextField = {
      let textView = CancellableTextField()
      textView.textField.placeholder = "Nickname".localized()
      textView.isHidden = true
      return textView
    }()
    
    func addSeparator(flex: Flex) {
      // Separator
      flex.addItem().height(0.3).backgroundColor(.systemGray4)
    }
    
    func addItem(flex: Flex, item: UIView) {
      flex.addItem(item).height(50).width(100%)
      addSeparator(flex: flex)
    }
    
    rootFlexContainer.flex.direction(.column).define { (flex) in
      if viewModel.isPrefixVisible {
        addItem(flex: flex, item: prefix)
      }
      
      addItem(flex: flex, item: firstName)
      
      if viewModel.isPhoneticNameVisible {
        addItem(flex: flex, item: phoneticFirstName)
      }
      if viewModel.isMiddlenameVisible {
        addItem(flex: flex, item: middleName)
      }
      if viewModel.isPhoneticMiddlenameVisible {
        addItem(flex: flex, item: phoneticMiddleName)
      }
      
      addItem(flex: flex, item: lastName)
      
      if viewModel.isPhoneticSurnameVisible {
        addItem(flex: flex, item: phoneticLastName)
      }
      if viewModel.isMaidennameVisible {
        addItem(flex: flex, item: maidenName)
      }
      if viewModel.isSuffixVisible {
        addItem(flex: flex, item: suffix)
      }
      if viewModel.isNicknameVisible {
        addItem(flex: flex, item: nickname)
      }
      // remove the last separator from the view
      let view = flex.view?.subviews.reversed()[0]
      view?.removeFromSuperview()
    }
    
    title.pin.left(20).width(18%).top(20)
    rootFlexContainer.pin.right(of: title).marginLeft(50).top(10).right().bottom()
    rootFlexContainer.flex.layout(mode: .adjustHeight)
    
    return rootFlexContainer.frame.height+23
  }
}
