import Foundation
import DifferenceKit
import BlackboxCore

extension Blackbox {
    
    /// Takes an Array of [BBContact], groups them by name and return an array of [BBContactsSection]
    /// - Parameter contacts: the source array of BBContact
    /// - Returns: returns an array of BBContactsSection
    private func generateGroupedContactsSections(with contacts: [BBContact]) -> [BBContactsSection] {
        
        let regContacts = contacts.filter { $0.phonejsonreg.count > 0 }
        
        var placeholder = [String: Int]()
        var sections = [BBContactsSection]()
        
        for contact in regContacts {
            let initial = String(contact.name.lowercased().prefix(1))
            
            if let index = placeholder[initial] {
                // There is already a section with this initial, so we just append a contact to it
                for regNumber in contact.phonejsonreg {
                    let contactCopy = contact
                    contactCopy.registeredNumber = regNumber.phone
                    sections[index].contacts.append(contact)
                }
            } else {
                // We must create a new section for this initial
                placeholder[initial] = sections.count == 0 ? 0 : sections.count
                var _contacts = [BBContact]()
                for regNumber in contact.phonejsonreg {
                    let contactCopy = contact
                    contactCopy.registeredNumber = regNumber.phone
                    _contacts.append(contact)
                }
                sections.append(BBContactsSection(sectionInitial: initial, contacts: _contacts))
            }
        }
        
        // sort the contacts
        for (index, _) in sections.enumerated() {
            sections[index].contacts.sort { $0.name < $1.name }
        }
        return sections
    }
    
    private func addContact(_ contact: BBContact) {
        let initial = String(contact.name.lowercased().prefix(1))
        for (index, section) in self.contactsSections.enumerated() {
            if section.sectionInitial == initial  {
                // We have found the contact section
                self.contactsSections[index].contacts.append(contact)
                self.contactsSections[index].contacts.sort { $0.name < $1.name }
                return
            }
        }
        // No section was found with the same initial. We must add a new section based on the contact initial
        self.contactsSections.append(BBContactsSection(sectionInitial: initial, contacts: [contact]))
        self.contactsSections.sort { $0.sectionInitial < $1.sectionInitial }
    }
    
    private func deleteContact(_ contact: BBContact) {
        // remove contact from the list
        for index in 0..<contactsSections.count {
            contactsSections[index].contacts.removeAll { $0.ID == contact.ID }
        }
    }
    
