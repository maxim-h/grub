/*
 *  GRUB  --  GRand Unified Bootloader
 *  Copyright (C) 2020 Free Software Foundation, Inc.
 *
 *  GRUB is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  GRUB is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with GRUB.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <grub/symbol.h>
#include <grub/machine/memory.h>
#include <grub/cpu/linux.h>
#include <grub/offsets.h>
#include <multiboot2.h>

/*
 * Note: GRUB is compiled with the options -mrtd and -mregparm=3.
 *       So the first three arguments are passed in %eax, %edx, and %ecx,
 *       respectively, and if a function has a fixed number of arguments
 *       and the number if greater than three, the function must return
 *       with "ret $N" where N is ((the number of arguments) - 3) * 4.
 */

    .file    "startup.S"
    .text
    .globl   start, _start
start:
efi32_start:
_start:
    cmpl    $MULTIBOOT2_BOOTLOADER_MAGIC, %eax
    jne     0f
    movl    %ebx, EXT_C(kern_multiboot_info)
0:

    /* initialize the stack */
    movl  $GRUB_MEMORY_MACHINE_PROT_STACK, %esp

    /* jump to the main body of C code */
    jmp   EXT_C(grub_main)

efi64_start:
    movl    %eax, LOCAL(mb2_eax)
    movl    %ebx, LOCAL(mb2_ebx)
    /* disable paging */
    movl    %cr0, %eax
    andl    $(~GRUB_MEMORY_CPU_CR0_PAGING_ON), %eax
    movl    %eax, %cr0
    /* Disable amd64. */
    movl    $GRUB_MEMORY_CPU_AMD64_MSR, %ecx
    rdmsr
    andl    $(~GRUB_MEMORY_CPU_AMD64_MSR_ON), %eax
    wrmsr
    /* Turn off PAE. */
    movl    %cr4, %eax
    andl    $(~GRUB_MEMORY_CPU_CR4_PAE_ON), %eax
    movl    %eax, %cr4
    /* movl imm32, %eax*/
    .byte   0x66, 0xb8
LOCAL(mb2_eax):
    .long   0
    /* mov imm32, %ebx */
    .byte   0xbb
LOCAL(mb2_ebx):
    .long   0
    jmp     start

/*
 *  Support for booting GRUB from a Multiboot2 boot loader (e.g. GRUB itself).
 */
#define MULTIBOOT2_ARCH MULTIBOOT2_ARCHITECTURE_I386
    .align  8 /* force 8-byte alignment */
mb2_hdr:
    /* magic */
    .long   MULTIBOOT2_HEADER_MAGIC
    /* architecture */
    .long   MULTIBOOT2_ARCH
    /* header length */
    .long   mb2_hdr_end - mb2_hdr
    /* checksum */
    .long   -(MULTIBOOT2_HEADER_MAGIC + MULTIBOOT2_ARCH + (mb2_hdr_end - mb2_hdr))
    .align  8
fb_tag_start:
    .short  MULTIBOOT_HEADER_TAG_FRAMEBUFFER
    .short  MULTIBOOT_HEADER_TAG_OPTIONAL
    .long   fb_tag_end - fb_tag_start
    .long   1024
    .long   768
    .long   32
fb_tag_end:
    .align  8
bs_tag_start:
    .short  MULTIBOOT_HEADER_TAG_EFI_BS
    .short  MULTIBOOT_HEADER_TAG_OPTIONAL
    .long   bs_tag_end - bs_tag_start
bs_tag_end:
    .align  8
console_tag_start:
    .short  MULTIBOOT_HEADER_TAG_CONSOLE_FLAGS
    .short  0
    .long   console_tag_end - console_tag_start
    .long   0
console_tag_end:
    .align  8
efi64_tag_start:
    .short  MULTIBOOT_HEADER_TAG_ENTRY_ADDRESS_EFI64
    .short  MULTIBOOT_HEADER_TAG_OPTIONAL
    .long efi64_tag_end - efi64_tag_start
    .long   efi64_start
efi64_tag_end:
    .align  8
efi32_tag_start:
    .short  MULTIBOOT_HEADER_TAG_ENTRY_ADDRESS_EFI32
    .short  MULTIBOOT_HEADER_TAG_OPTIONAL
    .long efi32_tag_end - efi32_tag_start
    .long   efi32_start
efi32_tag_end:
    .align  8
tag_end:
    .word   0
    .word   0
    .long   8
tag_end_end:
mb2_hdr_end:

#include "../realmode.S"
#include "../int.S"
