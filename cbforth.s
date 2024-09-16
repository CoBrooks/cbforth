; vim:filetype=fasm
format ELF64 executable 3

W   equ rax
TOS equ rbx
IP  equ rsi
PSP equ rsp
RSP equ rdi
X   equ r8
Y   equ r9
Z   equ r10

macro align value { rb (value - 1)-($+value-1) mod value }

macro NEXT {
  lodsq         ; mov W, [IP++]
  jmp qword [W]
}

segment readable writeable executable
entry main

main:
  cld

  call setup_data_segment
  mov RSP, return_stack

  lea IP, [cold_start]
  NEXT

  int3

cold_start: dq QUIT

DOCOL:
  xchg W, IP
  stosq
  add IP, 8
  NEXT

link = 0

macro defcode name, flags, label {
  virtual at 0
    db name
    len = $
  end virtual
  
  assert (flags and not 31 = flags)
  assert (len < 32)

  header_#label :
    dq link
    link = header_#label
    db (flags or len)
    db name
  
  align 8
  #label :
    dq code_#label

  code_#label :
}

macro defword name, flags, label {
  virtual at 0
    db name
    len = $
  end virtual
  
  assert (flags and not 31 = flags)
  assert (len < 32)

  header_#label :
    dq link
    link = header_#label
    db (flags or len)
    db name
  
  align 8
  #label :
    dq DOCOL

  align 8
  code_#label :
}

macro defvar name, flags, label, initial {
  virtual at 0
    db name
    len = $
  end virtual
  
  assert (flags and not 31 = flags)
  assert (len < 32)

  header_#label :
    dq link
    link = header_#label
    db (flags or len)
    db name
  
  align 8
  #label :
    dq code_#label

  align 8
  code_#label :
    push TOS
    mov TOS, var_#label
    NEXT

  align 8
  var_#label :
    dq initial
}

F_IMMED  equ (1 shl 5)
F_HIDDEN equ (1 shl 6)

defcode "EXIT", 0, EXIT
  sub RSP, 8
  mov IP, qword [RSP]
  NEXT

defcode "LIT", 0, LIT
  push TOS
  lodsq
  mov TOS, W
  NEXT

defcode "DUP", 0, DUP_
  push TOS
  NEXT

defcode "SWAP", 0, SWAP
  pop W
  push TOS
  mov TOS, W
  NEXT

defcode "DROP", 0, DROP
  pop TOS
  NEXT

defcode "DUP2", 0, DUP2
  pop W
  push W
  push TOS
  push W
  NEXT

defcode "NIP", 0, NIP
  pop W
  NEXT

defcode "+", 0, ADD_
  pop W
  add TOS, W
  NEXT

defcode "-", 0, SUB_
  pop  W
  xchg TOS, W
  sub  TOS, W
  NEXT

defcode "*", 0, MUL_
  pop  W
  imul TOS, W
  NEXT

defcode "=", 0, EQL
  pop   W
  cmp   TOS, W
  sete  al
  movzx TOS, al
  NEXT

defcode "=0", 0, ZEQL
  cmp   TOS, 0
  sete  al
  movzx TOS, al
  NEXT

defcode "/MOD", 0, DIVMOD
  xor  rdx, rdx
  pop  X
  mov  W, TOS
  div  X
  mov  TOS, rdx
  push W
  NEXT

defcode "AND", 0, AND_
  pop W
  and TOS, W
  NEXT

defcode "XOR", 0, XOR_
  pop W
  xor TOS, W
  NEXT

defcode "OR", 0, OR_
  pop W
  or  TOS, W
  NEXT

defcode "NOT", 0, NOT_
  not TOS
  NEXT

defcode "!", 0, STORE_ ; ( x a -- )
  pop qword [TOS]
  pop TOS
  NEXT

defcode "@", 0, FETCH ; ( a -- x )
  mov TOS, qword [TOS]
  NEXT

defcode "c!", 0, CSTORE
  pop W
  mov byte [TOS], al
  pop TOS
  NEXT

defcode "c@", 0, CFETCH
  movzx TOS, byte [TOS]
  NEXT

defcode ">r", 0, TORSP
  mov qword [RSP], TOS
  add RSP, 8
  pop TOS
  NEXT

defcode "r>", 0, FROMRSP
  push TOS
  sub  RSP, 8
  mov  TOS, qword [RSP]
  NEXT

defcode "DBG", 0, DBG
  int3
  NEXT

defcode "KEY", 0, KEY
  push TOS
  call _KEY
  mov TOS, W
  NEXT

; out:
; | al = input character
_KEY:
  push rdi
  push rsi

  ; Is input buffer empty?
  mov W, qword [input_top]
  cmp W, qword [input_end]
  jb  @f
  
  ; grab more input
  mov rax, 0 ; SYS_READ
  mov rdi, 0 ; stdin
  mov rsi, input_buffer
  mov rdx, input_buffer.size
  syscall

  cmp rax, 0
  jle .done

  mov qword [input_top], input_buffer

  lea W, [input_buffer+W]
  mov qword [input_end], W
