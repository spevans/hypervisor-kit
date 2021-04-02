# HypervisorKit

A Swift library providing an interface for writing X86 hypervisors on macOS (Hypervisor.framework) and Linux (KVM).

Documentation is available [here](https://spevans.github.io/hypervisor-kit).

On macOS, [Hypervisor.framework](https://developer.apple.com/documentation/hypervisor) provides a very thin wrapper
over the Intel VMX virtualisation instructions, allowing direct access to VMCS (Virtual machine control structures).
Some functionality has to be implemented by the kernel, eg setting up EPT (Extended Page Tables) to map a process's
memory into the virtual machine's address space.

Conversely, Linux KVM provides a more abstract interface as it is designed to work across multiple CPU architectures,
eg x86_64, PPC etc and uses file descriptors and ioctl calls. KVM provides its own handling for vmexits and converts
this to a smaller, simplified collection of KVMExits.

HypervisorKit aims to provide equivalent functionality on macOS to match KVM allowing cross platform virtual machines
to be written for both macOS and Linux.
