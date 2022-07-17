//
//  kvm_vm.swift
//  HypervisorKit
//
//  Created by Simon Evans on 01/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

#if os(Linux)

@_implementationOnly import CHypervisorKit
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

    public func setMemoryRegionProtection(gpa: PhysicalAddress, size: UInt64, readable: Bool, writable: Bool) throws {
        if let memoryRegion = self.memoryRegion(containing: gpa) {
            try memoryRegion.modifySubRegion(gpa: gpa, size: size) { (subRegion) -> MemoryRegion.SubRegion in
                logger.debug("Updating memory protection on \(subRegion.kvmRegion) to writable: \(writable)")
                if subRegion.isWritable != writable {
                    var kvmRegion = subRegion.kvmRegion
                    // TODO: Check if a memory region can be modified without a delete first. It seemed to fail without
                    // the delete but it could be version specific.
                    var deleteRegion = kvmRegion
                    deleteRegion.memory_size = 0
                    guard ioctl3arg(vm_fd, _IOCTL_KVM_SET_USER_MEMORY_REGION, &deleteRegion) >= 0 else {
                        logger.error("kvm: Error deleteing \(deleteRegion)")
                        throw VMError.kvmMemoryError
                    }
                    kvmRegion.flags = !writable ? MemoryRegion.KVM_MEM_READONLY : 0
                    guard ioctl3arg(vm_fd, _IOCTL_KVM_SET_USER_MEMORY_REGION, &kvmRegion) >= 0 else {
                        logger.error("kvm: Error updating memory protection on \(kvmRegion)")
                        throw VMError.kvmMemoryError
                    }
                    return MemoryRegion.SubRegion(kvmRegion: kvmRegion)
                } else {
                    return subRegion
                }
            }
        }
    }

    internal func _createMemory(at guestAddress: UInt64, sizes: [UInt64], readOnly: Bool) throws -> MemoryRegion {
        let nextSlot = memoryRegions.reduce(0, { $0 + $1.subRegions.count })
        let memRegion = try MemoryRegion(sizes: sizes, at: guestAddress, slot: nextSlot)

        for subRegion in memRegion.subRegions {
            var kvmRegion = subRegion.kvmRegion
            guard ioctl3arg(vm_fd, _IOCTL_KVM_SET_USER_MEMORY_REGION, &kvmRegion) >= 0 else {
                logger.error("kvm: Error setting \(kvmRegion)")
                throw VMError.kvmMemoryError
            }
        }
        return memRegion
    }

    internal func _destroyMemory(region: MemoryRegion) throws {
        for subRegion in region.subRegions {
            var kvmRegion = subRegion.kvmRegion
            kvmRegion.memory_size = 0
            guard ioctl3arg(vm_fd, _IOCTL_KVM_SET_USER_MEMORY_REGION, &kvmRegion) >= 0 else {
                logger.error("kvm: Error destroying \(kvmRegion)")
                throw VMError.kvmMemoryError
            }
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
