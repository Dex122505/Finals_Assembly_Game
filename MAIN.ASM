bits 16
org 100h

; =============================================================================
; CONSTANTS  (screen pixel coords; BMP row-0 = top of screen as code writes it)
; =============================================================================

L1_BOX_CLR  equ 291          
L1_BOX_H    equ 33           
L1_BOX_X    equ 174          
L1_BOX_W    equ 292          
L1_FILL     equ 16           
L1_TEXT_X   equ 179          
L1_TEXT_Y   equ 303          

L2_P1_BOX_CLR  equ 288          
L2_P1_BOX_H    equ 30           
L2_P1_BOX_X    equ 136          
L2_P1_BOX_W    equ 169          
L2_P1_FILL     equ 19           
L2_P1_TEXT_X   equ 141          
L2_P1_TEXT_Y   equ 299          

L2_P2_BOX_CLR  equ 288
L2_P2_BOX_H    equ 30
L2_P2_BOX_X    equ 336          
L2_P2_BOX_W    equ 169          
L2_P2_FILL     equ 15           
L2_P2_TEXT_X   equ 341          
L2_P2_TEXT_Y   equ 299

TEXT_COLOR  equ 241           
MAX_NAME    equ 32

; =============================================================================
section .text
start:
    push cs
    pop ds
    call setup_sound
    mov byte [post_game_flag], 0 ; Reset post-game flag on home screen
    call set_vesa_640x480
    push cs
    pop ds
    mov dx, file_welcome
    call load_bmp_640x480
    call play_welcome            ; Start WELCOME music

wait_welcome:
    mov ah, 01h
    int 16h
    jz  wait_welcome
    mov ah, 00h
    int 16h
    cmp al, 'P'
    je  show_gamemode
    cmp al, 'p'
    je  show_gamemode
    cmp al, 'L'
    je  show_leaderboard
    cmp al, 'l'
    je  show_leaderboard
    cmp al, 27
    je  exit_program
    jmp wait_welcome

; -----------------------------------------------------------------------------
show_gamemode:
    push cs
    pop ds
    call play_welcome
    mov dx, file_gamemode
    call load_bmp_640x480

wait_gamemode:
    mov ah, 00h
    int 16h
    cmp al, '1'
    je  show_login1
    cmp al, '2'
    je  show_login2
    cmp al, 27
    je  start
    jmp wait_gamemode

; =============================================================================
; LOGIN 1  -  single player name entry
; =============================================================================
show_login1:
    push cs
    pop ds
    mov dx, file_login1
    call load_bmp_640x480

    push cs
    pop es
    mov di, player1_name
    mov cx, MAX_NAME+1
    xor al, al
    rep stosb
    mov byte [p1_len], 0

wait_login1:
    mov ah, 00h
    int 16h                   

    cmp al, 27
    je  show_gamemode
    cmp al, 13
    je  login1_done

    cmp al, 8
    je  login1_bs
    cmp ah, 0Eh
    je  login1_bs

    cmp al, 32
    jb  wait_login1
    cmp byte [p1_len], MAX_NAME
    jae wait_login1

    cmp al, 'a'
    jb  .l1_store
    cmp al, 'z'
    ja  .l1_store
    sub al, 32              
.l1_store:
    mov bl, [p1_len]
    xor bh, bh
    mov [player1_name + bx], al
    inc byte [p1_len]
    call redraw_login1
    jmp wait_login1

login1_bs:
    cmp byte [p1_len], 0
    je  wait_login1
    dec byte [p1_len]
    mov bl, [p1_len]
    xor bh, bh
    mov byte [player1_name + bx], 0
    call redraw_login1
    jmp wait_login1

login1_done:
    cmp byte [p1_len], 0     
    je  wait_login1
    mov byte [game_mode], 1  
    call save_names          
    jmp show_difficulty

redraw_login1:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov dx, L1_BOX_CLR
    mov cx, L1_BOX_H
.cl1:
    push cx
    push dx
    mov bx, L1_BOX_X
    mov cx, L1_BOX_W
    mov al, L1_FILL
    call fill_hline
    pop dx
    pop cx
    inc dx
    loop .cl1

    mov si, player1_name
    mov bx, L1_TEXT_X
    mov dx, L1_TEXT_Y
.dr1:
    mov al, [si]
    or  al, al
    jz  .dr1_done
    call draw_char      
    inc si
    jmp .dr1
.dr1_done:

    mov al, TEXT_COLOR
    mov cx, 2
.cur1_col:
    push cx
    mov di, L1_TEXT_Y
    mov cx, 8
.cur1_px:
    call plot_pixel     
    inc di
    loop .cur1_px
    inc bx
    pop cx
    loop .cur1_col

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; LOGIN 2  -  two-player name entry
; =============================================================================
show_login2:
    push cs
    pop ds
    mov dx, file_login2
    call load_bmp_640x480

    mov ax, 0000h
    int 33h                 
    mov ax, 0007h           
    mov cx, 0
    mov dx, 639
    int 33h
    mov ax, 0008h           
    mov cx, 0
    mov dx, 479
    int 33h

    push cs
    pop es
    mov di, player1_name
    mov cx, MAX_NAME+1
    xor al, al
    rep stosb
    mov di, player2_name
    mov cx, MAX_NAME+1
    xor al, al
    rep stosb
    mov byte [p1_len], 0
    mov byte [p2_len], 0
    mov byte [active_field], 0

wait_login2:
    mov ax, 0003h
    int 33h
    test bx, 1              
    jz  .no_click

    cmp cx, 136
    jb  .no_click
    cmp cx, 304
    ja  .check_p2_click
    cmp dx, 288
    jb  .no_click
    cmp dx, 317
    ja  .no_click
    mov byte [active_field], 0
    call redraw_login2
.wait_release1:
    mov ax, 0003h
    int 33h
    test bx, 1
    jnz .wait_release1
    jmp wait_login2

.check_p2_click:
    cmp cx, 336
    jb  .no_click
    cmp cx, 504
    ja  .no_click
    cmp dx, 288
    jb  .no_click
    cmp dx, 317
    ja  .no_click
    mov byte [active_field], 1
    call redraw_login2
.wait_release2:
    mov ax, 0003h
    int 33h
    test bx, 1
    jnz .wait_release2
    jmp wait_login2

.no_click:
    mov ah, 01h
    int 16h
    jz  wait_login2         

    mov ah, 00h
    int 16h

    cmp al, 27
    je  show_gamemode
    cmp al, 13
    je  login2_enter
    cmp al, 9
    je  login2_tab
    cmp al, 8
    je  login2_bs2
    cmp ah, 0Eh
    je  login2_bs2

    cmp al, 32
    jb  wait_login2

    cmp al, 'a'
    jb  .l2_store
    cmp al, 'z'
    ja  .l2_store
    sub al, 32
.l2_store:
    cmp byte [active_field], 0
    je  login2_add_p1

    cmp byte [p2_len], MAX_NAME
    jae wait_login2
    mov bl, [p2_len]
    xor bh, bh
    mov [player2_name + bx], al
    inc byte [p2_len]
    call redraw_login2
    jmp wait_login2

login2_add_p1:
    cmp byte [p1_len], MAX_NAME
    jae wait_login2
    mov bl, [p1_len]
    xor bh, bh
    mov [player1_name + bx], al
    inc byte [p1_len]
    call redraw_login2
    jmp wait_login2

login2_bs2:
    cmp byte [active_field], 0
    jne login2_bs2_p2
    cmp byte [p1_len], 0
    je  wait_login2
    dec byte [p1_len]
    mov bl, [p1_len]
    xor bh, bh
    mov byte [player1_name + bx], 0
    call redraw_login2
    jmp wait_login2
