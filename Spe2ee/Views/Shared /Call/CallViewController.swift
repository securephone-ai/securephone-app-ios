import UIKit
import PinLayout
import NextLevel
import AVFoundation

class CallViewController: UIViewController {
  
  // MARK: Properties
  private var call: BBCall?
  var callView: CallView?
  
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .portrait
  }
 
  init(call: BBCall) {
    self.call = call
    callView = CallView(call: call)
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  deinit {
    call = nil
    callView = nil
    logi("CallViewController Deinitialized")
  }
  
  override func loadView() {
    view = callView
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // We enter this block if the call was received when the app was closed and un-registered or with an invalid pwdConf.
    if let call = call {
      if call.needPassword {
        call.getInfo { success in
          if success {
            if call.hasVideo {
              call.answerVideoCall(audioOnly: false, completion: nil)
            } else {
              call.answerCall { (success) in
                call.startAudioIfNeeded(routeToSpeaker: false)
              }
            }
          } else {
            call.endCall()
          }
        }
      }
      
//      if !call.isOutgoing {
//        callView?.alpha = 0
//      }
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // if the call is outgoing we start the video right away, otherwise only when the call is answered.
    if let call = call, call.hasVideo, call.isOutgoing == true {
      do {
        try NextLevel.shared.start()
        NextLevel.shared.frameRate = 30
      } catch {
        loge("NextLevel, failed to start camera session - \(#function)")
      }
    }
    
    callView?.backButton.addTarget(self, action: #selector(backPressed), for: .touchUpInside)
    
    DispatchQueue.main.async { [weak self] in
      guard let strongSelf = self else { return }
      strongSelf.callView?.setNeedsLayout()
      strongSelf.callView?.layoutIfNeeded()
    }
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    NextLevel.shared.stop()
    callView?.cleanCallWorkers()
  }
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }

  @objc func backPressed() {
    self.dismiss(animated: true, completion: nil)
  }
  
  @objc func addContactPressed() {
    self.dismiss(animated: true, completion: nil)
  }
  
}

