//
//  kvm_vm.swift
//
//
//  Created by Simon Evans on 01/12/2019.
//

#if os(Linux)

import CBits
import Foundation
import Dispatch
import Logging

private let KVM_DEVICE = "/dev/kvm"

enum HVError: Error {
    case vmSubsystemFail
    case badIOCTL(Int)
    case setRegisters
    case getRegisters
    case vmRunError
    case vmMemoryError
    case invalidMemory
    case irqAlreadyQueued
    case irqNumberInvalid
    case irqAlreadyHandledByKernelPIC
    case vcpusStillRunning
}

public final class VirtualMachine {

    private var _shutdown = false
    internal let logger: Logger
    private let vm_fd: Int32

    public private(set) var vcpus: [VCPU] = []
    public private(set) var memoryRegions: [MemoryRegion] = []


    static var apiVersion: Int32? = {
        return try? ioctl2arg(vmFD(), _IOCTL_KVM_GET_API_VERSION)
    }()


    static var vcpuMmapSize: Int32? = {
        return try? ioctl2arg(vmFD(), _IOCTL_KVM_GET_VCPU_MMAP_SIZE)
    }()

    static private var _vmfd: Int32 = -1
    static private func vmFD() throws -> Int32 {
        if _vmfd == -1 {
            _vmfd = open2arg(KVM_DEVICE, O_RDWR)
            guard _vmfd >= 0 else {
                throw HVError.vmSubsystemFail
            }
        }
        return _vmfd
    }


    public init(logger: Logger) throws {
        self.logger = logger

        guard let dev_fd = try? Self.vmFD() else {
            logger.error("Cannot open \(KVM_DEVICE)")
            throw HVError.vmSubsystemFail
        }
        guard let apiVersion =  VirtualMachine.apiVersion, apiVersion >= 0 else {
            fatalError("Bad API version")
        }
        vm_fd = ioctl2arg(dev_fd, _IOCTL_KVM_CREATE_VM)
        guard vm_fd >= 0 else {
            logger.error("Cannont create VM")
            throw HVError.vmSubsystemFail
        }
    }


    deinit {
        guard _shutdown == true else {
            fatalError("VM has not been shutdown().")
        }
    }


    public func shutdown() throws {
        logger.info("Shutting down VM - deinit")
        precondition(_shutdown == false)
        guard allVcpusShutdown() else {
            throw HVError.vcpusStillRunning
        }

        close(vm_fd)
        vcpus = []
        memoryRegions = []
        _shutdown = true
    }


    public func addMemory(at guestAddress: UInt64, size: UInt64, readOnly: Bool = false) throws -> MemoryRegion {
        logger.info("Adding \(size) bytes at address 0x\(String(guestAddress, radix: 16))")

        precondition(guestAddress & 0xfff == 0)
        precondition(size & 0xfff == 0)
        let memRegion = try MemoryRegion(size: UInt64(size), at: guestAddress, slot: memoryRegions.count)

        var kvmRegion = memRegion.region
        guard ioctl3arg(vm_fd, _IOCTL_KVM_SET_USER_MEMORY_REGION, &kvmRegion) >= 0 else {
            throw HVError.vmMemoryError
        }
        memoryRegions.append(memRegion)
        logger.debug("Added memory")
        return memRegion
    }


    @discardableResult
    public func createVCPU(startup: @escaping (VCPU) -> (),
                           vmExitHandler: ((VirtualMachine.VCPU, VMExit) throws -> Bool)? = nil,
                           completionHandler: (() -> ())? = nil) throws -> VCPU {

        var vcpu: VCPU? = nil
        var createError: Error? = nil
        let semaphore = DispatchSemaphore(value: 0)
        let logger = self.logger

        let thread = Thread {

            let vcpu_fd = ioctl2arg(self.vm_fd, _IOCTL_KVM_CREATE_VCPU)
            guard vcpu_fd >= 0 else {
                logger.error("Cannot create vCPU")
                createError = HVError.vmSubsystemFail
                return
            }
            do {
                let _vcpu = try VCPU(vm: self, vcpu_fd: vcpu_fd)
                vcpu = _vcpu
                _vcpu.vmExitHandler = vmExitHandler
                _vcpu.completionHandler = completionHandler
                semaphore.signal()
                startup(_vcpu)
                _vcpu.runVCPU()
            } catch {
                createError = error
                return
            }
        }
        thread.start()
        semaphore.wait()
        if let error = createError { throw error }
        vcpus.append(vcpu!)
        return vcpu!
    }


    public func addPICandPIT() throws {
        // Enabling IRQCHIP stops vmexits due to HLT
        guard ioctl2arg(vm_fd, _IOCTL_KVM_CREATE_IRQCHIP) == 0 else {
            logger.error("Cant add IRQCHIP")
            throw HVError.vmSubsystemFail
        }

        var pit_config = kvm_pit_config()
        guard ioctl3arg(vm_fd, _IOCTL_KVM_CREATE_PIT2, &pit_config) == 0 else {
            logger.error("Cant create PIT")
            throw HVError.vmSubsystemFail
        }
    }
}

#endif
