bits 16
org 100h

; =============================================================================
; VIEWREC.COM - reads NAMES.TXT, prints single and two-player records
; File format: one line per record -> MODE,PLAYER1,PLAYER2<CR><LF>
; =============================================================================

BUF_SIZE equ 4096

start:
    push cs
    pop  ds

    ; --- open NAMES.TXT ---
    mov  ah, 3Dh
    mov  al, 0
    mov  dx, file_names
    int  21h
    jc   err_open
    mov  [fh], ax

    ; --- read whole file into buf ---
    mov  bx, [fh]
    mov  ah, 3Fh
    mov  cx, BUF_SIZE
    mov  dx, buf
    int  21h
    jc   err_open
    mov  [buf_len], ax

    mov  ah, 3Eh
    mov  bx, [fh]
    int  21h

    ; null-terminate
    mov  bx, [buf_len]
    mov  byte [buf + bx], 0

    cmp  word [buf_len], 0
    je   err_empty

    ; === SINGLE PLAYER SECTION ===
    mov  dx, hdr_sp
    call pstr

    mov  word [count], 0
    mov  word [pos], 0          ; pos = index into buf

.sp_loop:
    call next_line              ; fills: lmode, lp1, lp2; returns CF=1 at EOF
    jc   .sp_done
    cmp  byte [lmode], '1'
    jne  .sp_loop

    inc  word [count]
    mov  ax, [count]
    call pnum3                  ; print 3-digit number
    mov  dl, ' '
    call pch
    mov  dl, ' '
    call pch
    mov  dx, lp1
    call pstr
    ; pad to column and show score
    mov  dl, ' '
    call pch
    call pch
    mov  dx, lscore
    call pstr
    call pcrlf
    jmp  .sp_loop

.sp_done:
    cmp  word [count], 0
    jne  .sp_has
    mov  dx, msg_none
    call pstr
.sp_has:

    ; === TWO PLAYER SECTION ===
    call pcrlf
    mov  dx, hdr_tp
    call pstr

    mov  word [count], 0
    mov  word [pos], 0          ; rewind to start of buf

.tp_loop:
    call next_line
    jc   .tp_done
    cmp  byte [lmode], '2'
    jne  .tp_loop

    inc  word [count]
    mov  ax, [count]
    call pnum3
    mov  dl, ' '
    call pch
    mov  dl, ' '
    call pch
    mov  dx, lp1
    call pstr
    mov  dx, sep_vs
    call pstr
    mov  dx, lp2
    call pstr
    mov  dl, ' '
    call pch
    call pch
    mov  dx, lscore
    call pstr
    call pcrlf
    jmp  .tp_loop

.tp_done:
    cmp  word [count], 0
    jne  .tp_has
    mov  dx, msg_none
    call pstr
.tp_has:

    call pcrlf
    jmp  done

err_open:
    mov  dx, msg_err
    call pstr
    jmp  done

err_empty:
    mov  dx, msg_empty
    call pstr

done:
    mov  ah, 4Ch
    xor  al, al
    int  21h

; =============================================================================
; next_line
;   reads one line from buf starting at [pos]
;   fills lmode (1 byte), lp1 (name buf), lp2 (name buf)
;   advances [pos] past the line
;   returns CF=1 if at end of buffer (no more lines)
; =============================================================================
next_line:
    push ax
    push bx
    push si
    push di

    ; check if at end
    mov  bx, [pos]
    cmp  bx, [buf_len]
    jae  .nl_eof
    cmp  byte [buf + bx], 0
    je   .nl_eof

    ; read mode char
    mov  al, [buf + bx]
    mov  [lmode], al
    inc  bx                     ; skip mode

    ; skip comma after mode
    cmp  byte [buf + bx], ','
    jne  .nl_skip_p1            ; malformed, skip anyway
    inc  bx

.nl_skip_p1:
    ; copy player1 name into lp1 until ',' or CR or LF or NUL
    mov  di, lp1
    mov  cx, 32
.nl_p1:
    cmp  bx, [buf_len]
    jae  .nl_p1_done
    mov  al, [buf + bx]
    or   al, al
    jz   .nl_p1_done
    cmp  al, ','
    je   .nl_p1_done
    cmp  al, 13
    je   .nl_p1_done
    cmp  al, 10
    je   .nl_p1_done
    mov  [di], al
    inc  di
    inc  bx
    loop .nl_p1
.nl_p1_done:
    mov  byte [di], 0           ; null-terminate lp1

    ; skip comma between names
    cmp  bx, [buf_len]
    jae  .nl_skip_p2
    cmp  byte [buf + bx], ','
    jne  .nl_skip_p2
    inc  bx

