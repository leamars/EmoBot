//
//  ViewController.swift
//  EmoBot
//
//  Created by Lea Marolt on 6/17/17.
//  Copyright © 2017 elemes. All rights reserved.
//

import UIKit
import Affdex
import AVFoundation

let successSounds: [String] = ["smb_coin", "smb_coin", "smb_stage_clear"]
let failureSounds: [String] = ["smb_bowserfalls", "smb_bowserfalls", "smb_mariodie"]

var successes = 0;
var failures = 0;

enum result: Int {
    case success, failure
    
    var sound: String {
        switch self {
        case .success:
            let sound = successSounds[successes%3]
            successes += 1
            failures = 0
            return sound
        case .failure:
            let sound = failureSounds[failures%3]
            failures += 1
            successes = 0
            return sound
        }
    }
}

class ViewController: UIViewController {

    @IBOutlet weak var cameraView: UIImageView!
    @IBOutlet weak var positionSlider: UISlider!
    @IBOutlet weak var imageBluetoothStatus: UIImageView!
    
    var timerTXDelay: Timer?
    var replyTimer: Timer?
    var receiveTimer: Timer?
    var soundTimer: Timer?
    var allowTX: Bool = true
    
    var detector: AFDXDetector?
    let captureSession = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    let videoOutput = AVCaptureVideoDataOutput()
    
    var face: botFace?
    
    var player: AVAudioPlayer?
    var soundPlaying = false;
    var failureCount = 0;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Rotate slider to vertical position
//        guard let superView = positionSlider.superview else { return }
//        positionSlider.removeFromSuperview()
//        positionSlider.removeConstraints(view.constraints)
//        positionSlider.translatesAutoresizingMaskIntoConstraints = true
//        positionSlider.transform = CGAffineTransform.init(rotationAngle: .pi)
//        superView.addSubview(positionSlider)
//
//        // Set thumb image on slider
//        positionSlider.setThumbImage(UIImage(named:"Bar"), for: .normal)
//        allowTX = true
        
        // Watch Bluetooth connection
        NotificationCenter.default.addObserver(self, selector: #selector(connectionChanged(with:)), name: Notification.Name.init(Elemes_BLE_Service_Changed_Notification), object: nil)
        
        // Start the Bluetooth discovery process
        let service = BluetoothDiscovery.shared
        cameraView.contentMode = .scaleAspectFill
        
        startReceiveTimer()
        startSoundTimer()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.init(Elemes_BLE_Service_Changed_Notification), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        createDetector()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        destroyDetector()
    }
    
    // create timers
    func startReplyTimer() {
        if replyTimer == nil {
            replyTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(replyTimerDelayElapsed), userInfo: nil, repeats: false)
            stopReceiveTimer()
        }
    }
    
    @objc func replyTimerDelayElapsed() {
        
    }
    
    func stopReplyTimer() {
        guard let _timer = replyTimer else { return }
        
        _timer.invalidate()
        replyTimer = nil
    }
    
    func stopSoundTimer() {
        guard let _timer = soundTimer else { return }
        
        _timer.invalidate()
    }
    
    func startSoundTimer() {
        if soundTimer == nil {
            soundTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(soundTimerDelayElapsed), userInfo: nil, repeats: false)
        }
    }
    
    @objc func soundTimerDelayElapsed() {
        guard let peripheral = BluetoothDiscovery.shared.peripheralBLE,
            let characteristic = BluetoothDiscovery.shared.bluetoothService?.soundCharacteristic else { return }
        
        peripheral.readValue(for: characteristic)
    }
    
    func startReceiveTimer() {
        if receiveTimer == nil {
            receiveTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(receiveTimerDelayElapsed), userInfo: nil, repeats: true)
            stopReplyTimer()
        }
    }
    
    func stopReceiveTimer() {
        guard let _timer = receiveTimer else { return }
        
        _timer.invalidate()
        receiveTimer = nil
    }
    
    @objc func receiveTimerDelayElapsed() {
        guard let peripheral = BluetoothDiscovery.shared.peripheralBLE,
            let characteristic = BluetoothDiscovery.shared.bluetoothService?.faceCharacteristic else { return }
        
        peripheral.readValue(for: characteristic) 
        if let face = BluetoothDiscovery.shared.bluetoothService?.emoFace {
            self.face = face
        }
        
        return
    }
    
    func sendResult(position: UInt32) {
        var lastPosition: UInt32 = 4294967295
        
        if position == lastPosition { return }
        else if position < 0 || position > 180 { return }
        
        guard BluetoothDiscovery.shared.bluetoothService != nil else { return }
        BluetoothDiscovery.shared.bluetoothService!.write(position: position)
        lastPosition = position
        
        stopReceiveTimer()
        startReplyTimer()
    }
    
    //MARK: Sound
    func playSound(with result: result) {
        var sound = result.sound
        
        guard let url = Bundle.main.url(forResource: sound, withExtension: "wav") else {
            print("error")
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url)
            guard let player = player else { return }
            
            player.play()
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    //MARK: IBActions
    
    @IBAction func positionSliderChanged(_ sender: UISlider) {
        // Since the slider value range is from 0 to 180, it can be sent directly to the Arduino board
        send(position: UInt32(sender.value))
    }
    
    //MARK: Private
    
    @objc func connectionChanged(with notification: Notification) {
        guard let userInfoDict = notification.userInfo as? [String: String],
            let isConnected = userInfoDict["isConnected"]?.boolValue else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Bounce back to the main thread to update the UI
            let image: UIImage = isConnected ? UIImage(named: "Bluetooth_Connected")! : UIImage(named: "Bluetooth_Disconnected")!
            self.imageBluetoothStatus.image = image
            DispatchQueue.main.async {
                
                if isConnected {
                    //self.send(position: UInt8(self.positionSlider.value))
                }
            }
        }
    }
    
    func send(position: UInt32) {
                
        var lastPosition: UInt32 = 4294967295
        
        if position == lastPosition { return }
        else if position < 0 || position > 180 { return }
        
        guard BluetoothDiscovery.shared.bluetoothService != nil else { return }
        BluetoothDiscovery.shared.bluetoothService!.write(position: position)
        lastPosition = position
        
        // Start delay times
        allowTX = false
        if timerTXDelay == nil {
            timerTXDelay = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(timerTXDelayElapsed), userInfo: nil, repeats: false)
        }
        
    }
    
    func receiveTimerElapsed() {
        
    }
    
    @objc func timerTXDelayElapsed() {
        
        allowTX = true
        stopTimerTXDelay()
        
        // Send current slider position
        //send(position: UInt8(positionSlider.value))
    }
    
    func stopTimerTXDelay() {
        guard let _timer = timerTXDelay else { return }
        
        _timer.invalidate()
        timerTXDelay = nil
    }
}