login2_bs2_p2:
    cmp byte [p2_len], 0
    je  wait_login2
    dec byte [p2_len]
    mov bl, [p2_len]
    xor bh, bh
    mov byte [player2_name + bx], 0
    call redraw_login2
    jmp wait_login2

login2_tab:
    xor byte [active_field], 1
    call redraw_login2
    jmp wait_login2

login2_enter:
    cmp byte [active_field], 0
    jne login2_enter_p2
    cmp byte [p1_len], 0
    je  wait_login2
    mov byte [active_field], 1
    call redraw_login2
    jmp wait_login2
login2_enter_p2:
    cmp byte [p1_len], 0
    je  wait_login2
    cmp byte [p2_len], 0
    je  wait_login2
    mov byte [game_mode], 2  
    mov byte [current_player], 0  
    mov word [p1_score], 0
    mov word [p2_score], 0
    call save_names          
    jmp show_difficulty

redraw_login2:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov dx, L2_P1_BOX_CLR
    mov cx, L2_P1_BOX_H
.cl2p1:
    push cx
    push dx
    mov bx, L2_P1_BOX_X
    mov cx, L2_P1_BOX_W
    mov al, L2_P1_FILL
    call fill_hline
    pop dx
    pop cx
    inc dx
    loop .cl2p1

    mov si, player1_name
    mov bx, L2_P1_TEXT_X
    mov dx, L2_P1_TEXT_Y
.drp1:
    mov al, [si]
    or  al, al
    jz  .drp1_done
    call draw_char
    inc si
    jmp .drp1
.drp1_done:
    cmp byte [active_field], 0
    jne .no_cur_p1
    mov al, TEXT_COLOR
    mov cx, 2
.cur2p1:
    push cx
    mov di, L2_P1_TEXT_Y
    mov cx, 8
.cur2p1_px:
    call plot_pixel
    inc di
    loop .cur2p1_px
    inc bx
    pop cx
    loop .cur2p1
.no_cur_p1:

    mov dx, L2_P2_BOX_CLR
    mov cx, L2_P2_BOX_H
.cl2p2:
    push cx
    push dx
    mov bx, L2_P2_BOX_X
    mov cx, L2_P2_BOX_W
    mov al, L2_P2_FILL
    call fill_hline
    pop dx
    pop cx
    inc dx
    loop .cl2p2

    mov si, player2_name
    mov bx, L2_P2_TEXT_X
    mov dx, L2_P2_TEXT_Y
.drp2:
    mov al, [si]
    or  al, al
    jz  .drp2_done
    call draw_char
    inc si
    jmp .drp2
.drp2_done:
    cmp byte [active_field], 1
    jne .no_cur_p2
    mov al, TEXT_COLOR
    mov cx, 2
.cur2p2:
    push cx
    mov di, L2_P2_TEXT_Y
    mov cx, 8
.cur2p2_px:
    call plot_pixel
    inc di
    loop .cur2p2_px
    inc bx
    pop cx
    loop .cur2p2
.no_cur_p2:

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; DIFFICULTY SELECT
; =============================================================================
show_difficulty:
    push cs
    pop ds
    call play_welcome
    mov dx, file_letsplay
    call load_bmp_640x480

wait_difficulty:
    mov ah, 00h
    int 16h
    cmp al, '1'
    je  diff_baby
    cmp al, '2'
    je  diff_young
    cmp al, '3'
    je  diff_big
    cmp al, 27
    je  show_gamemode        
    jmp wait_difficulty

diff_baby:
    mov byte [difficulty], 1
    jmp show_howtoplay

diff_young:
    mov byte [difficulty], 2
    jmp show_howtoplay

diff_big:
    mov byte [difficulty], 3
    jmp show_howtoplay

; =============================================================================
; HOW TO PLAY
; =============================================================================
show_howtoplay:
    push cs
    pop ds
    mov dx, file_howtoplay
    call load_bmp_640x480

wait_howtoplay:
    mov ah, 00h
    int 16h
    cmp al, 27
    je  show_difficulty      
    cmp al, 13
    je  show_intro           
    jmp wait_howtoplay

; =============================================================================
; INTRO PAGE
; =============================================================================
show_intro:
    push cs
    pop ds
    mov dx, file_intro
    call load_bmp_640x480

wait_intro:
    mov ah, 00h
    int 16h
    cmp al, 27
    je  show_howtoplay       
    cmp al, 13
    je  start_game           
    jmp wait_intro

; =============================================================================
; GAME ENGINE  -  Easy mode
; =============================================================================
HEART_X1    equ 15          
HEART_GAP   equ 24          
HEART_SIZE  equ 16          
HEART_Y     equ 20          
SCORE_X     equ 490         
SCORE_Y     equ 20          
QN_X        equ 290         
QN_Y        equ 20          
HUD_CLR     equ 60          

MAX_HEARTS  equ 5
TOTAL_Q_E   equ 5           

start_game:
    push cs
    pop  ds
    call play_playing            ; Switch to PLAYING.IMF
    cmp  byte [difficulty], 2
    je   start_game_med
    cmp  byte [difficulty], 3
    je   start_game_hard

    mov  byte [cur_max_hearts], MAX_HEARTS
    mov  byte [cur_total_q],    TOTAL_Q_E
    mov  word [cur_bmp_table],  q_bmp_table
    mov  word [cur_ans_table],  q_ans_table
    mov  byte [hearts],         MAX_HEARTS
    mov  word [game_score],     0
    mov  byte [q_num],          0
    mov  byte [correct_count],  0

    cmp  byte [game_mode], 2
    jne  game_loop
    cmp  byte [current_player], 0
    je   .sg_show_p1
    push cs
    pop  ds
    mov  dx, file_2p_p2ready
    call load_bmp_640x480
    call delay_2s
    jmp  game_loop
.sg_show_p1:
    push cs
    pop  ds
    mov  dx, file_2p_p1ready
    call load_bmp_640x480
    call delay_2s

game_loop:
    push cs
    pop  ds
    cmp  byte [hearts], 0
    je   .go_gameover
    mov  al, [cur_total_q]
    cmp  byte [q_num], al
    jae  .go_finish
    jmp  .gl_load

.go_gameover:
    jmp  game_over_screen
.go_finish:
    jmp  game_finish

.gl_load:
    xor  bx, bx
    mov  bl, [q_num]
    shl  bx, 1
    mov  si, [cur_bmp_table]
    mov  dx, [si + bx]
    call load_bmp_640x480

    call set_heart_colors
    call draw_hud

wait_answer:
    mov  ah, 00h
    int  16h
    cmp  al, 27
    je   show_gamemode
    cmp  al, '1'
    je   .check1
    cmp  al, '2'
    je   .check2
    cmp  al, '3'
    je   .check3
    cmp  al, '4'
    je   .check4
    jmp  wait_answer

.check1:
    xor  bx, bx
    mov  bl, [q_num]
    mov  si, [cur_ans_table]
    mov  al, [si + bx]
    cmp  al, 1
    je   .do_correct
    jmp  .do_wrong

.check2:
    xor  bx, bx
    mov  bl, [q_num]
    mov  si, [cur_ans_table]
    mov  al, [si + bx]
    cmp  al, 2
    je   .do_correct
    jmp  .do_wrong

.check3:
    xor  bx, bx
    mov  bl, [q_num]
    mov  si, [cur_ans_table]
    mov  al, [si + bx]
    cmp  al, 3
    je   .do_correct
    jmp  .do_wrong

.check4:
    xor  bx, bx
    mov  bl, [q_num]
    mov  si, [cur_ans_table]
    mov  al, [si + bx]
    cmp  al, 4
    je   .do_correct
    jmp  .do_wrong

