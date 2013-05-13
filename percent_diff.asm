%include "amd64_abi.mac"

; A place to build samples for testing
[SECTION .data]
    Similarity_Text:        db "Between file: %s and file: %s", 10, "Percent Similar: %lf %%", 10, "Matched: %d", 10, "Compared: %d",10 ,0
    File_Error_Text:        db "A specified file was not behaving: %s",10,0
    Arg_count_error:        db "Need to specify TWO files. You gave %d.", 10, 0

[SECTION .bss]
    Longer_File_Len:    resq 1
    Shorter_File_Len:   resq 1
    Matched_Bytes:      resq 1
    Percentage_Match:   resq 1
    FileA_name:         resb 256
    FileB_name:         resb 256
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

Parse_args:
    mov rdx, rsi                    ; Save the pointer to first argument
    mov rsi, [rdx+10o]              ; Octal +8. Second argument which is first we care about.
    mov rdi, FileA_name             ; Place to store first file name
    call Move_string_til_null       ; Write from stack to FileA_name the second argument

    mov rsi, [rdx+20o]              ; Octal +16. Third argument
    mov rdi, FileB_name             ; Address of place to copy argument for storage
    call Move_string_til_null

Status_of_files:
    mov rbx, FileB_name             ; Get FileA's length
    call Get_file_length
    push rax

    mov rbx, FileA_name             ; Get FileA's length
    call Get_file_length
    pop rbx                         ; Puts File B's length into rbx

    cmp rax, rbx                    ; Makes sure they are in correct order
    jnl Files_are_ordered           ; if RAX >= jump to Files_are_ordered

    push rax
    push rbx
    call Swap_file_names
    pop  rax
    pop  rbx

Files_are_ordered:
    call Store_file_lengths

    mov  rsi, FileA_name
    mov  rdi, File_Buffer
    mov  rcx, [Shorter_File_Len]
    call Load_buffer_with_file

TESTING:
    mov  rsi, FileB_name
    mov  rdi, File_Buffer_2
    mov  rcx, [Shorter_File_Len]
    call Load_buffer_with_file

    mov rsi, File_Buffer
    mov rdi, File_Buffer_2
    mov rcx, [Shorter_File_Len]
    call Compare_memory_Segs

    mov [Matched_Bytes], rax

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
    mov rsi, rdi                ; Moves the pointer from main's start to rsi
    mov rdi, Arg_count_error    ; Points to the error message
    dec rsi                     ; Accounts for the called command being a commang arg
    call printf                 ; Prints error message

    jmp ArgumentError           ; Quits

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
;* NAME      : Get_file_length
;* PARAMS    : Filename => RBX
;* RETURNS   : Length (Bytes) => Rax
;* MEMORY    : File_Buffer used
;* DESTROYS  : RAX, RBX, RCX
;* CALLS     : int 80h, sys_newstat (106)
;* FUNCTION  : Returns the length of file named in RBX in RAX
;********************************************************************
Get_file_length:
    mov rax, 106                ; FileStats
    mov rcx, File_Buffer        ; Read file in RAX
    int 80h                     ; Call sys_read

    test rax, rax               ; Checks returned error code
    jl Bad_file                 ; Jump to File error handle

    mov eax,[File_Buffer+20]    ; Moves value of File_length into RAX
    ret

Bad_file:
    mov rsi, rbx
    jmp File_error

;********************************************************************
;* NAME      : Store_file_lengths
;* PARAMS    : Longer file length => RAX
;*           : Shorter file length => RBX
;* RETURNS   : None
;* MEMORY    : Longer_File_Len
;*           : Shorter_File_Len
;* DESTROYS  : None
;* CALLS     : None
;* FUNCTION  : Too short to describe
;********************************************************************
Store_file_lengths:
    mov [Longer_File_Len], rax       ; Store RAX as longer length
    mov [Shorter_File_Len], rbx      ; Store RBX as shorter length
    ret