//MARK: Affectiva
extension ViewController: AFDXDetectorDelegate {
    
    func detector(_ detector: AFDXDetector!, hasResults faces: NSMutableDictionary!, for image: UIImage!, atTime time: TimeInterval) {
        
        if faces == nil {
            unprocessedImageReady(for: detector, image: image, at: time)
        } else {
            processedImageReady(for: detector, image: image, faces: faces, at: time)
        }
    }
    
    func processedImageReady(for detector: AFDXDetector, image: UIImage, faces: NSDictionary, at time: TimeInterval) {
        guard let allFaces = faces.allValues as? [AFDXFace] else { return }
        
        for face in allFaces {
            guard let _botFace = self.face else { return }
            let match = _botFace.matchingFace(face: face)
            
            if (match) {
                //print("IT'S A MATCH!!!!!!!!!!!")
                if let _player = player {
                    if !_player.isPlaying {
                        playSound(with: result.success)
                    }
                } else {
                    playSound(with: result.success)
                }
                
                guard BluetoothDiscovery.shared.bluetoothService != nil else { return }
                BluetoothDiscovery.shared.bluetoothService!.write(position: UInt32(1337))
                self.face = nil
                failureCount = 0
                
            } else {
                //print("no match...")
                if failureCount > 25 {
                    if let _player = player {
                        if !_player.isPlaying {
                            playSound(with: result.failure)
                            failureCount = 0
                        }
                    } else {
                        playSound(with: result.failure)
                        failureCount = 0
                    }
                    guard BluetoothDiscovery.shared.bluetoothService != nil else { return }
                    BluetoothDiscovery.shared.bluetoothService!.write(position: UInt32(666))
                    self.face = nil
                }
                failureCount += 1
            }
        }
    }
    
    func unprocessedImageReady(for detector: AFDXDetector, image: UIImage, at time: TimeInterval) {
        DispatchQueue.main.async {
            self.cameraView?.image = UIImage(cgImage: image.cgImage!, scale: 1.0, orientation: .upMirrored)
        }
    }
    
    func destroyDetector() {
        detector?.stop() // Handle Error
    }
    
    func createDetector() {
        // ensure the detector has stopped
        destroyDetector()
        
        let deviceTypes: [AVCaptureDevice.DeviceType] = [AVCaptureDevice.DeviceType.builtInWideAngleCamera]
        
        let allDevices = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: AVMediaType.video, position: .unspecified)
        
        for device in allDevices.devices {
            if device.position == .front {
                detector = AFDXDetector(delegate: self, using: device, maximumFaces: 1, face: FaceDetectorMode.init(0))
                
                detector!.setDetectEmojis(true) // WHAT IS THIS?
                detector!.setDetectAllEmotions(true)
                detector!.setDetectAllExpressions(true)
                
                detector!.gender = true
                detector!.glasses = true
                
                guard let error: Error = detector!.start() else {
                    print("All is well with the world.")
                    return
                }
                print("There was an error :( \(error.localizedDescription)")
            }
        }
        
    }
}