.do_correct:
    push cs
    pop  ds
    inc  byte [correct_count]
    add  word [game_score], 10
    inc  byte [q_num]
    call draw_hud            
    jmp  game_loop

.do_wrong:
    push cs
    pop  ds
    dec  byte [hearts]
    inc  byte [q_num]
    call draw_hud            
    jmp  game_loop

; =============================================================================
; GAME ENGINE  -  Medium mode 
; =============================================================================
MAX_HEARTS_MED  equ 5
TOTAL_Q_MED     equ 5

start_game_med:
    push cs
    pop  ds
    call play_playing            ; Switch to PLAYING.IMF
    mov  byte [cur_max_hearts], MAX_HEARTS_MED
    mov  byte [cur_total_q],    TOTAL_Q_MED
    mov  word [cur_bmp_table],  q_bmp_table_med
    mov  word [cur_ans_table],  q_ans_table_med
    mov  byte [hearts],         MAX_HEARTS_MED
    mov  word [game_score],     0
    mov  byte [q_num],          0
    mov  byte [correct_count],  0

    cmp  byte [game_mode], 2
    jne  game_loop
    cmp  byte [current_player], 0
    je   .sgm_show_p1
    push cs
    pop  ds
    mov  dx, file_2p_p2ready
    call load_bmp_640x480
    call delay_2s
    jmp  game_loop
.sgm_show_p1:
    push cs
    pop  ds
    mov  dx, file_2p_p1ready
    call load_bmp_640x480
    call delay_2s
    jmp  game_loop

; =============================================================================
; GAME ENGINE  -  Hard mode
; =============================================================================
MAX_HEARTS_HARD equ 5
TOTAL_Q_HARD    equ 5

start_game_hard:
    push cs
    pop  ds
    call play_playing            ; Switch to PLAYING.IMF
    mov  byte [cur_max_hearts], MAX_HEARTS_HARD
    mov  byte [cur_total_q],    TOTAL_Q_HARD
    mov  word [cur_bmp_table],  q_bmp_table_hard
    mov  word [cur_ans_table],  q_ans_table_hard
    mov  byte [hearts],         MAX_HEARTS_HARD
    mov  word [game_score],     0
    mov  byte [q_num],          0
    mov  byte [correct_count],  0

    cmp  byte [game_mode], 2
    jne  game_loop
    cmp  byte [current_player], 0
    je   .sgh_show_p1
    push cs
    pop  ds
    mov  dx, file_2p_p2ready
    call load_bmp_640x480
    call delay_2s
    jmp  game_loop
.sgh_show_p1:
    push cs
    pop  ds
    mov  dx, file_2p_p1ready
    call load_bmp_640x480
    call delay_2s
    jmp  game_loop

; ---------------------------------------------------------------------------
game_finish:
    push cs
    pop  ds

    cmp  byte [game_mode], 2
    jne  .gf_single

    cmp  byte [current_player], 0
    jne  .gf_p2_done

    mov  ax, [game_score]
    mov  [p1_score], ax
    mov  al, [correct_count]
    mov  [p1_correct], al
    mov  byte [current_player], 1
    jmp  start_game           

.gf_p2_done:
    mov  ax, [game_score]
    mov  [p2_score], ax
    mov  al, [correct_count]
    mov  [p2_correct], al
    call save_score_2p
    jmp  show_2p_winner

.gf_single:
    mov  al, [correct_count]
    mov  bl, 100
    mul  bl
    mov  bl, [cur_total_q]
    div  bl                  

    mov byte [post_game_flag], 1 ; Flag that we came from an active game

    cmp  al, 100
    je   .gf_perfect
    cmp  al, 60
    jae  .gf_good
    cmp  al, 30
    jae  .gf_okay
    jmp  .gf_try

.gf_perfect: mov dx, file_perfect  
    jmp .gf_show
.gf_good:    mov dx, file_goodjob  
    jmp .gf_show
.gf_okay:    mov dx, file_okay     
    jmp .gf_show
.gf_try:     mov dx, file_tryagain

.gf_show:
    call load_bmp_640x480
    call save_score
    call delay_2s
    jmp  show_leaderboard

; ---------------------------------------------------------------------------
game_over_screen:
    push cs
    pop  ds

    cmp  byte [game_mode], 2
    jne  .go_single

    cmp  byte [current_player], 0
    jne  .go_p2_done

    mov  ax, [game_score]
    mov  [p1_score], ax
    mov  al, [correct_count]
    mov  [p1_correct], al
    mov  byte [current_player], 1
    jmp  start_game           

.go_p2_done:
    mov  ax, [game_score]
    mov  [p2_score], ax
    mov  al, [correct_count]
    mov  [p2_correct], al
    call save_score_2p
    jmp  show_2p_winner

.go_single:
    mov byte [post_game_flag], 1 ; Flag that we came from an active game
    mov  dx, file_tryagain
    call load_bmp_640x480
    call save_score
    call delay_2s
    jmp  show_leaderboard

; ---------------------------------------------------------------------------
show_2p_winner:
    push cs
    pop  ds
    mov byte [post_game_flag], 1 ; Flag that we came from an active game
    mov  byte [current_player], 0

    mov  ax, [p1_score]
    mov  bx, [p2_score]
    cmp  ax, bx
    ja   .w_p1wins
    jb   .w_p2wins
    mov  dx, file_2p_draw
    jmp  .w_show
.w_p1wins:
    mov  dx, file_2p_p1wins
    jmp  .w_show
.w_p2wins:
    mov  dx, file_2p_p2wins
.w_show:
    call load_bmp_640x480

    push cs
    pop  ds
    mov  bx, 60
    mov  dx, 300
    mov  al, 'P'
    call draw_char
    mov  al, '1'
    call draw_char
    mov  al, ':'
    call draw_char
    mov  ax, [p1_score]
    call draw_num_ax

    mov  bx, 360
    mov  dx, 300
    mov  al, 'P'
    call draw_char
    mov  al, '2'
    call draw_char
    mov  al, ':'
    call draw_char
    mov  ax, [p2_score]
    call draw_num_ax

    call delay_2s
    call delay_2s

wait_2p_winner:
    mov  ah, 00h
    int  16h
    cmp  al, 27
    je   start
    cmp  al, 13
    je   show_leaderboard
    jmp  wait_2p_winner

; ---------------------------------------------------------------------------
save_score_2p:
    push ax
    push bx
    push cx
    push dx
    push si
    push ds
    push cs
    pop  ds

    mov  ax, [p1_score]
    mov  [game_score], ax
    mov  al, [p1_correct]
    mov  [correct_count], al
    call save_score

    mov  ax, [p2_score]
    mov  [game_score], ax
    mov  al, [p2_correct]
    mov  [correct_count], al
    call save_score

    pop  ds
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; ---------------------------------------------------------------------------
set_heart_colors:
    push ax
    push dx

    mov  dx, 3C8h
    mov  al, 4
    out  dx, al
    mov  dx, 3C9h
    mov  al, 63
    out  dx, al
    xor  al, al
    out  dx, al
    out  dx, al

    mov  dx, 3C8h
    mov  al, 15
    out  dx, al
    mov  dx, 3C9h
    mov  al, 38
    out  dx, al
    mov  al, 38
    out  dx, al
    mov  al, 38
    out  dx, al

    pop  dx
    pop  ax
    ret

; ---------------------------------------------------------------------------
draw_hud:
    push ax
    push bx
    push cx
    push dx
    push si
    push ds
    push cs
    pop  ds

    xor  dx, dx          
