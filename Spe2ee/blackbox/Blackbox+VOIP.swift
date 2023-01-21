import Foundation
import DifferenceKit
import BlackboxCore


// MARK: - Voip utility functions
extension Blackbox {
    func fetchCallsHistoryAsync(completion block:((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self,
                  let jsonString = BlackboxCore.accountGetCallsHistory() else {
                block?(false)
                return
            }
//            logPrettyJsonString(jsonString)
            do {
                let response = try JSONDecoder().decode(FetchCallsHistoryResponce.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    // Compare and check if the chatItems list needs to be updated.
                    let groupedCalls = strongSelf.generateGroupedCallsHistory(calls: response.callsHistory)
                    let changeset = StagedChangeset(source: strongSelf.callHistoryCellsViewModels, target: groupedCalls)
                    if !changeset.isEmpty {
                        strongSelf.callHistoryCellsViewModels = groupedCalls
                    }
                    block?(true)
                } else {
                    block?(false)
                    loge(response.message)
                }
            } catch {
                block?(false)
                loge(error)
            }
        }
    }
    
    private func generateGroupedCallsHistory(calls: [BBCallHistory]) -> [CallHistoryCellViewModel] {
        var cellViewModels = [CallHistoryCellViewModel]()
        
        let groupedByDate = Dictionary(grouping: calls) { (item) -> Date in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: item.dateSetup)
            return formatter.date(from: dateString)!
        }
        
        groupedByDate.forEach { (args) in
            
            let groupedByNumber = Dictionary(grouping: args.value) { (item) -> String in
                return item.recipient
            }
            
            groupedByNumber.forEach { (args2) in
                var contact: BBContact?
                // retrieve the contact from the handle value (contact registeredNumber)
                Blackbox.shared.contactsSections.forEach { (contactsSection) in
                    for _contact in contactsSection.contacts where _contact.registeredNumber == args2.key {
                        contact = _contact
                    }
                }
                
                if contact == nil {
                    contact = BBContact()
                    contact?.registeredNumber = args2.key
                    contact?.name = args2.value.first!.name
                }
                
                let b = Dictionary(grouping: args2.value) { (item) -> BBCallType in
                    return item.type
                }
                b.forEach { (args3) in
                    let c = Dictionary(grouping: args3.value) { (item) -> BBCallDirection in
                        return item.direction
                    }
                    c.forEach {
                        cellViewModels.append(CallHistoryCellViewModel(callGroup: BBCallsHistoryGroup(calls: $0.value, direction: $0.key, type: args3.key, contact: contact!)))
                    }
                }
            }
            
        }
        
        return cellViewModels.sorted(by: { (c1, c2) -> Bool in
            c1.callGroup.calls.first!.dateSetup > c2.callGroup.calls.first!.dateSetup
        })
    }
}

