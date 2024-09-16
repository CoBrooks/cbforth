WORD xxxxxx_ CREATE
DOCOL @ ,
  ] CREATE EXIT [

WORD xxxxxx CREATE
LATEST @ 8 + DUP c@ 96 XOR SWAP c!
DOCOL @ ,
  ] WORD CREATE EXIT [
LATEST @ 8 + DUP c@ 64 XOR SWAP c!

CREATE IMMEDIATE
DOCOL @ ,
  ] LATEST @ 8 + DUP c@ 32 XOR SWAP c! EXIT [

CREATE ['] IMMEDIATE
DOCOL @ ,
  ] WORD FIND EXIT  [

CREATE :
DOCOL @ ,
  ] WORD CREATE_    [
  ] DOCOL @ ,       [
  ] LATEST @ HIDDEN [
  ] ] EXIT          [

CREATE '
DOCOL @ ,
  ] WORD FIND EXIT  [

CREATE ; IMMEDIATE
DOCOL @ ,
  ] LIT EXIT ,      [
  ] LATEST @ HIDDEN [
  ['] [ >CFA ,
  ] EXIT            [

: IF
  LIT [ ' ?BRANCH >CFA , ] ,
  HERE @
  0 ,
; IMMEDIATE

: THEN
  DUP HERE @ SWAP - 8 - SWAP !
; IMMEDIATE

: \
  [ HERE @ ]
  KEY 10 =
  ?BRANCH [ HERE @ - 8 - , ]
; IMMEDIATE

\ Now we have line comments! :)

: (
  [ HERE @ ]
  KEY LIT [ KEY ) , ] =
  ?BRANCH [ HERE @ - 8 - , ]
; IMMEDIATE

( Now we have block comments! :)

: 2DUP ( a b -- a b a b )
  DUP >r
  SWAP DUP >r
  SWAP
  r> r>
;

: bin{  2 BASE ! ; IMMEDIATE
: oct{  8 BASE ! ; IMMEDIATE
: hex{ 16 BASE ! ; IMMEDIATE
: }dec 10 BASE ! ; IMMEDIATE

: CODE
  WORD CREATE_
  HERE @ 8 + ,
;

: lodsq, hex{
  48 c, AD c,
}dec ;

: jmp[W], hex{
  FF c, 20 c,
}dec ;

: NEXT, 
  lodsq,
  jmp[W],
;

: W   0 ; \ rax
: TOS 3 ; \ rbx

: pop, ( reg -- ) hex{
  58 OR c,
}dec ;

: REX.W hex{ 48 }dec ;

: ModR/M ( rm reg -- ModR/M ) bin{
  11000000 SWAP 1000 * OR OR
}dec ;

: cmp, ( rhs lhs -- ) hex{
  REX.W OR c,
  39 c,
  0 SWAP ModR/M c,
}dec ;

: setg, ( reg -- ) hex{
  0F c, 9F c,
  0 ModR/M c,
}dec ;

: movzx, ( dst src -- ) hex{
  REX.W OR c,
  0F c, B6 c,
  0 SWAP ModR/M c,
}dec ;

CODE > ( a b -- a>b )
  W     pop,
  TOS W cmp,
  W     setg,
  TOS W movzx,
  NEXT,

: BOOL IF 1 EXIT THEN 0 ;
: NOT BOOL 1 SWAP - ;

: WHICH ( a -- a )
  LATEST [ HERE @ ]

  \ Last entry?
  DUP NOT IF
    DROP EXIT
  THEN

  \ Next entry
  2DUP @

  \ Current entry less than input?
  > IF
    \ Return current entry
    @ SWAP DROP
    EXIT
  THEN

  @ BRANCH [ HERE @ - 8 - , ]
;

: @+ DUP 8 + SWAP @ ;
: c@+ DUP 1 + SWAP c@ ;

['] CODE >CFA 8 + @ WHICH 8 + DUP c@ 31 AND SWAP 1 + SWAP TELL

foobar

