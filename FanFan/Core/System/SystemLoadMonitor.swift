//
//  SystemLoadMonitor.swift
//  FanFan
//
//  Created by Guilherme Rambo on 26/03/21.
//

#if !arch(x86_64)
import Foundation
import os.log

// Based on https://stackoverflow.com/posts/53901721/revisions
// CPU usage credit VenoMKO: https://stackoverflow.com/a/6795612/1033581

final class SystemLoadMonitor: ObservableObject {
    private let log = OSLog(subsystem: "codes.rambo.FanFan", category: String(describing: SystemLoadMonitor.self))
    
    var cpuInfo: processor_info_array_t!
    var prevCpuInfo: processor_info_array_t?
    var numCpuInfo: mach_msg_type_number_t = 0
    var numPrevCpuInfo: mach_msg_type_number_t = 0
    var numCPUs: uint = 0
    var updateTimer: Timer!
    let CPUUsageLock: NSLock = NSLock()
    
    private let maxSampleCount = 24
    private var samples: [Float] = []
    
    @Published private(set) var currentLoad: Float = 0 {
        didSet {
            guard currentLoad != oldValue else { return }
            os_log("currentLoad = %{public}.2f", log: self.log, type: .debug, currentLoad)
        }
    }

    init() {
        let mibKeys: [Int32] = [ CTL_HW, HW_NCPU ]
        // sysctl Swift usage credit Matt Gallagher: https://github.com/mattgallagher/CwlUtils/blob/master/Sources/CwlUtils/CwlSysctl.swift
        mibKeys.withUnsafeBufferPointer() { mib in
            var sizeOfNumCPUs: size_t = MemoryLayout<uint>.size
            let status = sysctl(processor_info_array_t(mutating: mib.baseAddress), 2, &numCPUs, &sizeOfNumCPUs, nil, 0)
            if status != 0 {
                numCPUs = 1
            }
            updateTimer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(updateInfo), userInfo: nil, repeats: true)
            updateTimer.tolerance = 0.5
            updateInfo(updateTimer)
        }
    }

    @objc func updateInfo(_ timer: Timer) {
        var numCPUsU: natural_t = 0
        let err: kern_return_t = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo);
        if err == KERN_SUCCESS {
            CPUUsageLock.lock()
            
            var sum: Float = 0

            for i in 0 ..< Int32(numCPUs) {
                var inUse: Int32
                var total: Int32
                if let prevCpuInfo = prevCpuInfo {
                    inUse = cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_USER)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_USER)]
                        + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_SYSTEM)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_SYSTEM)]
                        + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_NICE)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_NICE)]
                    total = inUse + (cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_IDLE)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_IDLE)])
                } else {
                    inUse = cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_USER)]
                        + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_SYSTEM)]
                        + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_NICE)]
                    total = inUse + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_IDLE)]
                }

                sum += Float(inUse) / Float(total)
            }
            CPUUsageLock.unlock()

            if let prevCpuInfo = prevCpuInfo {
                // vm_deallocate Swift usage credit rsfinn: https://stackoverflow.com/a/48630296/1033581
                let prevCpuInfoSize: size_t = MemoryLayout<integer_t>.stride * Int(numPrevCpuInfo)
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevCpuInfo), vm_size_t(prevCpuInfoSize))
            }

            prevCpuInfo = cpuInfo
            numPrevCpuInfo = numCpuInfo
            
            DispatchQueue.main.async { [self] in
                let sample = sum / Float(numCPUs)
                samples.append(sample)
                if samples.count >= maxSampleCount { samples.removeFirst() }
                self.currentLoad = samples.reduce(0, { $0 + $1 }) / Float(samples.count)
            }

            cpuInfo = nil
            numCpuInfo = 0
        } else {
            os_log("Failed to get CPU load information", log: self.log, type: .fault)
        }
    }
}
#endif
