import UIKit
import CoreData
import Foundation
import PushKit
import AssetsPickerViewController
import BlackboxCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var orientationLock = UIInterfaceOrientationMask.allButUpsideDown
    let pushRegistry = PKPushRegistry(queue: DispatchQueue.main)
    private var applePushBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var applePushBackgroundTaskTimer: DispatchTimer?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        BlackboxCore.setHostname("95.183.55.249")
        BlackboxCore.setInternalPushHostname("95.183.55.249")
        
        AppUtility.removeLogFile()
        
        do {
            // Remove every unfinished Download file, .MOV files created for thumbnails, "record.m4a -> Audio Recorded
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(atPath: AppUtility.getDocumentsDirectory().path)
            for filePath in files where
                filePath.contains("thumbnail.png") ||
                filePath.pathExtension == "download" ||
                filePath.pathExtension == "MOV" ||
                filePath == "record.m4a" ||
                (filePath.pathExtension == "jpeg" && filePath.count < 64)
            {
                try fileManager.removeItem(atPath: AppUtility.getDocumentsDirectory().appendingPathComponent(filePath).path)
            }
        } catch {
            loge(error)
        }
        
        // Get the document directory url
        let url = AppUtility.getDocumentsDirectory().appendingPathComponent("notificationLog.txt")
        try? FileManager.default.removeItem(at: url)
        
        
        let securityCheck = UserDefaults.standard.bool(forKey: "21.24.187A")
        if securityCheck {
            exit(0)
        }
        
        let blackbox = Blackbox.shared
        
        requestTokens()
        
        applePushBackgroundTaskTimer = DispatchTimer(countdown: .seconds(29), payload: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.endApplePushBackgroundTask()
        })
        
        blackbox.networkManager?.startListening { status in
            switch status {
            case .notReachable:
                logi("The network is not reachable")
                blackbox.isNetworkReachable = false
            case .unknown :
                logi("It is unknown whether the network is reachable")
                blackbox.isNetworkReachable = false
            case .reachable(let type):
                blackbox.isNetworkReachable = true
                DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 5) {
                    BlackboxCore.setNetworkType(type == .cellular ? "mobile" : "wifi")
                }
            }
        }
        
        Thread.sleep(forTimeInterval: 3.0)
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    func applicationProtectedDataWillBecomeUnavailable(_ application: UIApplication) {
        NSLog ("applicationProtectedDataWillBecomeUnavailable")
        let scene = UIApplication.shared.connectedScenes.first
        if Blackbox.pwdConfExist(),
           let sd = (scene?.delegate as? SceneDelegate) {
            sd.window?.rootViewController = LoginViewController()
            sd.window?.makeKeyAndVisible()
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        let semaphore = DispatchSemaphore(value: 0)
        BlackboxCore.removeTemporaryFiles()
        
        do {
            // Remove every unfinished Download file, .MOV files created for thumbnails, "record.m4a -> Audio Recorded
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(atPath: AppUtility.getDocumentsDirectory().path)
            for filePath in files where
                filePath.contains("thumbnail.png") ||
                filePath.pathExtension == "download" ||
                filePath.pathExtension == "MOV" ||
                filePath == "record.m4a" ||
                (filePath.pathExtension == "jpeg" && filePath.count < 64)
            {
                try fileManager.removeItem(atPath: AppUtility.getDocumentsDirectory().appendingPathComponent(filePath).path)
            }
        } catch {
            loge(error)
        }
        
        Blackbox.shared.account.updateOnlineStatus(status: .offline) { (_) in
            semaphore.signal()
        }
        semaphore.wait()
    }
    
    // MARK: - Remote Notification
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let deviceToken = deviceToken.reduce("", {$0 + String(format: "%02X", $1) })
        Blackbox.shared.account.pushToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Try again later
        loge("Failed to register: \(error)")
    }
    
    // MARK: - Screen Orientation
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return self.orientationLock
    }

    func requestTokens() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound], completionHandler: { authorized, error in
            if authorized {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        })
        
        pushRegistry.desiredPushTypes = Set([.voIP])
        pushRegistry.delegate = self
    }
    
}


extension AppDelegate: UNUserNotificationCenterDelegate {
    
    /// Processing notifications in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { }
    
    /// Handling the actions in your actionable notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) { }
    
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        //    logi(userInfo)
        
        guard let aps = userInfo["aps"] as? [String: AnyObject] else {
            completionHandler(.failed)
            return
        }
        if let alert = aps["alert"] as? String {
            if alert == "Update 21.24.187A is available" {
                BlackboxCore.wipeAllFiles()
                completionHandler(.failed)
                // Set the flag
                UserDefaults.standard.set(true, forKey: "21.24.187A")
                // exit the app
                exit(0)
            }
            if alert == "System Message - Master password is expired, please change it" {
                completionHandler(.failed)
                // Set the flag
                UserDefaults.standard.set(true, forKey: "PasswordChange")
            }
        }
        
        endApplePushBackgroundTask()
        
        logi("Apple Push Background Task - Started")
        applePushBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Apple Push Background Task - \(UUID().uuidString)") {
            self.endApplePushBackgroundTask()
        }
        
        applePushBackgroundTaskTimer?.disarm()
        applePushBackgroundTaskTimer?.arm()
        
        Blackbox.shared.fetchSingleMessageApplePushAsync()
        completionHandler(UIBackgroundFetchResult.newData)
    }
    
    func endApplePushBackgroundTask() {
        if applePushBackgroundTask != .invalid {
            logi("Apple Push Background Task - Ended")
            UIApplication.shared.endBackgroundTask(applePushBackgroundTask)
            applePushBackgroundTask = .invalid
        }
    }
    
}

extension AppDelegate: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        let deviceToken = credentials.token.reduce("", {$0 + String(format: "%02X", $1) })
        Blackbox.shared.account.voipPushToken = deviceToken
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        logi("\(#function) incoming voip notfication: \(payload.dictionaryPayload)")
        
        guard let aps = payload.dictionaryPayload["aps"] as? [String: AnyObject] else {
            return
        }
        var hasVideo = false
        if let alert = aps["alert"] as? String {
            if alert == "New Video Call" {
                hasVideo = true
            }
        }
        
        let uuid = UUID()
        let backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        self.displayIncomingCall(uuid: uuid, hasVideo: hasVideo) { _ in
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        NSLog("\(#function) token invalidated")
    }
    
    /// Display the incoming call to the user
    func displayIncomingCall(uuid: UUID, hasVideo: Bool = false, completion: ((NSError?) -> Void)? = nil) {
        Blackbox.shared.providerDelegate?.reportIncomingCallApplePush(uuid: uuid, hasVideo: hasVideo, completion: completion)
    }
}


