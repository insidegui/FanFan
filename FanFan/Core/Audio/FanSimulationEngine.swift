//
//  FanSimulationEngine.swift
//  FanFan
//
//  Created by Guilherme Rambo on 26/03/21.
//

#if !arch(x86_64)
import Cocoa
import AVFoundation

final class FanSimulationEngine: NSObject, ObservableObject {
    
    private lazy var audioEngine = AVAudioEngine()
    private lazy var player = AVAudioPlayerNode()
    private lazy var pitchUnit = AVAudioUnitTimePitch()
    
    private lazy var fileURL4800: URL = {
        guard let url = Bundle.main.url(forResource: "4800", withExtension: "wav") else { fatalError() }
        
        return url
    }()

    typealias AudioFileNodes = (file: AVAudioFile, buffer: AVAudioPCMBuffer)
    
    private func nodes(from url: URL) -> AudioFileNodes {
        do {
            let file = try AVAudioFile(forReading: url)
            let audioFormat = file.processingFormat
            let audioFrameCount = UInt32(file.length)
            guard let buf = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount) else {
                fatalError("Failed to initialize buffer")
            }
            try file.read(into: buf)
            return (file, buf)
        } catch {
            fatalError(String(describing: error))
        }
    }
    
    private lazy var nodes4800: AudioFileNodes = { nodes(from: fileURL4800) }()
    
    private let minPitch: Float = -800
    private let maxPitch: Float = 140
    
    private let minVolume: Float = 0.02
    private let maxVolume: Float = 1.0
    
    private var currentAnimator: Animator?
    
    private var presentationIntensity: Float = 0.01
    
    @Published var intensity: Float = 0.01 {
        didSet {
//            currentAnimator?.stop()
//            currentAnimator = nil

            currentAnimator = Animator(fromValue: Double(presentationIntensity), toValue: Double(intensity), duration: 0.8) { [weak self] v in
                guard let self = self else { return }
                self.presentationIntensity = Float(v)
                self.updatePitch(with: Float(v))
            }
            currentAnimator?.start()
        }
    }
    
    private func updatePitch(with value: Float) {
        let pitch = lerp(value, min: minPitch, max: maxPitch)
        pitchUnit.pitch = pitch
        
        let volume = lerp(value, min: minVolume, max: maxVolume)
        audioEngine.mainMixerNode.outputVolume = volume
        
//        print("v = \(value)")
    }
    
    func start() {
        guard !audioEngine.isRunning else { return }
        
        let mixer = audioEngine.mainMixerNode
        
        audioEngine.attach(player)
        audioEngine.attach(pitchUnit)
        
        audioEngine.connect(player, to: pitchUnit, format: nodes4800.buffer.format)
        audioEngine.connect(pitchUnit, to: mixer, format: nodes4800.buffer.format)
        
        updatePitch(with: intensity)
        
        try! audioEngine.start()

        player.play()
        
        player.scheduleBuffer(nodes4800.buffer, at: nil, options: .loops, completionHandler: nil)
        
        try! audioEngine.start()
    }
    
    func stop() {
        guard audioEngine.isRunning else { return }
        
        audioEngine.stop()
    }

}
#endif
