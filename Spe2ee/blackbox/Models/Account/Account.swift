import Foundation
import Combine
import UIKit
import CallKit
import CwlUtils
import CryptoSwift
import BlackboxCore


enum RegistrationState {
    case offline
    case registering
    case registered
}

enum RegistrationError {
    case invalidPushToken
    case invalidVoipToken
    case invalidAccount
    case registrationInProgess
    case alreadyRegistered
}

/// This class represents the main Accont object
class Account {
    
    private let key = "QfTjWnZq4t7w!z%C*F-JaNdRgUkXp2s5"
    private let iv = "A?D(G+KbPeShVmYq"
    
    private let registrationQueue = DispatchQueue(label: "account_registration_queue", qos: .background)
    private let statusQueue = DispatchQueue(label: "update_online_status_queue", qos: .background)
    
    private var perdiocallyCheckMessagesTimer: DispatchTimer? = nil
    
    
    private var registrationWorkItem: DispatchWorkItem?
    
    var settings = BBSettings()
    
    var pushToken: String? {
        get {
            do {
                guard let hex = UserDefaults.standard.string(forKey: "push_token") else { return nil }
                let bytes = hex.hexaBytes
                let aes = try AES(key: key, iv: iv)
                let decrypted = try aes.decrypt(bytes)
                return String(bytes: decrypted, encoding: .utf8)
            } catch {
                loge(error)
            }
            return nil
        } set {
            if newValue != nil, !newValue!.isEmpty {
                do {
                    let aes = try AES(key: key, iv: iv)
                    let ciphertext = try aes.encrypt(Array(newValue!.utf8))
                    UserDefaults.standard.set(ciphertext.toHexString(), forKey: "push_token")
                } catch {
                    loge(error)
                }
            }
        }
    }
    var voipPushToken: String? {
        get {
            do {
                guard let hex = UserDefaults.standard.string(forKey: "voip_push_token") else { return nil }
                let bytes = hex.hexaBytes
                let aes = try AES(key: key, iv: iv)
                let decrypted = try aes.decrypt(bytes)
                return String(bytes: decrypted, encoding: .utf8)
            } catch {
                loge(error)
            }
            return nil
        } set {
            if newValue != nil, !newValue!.isEmpty {
                do {
                    let aes = try AES(key: key, iv: iv)
                    let ciphertext = try aes.encrypt(Array(newValue!.utf8))
                    UserDefaults.standard.set(ciphertext.toHexString(), forKey: "voip_push_token")
                } catch {
                    loge(error)
                }
            }
        }
    }
    
    private var _registeredNumber: String? = nil
    var registeredNumber: String? {
        if let number = _registeredNumber {
            return number
        } else {
            guard let jsonString = BlackboxCore.getAccountNumber() else {
                return nil
            }
            do {
                let response = try JSONDecoder().decode(GetAccountNumberResponse.self, from: jsonString.data(using: .utf8)!)
                _registeredNumber = response.mobilenumber
                return _registeredNumber
            } catch {
                loge(error)
            }
        }
        return nil
    }
    var isValid: Bool {
        registeredNumber != nil
    }
    
    var periodicallyCheckForNewMessages: Bool = false {
        didSet {
            perdiocallyCheckMessagesTimer?.disarm()
            perdiocallyCheckMessagesTimer = nil
            
            if periodicallyCheckForNewMessages {
                perdiocallyCheckMessagesTimer = DispatchTimer(
                    countdown: .seconds(Constants.CheckNewMessagesTimer),
                    repeating: .seconds(Constants.CheckNewMessagesTimer),
                    executingOn: .global(),
                    payload: {
                        Blackbox.shared.fetchSingleMessageInternalPushAsync(periodicCheck: true, completion: nil)
                })
                perdiocallyCheckMessagesTimer?.arm()
            }
        }
    }
    
    @Published var name: String?
    @Published var statusMessage: String?
    @Published var lastSeen: Date?
    @Published var profilePhotoPath: String?
    @Published var state: RegistrationState = .offline {
        didSet {
            if state == .registered {
                logi("Registered")
            }
            stateDidChange?()
        }
    }
    
