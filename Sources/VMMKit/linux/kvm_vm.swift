//
//  kvm_vm.swift
//  VMMKit
//
//  Created by Simon Evans on 01/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

#if os(Linux)

import CBits
import Logging


private let KVM_DEVICE = "/dev/kvm"

extension VirtualMachine {

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
                throw VMError.kvmCannotAccessSubsystem
            }
        }
        return _vmfd
    }


    internal func _createVM() throws {
        let dev_fd = try Self.vmFD()
        guard let apiVersion = VirtualMachine.apiVersion, apiVersion >= 12 else {
            close(dev_fd)
            throw VMError.kvmApiTooOld
        }
        let fd = ioctl2arg(dev_fd, _IOCTL_KVM_CREATE_VM)
        guard fd >= 0 else {
            close(dev_fd)
            throw VMError.kvmCannotCreateVM
        }
        vm_fd = fd
    }


    internal func _shutdownVM() throws {
        close(vm_fd)
        vm_fd = -1
    }


    internal func _createMemory(at guestAddress: UInt64, size: UInt64, readOnly: Bool) throws -> MemoryRegion {
        let memRegion = try MemoryRegion(size: UInt64(size), at: guestAddress, slot: memoryRegions.count)

        var kvmRegion = memRegion.kvmRegion
        guard ioctl3arg(vm_fd, _IOCTL_KVM_SET_USER_MEMORY_REGION, &kvmRegion) >= 0 else {
            throw VMError.kvmMemoryError
        }
        return memRegion
    }

    internal func _destroyMemory(region: MemoryRegion) throws {
        var kvmRegion = region.kvmRegion
        kvmRegion.memory_size = 0
        guard ioctl3arg(vm_fd, _IOCTL_KVM_SET_USER_MEMORY_REGION, &kvmRegion) >= 0 else {
            throw VMError.kvmMemoryError
        }
    }


    /// This runs inside its own thread.
    internal func _createVCPU() throws -> VCPU {
        let vcpu_fd = ioctl2arg(self.vm_fd, _IOCTL_KVM_CREATE_VCPU)
        guard vcpu_fd >= 0 else {
            throw VMError.kvmCannotCreateVcpu
        }
        return try VCPU(vm: self, vcpu_fd: vcpu_fd)
    }


    public func addPICandPIT() throws {
        // Enabling IRQCHIP stops vmexits due to HLT
        guard ioctl2arg(vm_fd, _IOCTL_KVM_CREATE_IRQCHIP) == 0 else {
            logger.error("Cant add IRQCHIP")
            throw VMError.kvmCannotAddPic
        }

        var pit_config = kvm_pit_config()
        guard ioctl3arg(vm_fd, _IOCTL_KVM_CREATE_PIT2, &pit_config) == 0 else {
            logger.error("Cant create PIT")
            throw VMError.kvmCannotAddPit
        }
    }
}

#endif