// MARK: - Voice Call
extension Blackbox {
    // MARK: - OneToOne Calls  functions
    func getCallInfoAsync(call: BBCall, completion block: ((Bool)->Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            
            guard let jsonString = BlackboxCore.voiceCallCheckIncoming() else {
                loge("voiceCallCheckIncoming unable to exectute")
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            do {
                let response = try JSONDecoder().decode(CallInfoResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    // retrieve the contact
                    if !response.callerID.isEmpty {
                        if let contact = self.getContact(registeredNumber: response.callerID) {
                            contact.callInfo.callID = response.callID
                            call.members = [contact]
                        } else if let contact = self.getTemporaryContact(registeredNumber: response.callerID) {
                            contact.callInfo.callID = response.callID
                            call.members = [contact]
                        }
                    }
                    
                    if call.members.isEmpty {
                        let contact = BBContact()
                        contact.ID = response.contactID
                        contact.name = response.contactName
                        contact.registeredNumber = response.callerID
                        contact.phonesjson = [PhoneNumber(tag: "mobile", phone: response.callerID)]
                        contact.phonejsonreg = [PhoneNumber(tag: "mobile", phone: response.callerID)]
                        contact.callInfo.callID = response.callID
                        call.members = [contact]
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
    
    func startCallAsync(_ call: BBCall, isSingleContact: Bool = true, completion block: response<Bool>) {
        if isSingleContact {
            guard let contact = call.members.first else {
                block?(false, "Call invalid contact")
                return
            }
            
            DispatchQueue.global(qos: .background).async {
                guard let jsonString = BlackboxCore.voiceCallStart(contact.registeredNumber) else {
                    loge("voiceCallStart unable to exectute")
                    block?(false, "Start call unable to execute".localized())
                    return
                }
                logPrettyJsonString(jsonString)
                do {
                    let response = try JSONDecoder().decode(StartCallResponse.self, from: jsonString.data(using: .utf8)!)
                    
                    if response.isSuccess() {
                        call.members[0].callInfo.callID = response.callID
                        block?(true, nil)
                    } else {
                        // TODO: Handle Error
                        block?(false, response.message)
                    }
                } catch {
                    loge(error)
                    block?(false, "Start call invalid response")
                }
            }
        }
    }
    
    func answerCallAsync(_ call: BBCall, completion block: ((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async {
            guard let jsonString = BlackboxCore.voiceCallAnswer() else {
                loge("voiceCallAnswer unable to exectute")
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try JSONDecoder().decode(CallInfoResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    block?(true)
                } else {
                    block?(false)
                }
            } catch {
                loge(error)
            }
        }
    }
    
    func endCallAsync(_ call: BBCall, completion block: ((Bool)->Void)?) {
        if let contact = call.members.first {
            DispatchQueue.global(qos: .background).async {
                guard let callId = contact.callInfo.callID,
                      let jsonString = BlackboxCore.voiceCallEnd(callId) else {
                    block?(false)
                    return
                }
                do {
                    let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                    
                    if response.isSuccess() {
                        block?(true)
                    } else {
                        block?(false)
                    }
                } catch {
                    loge(error)
                    block?(false)
                }
            }
        }
    }
    
    
    
    // MARK: - Conference Calls
    func startConferenceCallAsync(_ call: BBCall, completion block: ((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async {
            var successCount = 0
            for (index, contact) in call.members.enumerated() {
                contact.callInfo.callSession = index
                guard let jsonString = BlackboxCore.conferenceCallStart(contact.registeredNumber, sessionId: index) else {
                    loge("Unable to start the call with contact \(contact.completeName)")
                    continue
                }
                logPrettyJsonString(jsonString)
                do {
                    let response = try JSONDecoder().decode(StartCallResponse.self, from: jsonString.data(using: .utf8)!)
                    
                    if response.isSuccess() {
                        contact.callInfo.callID = response.callID
                        successCount += 1
                    } else {
                        // TODO: Handle Error
                        loge(response.message)
                        break
                    }
                } catch {
                    loge(error)
                    break
                }
            }
            
            if successCount == call.members.count {
                block?(true)
            } else {
                block?(false)
            }
        }
    }
    
    func endConferenceCallAsync(_ call: BBCall, completion block: ((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async {
            var successCount = 0
            var lock = os_unfair_lock()
            let queue = OperationQueue()
            for (index, contact) in call.members.enumerated() {
                queue.addOperation {
                    guard let callId = contact.callInfo.callID,
                          let jsonString = BlackboxCore.conferenceCallEnd(callId, sessionId: index) else {
                        loge("unable to remove contact \(contact.completeName) from the call")
                        return
                    }
                    logPrettyJsonString(jsonString)
                    do {
                        let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                        if response.isSuccess() {
                            os_unfair_lock_lock(&lock)
                            successCount += 1
                            os_unfair_lock_unlock(&lock)
                        } else {
                            loge(response.message)
                        }
                    } catch {
                        loge(error)
                    }
                }
            }
            queue.waitUntilAllOperationsAreFinished()
            
            if successCount == call.members.count {
                block?(true)
            } else {
                block?(false)
            }
        }
    }
    
    func appendContactToConferenceAsync(_ call: BBCall, contact: BBContact, completion block: ((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async {
            // get available Session index
            var session = 0
            let sessions = call.members.reduce(into: [Int]()) {
                if let s = $1.callInfo.callSession {
                    $0.append(s)
                }
            }
            if sessions.contains(0) == false {
                session = 0
            }
            else if sessions.contains(1) == false {
                session = 1
            }
            else if sessions.contains(2) == false {
                session = 2
            }
            else if sessions.contains(3) == false {
                session = 3
            }
            else {
                loge("invalid sessions...")
                block?(false)
                return
            }
            
            contact.callInfo.callSession = session
            
            guard let jsonString = BlackboxCore.conferenceCallStart(contact.registeredNumber, sessionId: session) else {
                loge("Unable to execute")
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let response = try JSONDecoder().decode(StartCallResponse.self, from: jsonString.data(using: .utf8)!)
                
                if response.isSuccess() {
                    contact.callInfo.callID = response.callID
                    block?(true)
                } else {
                    // TODO: Handle Error
                    loge(response.message)
                    block?(false)
                }
            } catch {
                loge(error)
                block?(false)
            }
        }
    }
    
    func appendContactsToConferenceAsync(_ call: BBCall, contacts: [BBContact], completion block: ((_ addedContacts: [BBContact]?, _ failedContacts: [BBContact]?)->Void)?) {
        
        DispatchQueue(label: "appendContactQueue", qos: .background).async {
            if let pwdConfPtr = Blackbox.getPwdConfPointer() {
                defer {
                    pwdConfPtr.deallocate()
                }
                
                var addedContacts = [BBContact]()
                var failedContacts = [BBContact]()
                for contact in contacts {
                    // get available Session index
                    var session = 0
                    let sessions = call.members.reduce(into: [Int]()) {
                        if let s = $1.callInfo.callSession {
                            $0.append(s)
                        }
                    }
                    if sessions.contains(0) == false {
                        session = 0
                    }
                    else if sessions.contains(1) == false {
                        session = 1
                    }
                    else if sessions.contains(2) == false {
                        session = 2
                    }
                    else if sessions.contains(3) == false {
                        session = 3
                    }
                    else {
                        loge("invalid sessions...")
                        failedContacts.append(contact)
                        continue
                    }
                    
                    contact.callInfo.callSession = session
                    guard let jsonString = BlackboxCore.conferenceCallStart(contact.registeredNumber, sessionId: session) else {
                        loge("conferenceCallStart unable to exectute for contact \(contact.completeName)")
                        failedContacts.append(contact)
                        continue
                    }
                    logPrettyJsonString(jsonString)
                    do {
                        let response = try JSONDecoder().decode(StartCallResponse.self, from: jsonString.data(using: .utf8)!)
                        
                        if response.isSuccess() {
                            contact.callInfo.callID = response.callID
                            call.members.append(contact)
                            addedContacts.append(contact)
                        } else {
                            // TODO: Handle Error
                            failedContacts.append(contact)
                            loge(response.message)
                        }
                    } catch {
                        failedContacts.append(contact)
                        loge(error)
                    }
                }
                if addedContacts.count == contacts.count {
                    block?(addedContacts, nil)
                } else if failedContacts.count == contacts.count {
                    block?(nil, failedContacts)
                } else {
                    block?(addedContacts, failedContacts)
                }
                
            }
            else {
                block?(nil, nil)
            }
        }
        
    }
    
    
}

// MARK: - Video Call
extension Blackbox {
    // MARK: - OneToOne Video Calls functions
    func getVideoCallInfoAsync(call: BBCall, completion block: ((Bool)->Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            guard let jsonString = BlackboxCore.videoCallCheckIncoming() else {
                loge("videoCallCheckIncoming unable to exectute")
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            do {
                let response = try JSONDecoder().decode(CallInfoResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    call.hasVideo = true
                    
                    // retrieve the contact
                    if !response.callerID.isEmpty {
                        if let contact = self.getContact(registeredNumber: response.callerID) {
                            contact.callInfo.callID = response.callID
                            call.members = [contact]
                        } else if let contact = self.getTemporaryContact(registeredNumber: response.callerID) {
                            contact.callInfo.callID = response.callID
                            call.members = [contact]
                        }
                    }
                    
                    if call.members.isEmpty {
                        let contact = BBContact()
                        contact.ID = response.contactID
                        contact.name = response.contactName
                        contact.registeredNumber = response.callerID
                        contact.phonesjson = [PhoneNumber(tag: "mobile", phone: response.callerID)]
                        contact.phonejsonreg = [PhoneNumber(tag: "mobile", phone: response.callerID)]
                        contact.callInfo.callID = response.callID
                        call.members = [contact]
                    }
                    
                    block?(true)
                } else {
                    loge(response.message)
                    block?(false)
                }
            } catch {
                loge(error)
            }
        }
    }
    
    func startVideoCallAsync(_ call: BBCall, completion block: response<Bool>) {
        guard let contact = call.members.first else {
            block?(false, "Call invalid contact")
            return
        }
        DispatchQueue.global(qos: .background).async {
            guard let jsonString = BlackboxCore.videoCallStart(contact.registeredNumber) else {
                loge("videoCallStart unable to exectute for contact \(contact.completeName)")
                block?(false, "Originate voice call unable to execute".localized())
                return
            }
            logPrettyJsonString(jsonString)
            do {
                let response = try JSONDecoder().decode(StartCallResponse.self, from: jsonString.data(using: .utf8)!)
                
                if response.isSuccess() {
                    contact.callInfo.callID = response.callID
                    block?(true, nil)
                } else {
                    // TODO: Handle Error
                    block?(false, response.message)
                }
            } catch {
                loge(error)
            }
        }
    }
    
    func answerVideoCallAsync(_ call: BBCall, audioOnly: Bool = true, completion block: ((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async {
            guard let jsonString = BlackboxCore.videoCallAnswer(audioOnly) else {
                loge("videoCallAnswer unable to exectute")
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            do {
                let response = try JSONDecoder().decode(CallInfoResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    block?(true)
                } else {
                    block?(false)
                }
            } catch {
                loge(error)
            }
        }
    }
    
    func endVideoCallAsync(_ call: BBCall, completion block: ((Bool)->Void)?) {
        guard let contact = call.members.first, let callId = contact.callInfo.callID else {
            block?(false)
            return
        }
        DispatchQueue.global().async {
            guard let jsonString = BlackboxCore.videoCallEnd(callId) else {
                block?(false)
                return
            }
            do {
                let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                
                block?(response.answer == "OK" ? true : false)
                
            } catch {
                loge(error)
                block?(false)
            }
        }
    }
}