.dh_clr:
    cmp  dx, HUD_CLR
    jae  .dh_clr_done
    push dx
    mov  bx, 0           
    mov  cx, 640         
    mov  al, 0           
    call fill_hline
    pop  dx
    inc  dx
    jmp  .dh_clr
.dh_clr_done:

    xor  si, si

.dh_next_heart:
    xor  ax, ax
    mov  al, [cur_max_hearts]
    cmp  si, ax
    jae  .dh_done_hearts

    mov  cx, si
    mov  ax, HEART_GAP
    push dx
    mul  cx               
    pop  dx
    add  ax, HEART_X1     
    mov  bx, ax           

    mov  al, [hearts]     
    cmp  si, ax           
    jb   .dh_alive
    mov  al, 15           
    jmp  .dh_drawcolor
.dh_alive:
    mov  al, 4            

.dh_drawcolor:
    mov  ah, al

    mov  dx, HEART_Y
    mov  cx, 6
    mov  al, ah
    call fill_hline
    mov  dx, HEART_Y+1
    mov  cx, 6
    mov  al, ah
    call fill_hline
    mov  dx, HEART_Y+2
    mov  cx, 6
    mov  al, ah
    call fill_hline

    add  bx, 10
    mov  dx, HEART_Y
    mov  cx, 6
    mov  al, ah
    call fill_hline
    mov  dx, HEART_Y+1
    mov  cx, 6
    mov  al, ah
    call fill_hline
    mov  dx, HEART_Y+2
    mov  cx, 6
    mov  al, ah
    call fill_hline
    sub  bx, 10           

    sub  bx, 2
    mov  cx, 20
    mov  dx, HEART_Y+3
    mov  al, ah
    call fill_hline
    mov  dx, HEART_Y+4
    mov  al, ah
    call fill_hline
    mov  dx, HEART_Y+5
    mov  al, ah
    call fill_hline
    mov  dx, HEART_Y+6
    mov  al, ah
    call fill_hline

    add  bx, 4
    mov  cx, 12
    mov  dx, HEART_Y+7
    mov  al, ah
    call fill_hline
    mov  dx, HEART_Y+8
    mov  al, ah
    call fill_hline

    add  bx, 3
    mov  cx, 6
    mov  dx, HEART_Y+9
    mov  al, ah
    call fill_hline

    add  bx, 2
    mov  cx, 2
    mov  dx, HEART_Y+10
    mov  al, ah
    call fill_hline

    inc  si
    jmp  .dh_next_heart

.dh_done_hearts:

    mov  bx, SCORE_X
    mov  dx, SCORE_Y
    mov  al, 'S'
    call draw_char
    mov  al, 'C'
    call draw_char
    mov  al, ':'
    call draw_char
    mov  ax, [game_score]
    call draw_num_ax

    mov  bx, QN_X
    mov  dx, QN_Y
    mov  al, 'Q'
    call draw_char
    mov  al, ':'
    call draw_char
    mov  al, [q_num]
    inc  al               
    add  al, '0'
    call draw_char
    mov  al, '/'
    call draw_char
    mov  al, [cur_total_q]
    add  al, '0'
    call draw_char

    cmp  byte [game_mode], 2
    jne  .dh_no2p
    mov  bx, 560
    mov  dx, QN_Y
    cmp  byte [current_player], 0
    je   .dh_p1tag
    mov  al, 'P'
    call draw_char
    mov  al, '2'
    call draw_char
    jmp  .dh_no2p
.dh_p1tag:
    mov  al, 'P'
    call draw_char
    mov  al, '1'
    call draw_char
.dh_no2p:

    pop  ds
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret


draw_num_ax:
    push ax
    push cx
    push dx
    push si
    push cs
    pop  ds
    mov  si, num_buf + 5    
    mov  byte [si], 0       
    mov  cx, 0              
    cmp  ax, 0
    jne  .dna_loop
    dec  si
    mov  byte [si], '0'
    inc  cx
    jmp  .dna_print
.dna_loop:
    cmp  ax, 0
    je   .dna_print
    push bx
    mov  bx, 10
    push dx                 
    xor  dx, dx
    div  bx
    mov  cl, dl             
    pop  dx                 
    pop  bx
    dec  si
    add  cl, '0'
    mov  [si], cl
    inc  cx
    jmp  .dna_loop
.dna_print:
.dna_out:
    mov  al, [si]
    or   al, al
    jz   .dna_done
    call draw_char
    inc  si
    jmp  .dna_out
.dna_done:
    pop  si
    pop  dx
    pop  cx
    pop  ax
    ret

; ---------------------------------------------------------------------------
delay_2s:
    push ax
    push bx
    push cx
    push dx
    mov  ah, 00h
    int  1Ah
    add  dx, 37             
    adc  cx, 0
    mov  bx, dx
    mov  si, cx
.dl_wait:
    mov  ah, 00h
    int  1Ah
    cmp  cx, si
    ja   .dl_done
    jb   .dl_wait
    cmp  dx, bx
    jb   .dl_wait
.dl_done:
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; ---------------------------------------------------------------------------
save_score:
    push ax
    push bx
    push cx
    push dx
    push si
    push ds
    push cs
    pop  ds

    mov  ah, 3Dh
    mov  al, 02h             
    mov  dx, file_names
    int  21h
    jnc  .ss_seek
    mov  ah, 3Ch
    xor  cx, cx
    mov  dx, file_names
    int  21h
    jc   .ss_done
.ss_seek:
    mov  [filehandle], ax
    mov  ah, 42h
    mov  al, 02h
    mov  bx, [filehandle]
    xor  cx, cx
    xor  dx, dx
    int  21h

    mov  al, [game_mode]
    add  al, '0'
    mov  [sn_byte], al
    call .ss_wb

    mov  byte [sn_byte], ','
    call .ss_wb

    mov  si, player1_name
.ss_p1:
    mov  al, [si]
    or   al, al
    jz   .ss_p1done
    mov  [sn_byte], al
    call .ss_wb
    inc  si
    jmp  .ss_p1
.ss_p1done:

    mov  byte [sn_byte], ','
    call .ss_wb

    mov  si, player2_name
.ss_p2:
    mov  al, [si]
    or   al, al
    jz   .ss_p2done
    mov  [sn_byte], al
    call .ss_wb
    inc  si
    jmp  .ss_p2
.ss_p2done:

    mov  byte [sn_byte], ','
    call .ss_wb

    mov  al, [difficulty]
    add  al, '0'
    mov  [sn_byte], al
    call .ss_wb

    mov  byte [sn_byte], ','
    call .ss_wb

    mov  ax, [game_score]
    push cs
    pop  ds
    mov  si, num_buf + 5
    mov  byte [si], 0
    cmp  ax, 0
    jne  .ss_digits
    dec  si
    mov  byte [si], '0'
    jmp  .ss_wrnum
.ss_digits:
    push bx
    mov  bx, 10
.ss_dloop:
    cmp  ax, 0
    je   .ss_dloop_done
    xor  dx, dx
    div  bx
    dec  si
    add  dl, '0'
    mov  [si], dl
    jmp  .ss_dloop
.ss_dloop_done:
    pop  bx
.ss_wrnum:
.ss_wloop:
    mov  al, [si]
    or   al, al
    jz   .ss_wcrlf
    mov  [sn_byte], al
    call .ss_wb
    inc  si
    jmp  .ss_wloop

.ss_wcrlf:
    mov  byte [sn_byte], 13
    call .ss_wb
    mov  byte [sn_byte], 10
    call .ss_wb

    mov  ah, 3Eh
    mov  bx, [filehandle]
    int  21h

.ss_done:
    pop  ds
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

