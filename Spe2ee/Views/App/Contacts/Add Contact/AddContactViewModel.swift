import Foundation
import Combine

class ContactForm {
  var name: String = "" {
    didSet {
      isSaveEnabled = name.isEmpty == false && number.count >= 3
    }
  }
  var surname: String = ""
  var title: String = ""
  var number: String = "" {
    didSet {
      isSaveEnabled = name.isEmpty == false && number.count >= 3
    }
  }
  
  @Published var isSaveEnabled = false
}

class AddContactViewModel {
  let contact: BBContact!
  var contactForm = ContactForm()
  var isEditing = false
  
  init(contact: BBContact?) {
    if contact == nil {
      self.contact = BBContact()
    }
    else {
      isEditing = true
      self.contact = contact
      self.contactForm.isSaveEnabled = true
      
      contactForm.name = self.contact.name
      contactForm.surname = self.contact.surname
      contactForm.title = self.contact.jobtitle
      contactForm.number = self.contact.registeredNumber
    }
  }
  
  private func addFormValuesToContact() {
    contact.name = contactForm.name
    contact.surname = contactForm.surname
    contact.jobtitle = contactForm.title
    contact.registeredNumber = contactForm.number
    contact.phonejsonreg = [PhoneNumber(tag: "mobile", phone: contactForm.number, prefix: "")]
    contact.phonesjson = [PhoneNumber(tag: "mobile", phone: contactForm.number, prefix: "")]
  }
  
  func addContact(completion block: ((String?)->Void)?) {
    addFormValuesToContact()
    Blackbox.shared.addContactAsync(contact: contact) { (contact, error) in
      block?(error)
    }
  }
  
  func updateContact(completion block: ((String?)->Void)?) {
    let oldName = contact.name
    let oldSurname = contact.surname
    let oldTitle = contact.jobtitle
    let oldNumber = contact.registeredNumber
    addFormValuesToContact()
    Blackbox.shared.updateContactAsync(contact: contact) { [weak self] (contact, error) in
      guard let strongSelf = self else { return }
      if error != nil {
        // restore previous Values
        strongSelf.contact.name = oldName
        strongSelf.contact.surname = oldSurname
        strongSelf.contact.jobtitle = oldTitle
        strongSelf.contact.registeredNumber = oldNumber
      }
      block?(error)
    }
  }
}
