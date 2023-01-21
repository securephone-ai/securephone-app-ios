//
//  DialPadViewController.swift
//  

import UIKit
import Combine
import PinLayout

class DialPadViewController: BBViewController {
    
    @IBOutlet weak var dialPadHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var contactTblView: UITableView!
    @IBOutlet weak var dialPadColView: UICollectionView!
    @IBOutlet weak var dialedTextLbl: UILabel!
    
    private var filteredContacts: [BBContact] = [BBContact]()
    private var contactList: [BBContact] = [BBContact]()
    private var selectedContact: BBContact? = nil
    private var displayedDialedNumberStr: String = ""
    
    var cancellable: AnyCancellable?

    let dialPadList = [
        DialPadData(title: "1", subTitle: "", translatedSubTitle: "", imageName: "dial_num_1_wht"),
        DialPadData(title: "2", subTitle: "ABC", translatedSubTitle: "АБВГ", imageName: "dial_num_2_wht"),
        DialPadData(title: "3", subTitle: "DEF", translatedSubTitle: "ДЕЁЖЗ", imageName: "dial_num_3_wht"),
        DialPadData(title: "4", subTitle: "GHI", translatedSubTitle: "ИЙКЛ", imageName: "dial_num_4_wht"),
        DialPadData(title: "5", subTitle: "JKL", translatedSubTitle: "МНОП", imageName: "dial_num_5_wht"),
        DialPadData(title: "6", subTitle: "MNO", translatedSubTitle: "РСТУ", imageName: "dial_num_6_wht"),
        DialPadData(title: "7", subTitle: "PQRS", translatedSubTitle: "ФХЦЧ", imageName: "dial_num_7_wht"),
        DialPadData(title: "8", subTitle: "TUV", translatedSubTitle: "ШЩЪЫ", imageName: "dial_num_8_wht"),
        DialPadData(title: "9", subTitle: "WXYZ", translatedSubTitle: "ЬЭЮЯ", imageName: "dial_num_9_wht"),
        DialPadData(title: "*", subTitle: "", translatedSubTitle: "", imageName: "dial_num_star_wht"),
        DialPadData(title: "0", subTitle: "+", translatedSubTitle: "", imageName: "dial_num_0_wht"),
        DialPadData(title: "#", subTitle: "", translatedSubTitle: "", imageName: "dial_num_pound_wht"),
    ]
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Dial Pad"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        self.cancellable = Blackbox.shared.$contactsSections.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (_) in
            guard let strongSelf = self else { return }
            
            strongSelf.contactList.removeAll()
            Blackbox.shared.contactsSections.forEach{
                strongSelf.contactList.append(contentsOf:  $0.contacts)
            }
            strongSelf.filteredContacts = strongSelf.contactList
            strongSelf.contactTblView.reloadData()
        })
        
        contactTblView.register(cellWithClass: ContactCell.self)
        contactTblView.tableFooterView = UIView()
        dialPadColView.register(cellWithClass: DialPadKeyCell.self)
        
        Blackbox.shared.contactsSections.forEach{
            contactList.append(contentsOf:  $0.contacts)
        }
        filteredContacts = contactList
    }
    
    
    @IBAction func dialPadTapped(_ sender: Any) {
        
        dialPadHeightConstraint.constant = ( dialPadHeightConstraint.constant == 0 ) ? -(view.frame.height * 0.32) : 0
        
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.view.layoutIfNeeded()
        }
    }
    
    @IBAction func phoneTapped(_ sender: Any) {
        
        if dialedTextLbl.text!.isEmpty { return }
        let contact = getContact(from: dialedTextLbl.text!)
        Blackbox.shared.callManager.startCall(contact: contact)
    }
    
    @IBAction func removeTapped(_ sender: Any) {
        dialedTextLbl.text! = String(dialedTextLbl.text!.dropLast())
        filterContentForSearchText(searchText: dialedTextLbl.text!)
    }
    
    private func filterContentForSearchText(searchText: String) {
        
        filteredContacts = (searchText.isEmpty) ? contactList : contactList.filter{ ($0.registeredNumber.lowercased().contains(searchText)) }
        selectedContact = filteredContacts.first
        contactTblView.reloadData()
    }
    
    private func getContact(from number: String) -> BBContact {
        
        if let contact = Blackbox.shared.getContact(registeredNumber: number) { return contact
        } else if let tempcontact = Blackbox.shared.getTemporaryContact(registeredNumber: number) {
            return tempcontact
        } else {
            // generate a contact based on the number info, use this function from
            let contactNumber = PhoneNumber(tag: "mobile", phone: number)
            let contact =  BBContact(id: number, name: "", phones: [contactNumber], phonejsonreg: [contactNumber])
            contact.registeredNumber = number
            return contact
        }
    }
    
    func showInvalidNumberAlert() {
        showAlert(title: "Sorry", message: "This is not a registered number")
    }
}