.ss_wb:
    push ax
    push cx
    push dx
    mov  bx, [filehandle]
    mov  ah, 40h
    mov  cx, 1
    mov  dx, sn_byte
    int  21h
    pop  dx
    pop  cx
    pop  ax
    ret

; =============================================================================
save_names:
    ret

; =============================================================================
; LEADERBOARD
; =============================================================================

LB_ROWS equ 5
LB_NLEN equ 10
LB_ESIZ equ 12          

LB_X0   equ 103         
LB_X1   equ 263         
LB_X2   equ 423         
LB_Y0   equ 208         
LB_YGAP equ 30          

show_leaderboard:
    push cs
    pop  ds
    
    ; Check if we came from an active game or the main menu
    cmp byte [post_game_flag], 1
    je .keep_playing_music
    call play_welcome
    jmp .music_set
.keep_playing_music:
    call play_playing
.music_set:

    mov  dx, file_leaderboard
    call load_bmp_640x480

    push ax
    push dx
    mov  dx, 3C8h
    mov  al, 241
    out  dx, al
    mov  dx, 3C9h
    mov  al, 26          
    out  dx, al
    mov  al, 15          
    out  dx, al
    mov  al, 5           
    out  dx, al
    pop  dx
    pop  ax

    push cs
    pop  ds
    push cs
    pop  es
    mov  di, lb_board
    mov  cx, 3 * LB_ROWS * LB_ESIZ
    xor  al, al
    rep  stosb
    mov  byte [lb_used+0], 0
    mov  byte [lb_used+1], 0
    mov  byte [lb_used+2], 0

    push cs
    pop  ds
    mov  ah, 3Dh
    mov  al, 00h
    mov  dx, file_names
    int  21h
    jc   .draw              

    mov  [filehandle], ax

.rdline:
    call lb_readline        
    cmp  cx, 0
    je   .closefile

    call lb_skipfield
    jc   .rdline

    push cs
    pop  ds
    mov  di, lb_tmp_name
    mov  cx, LB_NLEN
    call lb_copyfield
    jc   .rdline

    call lb_skipfield
    jc   .rdline

    mov  al, [si]
    sub  al, '0'
    cmp  al, 1
    jb   .rdline
    cmp  al, 3
    ja   .rdline
    mov  [lb_tmp_diff], al
    call lb_skipfield
    jc   .rdline

    call lb_parsenum        
    mov  [lb_tmp_score], ax

    call lb_insert

    jmp  .rdline

.closefile:
    mov  ah, 3Eh
    mov  bx, [filehandle]
    int  21h

.draw:
    push cs
    pop  ds

    mov  bx, LB_X0
    mov  si, lb_board + 0 * LB_ROWS * LB_ESIZ
    mov  al, [lb_used+0]
    call lb_drawcol

    mov  bx, LB_X1
    mov  si, lb_board + 1 * LB_ROWS * LB_ESIZ
    mov  al, [lb_used+1]
    call lb_drawcol

    mov  bx, LB_X2
    mov  si, lb_board + 2 * LB_ROWS * LB_ESIZ
    mov  al, [lb_used+2]
    call lb_drawcol

wait_leaderboard:
    mov  ah, 00h
    int  16h
    cmp  al, 27
    je   ret_home_from_lb   
    cmp  al, 13
    je   ret_home_from_lb   
    jmp  wait_leaderboard

ret_home_from_lb:
    jmp  start

; ---------------------------------------------------------------------------
lb_drawcol:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push cs
    pop  ds

    mov  [lb_col_x], bx

    xor  ah, ah
    mov  cx, ax             
    xor  di, di             

.lcol_loop:
    cmp  di, cx
    jae  .lcol_done
    cmp  di, LB_ROWS
    jae  .lcol_done

    push ax
    mov  ax, di
    push cx
    mov  cx, LB_YGAP
    mul  cx
    pop  cx
    add  ax, LB_Y0
    mov  dx, ax
    pop  ax

    mov  bx, [lb_col_x]

    push si
    add  si, 2              
    push cx
    mov  cx, LB_NLEN
.lcol_name:
    mov  al, [si]
    or   al, al
    jz   .lcol_name_done
    call draw_char
    inc  si
    dec  cx
    jnz  .lcol_name
.lcol_name_done:
    pop  cx
    pop  si                 

    mov  bx, [lb_col_x]
    add  bx, 48

    push ax
    mov  ax, [si]
    call draw_num_ax
    pop  ax

    add  si, LB_ESIZ
    inc  di
    jmp  .lcol_loop

.lcol_done:
    pop  ds
    pop  di
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; ---------------------------------------------------------------------------
lb_insert:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push cs
    pop  ds

    xor  bh, bh
    mov  bl, [lb_tmp_diff]
    dec  bl

    mov  ax, bx
    mov  cx, LB_ROWS * LB_ESIZ
    mul  cx
    add  ax, lb_board
    mov  di, ax

    xor  ch, ch
    mov  cl, [lb_used + bx]

    mov  ax, [lb_tmp_score]

    xor  dx, dx
.lbi_find:
    cmp  dx, cx
    jae  .lbi_doins         
    push ax
    push bx
    mov  bx, dx
    push cx
    mov  cx, LB_ESIZ
    xchg ax, bx
    mul  cx                 
    xchg ax, bx             
    pop  cx
    add  bx, di             
    cmp  ax, [bx]           
    pop  bx
    pop  ax
    ja   .lbi_doins         
    inc  dx
    jmp  .lbi_find

.lbi_doins:
    cmp  dx, LB_ROWS
    jae  .lbi_done

    mov  si, cx             
    cmp  si, LB_ROWS
    jb   .lbi_shok
    mov  si, LB_ROWS - 1   
.lbi_shok:
.lbi_shloop:
    cmp  si, dx
    jbe  .lbi_shend
    push ax
    push bx
    push cx
    mov  ax, si
    dec  ax
    mov  cx, LB_ESIZ
    mul  cx
    add  ax, di
    push ax                 
    mov  ax, si
    mul  cx
    add  ax, di
    mov  bx, ax             
    pop  ax                 
    push si
    mov  si, ax
    mov  cx, LB_ESIZ
.lbi_cp:
    mov  al, [si]
    mov  [bx], al
    inc  si
    inc  bx
    loop .lbi_cp
    pop  si
    pop  cx
    pop  bx
    pop  ax
    dec  si
    jmp  .lbi_shloop

.lbi_shend:
    push ax
    push bx
    push cx
    mov  ax, dx
    mov  cx, LB_ESIZ
    mul  cx
    add  ax, di
    mov  bx, ax             

    mov  ax, [lb_tmp_score]
    mov  [bx], ax
    add  bx, 2

    push cs
    pop  ds
    mov  si, lb_tmp_name
    mov  cx, LB_NLEN
.lbi_wn:
    mov  al, [si]
    mov  [bx], al
    inc  si
    inc  bx
    loop .lbi_wn

    pop  cx
    pop  bx
    pop  ax

    push cs
    pop  ds
    xor  bh, bh
    mov  bl, [lb_tmp_diff]
    dec  bl
    cmp  byte [lb_used + bx], LB_ROWS
    jae  .lbi_done
    inc  byte [lb_used + bx]

.lbi_done:
    pop  ds
    pop  di
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; ---------------------------------------------------------------------------
lb_readline:
    push ds
    push cs
    pop  ds
    mov  di, lb_rbuf
    xor  cx, cx
.lbrl:
    push cx
    push di
    mov  ah, 3Fh
    mov  bx, [filehandle]
    mov  dx, di
    mov  cx, 1
    int  21h
    pop  di
    pop  cx
    or   ax, ax
    jz   .lbrl_eof
    mov  al, [di]
    cmp  al, 10
    je   .lbrl_done
    cmp  al, 13
    je   .lbrl
    inc  di
    inc  cx
    cmp  cx, 126
    jb   .lbrl