    var inOnCall: Bool {
        return Blackbox.shared.callManager.calls.count > 0
    }
    var needUpdate: Bool {
        if forceUpdate {
            if let installedVersion = Bundle.main.releaseVersionNumber,
               let availableVersion = self.currentAvailableVersion,
               availableVersion != installedVersion {
                return true
            }
        }
        return false
    }
    private var forceUpdate: Bool = false
    var currentAvailableVersion: String?
    var appUpdateUrl: String?
    
    var stateDidChange: (() -> Void)?
    
    /// Register for the internal Push notifications and also register the Notification callback
    func registerInternalPush() {
        if let regNumber = registeredNumber {
            DispatchQueue.global(qos: .background).async {
                let numPtr = regNumber.toMutablePointer()
                defer {
                    numPtr?.deallocate()
                }
                
                BlackboxCore.registerInternalPushMessage(regNumber) { (pushType) in
                    logi("push type: \(pushType)")
                    if pushType == 0 {
                        // new message
                        Blackbox.shared.fetchSingleMessageInternalPushAsync(completion: nil)
                    } else if pushType == 1 {
                        // incoming voip call
                        let uuid = UUID()
                        Blackbox.shared.providerDelegate?.reportIncomingCallInternalPush(uuid: uuid)
                    } else if pushType == 2 {
                        // incoming voip call
                        DispatchQueue.main.async {
                            let uuid = UUID()
                            Blackbox.shared.providerDelegate?.reportIncomingCallInternalPush(uuid: uuid, hasVideo: true)
                        }
                    }
                }
            }
        }
    }
    
    var isInternalPushregistered: Bool = false {
        didSet {
            BlackboxCore.closeInternalPush()
            if isInternalPushregistered == true {
                registerInternalPush()
            }
        }
    }
    
    /// Signup new device and store the pwdConf in RAM
    /// - Parameters:
    ///   - number: The Device mobile number
    ///   - otp: One Time Password
    func signUpAsync(number: String, otp: String, completion block:((Bool) -> Void)?)  {
        DispatchQueue.global(qos: .background).async {
            guard let jsonString = BlackboxCore.signupDevice(number, otp: otp, smsotp: otp) else {
                block?(false)
                return
            }
            
//            print(jsonString)
            
//            let jsonString = "{\"answer\":\"OK\",\"message\":\"Signup completed\",\"pwdconf\":\"eyJrZXlhZXMiOiJXZEFmMVFtQU1iK1dmZUJwaytwZzlZMjVteVQwdVp4UjFJYmFkSnpuODFVPSIsIml2YWVzIjoiS2MzZHRsRXBIQnlMbUdNelJaNGtHQT09IiwidGFnYWVzIjoiNllFRk9Ud0lOVllENm9MVERLb0VLdz09Iiwia2V5Y2FtZWxsaWEiOiI5NVFMR01JTnE0bncwUk9SajJtODBqbCttNUxCR3NDbHl0cXVDQzZZL0xRPSIsIml2Y2FtZWxsaWEiOiJnd0ovV293TTNsS1dhOFo4a2xGRWZnPT0iLCJrZXljaGFjaGEiOiI4VDRJNHNCdHMwNmZrUTBEZkFkTWdkZk9QRERHUWQ2aHc1R3A4THI1RXQ0PSIsIml2Y2hhY2hhIjoiLytvTVNzMUZZcHdsNnRzMUlWNW4zdz09In0=\"}"
            
            do {
                let response = try JSONDecoder().decode(SignupResponse.self, from: jsonString.data(using: .utf8)!)
                DispatchQueue.main.async {
                    if response.isSuccess(), response.pwdconf.count > 0 {
                        // Store the pwdConf in Ram
                        if let data = Data(base64Encoded: response.pwdconf) {
                            Blackbox.shared.pwdConf = String(data: data, encoding: .utf8)
                            block?(true)
                        } else {
                            block?(false)
                        }
                    }
                    else {
                        loge(response.message)
                        block?(false)
                    }
                }
            } catch {
                block?(false)
                loge(error)
            }
        }
    }
    
    /// Register the Account presence on a background thread
    /// - Parameter block: completion block --> return true if success, otherwise return false.
    private func registerPresence(completion block: ((Bool) -> Void)?) {
        guard let pwdConf = Blackbox.shared.pwdConf,
              let pushId = self.pushToken,
              let voipPushId = self.voipPushToken else {
            block?(false)
            return
        }
        let os = "ios#\(UIDevice.current.systemVersion)#\(Bundle.main.releaseVersionNumber ?? "")"
        guard let jsonString = BlackboxCore.accountRegisterPresence(pwdConf, os: os, pushId: pushId, voipPushId: voipPushId) else {
            block?(false)
            return
        }
        logPrettyJsonString(jsonString)
        
        do {
            let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
            if response.isSuccess() {
                block?(true)
            } else {
                block?(false)
            }
        } catch {
            self.state = .offline
            loge(error)
            block?(false)
        }
    }
    
