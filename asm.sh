#!/bin/sh

nasm  -Werror -f bin -l real_mode_test.lst -o Tests/VMMKitTests/real_mode_test.bin Tests/VMMKitTests/real_mode_test.asm
