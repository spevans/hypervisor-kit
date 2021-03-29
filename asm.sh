#!/bin/sh

nasm  -Werror -f bin -l real_mode_test.lst -o Tests/HypervisorKitTests/real_mode_test.bin Tests/HypervisorKitTests/real_mode_test.asm
