import Foundation
import Combine
import SCLAlertView
import BlackboxCore


class CallsHistoryViewModel: NSObject {
    
    fileprivate var filteredCalls: [CallHistoryCellViewModel]?
    fileprivate var missedCalls = [CallHistoryCellViewModel]()
    
    @Published var isEditing: Bool = false {
        didSet {
            for call in Blackbox.shared.callHistoryCellsViewModels {
                call.isEditing = isEditing
            }
        }
    }
    
    var showMissedCalls = false {
        didSet {
            if showMissedCalls {
                missedCalls = Blackbox.shared.callHistoryCellsViewModels.filter { (item) -> Bool in
                    return item.callGroup.direction == .missed
                }
            } else {
                missedCalls = []
            }
        }
    }
    
    override init() { }
    
    /**
     Return all the calls, the missed calls or the Filtered Calls.
     */
    func getCalls() -> [CallHistoryCellViewModel] {
        if filteredCalls != nil {
            return filteredCalls!
        }
        if showMissedCalls {
            return missedCalls
        }
        return Blackbox.shared.callHistoryCellsViewModels
    }
    
    func getCall(row: Int) -> CallHistoryCellViewModel {
        return getCalls()[row]
    }
    
    /**
     Add a single Call to the list
     */
    func addCall(cellViewModel: CallHistoryCellViewModel) {
        Blackbox.shared.callHistoryCellsViewModels.append(cellViewModel)
        if showMissedCalls, cellViewModel.callGroup.direction == .missed {
            missedCalls.append(cellViewModel)
        }
        
        isEditing = false
    }
    
    /**
     Add multiple Calls to the list
     */
    func addCalls(cellsViewModels: [CallHistoryCellViewModel]) {
        Blackbox.shared.callHistoryCellsViewModels.append(contentsOf: cellsViewModels)
        if showMissedCalls {
            for viewModel in cellsViewModels where viewModel.callGroup.direction == .missed {
                missedCalls.append(viewModel)
            }
        }
        
        isEditing = false
    }
    
    /**
     Delete a single Call from the list
     */
    func deleteCall(callHistoryCellViewModel: CallHistoryCellViewModel) {
        let blackbox = Blackbox.shared
        if showMissedCalls {
            // remove the call from the missed call
            missedCalls = missedCalls.filter({ (missedCall) -> Bool in
                if missedCall == callHistoryCellViewModel {
                    return false;
                }
                return true
            })
        }
        
        // Now remove the call from the main list
        blackbox.callHistoryCellsViewModels = blackbox.callHistoryCellsViewModels.filter({ (item) -> Bool in
            if item == callHistoryCellViewModel {
                return false;
            }
            return true
        })
        
        DispatchQueue.global().async {
            var success = true
            for call in callHistoryCellViewModel.callGroup.calls {
                if blackbox.account.state == .registered {
                    guard let jsonString = BlackboxCore.accountDeleteVoiceCall(call.callID) else {
                        return
                    }
                    logPrettyJsonString(jsonString)
                    do {
                        let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                        if !response.isSuccess() {
                            success = false
                        } else {
                            callHistoryCellViewModel.callGroup.calls.removeAll { $0.callID == call.callID }
                        }
                    } catch {
                        success = false
                        loge(error)
                    }
                }
                
                if success == false {
                    // If we were unable to delete some calls of the group, we try again after 2 seconds.
                    DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 2) {
                        self.deleteCall(callHistoryCellViewModel: callHistoryCellViewModel)
                    }
                }
                
            }
        }
        
    }
    
    /**
     Filter all the calls that start with the used string.
     - Parameter needle: Text to search
     */
    func filterCalls(using needle: String) {
        if needle == "" {
            filteredCalls = nil
            return
        }
        
        filteredCalls = Blackbox.shared.callHistoryCellsViewModels.filter { (item) -> Bool in
            if let contact = item.callGroup.contact {
                return contact.name.lowercased().starts(with: needle.lowercased())
            } else if let contacts = item.callGroup.contacts {
                let a = contacts.filter { (contact) -> Bool in
                    return contact.name.lowercased().starts(with: needle.lowercased())
                }
                if a.count > 0 {
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        }
    }
    
    
    /**
     Delete all the calls
     */
    func deleteAllCalls() {
        // TODO: Blackbox function
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else { return }
            let blackbox = Blackbox.shared
            
            if blackbox.account.state == .registered {
                guard let jsonString = BlackboxCore.accountDeleteVoiceCall("all") else {
                    return
                }
                logPrettyJsonString(jsonString)
                do {
                    let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                    if !response.isSuccess() {
                        DispatchQueue.main.async {
                            SCLAlertView().showWarning("Failed to delete".localized(), subTitle: "Something went wrong while connecting to the server.".localized())
                        }
                    } else {
                        
                        blackbox.callHistoryCellsViewModels.removeAll()
                        strongSelf.missedCalls.removeAll()
                        if strongSelf.filteredCalls != nil {
                            strongSelf.filteredCalls!.removeAll()
                        }
                    }
                } catch {
                    loge(error)
                }
            }
        }
    }
}