    /// Register with the server
    /// - Parameter block: Completion block with the result called on the main thread
    func registerAsync(checkTokens: Bool = true, completion block: ((Bool, RegistrationError?) -> Void)?) {
        registrationWorkItem = DispatchWorkItem {
            
            if self.isValid == false {
                logi("Account Invalid")
                block?(false, .invalidAccount)
                return
            }
            
            if checkTokens {
                if self.pushToken == nil {
                    logi("Account Push token invalid")
                    block?(false, .invalidPushToken)
                    return
                }
                
                if self.voipPushToken == nil {
                    logi("Account VOIP Push token invalid")
                    block?(false, .invalidVoipToken)
                    return
                }
                //        block?(false, .invalidVoipToken)
                //        return
            }
            else {
                if self.pushToken == nil {
                    self.pushToken = String.random(ofLength: 30)
                }
                
                if self.voipPushToken == nil {
                    self.voipPushToken = String.random(ofLength: 30)
                }
            }
            
            if self.state == .registering {
                logi("Account is already trying to register")
                block?(false, .registrationInProgess)
                return
            }
            
            if self.state == .registered {
                logi("Account is already registered")
                block?(false, .alreadyRegistered)
                return
            }
            
            self.state = .registering
            
            self.registerPresence { (success) in
                if success {
                    self.state = .registered
                    block?(true, nil)
                } else {
                    self.state = .offline
                    block?(false, nil)
                }
            }
        }
        
        registrationQueue.async(execute: registrationWorkItem!)
    }
    
    /// Refresh account info
    /// - Parameter block: completion block
    func fetchAccountInfoAsync(completion block:((Bool)->Void)?) {
        Exec.user.invokeAsync { [weak self] in
            guard let strongSelf = self else { return }
            
            guard let regNum = strongSelf.registeredNumber,
                  let jsonString = BlackboxCore.getProfileInfo(regNum) else {
                block?(false)
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(FetchAccountInfoResponse.self, from: jsonString.data(using: .utf8)!)
                
                if response.isSuccess() {
                    strongSelf.name = response.name
                    strongSelf.statusMessage = response.statusMessage
                    strongSelf.lastSeen = response.lastSeen
                    
                    strongSelf.forceUpdate = response.forceUpdate
                    strongSelf.currentAvailableVersion = response.currentIOSVersion
                    strongSelf.appUpdateUrl = response.updateUrl
                    
                    block?(true)
                    
                    if response.photoName.isEmpty == false {
                        guard let jsonString = BlackboxCore.getPhoto(response.photoName) else { return }
                        //                logPrettyJsonString(jsonString)
                        
                        let response2 = try decoder.decode(SendFileMessageReponse.self, from: jsonString.data(using: .utf8)!)
                        if response2.answer == "OK" {
                            strongSelf.profilePhotoPath = response2.localFilename
                        } else {
                            loge(response2.message)
                        }
                    }
                } else {
                    loge(response.message)
                    block?(false)
                }
                
            } catch {
                block?(false)
                loge(error)
            }
        }
    }
    
