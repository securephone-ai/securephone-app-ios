

import Foundation
import UIKit
import AudioToolbox

import AVFoundation

extension ChatFooterView: AVAudioRecorderDelegate {
  
  @objc func micButtonLongPress(_ sender: UIGestureRecognizer) {
    
    let button = sender.view as! UIButton
    let location = sender.location(in: button)
    
    if sender.state ==  .began, recordingState == .none {
      // Recording started
      
      if !audioRecorder.checkPermission() {
        audioRecorder.askPermission(completion: nil)
      } else {
        recordingStartingPoint = location
        recordingState = .recording
        Vibration.light.vibrate()
      }
    } else if sender.state == .changed, audioRecorder.checkPermission() {
      
      // Recording in progress...
      // Check the slide direction to Lock or Cancel the recording
      // Lock the recording if the slide is going UP
      // Cancel the recording if the slide go left
      if location.x < 0, location.x >= -100 {
        let newX = ((frame.size.width/2)-(recordingLabel.frame.size.width/2)+(location.x/1.8))-5
        if newX < recordingLabelStartingX {
          recordingLabel.alpha -= 0.01
          chevronLeftImage.alpha -= 0.01
        } else {
          recordingLabel.alpha += 0.01
          chevronLeftImage.alpha += 0.01
        }
        
        recordingLabel.pin.left(newX)
        chevronLeftImage.pin.centerLeft(to: self.recordingLabel.anchor.centerRight).marginLeft(4)
        recordingLabelStartingX = newX
      }
      if location.x >= 0 {
        recordingLabel.alpha = 1
        chevronLeftImage.alpha = 1
      }
      
      // Sliding Left
      if location.x < recordingStartingPoint.x {
        if location.x < -100 {
          // Cancel Recording
          if recordingState != .none {
            Vibration.light.vibrate()
            recordingState = .none
            audioRecorder.stopRecording()
          }
        }
      }
      
      //Sliding Up
      if location.y < recordingStartingPoint.y {
        if location.y < -100 {
          // Lock Recording
          logi("Lock Recording")
          recordingState = .locked
        }
      }
      
    } else if sender.state == .ended, audioRecorder.checkPermission() {
      // Reset the view to initial state if is not locked
      if recordingState == .recording {
        recordingStartingPoint = CGPoint.zero
        recordingState = .none
        audioRecorder.stopRecording()
        
        guard let delegate = self.delegate else { return }
        delegate.didSendAudio(filePath: audioRecorder.getFilePath(), replyTo: chatFooterReplyView?.message)
        
        self.msgTextView.text = ""
        self.closeReplyView()
      }
    }
  }
  
}
