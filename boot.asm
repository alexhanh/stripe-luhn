; Implementation of Luhn algorithm inside a 512-byte master boot record
; Author: alexhanh@gmail.com

; Use nasm to compile and dd to write to target media
;.\nasm -f bin -o boot.img .\boot.asm
;.\dd.exe if=boot.img of=\\.\d:

org 7C00h
use16

sum dd 0
digit dd 0
two dd 2
nine dd 9
ten dd 10
check dd 0
output dd 0

jmp start

; Doubles the number like described in Luhn's algorithm
; For example 8 => 2*8 => 16 => (1+6) => 7
luhn_double: 

  ; Multiply the number by 2 by shifting left
  shl [digit], 1       

  ; Jump back if digit is <10
  cmp dword [digit], 9h
  jb after

  ; Digit is >=10, so take the rightmost digit and add one to it
  sub dword [digit], 10
  inc dword [digit]

  jmp after

get_digit:
  mov ah, 00h ; 16H00H reads a keypress into AL
  int 16h

  mov ah, 0eh ; Echo the input back to the user
  int 10h

  sub al, 48  ; ASCII -> Dec
  mov [digit], al

  ret

; Prints the byte from [output]
print:
  mov ah, 0eh
  mov al, [output]
  int 10h
  ret

; http://www.ctyme.com/intr/rb-0106.htm
print_newline:
  
  mov dword [output], 0Ah
  call print

  mov dword [output], 0Dh
  call print

  ret

prepare_print:

  ; Update cursor position
  mov ah, 03h
  xor bh, bh
  int 10h

  ; http://www.ctyme.com/intr/rb-0210.htm
  mov ah, 13h

  ret

print_stripe:

  call prepare_print

  mov bl, 8 ; Dark gray
  mov cx, 6 ; How many to write
  mov al, 1 ; Advance cursor

  mov bp, stripe_message
  int 10h

  ret

print_valid:
  
  call prepare_print

  mov bl, 02h ; Green
  mov cx, 5 ; How many to write
  mov al, 1 ; Advance cursor

  mov bp, valid_message
  int 10h

  ret

print_invalid:
  
  call prepare_print

  mov bl, 04h ; Red
  mov cx, 7 ; How many to write
  mov al, 1 ; Advance cursor

  mov bp, invalid_message
  int 10h

  ret

print_instructions:

  call prepare_print

  mov bl, 07h ; White
  mov cx, 69 ; How many to write
  mov al, 1 ; Advance cursor

  mov bp, instructions
  int 10h

  ret

start:
  call print_instructions
  call print_newline

  mov cx, 15

  ; Get the first 15 numbers of the credit card
  get_numbers:
    
    call get_digit
          
    ; Check if the counter is even
    mov ax, cx
    mov dx, 0
    div dword [two]
    cmp dx, 0

    ; Do the Luhn double on every second digit
    jne luhn_double 
    
    after:

    ; Add to total sum
    mov al, [digit]
    add [sum], al

  loop get_numbers

  ; Ask for the 16th number, the check digit
  call get_digit

  ; Compute check digit from the sum by doing 10 - (sum % 10)
  mov dx, 0
  mov ax, [sum]
  div dword [ten]
  mov [check], dx
  mov ax, 10
  sub ax, dx

  mov [check], ax

  ; Check if the given and computed check digits match
  mov ax, [digit]
  cmp ax, [check]

  jne invalid

  call print_newline
  call print_valid
  jmp exit

  invalid:
    call print_newline
    call print_invalid    

  exit:
    call print_newline

    call print_stripe

    ; get one more keystroke before exit
    call get_digit

stripe_message: db "Stripe"
valid_message: db "Valid"
invalid_message: db "Invalid"
instructions: db "Please type a 16 digit credit card number (example 4485178907171896):"

times (512 - 2) - ($ - $$) db 0 ;Zerofill up to 510 bytes
dw 0AA55h                       ;Boot Sector signature