;********************************************************************
;* NAME      : Swap_file_names
;* PARAMS    : None
;* RETURNS   : None
;* MEMORY    : [FileA_name]
;*           : [FileB_name]
;*           : [File_Buffer]
;* DESTROYS  : RAX, RCX, RDI, RSI, R11
;* CALLS     : Move_string_til_null
;* FUNCTION  : Switches the given file names.
;********************************************************************
Swap_file_names:
    mov rsi, FileA_name                 ; Takes String-NullByte
    mov rdi, File_Buffer                ; Aims it at the buffer
    call Move_string_til_null           ; Stores it there

    mov rsi, FileB_name                 ; Moves Name of FileB
    mov rdi, FileA_name                 ; To FileA location
    call Move_string_til_null           ; And stores it there

    mov rsi, File_Buffer                ; Takes the buffer-stored Name
    mov rdi, FileB_name                 ; Puts it in FileB's place
    call Move_string_til_null
    ret

;********************************************************************
;* NAME      : Compare_memory_Segs
;* PARAMS    : Section A => RSI
;*           : Section B => RDI
;*           : Length to compare => RCX
;* RETURNS   : Number of matching => RAX
;* MEMORY    : No changes to memory
;* DESTROYS  : RAX, RCX, RDX, RDI, RSI
;* CALLS     : None
;* FUNCTION  : For the length of RCX compares bytes. Each match enumerates
;*              RDX. Returns the match # in RAX.
;********************************************************************
Compare_memory_Segs:
    xor rdx, rdx        ; Zeroes RDX for match count

.Cycle_comparison:
    mov al, [rdi]       ; Moves [RDI] into AL
    cmp [rsi], al       ; Compares this byte to [RSI]
    jne .Not_Matching   ; If != skip increment
    inc rdx             ; Increment Match Counter

.Not_Matching:
    inc rsi             ; Move the goal posts
    inc rdi             ; To the next pair of bytes
    dec rcx             ; Subtract remaining byte count
    jnz .Cycle_comparison   ; If RCX is not ZERO repeat loop
    mov rax, rdx            ; Pass RDX counter to RAX for return value
    ret

;********************************************************************
;* NAME      : Load_buffer_with_file
;* PARAMS    : Buffer => RDI
;*           : Filename => RSI
;*           : Filelength => RCX
;* RETURNS   : Loaded bytes => RAX
;* MEMORY    : File_Buffer
;*           : Mem_LocB
;* DESTROYS  : RAX, RBX, RCX, RDX, RSI, RDI
;* CALLS     : Open File, Read File
;* FUNCTION  : Takes file name, length and loads it into given buffer.
;********************************************************************
Load_buffer_with_file:
    push rdi            ; Saves the buffer location
    push rcx            ; Saves the byte count

    mov rbx, rsi        ; File name passed to proc
    mov rax, 5          ; Open file
    mov rcx, 0          ; Read only
    int 80h

    mov rbx, rax        ; Moves returned file handle into rbx
    mov rax,3           ; Specify sys_read call
    pop rdx             ; Pops the file size into RDX
    pop rcx             ; Pops the Buffer location
    int 80h             ; Call sys_read

    ret

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
;    mov rax, 9533                   ; TESTing
;    mov [Matched_Bytes], rax        ; TESTing

;    mov rax, 10000                  ; TESTing
;    mov [Shorter_File_Len], rax     ; TESTing

;    mov rax, [Matched_Bytes]    ; Puts the divisor in rax :: Matched bytes
    cvtsi2sd xmm0, [Matched_Bytes]          ; then into xmm0
;    mov rax, [Shorter_File_Len] ; Move the dividend into xmm1 through RAX
    cvtsi2sd xmm1, [Shorter_File_Len]
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
    mov rcx, [Matched_Bytes]
    mov r8, [Shorter_File_Len]
    movsd xmm0, [Percentage_Match]  ; Re
    mov rax, 1                  ; Number of XMM regs used

    call printf                 ; Send the formatted string to C-printf

    add rsp, 8
    ret

Unkown_scan_error:
    mov rax, -7  ; Argument length too long
    mov rsp, rbp ; Return RBP to RSP
    sub rsp, 30h ; Account for saved stack
    jmp Exit

File_error:

    mov rdi, File_Error_Text
    xor rax, rax
    call printf                 ; Send the formatted string to C-printf

    mov rax, -2  ; File error code.
    add rsp, 8
    jmp Exit

ArgumentError:
    mov rax, -22  ; Argument error code.
    jmp Exit

NormalExit:     ; Jmp location for normal exit
    mov rax,1   ; Move exit code of 1 to rax

Exit:
_restore_64AMD_ABI_regs_RET