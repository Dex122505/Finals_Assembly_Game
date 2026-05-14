bits 16
org 100h

; =============================================================================
; PLAYTEST.ASM - SB16 WAV player using Direct DAC (no DMA at all)
; DSP command 10h writes one sample at a time - simple and reliable
; 22050 Hz = one sample every ~45 microseconds
; Assemble: nasm -f bin PLAYTEST.ASM -o PLAYTEST.COM
; =============================================================================

SB_RESET  equ 226h
SB_READ   equ 22Ah
SB_WRITE  equ 22Ch
SB_RSTAT  equ 22Eh

WAV_HDR   equ 44

start:
    push cs
    pop ds

    ; ---- Reset DSP ----
    mov dx, SB_RESET
    mov al, 1
    out dx, al
    mov cx, 256
.dly: loop .dly
    xor al, al
    out dx, al

    mov cx, 0FFFFh
.waitaa:
    mov dx, SB_RSTAT
    in  al, dx
    test al, 80h
    jz  .nextaa
    mov dx, SB_READ
    in  al, dx
    cmp al, 0AAh
    je  .dsp_ok
.nextaa:
    loop .waitaa
    mov dx, msg_no_dsp
    mov ah, 9
    int 21h
    ret

.dsp_ok:
    ; Speaker on
    mov al, 0D1h
    call dsp_cmd

    ; Open WAV
    mov ah, 3Dh
    xor al, al
    mov dx, fname
    int 21h
    jc  .no_file
    mov [fh], ax

    ; Seek past 44-byte header
    mov ax, 4200h
    mov bx, [fh]
    xor cx, cx
    mov dx, WAV_HDR
    int 21h

    mov dx, msg_playing
    mov ah, 9
    int 21h

    ; ---- Playback loop ----
    ; Read 512 bytes at a time, output each sample via cmd 10h
.play_loop:
    ; Check keypress
    mov ah, 1
    int 16h
    jnz .stop

    ; Read 512 bytes from file
    mov ah, 3Fh
    mov bx, [fh]
    mov cx, 512
    mov dx, buf
    int 21h
    jc  .stop
    or  ax, ax
    jz  .restart        ; EOF - loop back
    mov cx, ax          ; CX = bytes read
    mov si, buf         ; SI points to buffer

    ; Output each sample via Direct DAC (cmd 10h)
.sample_loop:
    ; Wait for DSP write port ready
    mov dx, SB_WRITE
.wait_write:
    in  al, dx
    test al, 80h
    jnz .wait_write

    ; Send cmd 10h = Direct DAC output
    mov al, 10h
    out dx, al

    ; Wait again for data port ready
.wait_data:
    in  al, dx
    test al, 80h
    jnz .wait_data

    ; Send the sample byte
    mov al, [si]
    out dx, al
    inc si

    ; Delay loop to approximate 22050 Hz timing
    ; At ~50000 DOSBox cycles, need ~45us per sample
    ; roughly 2268 cycles per sample at 50MHz equiv
    push cx
    mov cx, 200
.delay: loop .delay
    pop cx

    loop .sample_loop
    jmp .play_loop

.restart:
    mov ax, 4200h
    mov bx, [fh]
    xor cx, cx
    mov dx, WAV_HDR
    int 21h
    jmp .play_loop

.stop:
    mov ah, 0
    int 16h
    mov al, 0D3h
    call dsp_cmd
    mov ah, 3Eh
    mov bx, [fh]
    int 21h
    mov dx, msg_done
    mov ah, 9
    int 21h
    ret

.no_file:
    mov dx, msg_nofile
    mov ah, 9
    int 21h
    ret

dsp_cmd:
    push ax
    push cx
    push dx
    mov ah, al
    mov cx, 0FFFFh
.w:
    mov dx, SB_WRITE
    in  al, dx
    test al, 80h
    jz  .go
    loop .w
    jmp .done
.go:
    mov al, ah
    out dx, al
.done:
    pop dx
    pop cx
    pop ax
    ret

fname:       db 'WELCOME.WAV', 0
msg_no_dsp:  db 'DSP not found!', 13, 10, '$'
msg_playing: db 'DSP OK - playing (Direct DAC), press any key to stop...', 13, 10, '$'
msg_nofile:  db 'WELCOME.WAV not found!', 13, 10, '$'
msg_done:    db 'Done.', 13, 10, '$'

fh:   dw 0
buf:  times 512 db 0