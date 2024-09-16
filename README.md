# CBForth

A sandbox project to experiment with different sets of Forth primitives and patterns.

## Dependencies

- A x86_64 linux system
- [Flat Assembler](https://flatassembler.net/)

## Building

```sh
$ fasm cbforth.s
```

## Documentation

## Overview

This is an indirectly-threaded Forth. The only intent behind this design decision was the simplicity of the implementation.

### Primitives

The following set of primitives are, I believe, the smallest set that keeps the initial Forth bootstrapping
concise and simple. More primitives are currently implemented, but are not documented here.

```forth
+
-
*
/MOD

=
=0

!
@
c!
c@

,
c,

AND
OR
NOT
XOR

>r
r>

DUP
DROP
SWAP

[
]

BASE
HERE
LATEST
DOCOL

CREATE
>CFA

WORD
EXIT
LIT
```
