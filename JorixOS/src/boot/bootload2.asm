;_________________________________________________________________________________________________________________________/ kernel.asm
;   Author: Joris Rietveld  <jorisrietveld@gmail.com>
;   Created: 27-12-2017 19:22
;   
;   Description:
;   A simple 32 bit kernel.
;
org 0x100000
bits 32

jmp stage3

%include "library/stdio.asm"
%include "include/fancy_headers.asm"

stage3:
    mov ax, 0x10                ; Set the segments to 0x10
    mov ds, ax                  ; Move the data segment to 0x10
    mov ss, ax                  ; Move the stack segment to 0x10
    mov es, ax                  ; Move the extra segment to 0x10
    mov esp, 0x90000         ; The stack will start from address 0x900000 (Growing downwards)

showMenu:
    ; Print welcome message from 32 bit kernel.
    call clearDisplay32         ; Clean up the screen.
    mov ebx, msgFancyHeader         ; Get the pointer to the string as argument for the printString32 call.
    call printString32          ; Print the sting to the screen.

    ; Perform my favorite way to spend time.
    cli
    hlt