.lbrl_done:
    mov  byte [di], 0
    mov  si, lb_rbuf
    pop  ds
    ret
.lbrl_eof:
    mov  byte [di], 0
    mov  si, lb_rbuf
    pop  ds
    ret

; ---------------------------------------------------------------------------
lb_skipfield:
.lbsf:
    mov  al, [si]
    or   al, al
    jz   .lbsf_err
    inc  si
    cmp  al, ','
    jne  .lbsf
    clc
    ret
.lbsf_err:
    stc
    ret

; ---------------------------------------------------------------------------
lb_copyfield:
    push cx
.lbcf:
    mov  al, [si]
    or   al, al
    jz   .lbcf_eol
    inc  si
    cmp  al, ','
    je   .lbcf_done
    jcxz .lbcf             
    mov  [di], al
    inc  di
    dec  cx
    jmp  .lbcf
.lbcf_done:
    mov  byte [di], 0
    pop  cx
    clc
    ret
.lbcf_eol:
    mov  byte [di], 0
    pop  cx
    stc
    ret

; ---------------------------------------------------------------------------
lb_parsenum:
    xor  ax, ax
.lbpn:
    mov  cl, [si]
    cmp  cl, '0'
    jb   .lbpn_done
    cmp  cl, '9'
    ja   .lbpn_done
    sub  cl, '0'
    push cx
    mov  cx, 10
    mul  cx
    pop  cx
    xor  ch, ch
    add  ax, cx
    inc  si
    jmp  .lbpn
.lbpn_done:
    ret

exit_program:
    call shutdown_sound
    mov ax, 0003h
    int 10h
    ret

; =============================================================================
; GRAPHICS PRIMITIVES
; =============================================================================
plot_pixel:
    push ax
    push bx
    push cx
    push dx
    push si
    push es

    mov cl, al              

    mov ax, di              
    mov si, 640
    mul si                  
    add ax, bx              
    adc dx, 0               

    push ax                 
    push dx
    push bx
    mov si, dx              
    mov ax, 4F05h
    xor bx, bx              
    mov dx, si              
    int 10h
    pop bx
    pop dx
    pop ax                  

    mov bx, ax              
    mov ax, 0A000h
    mov es, ax
    mov al, cl              
    mov [es:bx], al

    pop es
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

fill_hline:
    push bx
    push cx
    push di
    mov di, dx
.fhl:
    call plot_pixel
    inc bx
    loop .fhl
    pop di
    pop cx
    pop bx
    ret

; =============================================================================
; FONT ENGINE
; =============================================================================
draw_char:
    push ax
    push cx
    push si
    push di

    cmp al, 32
    jb  .dc_skip
    cmp al, 127
    ja  .dc_skip

    sub al, 32              
    xor ah, ah
    mov si, ax
    shl si, 3               
    add si, font_data

    mov di, dx              
    mov cx, 8               
.dc_row:
    push cx
    push bx
    mov ah, [si]            
    mov cx, 8               
.dc_col:
    test ah, 80h
    jz  .dc_no_px
    mov al, TEXT_COLOR
    call plot_pixel
.dc_no_px:
    inc bx
    shl ah, 1
    loop .dc_col
    pop bx
    pop cx
    inc si
    inc di
    loop .dc_row

.dc_skip:
    add bx, 9              
    pop di
    pop si
    pop cx
    pop ax
    ret

; =============================================================================
; VESA SETUP
; =============================================================================
set_vesa_640x480:
    mov ax, 4F02h
    mov bx, 0101h
    int 10h
    cmp ax, 004Fh
    je  .done
    mov ax, 0003h
    int 10h
.done:
    ret

; =============================================================================
; BMP LOADER 
; =============================================================================
load_bmp_640x480:
    mov ax, 3D00h
    int 21h
    jc  .fail
    mov [filehandle], ax

    mov bx, [filehandle]
    mov ah, 3Fh
    mov cx, 54
    mov dx, bmp_header
    int 21h

    mov bx, [filehandle]
    mov ah, 3Fh
    mov cx, 1024
    mov dx, bmp_palette
    int 21h

    mov dx, 03C8h
    xor al, al
    out dx, al
    inc dx                  
    mov si, bmp_palette
    mov cx, 256
.pal_loop:
    mov al, [si+2]          
    shr al, 2
    out dx, al
    mov al, [si+1]          
    shr al, 2
    out dx, al
    mov al, [si+0]          
    shr al, 2
    out dx, al
    add si, 4
    loop .pal_loop

    xor si, si
.full_banks:
    cmp si, 4
    je  .last_bank

    mov dx, si
    call set_vesa_bank

    mov bx, [filehandle]
    mov cx, 32768
    xor dx, dx
    call read_chunk_to_vram

    mov bx, [filehandle]
    mov cx, 32768
    mov dx, 8000h
    call read_chunk_to_vram

    inc si
    jmp .full_banks

.last_bank:
    mov dx, si
    call set_vesa_bank

    mov bx, [filehandle]
    mov cx, 32768
    xor dx, dx
    call read_chunk_to_vram

    mov bx, [filehandle]
    mov cx, 12288
    mov dx, 8000h
    call read_chunk_to_vram

    mov ax, 3E00h
    mov bx, [filehandle]
    int 21h
.fail:
    ret

set_vesa_bank:
    push ax
    push bx
    mov ax, 4F05h
    xor bx, bx              
    int 10h
    pop bx
    pop ax
    ret

read_chunk_to_vram:
    push si
    push ds
    mov ax, 0A000h
    mov ds, ax
    mov ah, 3Fh
    int 21h
    pop ds
    pop si
    ret

; =============================================================================
; BACKGROUND IMF AUDIO ENGINE
; =============================================================================
setup_sound:
    mov ax, 351Ch
    int 21h
    mov [old_int1C_off], bx
    mov [old_int1C_seg], es
    push ds
    push cs
    pop ds
    mov ax, 251Ch
    mov dx, imf_timer_tick
    int 21h
    pop ds
    ret

shutdown_sound:
    call stop_music
    push ds
    mov ax, 251Ch
    mov dx, [old_int1C_off]
    mov ds, [old_int1C_seg]
    int 21h
    pop ds
    ret

stop_music:
    cmp word [imf_handle], 0
    je .silence
    mov ah, 3Eh
    mov bx, [imf_handle]
    int 21h
    mov word [imf_handle], 0
.silence:
    mov byte [current_track], 0
    mov word [imf_delay], 0
    mov cx, 0F5h
    mov bl, 0
.clear_loop:
    mov al, bl
    mov ah, 0
    call write_opl2
    inc bl
    loop .clear_loop
    ret

write_opl2:
    push ax
    push cx
    push dx
    mov dx, 388h
    out dx, al
    mov cx, 6             
.wait1: in al, dx
    loop .wait1
    mov dx, 389h
    mov al, ah
    out dx, al
    mov dx, 388h
    mov cx, 35            
.wait2: in al, dx
    loop .wait2
    pop dx
    pop cx
    pop ax
    ret

play_welcome:
    cmp byte [current_track], 1
    je .done
    call stop_music
    mov byte [current_track], 1
    mov dx, imf_file_welcome
    call load_imf
.done: ret

play_playing:
    cmp byte [current_track], 2
    je .done
    call stop_music
    mov byte [current_track], 2
    mov dx, imf_file_playing
    call load_imf
.done: ret

load_imf:
    mov ax, 3D00h         
    int 21h
    jc .error
    mov [imf_handle], ax
    mov word [imf_delay], 0
.error: ret

