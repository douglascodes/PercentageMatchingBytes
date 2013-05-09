%include "amd64_abi.mac"

; A place to build samples for testing
[SECTION .data]
    Similarity_Text:        db "The similarities between file: %s and file: %s are %g%%", 10,0
    File_Error_Text:        db "A specified file was not found.",10,0
    Arg_count_error:        db "Need to specify TWO files. You gave %d.", 10, 0

[SECTION .bss]
    Longer_File_Len:    resq 1
    Shorter_File_Len:   resq 1
    Matched_Bytes:      resq 1
    Percentage_Match:   resq 1
    FileA_name:         resb 256
    FileB_name:         resb 256
    FileA_pointer:      resq 1
    FileB_pointer:      resq 1
    File_Buffer:        resb 1048576
    File_Buffer_2:      resb 1048576

[SECTION .text]
    EXTERN _DEBUG_Register_Dump
    EXTERN printf

    GLOBAL main

main:
    _preserve_64AMD_ABI_regs
                                    ; When main loads. RDI = Argc ... RSI = ADDRESS of first arg. The program itself.
    cmp rdi,3                       ; 1 = Program itself. 2 / 3 are the files to compare
    jne Arg_Count_Check_Fail        ; Wrong number of arguments jump to ArgumentError exit protocol

    mov rdx, rsi                    ; Save the pointer to first argument
    mov rsi, [rdx+10o]              ; Octal +8. Second argument which is first we care about.
    mov rdi, FileA_name             ; Place to store first file name
    call Move_string_til_null       ; Write from stack to FileA_name the second argument

    mov rsi, [rdx+20o]              ; Octal +16. Third argument
    mov rdi, FileB_name             ; Address of place to copy argument for storage
    call Move_string_til_null


    call Read_file_lengths

    call Divide_percentage

    call Print_file_comp_results
    jmp NormalExit

;********************************************************************
;* NAME      : Arg_Count_Check_Fail
;* PARAMS    : Arg Count => RDI
;*           : ValueX => Register
;* RETURNS   : Bytes written => RAX
;* DESTROYS  : RAX
;* CALLS     : printf
;* FUNCTION  : Writes error message via printf
;********************************************************************
Arg_Count_Check_Fail:
    mov rsi, rdi
    mov rdi, Arg_count_error
    dec rsi
    call printf

    jmp ArgumentError

;********************************************************************
;* NAME      : Move_string_til_null
;* PARAMS    : [Source] => RSI
;*           : [Destination] => RDI
;* RETURNS   : Bytes moved => RAX
;* MEMORY    : [Source]
;*           : Mem_LocB
;* DESTROYS  : RAX RCX RDI RSI R11
;* CALLS     :
;* FUNCTION  : Reads string from source to dest until 0-byte encountered.
;* Will overwrite anything in destination until 0 is encountered in
;********************************************************************
Move_string_til_null:
    xchg rdi, rsi           ; We need to swap temporarily to get length of source
    mov r11, rdi            ; Save a copy of Source index
    mov rcx, 0FFFFFFFFh     ; Search no more than this far for a zero-byte
    cld
    xor rax, rax            ; Set AL to zero
    repne scasb             ; Scans RDI and increments til AL == byte [RDI]
    jnz Unkown_scan_error   ; We scanned way to far without a zero-byte

    sub rdi, r11            ; Difference between rdi and r11 is argX_length
    mov rcx, rdi            ; store this value in RCX for the MOVSB

    mov rdi, r11            ; Copies the source index back into rdi
    xchg rdi, rsi           ; Swaps these again so now Source and Dest are back

    rep movsb               ; Blasts the string of RCX length from RSI -> RDI

    ret

;********************************************************************
;* NAME      : Read_file_lengths
;* RETURNS   : ValueX => Register
;* MEMORY    : [Longer_File_Len]
;*           : [Shorter_File_Len]
;* DESTROYS  : Register
;* CALLS     : Readfile
;* FUNCTION  : Opens files and stores their lengths
;********************************************************************
Read_file_lengths:
    ret

; Store these in buffers

; Open file-A and fill memory buffer

; Get filebyte count into rcx

; Open file-B and fill memory buffer
; Get filebyte count for B


;********************************************************************
;* NAME      : Divide_percentage
;* MEMORY    : [Longer_File_Len]
;*           : [Shorter_File_Len]
;*           : [Percentage_Match]
;* DESTROYS  : RAX, XMM0-XMM2
;* CALLS     :
;* FUNCTION  : Takes the value of matched bytes, against the shorter file length.
;* Converts them into doubles and divides them. 100 * (Matched / Length) => Percentage_Match
;********************************************************************
Divide_percentage:
    mov rax, 9533                   ; TESTing
    mov [Matched_Bytes], rax        ; TESTing

    mov rax, 10000                  ; TESTing
    mov [Shorter_File_Len], rax     ; TESTing

    mov rax, [Matched_Bytes]    ; Puts the divisor in rax :: Matched bytes
    cvtsi2sd xmm0, rax          ; then into xmm0
    mov rax, [Shorter_File_Len] ; Move the dividend into xmm1 through RAX
    cvtsi2sd xmm1, rax
    divsd xmm0, xmm1            ; Divide and store in xmm0
    mov rax, 100                ; Move the percentage multiplier 100% = 1
    cvtsi2sd xmm2, rax          ; into xmm2
    mulsd xmm0, xmm2            ; Takes decimal value in xmm0 and makes it a percentage
    movsd [Percentage_Match], xmm0 ; Stores the percentage in
    ret

Print_file_comp_results:
    sub rsp, 8

    mov rdi, Similarity_Text
    mov rsi, FileA_name
    mov rdx, FileB_name
    movsd xmm0, [Percentage_Match]
    mov rax, 1

    call printf                 ; Send the formatted string to C-printf

    add rsp, 8
    ret
Unkown_scan_error:
    mov rax, -2  ; Excessive scan length.
    mov rsp, rbp
    sub rsp, 30h
    jmp Exit

ArgumentError:
    mov rax, 2  ; Argument error code.
    jmp Exit
NormalExit:     ; Jmp location for normal exit
    mov rax,1   ; Move exit code of 1 to rax
Exit:
_restore_64AMD_ABI_regs_RET