.nl_skip_p2:
    ; copy player2 name into lp2 until CR or LF or NUL
    mov  di, lp2
    mov  cx, 32
.nl_p2:
    cmp  bx, [buf_len]
    jae  .nl_p2_done
    mov  al, [buf + bx]
    or   al, al
    jz   .nl_p2_done
    cmp  al, 13
    je   .nl_p2_done
    cmp  al, 10
    je   .nl_p2_done
    mov  [di], al
    inc  di
    inc  bx
    loop .nl_p2
.nl_p2_done:
    mov  byte [di], 0           ; null-terminate lp2

    ; copy score field into lscore
    cmp  bx, [buf_len]
    jae  .nl_no_score
    cmp  byte [buf + bx], ','
    jne  .nl_no_score
    inc  bx                     ; skip comma

    mov  di, lscore
    mov  cx, 8
.nl_sc:
    cmp  bx, [buf_len]
    jae  .nl_sc_done
    mov  al, [buf + bx]
    or   al, al
    jz   .nl_sc_done
    cmp  al, 13
    je   .nl_sc_done
    cmp  al, 10
    je   .nl_sc_done
    mov  [di], al
    inc  di
    inc  bx
    loop .nl_sc
.nl_sc_done:
    mov  byte [di], 0
    jmp  .nl_skip_crlf

.nl_no_score:
    mov  byte [lscore], 0       ; no score field

.nl_skip_crlf:
    ; skip CR LF
    cmp  bx, [buf_len]
    jae  .nl_done
    cmp  byte [buf + bx], 13
    jne  .nl_chklf
    inc  bx
.nl_chklf:
    cmp  bx, [buf_len]
    jae  .nl_done
    cmp  byte [buf + bx], 10
    jne  .nl_done
    inc  bx

.nl_done:
    mov  [pos], bx
    clc
    jmp  .nl_ret

.nl_eof:
    stc

.nl_ret:
    pop  di
    pop  si
    pop  bx
    pop  ax
    ret

; =============================================================================
; pstr  - print null-terminated string at DX
; =============================================================================
pstr:
    push ax
    push bx
    push si
    mov  si, dx
.ps:
    mov  al, [si]
    or   al, al
    jz   .ps_done
    mov  ah, 02h
    mov  dl, al
    int  21h
    inc  si
    jmp  .ps
.ps_done:
    pop  si
    pop  bx
    pop  ax
    ret

; =============================================================================
; pch - print single char in DL
; =============================================================================
pch:
    push ax
    mov  ah, 02h
    int  21h
    pop  ax
    ret

; =============================================================================
; pcrlf - print CR LF
; =============================================================================
pcrlf:
    push ax
    push dx
    mov  ah, 02h
    mov  dl, 13
    int  21h
    mov  dl, 10
    int  21h
    pop  dx
    pop  ax
    ret

; =============================================================================
; pnum3 - print AX as 3-digit right-aligned number (e.g. 001, 012, 123)
; =============================================================================
pnum3:
    push ax
    push bx
    push cx
    push dx
    mov  bx, 10
    ; build digits into tmp (right to left)
    xor  cx, cx
    mov  di, tmp + 2
.pn_div:
    xor  dx, dx
    div  bx
    add  dl, '0'
    mov  [di], dl
    dec  di
    inc  cx
    cmp  cx, 3
    jl   .pn_div
    ; print 3 chars
    mov  si, tmp
    mov  cx, 3
.pn_prn:
    mov  dl, [si]
    mov  ah, 02h
    int  21h
    inc  si
    loop .pn_prn
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; =============================================================================
; DATA
; =============================================================================
file_names: db 'NAMES.TXT', 0

hdr_sp:
    db '========================================', 13, 10
    db '  SINGLE PLAYER RECORDS                 ', 13, 10
    db '  #    NAME                     SCORE   ', 13, 10
    db '----------------------------------------', 13, 10, 0

hdr_tp:
    db '========================================', 13, 10
    db '  TWO PLAYER RECORDS                    ', 13, 10
    db '  #    PLAYER 1    VS  PLAYER 2   SCORE ', 13, 10
    db '----------------------------------------', 13, 10, 0

sep_vs:     db '  vs  ', 0
msg_none:   db '  (no records)', 13, 10, 0
msg_err:    db 'ERROR: Cannot open NAMES.TXT', 13, 10, 0
msg_empty:  db 'NAMES.TXT is empty.', 13, 10, 0

fh:         dw 0
buf_len:    dw 0
pos:        dw 0
count:      dw 0
tmp:        db '000', 0

lmode:      db 0
lp1:        times 33 db 0
lp2:        times 33 db 0
lscore:     times 8  db 0

buf:        times BUF_SIZE+1 db 0