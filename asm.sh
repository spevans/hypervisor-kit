#!/bin/sh

nasm  -Werror -f bin -l real_mode_test.lst -o real_mode_test.bin real_mode_test.asm
