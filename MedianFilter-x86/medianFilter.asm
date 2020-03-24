section	.text
global  medianFilter

medianFilter:
	push	rbp
	mov	    rbp, rsp

    push    rax
    push    rbx
    push    rcx
    push    rdx
    push    rdi
    push    rsi
    push    r8
    push    r9
    push    r10
    push    r11
    push    r12
    push    r13
    push    r14
    push    r15

	mov     r15, rdx   ; output
	mov 	r14, rsi   ; input  
    mov     r13, rdi   ; buffer

    xor     r12, r12
    xor     r11, r11
	mov     r12D, DWORD [r14 + 18] ; getting width 
	mov 	r11D, DWORD [r14 + 22] ; getting height

	mov	    rbx, r12 
	add	    r12, rbx
	add	    r12, rbx        ; 3 * width

    ; Copying bmp header - first 54 bytes in file
    xor     rcx, rcx
	mov	    rcx, 54
	mov	    rsi, r14       ; copy from
	mov	    rdi, r15       ; copy to
	rep     movsb 
	mov	    r14, rsi       ; update pointers
	mov	    r15, rdi

calculating_padding: 
    xor     rax, rax
	mov	    rax, r12            ; storing width for calculation
    and     rax, 3
    xor     rbx, rbx
    mov     rbx, 4	                
    cmp     rax, 0
    je      paddingCalculated   ;if 0 no padding
    sub     rbx, rax 
    mov     rax, rbx

paddingCalculated:  
    xor     r10, r10
	mov 	r10 ,rax            ; padding
	add	    r10, r12            ; 3*width+padding
    xor     r9, r9              ; processed rows
    xor     r8, r8              ; processed bytes in row

; rewriting first row from picture
rewrite_first_row:
    mov	    rsi, r14          ; copy from
	mov	    rdi, r15          ; copy to
    xor     rcx, rcx
    mov     rcx, r10          ; whole row + padding
    rep     movsb
    mov     r14, rsi          ; update pointers
    mov     r15, rdi
    inc     r9                ; row processed

rewrite_first_pixel_in_row:
    mov     rsi,r14           ; copy from
    mov     rdi,r15           ; copy to
    xor     rcx, rcx
    mov     rcx, 3            ; first pixel
    rep     movsb
    mov     r14, rsi          ; update pointers
    mov     r15, rdi
    add     r8, 3             ; first pixel processed

byte_in_the_middle:
    xor     rax, rax
	mov	    rax, r14          ; next byte 
    inc     r14               ; updating output pointer
	xor	    rbx, rbx
    xor     rcx, rcx          
    mov     rcx, r13          ; filling buffer for find_median

put_bytes_in_buffer:
	movzx   ebx, BYTE [rax - 3]    
    mov     [rcx], bl
    inc     rcx
    movzx   ebx, BYTE [rax] 
    mov     [rcx], bl
    inc     rcx
    movzx   ebx, BYTE [rax + 3]
    mov     [rcx], bl
    inc     rcx
    add     rax, r10
    movzx   ebx, BYTE [rax - 3] 
    mov     [rcx], bl
    inc     rcx
    movzx   ebx, BYTE [rax] 
    mov     [rcx], bl
    inc     rcx
    movzx   ebx, BYTE [rax + 3]
    mov     [rcx], bl 
    inc     rcx 
    sub     rax, r10
    sub     rax, r10
    movzx   ebx, BYTE [rax - 3] 
    mov     [rcx], bl
    inc     rcx
    movzx   ebx, BYTE [rax] 
    mov     [rcx], bl
    inc     rcx
    movzx   ebx, BYTE [rax + 3] 
    mov     [rcx], bl
    add     rax, r10
 
find_median:
    xor     rbx, rbx
    mov     rbx, r13
    add     rbx, 8          ; rbx - end of buffer

back_to_first_element:
    xor     rdi, rdi
    mov     rdi, r13

compare_two_elements:
    xor     rax, rax
    xor     rdx, rdx
    mov     al, BYTE [rdi]
    mov     dl, BYTE [rdi + 1]
    cmp     al, dl
    jle     no_swap
    mov     BYTE [rdi + 1], al
    mov     BYTE [rdi], dl

no_swap:
    inc     rdi
    cmp     rdi, rbx
    jne     compare_two_elements
    dec     rbx                     ; biggest element is at the end 
    cmp     r13, rbx
    jne     back_to_first_element

pick_median:
    xor     rax, rax
    mov     al, BYTE [r13 + 4]      ; median is fifth element in buffer
    mov     BYTE [r15], al          ; storing byte in output file
    inc     r15                     ; updating pointer
    inc     r8                      ; byte processed
    xor     rax, rax
    mov     rax, r12                ; width without padding
    sub     rax, 3                  
    cmp     rax, r8                 ; check whether all bytes in the middle were processed
    jne     byte_in_the_middle

rewrite_last_pixel_in_row:
    mov     rsi, r14            ; copy from
    mov     rdi, r15            ; copy to
    xor     rcx, rcx
    mov     rcx, r10
    add     rcx, 3           
    sub     rcx, r12            ; 3 + padding
    rep     movsb
    mov     r14, rsi            ; update pointers
    mov     r15, rdi

    inc     r9                  ; row processed
    xor     r8, r8              ; reseting processed bytes in row

    xor     rax, rax
    mov     rax, r9
    add     rax, 1
    cmp     rax, r11
    jne     rewrite_first_pixel_in_row

rewrite_last_row:
    mov     rsi, r14          ; copy from
    mov     rdi, r15          ; copy to
    xor     rcx, rcx
    mov     rcx, r10          ; whole row
    rep     movsb
    
    mov     r14, rsi          ; update pointers
    mov     r15, rdi

end:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    pop     rsi
    pop     rdi
    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax

    mov     rsp, rbp
    pop     rbp
    ret