extension DialPadViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredContacts.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return ContactCell.getCellRequiredHeight()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.ID, for: indexPath) as? ContactCell {
            
            let contact = filteredContacts[indexPath.row]
            cell.contactName.text = "\(contact.name) \(contact.surname)"
            cell.contactNumber.text = contact.registeredNumber
            
            if let imagePath = contact.profilePhotoPath {
                cell.avatar.contentMode = .scaleAspectFill
                cell.avatar.image = UIImage.fromPath(imagePath)
            }
            
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let contact = filteredContacts[indexPath.row]
        Blackbox.shared.callManager.startCall(contact: contact)
    }
    
}


extension DialPadViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dialPadList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DialPadKeyCell.ID, for: indexPath) as? DialPadKeyCell {            cell.configCell(data: dialPadList[indexPath.row], cellIndexPath: indexPath)
            return cell
        }
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: view.frame.size.width/3 , height: (view.frame.height * 0.32) / 4)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        dialedTextLbl.text! += dialPadList[indexPath.item].title
        filterContentForSearchText(searchText: dialedTextLbl.text!)
    }
}

class DialPadKeyCell: UICollectionViewCell {
    
    static let ID = "DialPadKeyCell"
    
    private var deafultColor : UIColor = .white
    private var highlitedcolor : UIColor = UIColor(white: 0.9, alpha: 1)
    
    private var titleLbl: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont.appFontSemiBold(ofSize: 24, textStyle: .title1)
        lbl.textColor = .clear
        return lbl
    }()
    
    private var subTitleLbl: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont.appFontLight(ofSize: 10)
        lbl.textColor = .clear
        return lbl
    }()
    
    private var subTitleTranslation: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont.appFontLight(ofSize: 10)
        lbl.textColor = .clear
        return lbl
    }()
    
    let dialPadItem: UIImageView = {
      let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
      imageView.contentMode = .scaleAspectFill
      imageView.layer.masksToBounds = true
      return imageView
    }()
    
    private var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 1
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fillProportionally
        return stackView
    }()
    
    override var isSelected: Bool {
        didSet{
            backgroundColor = isSelected ? highlitedcolor : deafultColor
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.borderWidth = 0.75
        layer.borderColor = UIColor.lightGray.cgColor
        stackView.addArrangedSubviews([titleLbl, subTitleLbl, subTitleTranslation]);
        addSubview(stackView)
        addSubview(dialPadItem)
        stackView.anchorCenterSuperview()
        dialPadItem.anchorCenterSuperview()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configCell(data: DialPadData, cellIndexPath indexpath: IndexPath) {
        titleLbl.text = data.title
        subTitleLbl.text = data.subTitle
        subTitleLbl.isHidden = data.subTitle.isEmpty
        
        subTitleTranslation.text = data.translatedSubTitle
        subTitleTranslation.isHidden = data.translatedSubTitle.isEmpty

        titleLbl.font = indexpath.row == 9 ? UIFont.appFontSemiBold(ofSize: 40) : UIFont.appFontSemiBold(ofSize: 24)
        
        guard let imageName = data.imageName,
              let image = UIImage(named: imageName)
        else { return }
        dialPadItem.image = image
    }
}


struct DialPadData {
    let title: String
    let subTitle: String
    let translatedSubTitle: String
    let imageName: String?
}