@@:
  xor rax, rax

  mov rsi, qword [input_top]
  lodsb
  mov qword [input_top], rsi
.done:
  pop rsi
  pop rdi
  ret

input_end: dq input_buffer
input_top: dq input_buffer

defcode "WORD", 0, WORD_
  push TOS
  call _WORD
  push W
  NEXT

; out:
; | W   = ptr to word
; | TOS = len of word
_WORD:
  ; skip whitespace
  call _KEY

  cmp al, " "
  jle _WORD

  push rdi
  mov  rdi, word_buffer

  xor rcx, rcx
  mov cl, 32
@@:
  stosb
  call _KEY

  cmp al, " "
  jle @f

  loop @b
@@:
  neg cl
  add cl, 33   ; add extra 1 to length
  mov TOS, rcx

  mov W, word_buffer

  pop rdi
  ret

word_buffer: rb 32

defcode ",", 0, COMMA
  call _COMMA
  pop TOS
  NEXT

; in:
; | TOS = value to store
_COMMA:
  push rdi
  
  mov rdi, qword [var_HERE]
  mov rax, TOS
  stosq

  mov qword [var_HERE], rdi

  pop rdi
  ret

defcode "c,", 0, CCOMMA
  call _CCOMMA
  pop TOS
  NEXT

; in:
; | TOS = value to store
_CCOMMA:
  push rdi
  
  mov rdi, qword [var_HERE]
  mov al, bl
  stosb

  mov qword [var_HERE], rdi

  pop rdi
  ret

defcode "FIND", 0, FIND
  pop  W
  call _FIND
  NEXT

; in:
; | W   = ptr to word
; | TOS = len of word
; out:
; | TOS = ptr to dict header or NULL
; | (clobbered) W
_FIND:
  push rdi
  push rsi

  mov rdi, W
  mov X, TOS

  xor rax, rax
  mov TOS, var_LATEST
@@:
  ; next entry
  mov TOS, qword [TOS]

  ; done?
  cmp TOS, 0
  je .done
  
  ; compare name lengths
  mov rcx, X
  mov al, byte [TOS+8]
  and al, 00011111b
  cmp al, cl
  jne @b

  ; skip if F_HIDDEN
  mov al, byte [TOS+8]
  and al, F_HIDDEN
  jnz @b

  ; compare names
  mov W, rdi
  lea rsi, [TOS+9]
  repe cmpsb
  je  .done
  
  mov rdi, W
  jmp @b
.done:
  pop rsi
  pop rdi
  ret

defcode ">CFA", 0, TCFA
  call _TCFA
  NEXT

; in:
; | TOS = ptr to header
; out:
; | TOS = ptr to codeword field
; | (clobbered) W
_TCFA:
  add   TOS, 8
  movzx rax, byte [TOS]
  and   rax, 00011111b
  lea   TOS, [TOS + 1]
  add   TOS, rax

  add TOS, 7
  and TOS, not 7

  ret

defcode "BRANCH", 0, BRANCH
  lodsq
  add IP, W
  NEXT

defcode "?BRANCH", 0, ZBRANCH
  lodsq
  test TOS, TOS
  jne  @f
  add  IP, W
@@:
  pop TOS
  NEXT

defcode "EXECUTE", 0, EXECUTE
  mov W, TOS
  pop TOS
  jmp qword [W]

defcode "NUMBER", 0, NUMBER
  pop W
  call _NUMBER
  push TOS
  mov TOS, W
  NEXT

; in:
; | W   = ptr to word
; | TOS = len of word
; out:
; | TOS = parsed number
; | W   = remaining digits (nonzero = error)
_NUMBER:
  push rsi

  mov rcx, TOS
  mov rsi, W

  xor rax, rax
  xor TOS, TOS
.next_digit:
  lodsb

  imul TOS, qword [var_BASE]

  cmp al, "0"
  jb .done
  cmp al, "9"
  ja  @f

  sub al, "0"
  cmp rax, qword [var_BASE]
  jge .done

  add TOS, rax
  loop .next_digit
@@:
  cmp al, "A"
  jb .done
  cmp al, "Z"
  ja .done

  sub al, "A" - 10
  cmp rax, qword [var_BASE]
  jge .done

  add TOS, rax
  loop .next_digit
.done:
  mov W, rcx
  pop rsi
  ret

defcode "[", F_IMMED, LBRAC
  mov qword [var_STATE], 0
  NEXT

defcode "]", 0, RBRAC
  mov qword [var_STATE], 1
  NEXT

defcode "foobar", 0, foobar
  mov rdi, 69
  mov rax, 60
  syscall

defcode "INTERPRET", 0, INTERPRET
  push TOS

  ; out:
  ; | W   = ptr to word
  ; | TOS = len of word
  call _WORD

  ; save word to stack
  mov qword [curword], W
  mov qword [curword.length], TOS

  ; out:
  ; | TOS = ptr to dict header or NULL
  ; | (clobbered) W
  call _FIND
  test TOS, TOS
  jz  .number

  ; load flags
  movzx W, byte [TOS+8]
  and   W, F_IMMED
  jnz  .execute

  ; jump to execute if not compiling
  mov  W, qword [var_STATE]
  test W, W
  je  .execute
  
  ; out:
  ; | TOS = ptr to codeword field
  ; | (clobbered) W
  call _TCFA

  call _COMMA
  pop TOS
  jmp .done
