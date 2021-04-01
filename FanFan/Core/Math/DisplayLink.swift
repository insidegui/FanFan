import Foundation
import CoreVideo

internal final class DisplayLink: NSObject {
    var callback: () -> Void = {}
    private var link: CVDisplayLink?

    deinit {
        guard let link = link else {
            return
        }

        CVDisplayLinkStop(link)
    }

    func activate() {
        CVDisplayLinkCreateWithActiveCGDisplays(&link)

        guard let link = link else {
            return
        }

        let opaquePointerToSelf = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkSetOutputCallback(link, _displayLinkCallback, opaquePointerToSelf)

        CVDisplayLinkStart(link)
    }

    func invalidate() {
        guard let currentLink = link else { return }
        CVDisplayLinkStop(currentLink)
        link = nil
    }

    @objc func screenDidRender() {
        DispatchQueue.main.async(execute: callback)
    }
}

// swiftlint:disable:next function_parameter_count
private func _displayLinkCallback(displayLink: CVDisplayLink,
                                             _ now: UnsafePointer<CVTimeStamp>,
                                             _ outputTime: UnsafePointer<CVTimeStamp>,
                                             _ flagsIn: CVOptionFlags,
                                             _ flagsOut: UnsafeMutablePointer<CVOptionFlags>,
                                             _ displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn {
    unsafeBitCast(displayLinkContext, to: DisplayLink.self).screenDidRender()
    return kCVReturnSuccess
}
