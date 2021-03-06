;                                                                                       ,   ,           ( VERSION 0.0.2
;                                                                                         $,  $,     ,   `̅̅̅̅̅̅( 0x002
;                                                                                         "ss.$ss. .s'          `̅̅̅̅̅̅
;   MMMMMMMM""M MMP"""""YMM MM"""""""`MM M""M M""MMMM""M                          ,     .ss$$$$$$$$$$s,
;   MMMMMMMM  M M' .mmm. `M MM  mmmm,  M M  M M  `MM'  M                          $. s$$$$$$$$$$$$$$`$$Ss
;   MMMMMMMM  M M  MMMMM  M M'        .M M  M MM.    .MM    .d8888b. .d8888b.     "$$$$$$$$$$$$$$$$$$o$$$       ,
;   MMMMMMMM  M M  MMMMM  M MM  MMMb. "M M  M M  .mm.  M    88'  `88 Y8ooooo.    s$$$$$$$$$$$$$$$$$$$$$$$$s,  ,s
;   M. `MMM' .M M. `MMM' .M MM  MMMMM  M M  M M  MMMM  M    88.  .88       88   s$$$$$$$$$"$$$$$$""""$$$$$$"$$$$$,
;   MM.     .MM MMb     dMM MM  MMMMM  M M  M M  MMMM  M    `88888P' `88888P'   s$$$$$$$$$$s""$$$$ssssss"$$$$$$$$"
;   MMMMMMMMMMM MMMMMMMMMMM MMMMMMMMMMMM MMMM MMMMMMMMMM                       s$$$$$$$$$$'         `"""ss"$"$s""
;                                                                               s$$$$$$$$$$,              `"""""$  .s$$s
;   ______[  Author ]______    ______[  Contact ]_______                        s$$$$$$$$$$$$s,...               `s$$'  `
;      Joris Rietveld           jorisrietveld@gmail.com                       sss$$$$$$$$$$$$$$$$$$$$####s.     .$$"$.   , s-
;                                                                             `""""$$$$$$$$$$$$$$$$$$$$#####$$$$$$"     $.$'
;   _______________[ Website & Source  ]________________                           "$$$$$$$$$$$$$$$$$$$$$####s""     .$$$|
;       https://github.com/jorisrietveld/Bootloaders                                 "$$$$$$$$$$$$$$$$$$$$$$$$##s    .$$" $
;                                                                                     $$""$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"   `
;   ___________________[ Licence ]______________________                             $$"  "$"$$$$$$$$$$$$$$$$$$$$S""""'
;             General Public licence version 3                                  ,   ,"     '  $$$$$$$$$$$$$$$$####s
;   ===============================================================================================================    ;
;                                                                                           Second Stage Bootloader    ;                                                                                                                     ;
;   Description:                                                                            ̅̅̅̅̅̅̅̅̅̅̅̅̅̅̅̅̅̅̅̅̅̅̅    ;
;   This file contains the second stage of the bootloader. Because of the memory size constrains of only 512 bytes,    ;
;   we have split the bootloader into two stages. One for setting up the minimal requirements of the system and a      ;
;   second one that can switch the CPU into protected mode and knows how to locate and start the operating system.     ;
;   This file contains the second stage that is responsible for loading the kernel. It contains both 16 bit and 32     ;
;   bit assembler code because it will switch the CPU from 16 bit real mode to 32 bit protected mode.                  ;
;                                                                                                                      ;
;   Created: 13-11-2017 21:40                                                                                          ;
;                                                                                                                      ;

org 0x500    ; Offset to address 0
bits 16     ; Assemble to 16 bit instructions (For 16 bit real-mode)
jmp main    ; Jump to the main label.

%include "libs/stdio.asm"             ; TODO MIGRATE TO intel16 lib.
%include "libs/gdt.inc"               ; TODO MIGRATE TO intel16 lib.
%include "libs/a20.inc"
%include "libs/common.inc"
%include "libs/utils.inc"
;________________________________________________________________________________________________________________________/ § data section
string msg_gdt, "Installed GDT..."
string msg_a20, "Enabled the A20 line..."
string msg_switch, "Switching the CPU into protected mode..."
;________________________________________________________________________________________________________________________/ § text section
;   Description:
;   The second stage of the bootloader, this stage executes after the bootstrap loader is finished preparing the system.
;   This section will switch the CPU from real mode to protected mode. It defines the GDT to use and enables the A20 line.
;
main:
    ; Align the segments to the new locations.
    cli                         ; clear the interrupts to prevent the CPU from tipple faulting while moving the segments.
    xor ax, ax                  ; Clear the accumulator.
    mov ds, ax                  ; Move the data segment to location 0.
    mov es, ax                  ; Move the extra segment to location 0.
    mov ax, 0x9000              ; Set the the location to place the stack segment.
    mov ss, ax                  ; Actually move the stack segment.
    mov sp, 0xFFFF              ; Set the base of the stack at 0xFFFF (grows down to 0x9000).
    sti                         ; Re-enable the interrupts.

    ; Define GDT
    call InstallGDT             ; Install the global descriptor table in the GDTR of the CPU.
    println_16 msg_gdt

    ; Enable A20
    EnableA20:
        call CheckA20                       ; Check if the A20 gate is already enabled.
        call enable_a20_bios                ; Try to enable the A20 gate with an BIOS interrupt.
        call CheckA20                       ; Check if the BIOS interrupt worked.
        call enable_a20_keyboard            ; No luck, try writing to the keyboard (PC/2) controller.
        call CheckA20                       ; Check if writing to the keyboard controller worked.
        call enable_a20_fast                ; Running out of options, try it the dangerous way that can blank the monitor.
        call CheckA20                       ; Check if writing to the System Control Port worked...

        ; In your case, switching the A20 gate might involve black magic.
        .giveUp:
            ;println_16 msg_fatal            ; Notify the user that the system is unable to boot.
            jmp stop      ; Halt the processor until this moment.

    CheckA20:
        call check_a20                      ; Check if the A20 line is enabled.
        cmp ax, 1                           ; does check_a20 return a one?
        je enter_stage3                     ; The BIOS enabled it for us, tnx!
        ret                                 ; That did'nt work return to the caller.
    println_16 msg_a20

;_________________________________________________________________________________________________________________________/ § enter_stage3
;   This section will switch the CPU into protected mode and jump the the third stage of the bootloader.
enter_stage3:
    println_16 msg_switch
    cli                         ; Disable the interrupts because they will tipple fault the CPU in protected mode.
    mov eax, cr0                ; Get the value of the control register and copy it into eax.
    or eax, 1                   ; Alter the protected mode enable bit, set it to 1 so the CPU switches to it.
    mov cr0, eax                ; Copy the altered value with protected mode enabled back into the control register effectively switching modes.
    jmp 0x08:stage3     ; Jump to label that configures the CPU for 32 bits protected mode.

;________________________________________________________________________________________________________________________/ § Stage 3
;   Description:
;   The third stage of the bootloader, this stage executes after the CPU has switch to 32 bits protected mode. It is
;   important to remember that it is not allowed to use BIOS interrupts, it will cause a tipple fault on the CPU that
;   will crash the computer.
;
bits 32 ; Configure the assembler to assemble into 32 bit machine instructions.

stage3:
    mov ax, 0x10    ; Set the starting address of the segments.
    mov ds, ax      ; Move the data segment to the address 0x10.
    mov ss, ax      ; Move the stack segment to the address 0x10.
    mov es, ax      ; Move the extra segment to the address 0x10.
    mov esp, 0x9000 ; Move the top of the stack to location 0x9000.

    call clearDisplay32
printBootMenu:
    ; Print the title of the menu page.
    mov ebx, TITLE
    call printString32

    .printBootOptions:
        ; Print the menu and its options.
        mov ebx, MENU_HR
        call printString32

        mov ebx, MENU_OPT_1
        call printString32

        mov ebx, MENU_OPT_2
        call printString32

        mov ebx, MENU_OPT_3
        call printString32

        mov ebx, MENU_OPT_4
        call printString32

        mov ebx, MENU_FOOTER
        call printString32

        mov ebx, MENU_SELECT_0
        call printString32

stop: ; Halt and catch fire...
    cli
    hlt

TITLE           times 2 db  0x0A
                db "________________________________[ Jorix OS ]____________________________________",0x0A
                times 80 db "="
                db          0x0A, 0
MENU_HR         db "                NUM    OPTIONS", 0x0A, 0
MENU_OPT_1      db "                [1]    Start JoriX OS in normal mode.", 0x0A, 0
MENU_OPT_2      db "                (2)    Start JoriX OS in recovery mode.", 0x0A, 0
MENU_OPT_3      db "                (3)    Start JoriX OS in debuggin mode.", 0x0A, 0
MENU_OPT_4      db "                (4)    Start Teteris.", 0x0A, 0
MENU_OPT_5      db "                (5)    Shutdown the pc.", 0x0A, 0
MENU_FOOTER     times 80 db "="
                db 0x0A, 0
MENU_SELECT_0   db "               Please use your arrow keys to select an option.   ", 0x0A, 0
MENU_SELECT_1   db "               Press enter to start Jorix OS in normal mode   ", 0x0A, 0
MENU_SELECT_2   db "               Press enter to start Jorix OS in recovery modes.", 0x0A, 0
MENU_SELECT_3   db "               Press enter to start Jorix OS with debugging tools.", 0x0A, 0
MENU_SELECT_4   db "               Press enter to play teteris.", 0x0A, 0
MENU_SELECT_5   db "               Press enter to shutdown your pc.", 0x0A, 0


