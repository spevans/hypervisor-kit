//
//  VirtualMachine.swift
//  VMMKit
//
//  Created by Simon Evans on 01/01/2020.
//  Copyright © 2020 Simon Evans. All rights reserved.
//
//  Main class encapsulating a VM.
//

import Logging
import Dispatch
import Foundation

/// A type representing a full VM (virtual machine) including cpus and memory.
public final class VirtualMachine {
    private var isShutdown = true
    internal let logger: Logger
#if os(Linux)
    internal var vm_fd: Int32 = -1
#endif

    public private(set) var vcpus: [VCPU] = []
    public private(set) var memoryRegions: [MemoryRegion] = []


    /// Initialise the VM subsystem
    ///
    /// - parameter logger: `Logger` object for `debug` and `trace` messages.
    /// - throws: `VMError.vmCreateVMFailure`
    public init(logger: Logger) throws {
        self.logger = logger
        do {
            try self._createVM()
            isShutdown = false
        } catch {
            logger.debug("Cannot create VM: \(error)")
            throw VMError.vmCreateVMFailure
        }
    }

    deinit {
        guard isShutdown == true else {
            fatalError("VM has not been shutdown().")
        }
    }

    /// Adds a memory region into the physical address space of the VM.
    /// ```
    /// The VM requires at least one MemoryRegion to be added before starting the vCPU.
    /// ```
    /// - parameter guestAddress: Physical Address inside the VM where the region will start.
    /// - parameter size: Size in bytes of the memory region.
    /// - parameter readOnly: Flag to indicate if the memory should be treated as ROM or RAM by the Virtual CPUs.
    /// - returns: The new `MemoryRegion`.
    /// - precondition: `guestAddress` must be page aligned.
    /// - precondition: `size` is non-zero and is a multiple of the page size of the VM.
    /// - throws: `VMError.addMemoryFailure`.
    public func addMemory(at guestAddress: UInt64, size: UInt64, readOnly: Bool = false) throws -> MemoryRegion {
        logger.trace("Adding \(size) bytes at address 0x\(String(guestAddress, radix: 16))")

        precondition(guestAddress & 0xfff == 0)
        precondition(size > 0)
        precondition(size & 0xfff == 0)
        do {
            let memRegion = try _createMemory(at: guestAddress, size: size, readOnly: readOnly)
            memoryRegions.append(memRegion)
            logger.trace("Added memory")
            return memRegion
        } catch {
            logger.debug("Cannot add MemoryRegion: \(error)")
            throw VMError.addMemoryFailure
        }
    }

    /// Returns the memory region containing a specific physical address in the address space of the VM.
    /// - parameter guestAddress: The Physical Address in the VM.
    /// - returns: The `MemoryRegion` containing the address or `nil` if no region is found.
    public func memoryRegion(containing guestAddress: PhysicalAddress) -> MemoryRegion? {
        for region in memoryRegions {
            if region.guestAddress <= guestAddress && region.guestAddress + region.size >= guestAddress {
                return region
            }
        }
        return nil
    }

    /// Returns an `UnsafeMutableRawPointer` to a region of bytes at a specified physical address.
    /// - parameter guestAddress: Physical Address inside the VM where the region will start.
    /// - parameter count: The size in bytes of the region.
    /// - returns: An `UnsafeMutableRawPointer` pointing to a region of `count` bytes.
    /// - throws: `HVError.invalidMemory` if the region in not inside a specif `MemoryRegion`.
    public func memory(at guestAddress: PhysicalAddress, count: UInt64) throws -> UnsafeMutableRawPointer {
        for region in memoryRegions {
            if region.guestAddress <= guestAddress && region.guestAddress + region.size >= guestAddress + count {
                let offset = guestAddress - region.guestAddress
                return region.pointer.advanced(by: Int(offset))
            }
        }
        throw VMError.invalidMemoryRegion
    }

    /// Add a VCPU to the Virtual Machine.
    /// ```
    /// Creates a new Thread and initialises a vCPU in that thread. The `startup` function
    /// is executed to setup the vCPU and then it waits until the `.start()` method is called
    /// to begin executing code.
    /// ```
    /// - returns: The `VCPU` that has been added to the VM.
    /// - throws: `VMError.vcpuCreateFailure`.
    @discardableResult
    public func addVCPU() throws -> VCPU {
        var vcpu: VCPU? = nil
        var createError: Error? = nil
        let semaphore = DispatchSemaphore(value: 0)

        let thread = Thread {
            do {
                let _vcpu = try self._createVCPU()
                vcpu = _vcpu
                _vcpu.setupRealMode()
                try _vcpu.preflightCheck()
                _vcpu.status = .waitingToStart
                semaphore.signal()
                _vcpu.runVCPU()
            } catch {
                createError = error
                semaphore.signal()
                return
            }
        }
        thread.start()
        semaphore.wait()
        if let error = createError {
            logger.debug("Cannot create VCPU: \(error)")
            throw VMError.vcpuCreateFailure
        }
        vcpus.append(vcpu!)
        return vcpu!
    }

    /// Query all of the vCPUs to determine if they have been shutdown
    /// ```
    /// Use this method to check the shutdown status of all of the vCPUs.
    /// Before shutting down the VirtualMachine, all of the vCPUs must be
    /// in the shutdown state.
    /// The `.shutdownAllVcpus` method can be called to shutdown all the
    /// vCPUS.
    /// ```
    /// - returns: `true` if all vCPUs have been shutdown, `false` if any are still running.
    public func areVcpusShutdown() -> Bool {
        vcpus.allSatisfy { $0.status == .shutdown }
    }

    /// Request all of the vCPUs to enter the shutdown state.
    /// ```
    /// Use this method to request all vCPUs to shutdown.
    /// ```
    /// - returns: `true` if all vCPUs have been shutdown, `false` if any are still running.
    @discardableResult
    public func shutdownAllVcpus() -> Bool {
        vcpus.forEach { _ = $0.shutdown() }
        return areVcpusShutdown()
    }

    /// Shutdown the VM.
    /// ```
    /// shutdown() must be called before the VirtualMachine object is deallocated.
    /// Before calling, all vCPUS must be individually shutdown and a check is run
    /// to ensure the vCPUS are in the shutdown state.
    /// All MemoryRegions and VCPUS are deallocated by this method and the underlying
    /// hypervisor is shutdown by the OS.
    /// ```
    /// - throws: `VMError.vcpusStillRunning` if any vCPU is still running.
    /// - throws: `VMError.vmShutdownFailure` if an internal  subsystem error occurs.
    public func shutdown() throws {
        logger.trace("Shutting down VM - deinit")
        precondition(isShutdown == false)
        guard areVcpusShutdown() else {
            throw VMError.vcpusStillRunning
        }

        do {
            vcpus = []
            for region in memoryRegions {
                try _destroyMemory(region: region)
            }
            memoryRegions = []
            try _shutdownVM()
            isShutdown = true
        } catch {
            logger.debug("Error Shutting down VM: \(error)")
            throw VMError.vmShutdownFailure
        }
    }
}