    /// Update the account Name
    /// - Parameters:
    ///   - name: new name value
    ///   - block: ompletion block
    func updateProfileNameAsync(name: String, completion block:((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async {
            guard let jsonString = BlackboxCore.accountUpdateProfileName(name) else {
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SendFileMessageReponse.self, from: jsonString.data(using: .utf8)!)
                
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }
                    if response.isSuccess() {
                        strongSelf.name = name
                        block?(true)
                    } else {
                        block?(false)
                    }
                }
            } catch {
                loge(error)
            }
        }
    }
    
    /// Update the account profile picture on a background thread
    /// - Parameters:
    ///   - image: Image to upload
    ///   - blokc: Completion block with the result called on the main thread
    func updateProfilePhotoAsync(image: UIImage, completion block:((Bool) -> Void)?) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            
            if let img = image.fixedOrientation(), let imgData = img.jpegData(compressionQuality: 1) {
                let imgUrl = AppUtility.getDocumentsDirectory().appendingPathComponent("profileImagePlaceHolder.jpeg")
                do {
                    try imgData.write(to: imgUrl)
                    
                    guard let jsonString = BlackboxCore.accountUpdateProfilePhoto(imgUrl.path) else {
                        loge("accountUpdateProfilePhoto unable to exectute")
                        block?(false)
                        return
                    }
                    let response = try JSONDecoder().decode(SendFileMessageReponse.self, from: jsonString.data(using: .utf8)!)
                    
                    guard let strongSelf = self else { return }
                    if response.isSuccess() {
                        strongSelf.profilePhotoPath = response.localFilename
                        block?(true)
                    } else {
                        block?(false)
                    }
                    
                    // Delete the image
                    try FileManager.default.removeItem(at: imgUrl)
                    
                } catch {
                    loge(error)
                }
            }
        }
    }
    
    /// Update the account status on a  background thread
    /// - Parameters:
    ///   - status: The Status String
    ///   - block: completion block --> return true if success, otherwise return false.
    func setStatus(status: String, completion block:((Bool)->Void)?) {
        DispatchQueue.global(qos: .background).async {
            guard let jsonString = BlackboxCore.accountUpdateStatusMessage(status) else {
                block?(false)
                return
            }
            logPrettyJsonString(jsonString)
            do {
                let response = try Blackbox.shared.decoder.decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    self.statusMessage = status
                    block?(true)
                } else {
                    block?(false)
                }
            } catch {
                block?(false)
            }
        }
        
    }
    
    /// Update the account Online Status (Online/Offline) on a background thread
    /// - Parameters:
    ///   - status: The new account status
    ///   - block: completion block --> return true if success, otherwise return false.
    func updateOnlineStatus(status: OnlineStatus, complettion block: ((Bool)->Void)? = nil) {
        statusQueue.async {
            guard let jsonString = BlackboxCore.accountSetOnline(status == .online) else {
                block?(false)
                return
            }
            do {
                let response = try Blackbox.shared.decoder.decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                if response.isSuccess() {
                    block?(true)
                } else {
                    block?(false)
                }
            } catch {
                block?(false)
            }
        }
    }
    
    /// Fetch the account settings on a backgroun thread. It will update the var settings = BBSettings() property.
    func fetchAccountSettings() {
        guard let jsonString = BlackboxCore.accountGetSettings() else {
            return
        }
        logPrettyJsonString(jsonString)
        do {
            let response = try  Blackbox.shared.decoder.decode(FetchSettingsResponse.self, from: jsonString.data(using: .utf8)!)
            if response.isSuccess() {
                self.settings = response.settings
            } else {
                loge(response.message)
            }
        } catch {
            loge(error)
        }
    }
    
    
    /// This function MUST be called right after the registration to initialize the app RAM Storage
    func initializeApp(completion block: ((Bool)->Void)?) {
        let blackbox = Blackbox.shared
        
        AppUtility.benchmark("fetchAccountInfoAsync") { (f) in
            fetchAccountInfoAsync { (success) in
                
                f()
                
                if success && self.needUpdate == false {
                    
                    self.isInternalPushregistered = true
                    self.fetchAccountSettings()
                    
                    AppUtility.isAppInForeground { (success) in
                        if success {
                            self.updateOnlineStatus(status: .online)
                        }
                    }
                    
                    AppUtility.benchmark("fetchContactsAsync") { (f2) in
                        blackbox.fetchContactsAsync(limitsearch: 10000) { (success) in
                            
                            f2()
                            
                            AppUtility.benchmark("fetchChatListAsync") { (f3) in
                                // Fetch chats and messages
                                blackbox.fetchChatListAsync { (chats) in
                                    
                                    f3()
                                    
                                    // Fetch the contacts notifications sound
                                    blackbox.fetchChatsNotificationSoundAsync()
                                    
                                    // Call the completion block as soon as we have the chats list
                                    if let _ = chats {
                                        block?(true)
                                    } else {
                                        self.state = .offline
                                        block?(false)
                                    }
                                }
                            }
                            
                            // Fetch calls history
                            blackbox.fetchCallsHistoryAsync(completion: nil)
                        }
                    }
                } else {
                    self.state = .offline
                    block?(false)
                }
            }
        }
        
    }
    
}