.execute:
  ; out:
  ; | TOS = ptr to codeword field
  ; | (clobbered) W
  call _TCFA

  mov W, TOS
  pop TOS
  jmp qword [W]
.number:
  ; restore word from stack
  mov TOS, qword [curword.length]
  mov W, qword [curword]

  ; out:
  ; | TOS = parsed number
  ; | W   = remaining digits (nonzero = error)
  call _NUMBER
  test W, W
  jne .error
  
  mov  W, qword [var_STATE]
  test W, W
  je  .done

  ; compile LIT followed by number
  push TOS
  mov  TOS, LIT
  call _COMMA
  pop  TOS
  call _COMMA
  pop  TOS
.done:
  NEXT
.error:
  mov rax, 1
  mov rdi, 1
  mov rsi, [curword]
  mov rdx, [curword.length]
  syscall

  mov rax, 60
  mov rdi, 1
  syscall

curword: dq 0
.length: dq 0

defword "QUIT", 0, QUIT
@@:
  dq INTERPRET
  dq BRANCH, (@b - $ - 8)

defvar "HERE", 0, HERE, 0
defvar "R0", 0, R0, return_stack
defvar "LATEST", 0, LATEST, header___last
defvar "BASE", 0, BASE, 10
defvar "STATE", 0, STATE, 0
defvar "DOCOL", 0, DOCOL_, DOCOL

defcode "CREATE", 0, CREATE ; ( a n -- )
  pop X ; address of name

  push rdi
  push rsi

  mov rdi, qword [var_HERE]

  mov rax, qword [var_LATEST]
  stosq ; store link to prev entry
  
  mov al, bl
  stosb ; store name length

  mov rcx, TOS
  mov rsi, X
  repe movsb ; store name

  add rdi, 7
  and rdi, not 7

  ; update HERE and LATEST
  mov rax, qword [var_HERE]
  mov qword [var_LATEST], rax
  mov qword [var_HERE], rdi

  pop rsi
  pop rdi
  pop TOS
  NEXT

align 8
defword "COLON", 0, COLON
  dq WORD_
  dq CREATE
  dq LIT, DOCOL, COMMA
  dq LATEST, FETCH, HIDDEN
  dq RBRAC
  dq EXIT

align 8
defword "SEMICOLON", F_IMMED, SEMICOLON
  dq LIT, EXIT, COMMA
  dq LATEST, FETCH, HIDDEN
  dq LBRAC
  dq EXIT

defword "'", 0, TICK
  dq WORD_, FIND
  dq EXIT


defcode "HIDDEN", 0, HIDDEN
  add TOS, 8
  xor byte [TOS], F_IMMED
  pop TOS
  NEXT

defcode ".", 0, PRINT
  push rdi
  push rsi

  mov rdi, print_buffer
  mov rsi, number_prefix

  mov rcx, 2
  repnz movsb

  xor rcx, rcx
  mov rcx, 16
@@:
  rol TOS, 4
  mov X, TOS
  and X, 1111b

  lea rsi, [numbers+X]
  movsb

  loop @b
@@:
  mov rsi, newline
  movsb

  mov rax, 1
  mov rdi, 1
  mov rsi, print_buffer
  mov rdx, 19
  syscall

  pop rsi
  pop rdi
  pop TOS
  NEXT

defcode "TELL", 0, TELL ; ( a n -- )
  pop  X

  xchg X, rsi
  mov rdx, TOS
  mov rdi, 1
  mov rax, 1
  syscall

  mov rsi, newline
  mov rdx, 1
  mov rdi, 1
  mov rax, 1
  syscall

  xchg rsi, X
  pop TOS
  NEXT

print_buffer: rb 19
number_prefix: db "0x"
numbers: db "0123456789ABCDEF"
newline: db 10

; MUST BE LAST KERNEL ENTRY
defcode "__last", F_HIDDEN, __last
  int3

INITIAL_DATA_SEGMENT_SIZE = 2 shl 16

setup_data_segment:
  xor rdi, rdi
  mov rax, 12                        ; brk
  syscall

  mov qword [var_HERE], rax

  ; Allocate more heap
  mov rdi, INITIAL_DATA_SEGMENT_SIZE
  add rdi, rax
  mov rax, 12                        ; brk
  syscall

  ; Add PROT_EXEC to heap memory
  mov rdi, qword [var_HERE]
  mov rsi, INITIAL_DATA_SEGMENT_SIZE
  mov rdx, 00000111b                 ; PROT_READ | PROT_WRITE | PROT_EXEC
  mov rax, 10                        ; mprotect
  syscall

  ret

align 4096
return_stack: rb 4096
  .top:
  .size = $ - return_stack

align 4096
input_buffer: rb 4096
  .size = $ - input_buffer