imf_timer_tick:
    pushf                 
    call far [cs:old_int1C_off] 
    
    push ax
    push bx
    push cx
    push dx
    push ds
    push cs
    pop ds

    cmp word [imf_handle], 0
    je .tick_done
    cmp word [imf_delay], 0
    ja .dec_delay

.read_loop:
    mov ah, 3Fh
    mov bx, [imf_handle]
    mov cx, 4
    mov dx, imf_buffer
    int 21h
    cmp ax, 4
    jne .loop_track       

    mov al, [imf_buffer+0] 
    mov ah, [imf_buffer+1] 
    call write_opl2

    mov ax, word [imf_buffer+2]
    mov [imf_delay], ax

    cmp word [imf_delay], 0
    je .read_loop
    jmp .tick_done

.loop_track:
    mov ax, 4200h         
    mov bx, [imf_handle]
    xor cx, cx
    xor dx, dx
    int 21h
    jmp .read_loop

.dec_delay:
    cmp byte [current_track], 2  ; Is PLAYING.IMF active?
    je  .speed_up

    ; --- Normal Speed (For WELCOME.IMF) ---
    dec word [imf_delay]
    jmp .tick_done

.speed_up:
    ; --- Fast Speed (For PLAYING.IMF) ---
    sub word [imf_delay], 38     ; Adjust this number if it's too fast/slow (e.g. 4 for 70Hz)
    jbe .force_read              ; If delay <= 0, immediately trigger next read
    jmp .tick_done

.force_read:
    mov word [imf_delay], 0
    jmp .read_loop

.tick_done:
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    iret

; =============================================================================
; DATA
; =============================================================================
file_welcome:     db 'WELCOME.BMP', 0
file_gamemode:    db 'GAMEMOD.BMP', 0
file_2p_p1ready:  db '2P-PLAYER1.BMP', 0
file_2p_p2ready:  db '2P-PLAYER2.BMP', 0
file_2p_p1wins:   db '2P-P1WIN.BMP', 0
file_2p_p2wins:   db '2P-P2WIN.BMP', 0
file_2p_draw:     db '2P-DRAW.BMP', 0
file_leaderboard: db 'LEADERBD.BMP', 0
file_login1:      db 'LOGIN1.BMP', 0
file_login2:      db 'LOGIN2.BMP', 0
file_letsplay:    db 'LETSPLY.BMP', 0
file_howtoplay:   db 'HWTP.BMP', 0
file_intro:       db 'INTRO.BMP', 0
file_names:       db 'NAMES.TXT', 0
file_perfect:     db 'PERFECT.BMP', 0
file_goodjob:     db 'GOODJOB.BMP', 0
file_okay:        db 'OKAY.BMP', 0
file_tryagain:    db 'TRYAGAIN.BMP', 0
file_q_sqr_e:     db 'ES-SQR.BMP', 0
file_q_str_e:     db 'ES-STR.BMP', 0
file_q_trg_e:     db 'ES-TRG.BMP', 0
file_q_crl_e:     db 'ES-CRL.BMP', 0
file_q_crl2_e:    db 'ES-CRL2.BMP', 0

q_bmp_table:
    dw file_q_sqr_e
    dw file_q_str_e
    dw file_q_trg_e
    dw file_q_crl_e
    dw file_q_crl2_e

q_ans_table:
    db 2, 2, 1, 1, 2

file_q_d_med:     db 'MD-DIA.BMP', 0
file_q_h_med:     db 'MD-HRT.BMP', 0
file_q_st_med:    db 'MD-STR.BMP', 0
file_q_sq_med:    db 'MD-SQR.BMP', 0
file_q_rec_med:   db 'MD-RECT.BMP', 0

q_bmp_table_med:
    dw file_q_d_med
    dw file_q_h_med
    dw file_q_st_med
    dw file_q_sq_med
    dw file_q_rec_med

q_ans_table_med:
    db 1, 2, 2, 3, 3

file_q_spr_hard:  db 'HD-SPR.BMP', 0
file_q_pt_hard:   db 'HD-PT.BMP', 0
file_q_ot_hard:   db 'HD-OT.BMP', 0
file_q_clr_hard:  db 'HD-CLR.BMP', 0
file_q_cb_hard:   db 'HD-CB.BMP', 0

q_bmp_table_hard:
    dw file_q_spr_hard
    dw file_q_pt_hard
    dw file_q_ot_hard
    dw file_q_clr_hard
    dw file_q_cb_hard

q_ans_table_hard:
    db 3, 4, 4, 2, 2

imf_file_welcome  db 'WELCOME.IMF', 0
imf_file_playing  db 'PLAYING.IMF', 0

current_track     db 0    
imf_handle        dw 0    
imf_delay         dw 0    
old_int1C_off     dw 0    
old_int1C_seg     dw 0    
imf_buffer        times 4 db 0 
post_game_flag    db 0    

filehandle:       dw 0
bmp_header:       times 54   db 0
bmp_palette:      times 1024 db 0

player1_name:     times MAX_NAME+1 db 0
player2_name:     times MAX_NAME+1 db 0
p1_len:           db 0
p2_len:           db 0
active_field:     db 0
game_mode:        db 0    
difficulty:       db 0    
current_player:   db 0    
p1_score:         dw 0    
p2_score:         dw 0    
p1_correct:       db 0    
p2_correct:       db 0    
sn_byte:          db 0    
hud_color:        db 0    
cur_max_hearts:   db 3    
cur_total_q:      db 3    
cur_bmp_table:    dw q_bmp_table    
cur_ans_table:    dw q_ans_table    
hearts:           db 0    
game_score:       dw 0    
q_num:            db 0    
correct_count:    db 0    
num_buf:          times 8 db 0  

lb_board:    times 3 * 5 * 12 db 0  
lb_used:     db 0, 0, 0              
lb_rbuf:     times 130 db 0          
lb_tmp_name: times 11  db 0          
lb_tmp_score: dw 0                   
lb_tmp_diff:  db 0                   
lb_col_x:     dw 0                   

