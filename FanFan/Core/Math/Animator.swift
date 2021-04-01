//
//  Animator.swift
//  FanFan
//
//  Created by Guilherme Rambo on 26/03/21.
//

import Cocoa

final class Animator {
    
    private static var activeAnimators: [Animator] = []
    
    private func makeDisplayLink() -> DisplayLink {
        let l = DisplayLink()
        
        l.callback = { [weak self] in
            self?.progress()
        }
        
        return l
    }

    private(set) lazy var displayLink: DisplayLink = {
        return makeDisplayLink()
    }()
    
    private var startTime: TimeInterval = 0
    
    var duration: TimeInterval = 1
    
    func getTime() -> TimeInterval {
        return Date().timeIntervalSince1970
    }
    
    var fromValue: Double = 0 {
        didSet {
            change = toValue - fromValue
        }
    }
    var toValue: Double = 0 {
        didSet {
            change = toValue - fromValue
        }
    }
    
    var change: Double = 0
    
    var valueDidChange: (Double) -> Void = { _ in }
    
    var finished = false
    
    private let id: UUID
    
    init(fromValue: Double, toValue: Double, duration: TimeInterval, callback: @escaping (Double) -> Void) {
        self.id = UUID()
        self.fromValue = fromValue
        self.toValue = toValue
        self.duration = duration
        self.valueDidChange = callback
        self.change = toValue - fromValue
        
        Self.activeAnimators.append(self)
    }
    
    func progress() {
        let time = getTime() - startTime

        var newValue: CGFloat
        
        if time < duration {
            newValue = easeInOutSine(CGFloat(time), CGFloat(fromValue), CGFloat(change), CGFloat(duration))
        } else {
            newValue = CGFloat(toValue)
            fromValue = toValue
            finished = true
            
            stop()
        }
        
        valueDidChange(Double(newValue))
    }
    
    func start() {
        startTime = getTime()

        displayLink.activate()
    }
    
    func stop() {
        displayLink.invalidate()
        
        if let idx = Self.activeAnimators.firstIndex(where: { $0.id == id }) {
            Self.activeAnimators.remove(at: idx)
        }
    }
    
    private func easeInOutSine(_ t: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
        c * sin(t/d * (CGFloat.pi/2)) + b
    }
    
    deinit { displayLink.invalidate() }

}
