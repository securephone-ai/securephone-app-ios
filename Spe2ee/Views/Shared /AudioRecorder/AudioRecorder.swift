
import Foundation
import AVFoundation
import BlackboxCore

protocol AudioRecorder {
    func checkPermission(completion: ((Bool) -> Void)?)
    
    /// if url is nil audio will be stored to default url
    func record(to url: URL?)
    func stopRecording()
    
    /// if url is nil audio will be played from default url
    func play(from url: URL?, currentTime: TimeInterval)
    func stopPlaying()
    
    func getAudioDuration() -> TimeInterval
    func getAudioCurrentTime() -> TimeInterval
    func isAudioPlaying() -> Bool
    
    func pause()
    func resume()
}

protocol AudioPlayerDelegate: AnyObject {
    func didFinishPlaying(successfully flag: Bool)
}

class AudioRecorderImpl: NSObject, AudioRecorder {
    //private let session = AVAudioSession.sharedInstance()
    private var player: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private lazy var permissionGranted = false
    private lazy var isRecording = false
    private lazy var isPlaying = false
    private lazy var isPlayerConfigured = false
    private var fileURL: URL?
    private var fileKey: String?
    private let settings = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 2,
        AVEncoderAudioQualityKey:AVAudioQuality.high.rawValue
    ]
    
    public weak var playerDelegate: AudioPlayerDelegate?
    
    /// Automatically initialize a new  audio recorder with the give File name
    /// - Parameters:
    ///   - filename: filepath
    ///   - playerOnly: flag defining the record only
    init(filename: String = "recording.m4a", recorderOnly: Bool = false) {
        super.init()
        fileURL = AppUtility.getDocumentsDirectory().appendingPathComponent(filename)
        
        if recorderOnly, fileURL != nil {
            try? FileManager.default.removeItem(at: fileURL!)
            setupRecorder(url: fileURL!)
        }
    }
    
    
    /// Automatically initialize a new  audio player with the give File
    /// - Parameters:
    ///   - filename: filepath
    ///   - playerOnly: flag defining the player only
    init(filepath: String, key: String, playerOnly: Bool = false) {
        super.init()
        fileURL = URL(string: filepath)
        fileKey = key
        if playerOnly, fileURL != nil {
            setupPlayer(url: fileURL!, key: key)
        }
    }
    
    func record(to url: URL?) {
        guard permissionGranted, let url = url ?? fileURL else { return }
        
        setupRecorder(url: url)
        
        if isRecording {
            stopRecording()
        }
        
        isRecording = true
        recorder?.record()
    }
    
    func stopRecording() {
        isRecording = false
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    func play(from url: URL?, currentTime: TimeInterval = 0.0) {
        guard let url = url ?? fileURL else { return }
        
        if isPlayerConfigured {
            resume(at: currentTime)
        } else {
            setupPlayer(url: url, key: fileKey)
            
            if isRecording {
                stopRecording()
            }
            
            if isPlaying {
                stopPlaying()
            }
            
            if FileManager.default.fileExists(atPath: url.path) {
                isPlaying = true
                setupPlayer(url: url, key: fileKey)
                player?.play()
            }
        }
    }
    
    func stopPlaying() {
        player?.stop()
    }
    
    func pause() {
        player?.pause()
    }
    
    func resume() {
        if player?.isPlaying == false {
            player?.play()
        }
    }
    
    func resume(at time: Double) {
        guard let player = self.player else { return}
        if player.isPlaying == false {
            player.currentTime = time
            player.play()
        }
    }
    
    func checkPermission(completion: ((Bool) -> Void)?) {
        func assignAndInvokeCallback(_ granted: Bool) {
            self.permissionGranted = granted
            completion?(granted)
        }
        
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            assignAndInvokeCallback(true)
        case .denied:
            assignAndInvokeCallback(false)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission(assignAndInvokeCallback)
        default:
            break
        }
    }
    
    func checkPermission() -> Bool {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            self.permissionGranted = true
            return true
        case .denied:
            self.permissionGranted = false
            return false
        case .undetermined:
            self.permissionGranted = false
            return false
        default:
            return false
        }
    }
    
    func askPermission(completion: ((Bool) -> Void)?) {
        func assignAndInvokeCallback(_ granted: Bool) {
            self.permissionGranted = granted
            completion?(granted)
        }
        AVAudioSession.sharedInstance().requestRecordPermission(assignAndInvokeCallback)
    }
    
    func getFilePath() -> String {
        return fileURL?.path ?? ""
    }
    
    func getAudioDuration() -> TimeInterval {
        guard let player = self.player else { return TimeInterval.zero }
        return player.duration
    }
    
    func getAudioCurrentTime() -> TimeInterval {
        guard let player = self.player else { return TimeInterval.zero }
        return player.currentTime
    }
    
    func isAudioPlaying() -> Bool {
        guard let player = self.player else { return false }
        return player.isPlaying
    }
    
}

extension AudioRecorderImpl: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            stopRecording()
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard let delegate = self.playerDelegate else { return }
        delegate.didFinishPlaying(successfully: flag)
    }
}

private extension AudioRecorderImpl {
    func setupRecorder(url: URL) {
        guard permissionGranted else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, policy: .default, options: .defaultToSpeaker)
            try AVAudioSession.sharedInstance().setActive(true)
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            let _ = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true
            recorder?.prepareToRecord()
            
        } catch {
            // error
            loge(error)
        }
    }
    
    func setupPlayer(url: URL, key: String?) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            if url.path.contains(".enc"),
               let data = AppUtility.decryptFile(url.path, key: key?.base64Decoded ?? "") {
                player = try AVAudioPlayer(data: data)
            } else {
                player = try AVAudioPlayer(contentsOf: url)
            }
            
            if player != nil {
                isPlayerConfigured = true
                player?.delegate = self
                player?.prepareToPlay()
            } else {
                isPlayerConfigured = false
                isPlaying = false
            }
        } catch(let error) {
            isPlayerConfigured = false
            isPlaying = false
            loge(error.localizedDescription)
        }
    }
}