; =============================================================================
; 8x8 BITMAP FONT 
; =============================================================================
font_data:
; 32 space
db 000h,000h,000h,000h,000h,000h,000h,000h
; 33 !
db 018h,03Ch,03Ch,018h,018h,000h,018h,000h
; 34 "
db 06Ch,06Ch,06Ch,000h,000h,000h,000h,000h
; 35 #
db 06Ch,06Ch,0FEh,06Ch,0FEh,06Ch,06Ch,000h
; 36 $
db 018h,07Eh,0C0h,07Ch,006h,0FCh,018h,000h
; 37 %
db 000h,0C6h,0CCh,018h,030h,066h,0C6h,000h
; 38 &
db 038h,06Ch,038h,076h,0DCh,0CCh,076h,000h
; 39 '
db 018h,018h,030h,000h,000h,000h,000h,000h
; 40 (
db 00Ch,018h,030h,030h,030h,018h,00Ch,000h
; 41 )
db 030h,018h,00Ch,00Ch,00Ch,018h,030h,000h
; 42 *
db 000h,066h,03Ch,0FFh,03Ch,066h,000h,000h
; 43 +
db 000h,018h,018h,07Eh,018h,018h,000h,000h
; 44 ,
db 000h,000h,000h,000h,000h,018h,018h,030h
; 45 -
db 000h,000h,000h,07Eh,000h,000h,000h,000h
; 46 .
db 000h,000h,000h,000h,000h,018h,018h,000h
; 47 /
db 006h,00Ch,018h,030h,060h,0C0h,080h,000h
; 48 0
db 07Ch,0C6h,0CEh,0D6h,0E6h,0C6h,07Ch,000h
; 49 1
db 018h,038h,018h,018h,018h,018h,07Eh,000h
; 50 2
db 07Ch,0C6h,006h,01Ch,030h,066h,0FEh,000h
; 51 3
db 07Ch,0C6h,006h,03Ch,006h,0C6h,07Ch,000h
; 52 4
db 01Ch,03Ch,06Ch,0CCh,0FEh,00Ch,01Eh,000h
; 53 5
db 0FEh,0C0h,0C0h,0FCh,006h,0C6h,07Ch,000h
; 54 6
db 038h,060h,0C0h,0FCh,0C6h,0C6h,07Ch,000h
; 55 7
db 0FEh,0C6h,00Ch,018h,030h,030h,030h,000h
; 56 8
db 07Ch,0C6h,0C6h,07Ch,0C6h,0C6h,07Ch,000h
; 57 9
db 07Ch,0C6h,0C6h,07Eh,006h,00Ch,078h,000h
; 58 :
db 000h,018h,018h,000h,000h,018h,018h,000h
; 59 ;
db 000h,018h,018h,000h,000h,018h,018h,030h
; 60 <
db 006h,00Ch,018h,030h,018h,00Ch,006h,000h
; 61 =
db 000h,000h,07Eh,000h,000h,07Eh,000h,000h
; 62 >
db 060h,030h,018h,00Ch,018h,030h,060h,000h
; 63 ?
db 07Ch,0C6h,00Ch,018h,018h,000h,018h,000h
; 64 @
db 07Ch,0C6h,0DEh,0DEh,0DEh,0C0h,078h,000h
; 65 A
db 038h,06Ch,0C6h,0FEh,0C6h,0C6h,0C6h,000h
; 66 B
db 0FCh,066h,066h,07Ch,066h,066h,0FCh,000h
; 67 C
db 03Ch,066h,0C0h,0C0h,0C0h,066h,03Ch,000h
; 68 D
db 0F8h,06Ch,066h,066h,066h,06Ch,0F8h,000h
; 69 E
db 0FEh,062h,068h,078h,068h,062h,0FEh,000h
; 70 F
db 0FEh,062h,068h,078h,068h,060h,0F0h,000h
; 71 G
db 03Ch,066h,0C0h,0C0h,0CEh,066h,03Eh,000h
; 72 H
db 0C6h,0C6h,0C6h,0FEh,0C6h,0C6h,0C6h,000h
; 73 I
db 03Ch,018h,018h,018h,018h,018h,03Ch,000h
; 74 J
db 01Eh,00Ch,00Ch,00Ch,0CCh,0CCh,078h,000h
; 75 K
db 0E6h,066h,06Ch,078h,06Ch,066h,0E6h,000h
; 76 L
db 0F0h,060h,060h,060h,062h,066h,0FEh,000h
; 77 M
db 0C6h,0EEh,0FEh,0FEh,0D6h,0C6h,0C6h,000h
; 78 N
db 0C6h,0E6h,0F6h,0DEh,0CEh,0C6h,0C6h,000h
; 79 O
db 038h,06Ch,0C6h,0C6h,0C6h,06Ch,038h,000h
; 80 P
db 0FCh,066h,066h,07Ch,060h,060h,0F0h,000h
; 81 Q
db 078h,0CCh,0CCh,0CCh,0DCh,078h,01Ch,000h
; 82 R
db 0FCh,066h,066h,07Ch,06Ch,066h,0E6h,000h
; 83 S
db 07Ch,0C6h,0C0h,07Ch,006h,0C6h,07Ch,000h
; 84 T
db 07Eh,07Eh,05Ah,018h,018h,018h,03Ch,000h
; 85 U
db 0C6h,0C6h,0C6h,0C6h,0C6h,0C6h,07Ch,000h
; 86 V
db 0C6h,0C6h,0C6h,0C6h,0C6h,06Ch,038h,000h
; 87 W
db 0C6h,0C6h,0C6h,0D6h,0FEh,0EEh,0C6h,000h
; 88 X
db 0C6h,0C6h,06Ch,038h,038h,06Ch,0C6h,000h
; 89 Y
db 066h,066h,066h,03Ch,018h,018h,03Ch,000h
; 90 Z
db 0FEh,0C6h,08Ch,018h,032h,066h,0FEh,000h
; 91 [
db 03Ch,030h,030h,030h,030h,030h,03Ch,000h
; 92 \
db 0C0h,060h,030h,018h,00Ch,006h,002h,000h
; 93 ]
db 03Ch,00Ch,00Ch,00Ch,00Ch,00Ch,03Ch,000h
; 94 ^
db 010h,038h,06Ch,0C6h,000h,000h,000h,000h
; 95 _
db 000h,000h,000h,000h,000h,000h,000h,0FFh
; 96 `
db 030h,018h,00Ch,000h,000h,000h,000h,000h
; 97 a
db 000h,000h,078h,00Ch,07Ch,0CCh,076h,000h
; 98 b
db 0E0h,060h,060h,07Ch,066h,066h,0DCh,000h
; 99 c
db 000h,000h,078h,0CCh,0C0h,0CCh,078h,000h
; 100 d
db 01Ch,00Ch,00Ch,07Ch,0CCh,0CCh,076h,000h
; 101 e
db 000h,000h,078h,0CCh,0FCh,0C0h,078h,000h
; 102 f
db 038h,06Ch,060h,0F0h,060h,060h,0F0h,000h
; 103 g
db 000h,000h,076h,0CCh,0CCh,07Ch,00Ch,0F8h
; 104 h
db 0E0h,060h,06Ch,076h,066h,066h,0E6h,000h
; 105 i
db 018h,000h,038h,018h,018h,018h,03Ch,000h
; 106 j
db 006h,000h,006h,006h,006h,066h,066h,03Ch
; 107 k
db 0E0h,060h,066h,06Ch,078h,06Ch,0E6h,000h
; 108 l
db 038h,018h,018h,018h,018h,018h,03Ch,000h
; 109 m
db 000h,000h,0CCh,0FEh,0FEh,0D6h,0C6h,000h
; 110 n
db 000h,000h,0F8h,0CCh,0CCh,0CCh,0CCh,000h
; 111 o
db 000h,000h,078h,0CCh,0CCh,0CCh,078h,000h
; 112 p
db 000h,000h,0DCh,066h,066h,07Ch,060h,0F0h
; 113 q
db 000h,000h,076h,0CCh,0CCh,07Ch,00Ch,01Eh
; 114 r
db 000h,000h,0DCh,076h,066h,060h,0F0h,000h
; 115 s
db 000h,000h,07Ch,0C0h,078h,00Ch,0F8h,000h
; 116 t
db 010h,030h,07Ch,030h,030h,034h,018h,000h
; 117 u
db 000h,000h,0CCh,0CCh,0CCh,0CCh,076h,000h
; 118 v
db 000h,000h,0CCh,0CCh,0CCh,078h,030h,000h
; 119 w
db 000h,000h,0C6h,0D6h,0FEh,0FEh,06Ch,000h
; 120 x
db 000h,000h,0C6h,06Ch,038h,06Ch,0C6h,000h
; 121 y
db 000h,000h,0CCh,0CCh,0CCh,07Ch,00Ch,0F8h
; 122 z
db 000h,000h,0FCh,098h,030h,064h,0FCh,000h
; 123 {
db 01Ch,030h,030h,0E0h,030h,030h,01Ch,000h
; 124 |
db 018h,018h,018h,000h,018h,018h,018h,000h
; 125 }
db 0E0h,030h,030h,01Ch,030h,030h,0E0h,000h
; 126 ~
db 076h,0DCh,000h,000h,000h,000h,000h,000h
; 127 DEL
db 000h,000h,000h,000h,000h,000h,000h,000h