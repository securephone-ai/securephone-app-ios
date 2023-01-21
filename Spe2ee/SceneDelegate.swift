import UIKit
import DeviceKit
//import SwiftConnectivityStatusBar

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    var timeOutSeconds: TimeInterval = 0
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        
        
        let appearance = UINavigationBarAppearance()
        if Device.current.hasSensorHousing {
            // iPhone X
            appearance.backgroundColor = Constants.NavBarBackgroundiPhoneX
        }
        else {
            // older
            appearance.backgroundColor = Constants.NavBarBackground
        }
        appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
        
        UINavigationBar.appearance().tintColor = .link
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        window?.overrideUserInterfaceStyle = .light
        
        if AppUtility.isDeviceJailbroken {
            window?.rootViewController = JailbrokenDeviceViewController()
            window?.makeKeyAndVisible()
            return
        }
        
        let securityCheck = UserDefaults.standard.bool(forKey: "regFailed")
        if securityCheck {
            window?.rootViewController = RegistrationFailedViewController()
            window?.makeKeyAndVisible()
            return
        }
        
        if UserDefaults.standard.bool(forKey: "PasswordChange") {
            window?.rootViewController = ChangePasswordViewController()
            window?.makeKeyAndVisible()
        }
        else {
            if Blackbox.pwdConfExist() || Blackbox.alreadyLoggedIn() {
                UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                    DispatchQueue.main.async { [weak self] in
                        guard let strongSelf = self else { return }
                        if settings.authorizationStatus == .authorized {
                            if UserDefaults.standard.bool(forKey: "auto_login"), Blackbox.shared.isPwdConfValid() {
                                strongSelf.window?.rootViewController = AppStartViewController()
                            } else {
                                strongSelf.window?.rootViewController = LoginViewController()
                            }
                        } else {
                            strongSelf.window?.rootViewController = AllowNotificationViewController()
                        }
                        strongSelf.window?.makeKeyAndVisible()
                    }
                }
            }
            else {
                window?.rootViewController = AccountActivationViewController()
                window?.makeKeyAndVisible()
            }
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
//        SCStatusBar.shared.startMonitor()
        
        if AppUtility.isDeviceJailbroken {
            exit(0)
        }
        
        guard Blackbox.pwdConfExist() else { return }
        
        let defaults = UserDefaults.standard
        if let lastInactiveDate = defaults.object(forKey: "LastInactiveDate") as? Date {
            let seconds = Date().timeIntervalSince(lastInactiveDate)
            print(seconds)
            if seconds > timeOutSeconds {
                let vc = LoginViewController()
                vc.amount = "\(Double.random(in: 100...1000).rounded(toPlaces: 0))"
                window?.rootViewController = vc
                window?.makeKeyAndVisible()
            }
        }
        
        defaults.set(nil, forKey: "LastInactiveDate")
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
//        SCStatusBar.shared.stopMonitor()
        
        if UserDefaults.standard.bool(forKey: "PasswordChange") {
            // exit the app
            exit(0)
        }
        
        guard Blackbox.pwdConfExist() else { return }
        
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: "LastInactiveDate")
    }
    
    
}