    private func updateContact(_ contact: BBContact) {
        for (sectionIndex, contactsSection) in self.contactsSections.enumerated() {
            for (contactIndex, _contact) in contactsSection.contacts.enumerated() where _contact.registeredNumber == contact.registeredNumber {
                self.contactsSections[sectionIndex].contacts[contactIndex] = contact
            }
        }
    }
    
    
    /// Fetch contacts from the server in the background and return the response on a main thread completion block
    /// - Parameters:
    ///   - search: It is a string to search in name, surname or company name (can be set to “”
    ///   - contactid: is a the unique id of the contact to get (“search” has priority on this fileds, if not used can be set to “0”
    ///   - flagsearch: 1 to select only contacts that are registered with the app, 0 for any contact
    ///   - limitsearch: number of maximum record to get
    func fetchContactsAsync(search: String = "",
                            contactid: Int = 0,
                            flagsearch: Int = 0,
                            limitsearch: Int,
                            completion block: ((Bool)->Void)?) {
        
        contactsSerialQueue.async {
            guard let jsonString = BlackboxCore.accountGetContacts(search, contactId: contactid, flagSearch: flagsearch, limitSearch: limitsearch) else {
                loge("unable to exectute")
                block?(false)
                return
            }
            
            logPrettyJsonString(jsonString)
            
            do {
                let response = try JSONDecoder().decode(FetchContactsResponse.self, from: jsonString.data(using: .utf8)!)
                
                if response.isSuccess() {
                    let contacts = self.generateGroupedContactsSections(with: response.contacts)
                    if self.contactsSections.count == 0 {
                        self.contactsSections = contacts
                    } else {
                        let changeset = StagedChangeset(source: self.contactsSections, target: contacts)
                        if !changeset.isEmpty {
                            self.contactsSections = contacts
                        }
                    }
                    
                    block?(true)
                } else {
                    loge(response.message)
                    block?(false)
                }

            } catch {
                loge(error)
                block?(false)
            }
        }
    }
    
    
    /// Add a new contact in the background and return the response on the main thread
    /// - Parameters:
    ///   - contact: The contact object
    ///   - block: completion block returning the ID of the new contact if succesfull or an error if not.
    func addContactAsync(contact: BBContact, completion block: response<BBContact>) {
        DispatchQueue.global(qos: .background).async {
            do {
                let jsonData = try JSONEncoder().encode(contact)
                
                guard let json = String(data: jsonData, encoding: .utf8) else {
                    loge("Unable to decode the Json")
                    return
                }
                
                guard let jsonString = BlackboxCore.contactAdd(json) else {
                    loge("BlackboxCore.addContact unable to exectute")
                    block?(nil, "Add contact unable to execute".localized())
                    return
                }
                
                let response = try JSONDecoder().decode(AddContactResponse.self, from: jsonString.data(using: .utf8)!)
                
                if !response.isSuccess() {
                    DispatchQueue.main.async {
                        block?(nil, response.message)
                    }
                } else {
                    contact.ID = response.id
                    contact.phonejsonreg = response.registeredPhones
                    
                    // Add the contact if the added number is registered
                    if response.registeredPhones.count > 0 {
                        contact.registeredNumber = response.registeredPhones[0].phone
                        self.addContact(contact)
                    }
                    
                    // If present, remove the contact from the temporary(Unsaved) Contacts
                    self.temporaryContacts.removeAll { $0.registeredNumber == contact.registeredNumber }
                    
                    DispatchQueue.main.async {
                        block?(contact, nil)
                    }
                }
                
                
            } catch {
                loge(error)
            }
        }
    }
    
    
    /// Add a new contact in the background and return the response on the main thread
    /// - Parameters:
    ///   - contact: THe contact object
    ///   - block: completion block returning the ID of the new contact if succesfull or an error if not.
    func updateContactAsync(contact: BBContact, completion block: response<BBContact>) {
        DispatchQueue.global(qos: .background).async {
            do {
                let jsonEncoder = JSONEncoder()
                let jsonData = try jsonEncoder.encode(contact)
                guard let json = String(data: jsonData, encoding: .utf8) else {
                    loge(" Unable to decode the Json")
                    return
                }
                
                guard let jsonString = BlackboxCore.contactUpdate(json) else {
                    loge("BlackboxCore.contactUpdate unable to exectute")
                    block?(nil, "Update contact unable to execute")
                    return
                }
                
                let response = try JSONDecoder().decode(AddContactResponse.self, from: jsonString.data(using: .utf8)!)
                
                if !response.isSuccess() {
                    DispatchQueue.main.async {
                        block?(nil, response.message)
                    }
                } else {
                    let _contact = contact
                    
                    if !response.id.isEmpty, _contact.ID.isEmpty {
                        _contact.ID = response.id
                    }
                    
                    if response.registeredPhones.count > 0 {
                        _contact.phonejsonreg = response.registeredPhones
                    }
                    
                    self.updateContact(_contact)
                    
                    DispatchQueue.main.async {
                        block?(_contact, nil)
                    }
                }
            } catch {
                loge(error)
            }
        }
    }
    
    /// Delete Contact
    /// - Parameter contactId: Contact ID to delete
    func deleteContactAsync(_ contact: BBContact, completion block: ((Bool)->Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            guard let jsonString = BlackboxCore.contactDelete(contact.ID) else {
                loge("BlackboxCore.contactDelete unable to exectute")
                block?(false)
                return
            }
            
            do {
                let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                
                if !response.isSuccess() {
                    block?(false)
                } else {
                    self.deleteContact(contact)
                    block?(true)
                }
            } catch {
                loge(error)
            }
        }
    }
    
    /// Loog for a contact in our contactsSections that match the provided registeredNumber
    /// - Parameter registeredNumber: registered Number string
    /// - Returns: return the contact if founf or nil
    func getContact(registeredNumber: String) -> BBContact? {
        for section in contactsSections {
            for contact in section.contacts where contact.registeredNumber == registeredNumber {
                return contact
            }
        }
        return nil
    }
    
    /// Look for a contact in our temporaryContacts that match the provided registeredNumber
    /// - Parameter registeredNumber: registered Number string
    /// - Returns: return the contact if founf or nil
    func getTemporaryContact(registeredNumber: String) -> BBContact? {
        for contact in temporaryContacts where contact.registeredNumber == registeredNumber {
            return contact
        }
        return nil
    }
    
}


