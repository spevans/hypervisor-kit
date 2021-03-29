//
//  VMError.swift
//  HypervisorKit
//
//  Created by Simon Evans on 23/03/2021.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

/// A type that enumerates errors thrown by `HypervisorKit`.
public enum VMError: Error {
    // General
    /// Failed to initialise the VM subsystem.
    case vmCreateVMFailure

    /// Errror shutting down the VM subsystem.
    case vmShutdownFailure

    /// General failure adding a vCPU to the VM.
    case vcpuCreateFailure

    /// Trying to `start()` a vCPU that is not waiting to be started. Either it is being setup or has
    /// already been started.
    case vcpuNotWaitingToStart

    /// Trying to `shutdown()` the VM but one or more vCPUs are still running.
    case vcpusStillRunning

    /// Trying to read or write the vCPU registers when the vCPU has already been shutdown.
    case vcpuHasBeenShutdown

    /// Error reading the registers from the vCPU.
    case vcpuReadRegisterFailed

    /// Physical address is not valid in any `MemoryRegion`.
    case invalidMemoryRegion

    /// Cannot allocate memory to add to a VM.
    case memoryAllocationFailure

    /// A `MemoryRegion` is too small to load binary data into it.
    case memoryRegionTooSmall

    /// A error occured adding a`MemoryRegion` to the VM.
    case addMemoryFailure

    // Linux specific errors

    /// KVM: Cannot open `/dev/kvm`
    case kvmCannotAccessSubsystem

    /// KVM: Getting API version using `KVM_GET_API_VERSION` failed or API is not version 12.
    case kvmApiTooOld

    /// KVM: Creating Virtual Machine using`KVM_CREATE_VM` failed.
    case kvmCannotCreateVM

    /// KVM: Setting `MemoryRegion` using `KVM_SET_USER_MEMORY_REGION` failed.
    case kvmMemoryError

    /// KVM: Adding virtual PIC chip using `KVM_CREATE_IRQCHIP` failed.
    case kvmCannotAddPic

    /// KVM: Adding virtual PIT chip using `KVM_CREATE_PIT2` failed.
    case kvmCannotAddPit

    /// KVM: Creating a vCPU using `KVM_CREATE_VCPU` failed.
    case kvmCannotCreateVcpu

    /// KVM: Getting vCPU `mmap` region size using `KVM_GET_VCPU_MMAP_SIZE` failed.
    case kvmCannotGetVcpuSize

    /// KVM: `mmap` of VCPU  failed.
    case kvmCannotMmapVcpu

    /// KVM: Runnign vCPU using `KVM_RUN` failed.
    case kvmRunError

    /// KVM: Queuing IRQ using `KVM_INTERRUPT` returned `EEXIST`. IRQ has already been queued.
    case irqAlreadyQueued

    /// KVM: Queuing IRQ using `KVM_INTERRUPT` returned `EINVAL`. IRQ number is invalid.
    case irqNumberInvalid

    /// KVM: Queuing IRQ using `KVM_INTERRUPT` returned `ENXIO`. IRQ queuing is handled by the KVM PIC.
    case irqAlreadyHandledByKernelPIC

    /// KVM: Reading vCPU registers using`KVM_GET_REGS` failed.
    case kvmGetRegisters

    /// KVM: Writing vCPU registers using`KVM_SET_REGS` failed.
    case kvmSetRegisters

    /// KVM: Reading vCPU special registers using`KVM_GET_SREGS` failed.
    case kvmGetSpecialRegisters

    /// KVM: Writing vCPU special registers using`KVM_SET_SREGS` failed.
    case kvmSetSpecialRegisters

    // Hypervisor.framework (macOS) specific
    case hvError
    case hvBusy
    case hvBadArgument
    case hvNoResources
    case hvNoDevice
    case hvDenied
    case hvUnsupported
    case hvUnknownError(UInt32)
}
