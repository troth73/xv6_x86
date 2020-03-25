; Start the first CPU: switch to 32-bit protected mode, jump into C.
; The BIOS loads this code from the first sector of the hard disk into
; memory at physical address 0x7c00 and starts executing in real mode
; with %cs=0 %ip=7c00.

%define EARLY_STACK_ADDRESS 0x2000

[BITS 16]

GLOBAL start
start:
  cli                         ; BIOS enabled interrupts; disable

; Physical address line A20 is tied to zero so that the first PCs 
; with 2 MB would run software that assumed 1 MB.  Undo that.
enable_a20.1:
  in    al,0x64             ; wait until 8042 is ready
  test  al,0x02
  jnz   enable_a20.1
  mov   al,0d1h             ; command write
  out   0x64,al
enable_a20.2:
  in    al,0x64             ; wait until 8042 is ready
  test  al,0x02
  jnz   enable_a20.2
  mov   al,0xdf             ; enable a20
  out   0x60,al
enable_a20.3:
  in    al,0x64             ; wait until 8042 is ready
  test  al,0x02
  jnz   enable_a20.3

; Switch from real to protected mode.  Use a bootstrap GDT that makes
; virtual addresses map directly to physical addresses so that the
; effective memory map doesn't change during the transition.
  lgdt  [gdt_desc]
	mov   eax,cr0
	or    eax,0x0001
	mov   cr0,eax

; Complete the transition to 32-bit protected mode by using a long jmp
; to reload %cs and %eip.  The segment descriptors are set up with no
; translation, so that the mapping is still the identity mapping.
  jmp     CODE_SEG:start32

[BITS 32]

start32:
  mov   ax,DATA_SEG
  mov   ds,ax
  mov   es,ax
  mov   ss,ax

  xor   ax,ax                 
  mov   fs,ax
  mov   gs,ax

; Set up the stack pointer and call into C.
  mov   esp, EARLY_STACK_ADDRESS

  EXTERN bootmain
  call  bootmain 
halt_loop:
  hlt
  jmp   halt_loop

; Bootstrap GDT
ALIGN 4
gdt_start:
gdt_null:
    dd 0x0
    dd 0x0
gdt_code:
    dw 0xffff
    dw 0x0
    db 0x0
    db 10011010b
    db 11001111b
    db 0x0
gdt_data:
    dw 0xffff
    dw 0x0
    db 0x0
    db 10010010b
    db 11001111b
    db 0x0
gdt_end:
gdt_desc:
    dw gdt_end - gdt_start
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start
