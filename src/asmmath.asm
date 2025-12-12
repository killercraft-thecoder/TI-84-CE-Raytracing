public _fp_mul
public _fp_sqr
public _fp_dot3

; Multiplies two Fixed24 (12.12) values and returns the new value in HL
; Calling convention: same as original
_fp_mul:
  push ix
  push bc
  push iy

  ; E = 0, will hold sign parity
  xor  a
  ld   e, a

  ; ix = sp - 6 (scratch 48 bits), zero them via 16-bit stores
  ld   iy, 0
  ld   ix, -6        ; $FFFFFA
  add  ix, sp
  ld   (ix),  iy     ; bytes 0..3 = 0
  ld   (ix+2),iy     ; bytes 2..5 = 0

  ; iy = pointer to arguments: [x0,x1,x2,y0,y1,y2]
  ld   iy, 12
  add  iy, sp

  ; --------------------
  ; abs(x), track sign
  ; x in iy+0..2
  ; --------------------
  bit  7, (iy+2)
  jr   z, .abs_x_done

  inc  e
  ld   a, 0
  sub  a, (iy+0)
  ld   (iy+0), a
  ld   a, 0
  sbc  a, (iy+1)
  ld   (iy+1), a
  ld   a, 0
  sbc  a, (iy+2)
  ld   (iy+2), a

.abs_x_done:
  ; --------------------
  ; abs(y), track sign
  ; y in iy+3..5
  ; --------------------
  bit  7, (iy+5)
  jr   z, .abs_y_done

  inc  e
  ld   a, 0
  sub  a, (iy+3)
  ld   (iy+3), a
  ld   a, 0
  sbc  a, (iy+4)
  ld   (iy+4), a
  ld   a, 0
  sbc  a, (iy+5)
  ld   (iy+5), a

.abs_y_done:
  ; Cache operands in registers to reduce (iy+n) loads
  ld   a, (iy+0)      ; x0
  ld   d, (iy+1)      ; x1
  ld   h, (iy+2)      ; x2

  ld   c, (iy+3)      ; y0
  ld   b, (iy+4)      ; y1
  ld   l, (iy+5)      ; y2

  ; Naming in comments:
  ;  x = [x0,x1,x2] = [A,D,H]
  ;  y = [y0,y1,y2] = [C,B,L]

  ; ===========
  ; CF = x0*y0
  ; ===========
  ld   h, a           ; H = x0
  ld   l, c           ; L = y0
  mlt  hl             ; HL = CF

  ; store low word, keep mid word in HL via reload
  ld   (ix), hl
  ld   hl, (ix+1)

  ; ===========
  ; BF = y1*x0
  ; ===========
  ld   b, b           ; B already = y1
  ld   c, a           ; C = x0
  mlt  bc
  add  hl, bc

  ; ===========
  ; CE = y0*x1
  ; ===========
  ld   b, (iy+3)      ; y0
  ld   c, d           ; x1
  mlt  bc
  add  hl, bc

  ; shift 8 bits via store+reload
  ld   (ix+1), hl
  ld   hl, (ix+2)

  ; ===========
  ; AF = x2*y0
  ; ===========
  ld   b, h           ; x2
  ld   c, (iy+3)      ; y0
  mlt  bc
  add  hl, bc

  ; ===========
  ; BE = y1*x1
  ; ===========
  ld   b, (iy+4)      ; y1
  ld   c, d           ; x1
  mlt  bc
  add  hl, bc

  ; ===========
  ; CD = y0*x2
  ; ===========
  ld   b, (iy+3)      ; y0
  ld   c, h           ; x2
  mlt  bc
  add  hl, bc

  ld   (ix+2), hl
  ld   hl, (ix+3)

  ; ===========
  ; BD = y1*x2
  ; ===========
  ld   b, (iy+4)
  ld   c, h
  mlt  bc
  add  hl, bc

  ; ===========
  ; AE = x2*y1
  ; ===========
  ld   b, h
  ld   c, (iy+4)
  mlt  bc
  add  hl, bc

  ld   (ix+3), hl
  ld   hl, (ix+4)

  ; ===========
  ; AD = x2*y2
  ; ===========
  ld   b, h           ; x2
  ld   c, l           ; y2
  mlt  bc
  add  hl, bc
  ld   (ix+4), hl

  ; --------------------
  ; Fixed24 scaling (same as original):
  ; keep middle 24 bits with 4-bit alignment
  ; --------------------
  ld   hl, (ix+2)     ; start from byte 2..3

  add  hl, hl         ; <<4
  add  hl, hl
  add  hl, hl
  add  hl, hl

  ld   (ix+2), hl
  ld   bc, (ix+2)

  ld   hl, 0
  ld   l, (ix+1)      ; byte just below

  srl  l              ; >>4
  srl  l
  srl  l
  srl  l

  add  hl, bc         ; HL = final magnitude

  ; --------------------
  ; apply sign if needed
  ; --------------------
  bit  0, e
  jr   z, .done_sign

  ; negate 24-bit at (ix..ix+2), then load back
  ld   (ix), hl

  ld   a, 0
  sub  a, (ix+0)
  ld   (ix+0), a

  ld   a, 0
  sbc  a, (ix+1)
  ld   (ix+1), a

  ld   a, 0
  sbc  a, (ix+2)
  ld   (ix+2), a

  ld   hl, (ix)

.done_sign:
  pop  iy
  pop  bc
  pop  ix
  ret



; Computes the square of a Fixed24 value and returns the new value in HL
_fp_sqr:
  push ix
  push bc
  push iy

  ld   iy, 0

  ; Align ix to below the stack. Zero-fill 48 bits
  ld   ix, -6          ; $FFFFFA
  add  ix, sp
  ld   (ix),  iy
  ld   (ix+2),iy

  ; Align iy to the argument on the stack
  ld   iy, 12
  add  iy, sp

  ; Take absolute value of x (iy+0..2)
  bit  7, (iy+2)
  jr   z, .abs_x_done_sqr

  ld   a, 0
  sub  a, (iy+0)
  ld   (iy+0), a
  ld   a, 0
  sbc  a, (iy+1)
  ld   (iy+1), a
  ld   a, 0
  sbc  a, (iy+2)
  ld   (iy+2), a
.abs_x_done_sqr:

  ; Cache components: A = x0, D = x1, H = x2
  ld   a, (iy+0)
  ld   d, (iy+1)
  ld   h, (iy+2)

  ; Multiply CC (x0*x0)
  ld   l, a
  mlt  hl              ; HL = CC

  ; Shift our answer over by 8 bits
  ld   (ix), hl
  ld   hl, (ix+1)

  ; Multiply 2 * BC (2*x0*x1)
  ld   b, d            ; x1
  ld   c, a            ; x0
  mlt  bc
  add  hl, bc
  add  hl, bc          ; *2

  ; Shift our answer over by 8 bits
  ld   (ix+1), hl
  ld   hl, (ix+2)

  ; Multiply 2 * AC (2*x0*x2)
  ld   b, h            ; x2
  ld   c, a            ; x0
  mlt  bc
  add  hl, bc
  add  hl, bc          ; *2

  ; Multiply BB (x1*x1)
  ld   b, d
  ld   c, d
  mlt  bc
  add  hl, bc

  ; Shift our answer over by 8 bits
  ld   (ix+2), hl
  ld   hl, (ix+3)

  ; Multiply 2 * AB (2*x1*x2)
  ld   b, d            ; x1
  ld   c, h            ; x2
  mlt  bc
  add  hl, bc
  add  hl, bc          ; *2

  ; Shift our answer over by 8 bits
  ld   (ix+3), hl
  ld   hl, (ix+4)

  ; Multiply AA (x2*x2)
  ld   b, h
  ld   c, h
  mlt  bc
  add  hl, bc

  ld   (ix+4), hl

  ; Grab the last 24 bits of our computation
  ld   hl, (ix+2)

  ; Shift hl left by 4 bits
  add  hl, hl
  add  hl, hl
  add  hl, hl
  add  hl, hl

  ld   (ix+2), hl
  ld   bc, (ix+2)

  ; Grab one byte below our 24 bit chunk
  ld   hl, 0
  ld   l, (ix+1)

  ; Shift hl right by 4 bits
  srl  l
  srl  l
  srl  l
  srl  l

  add  hl, bc

  pop  iy
  pop  bc
  pop  ix
  ret

; ---------------------------------------------------------
; int24_t fp_dot3(int24_t ax, int24_t ay, int24_t az,
;                 int24_t bx, int24_t by, int24_t bz)
;
; CEdev calling convention:
; Each int24_t is padded to 4 bytes.
;
; Stack layout (sp relative AFTER call):
;
;   sp+0..1   return address
;   sp+2..5   ax (low, mid, high, pad)
;   sp+6..9   ay
;   sp+10..13 az
;   sp+14..17 bx
;   sp+18..21 by
;   sp+22..25 bz
;
; Returns 24-bit Fixed24 in HL.
; ---------------------------------------------------------

_fp_dot3:
    push ix
    push iy
    push bc
    push de

    ld iy,0
    add iy,sp

    ; -------------------------
    ; X term: ax * bx
    ; -------------------------
    ; Push bx (low+mid, high)
    ld hl,(iy+14)      ; bx low+mid
    push hl
    ld a,(iy+16)       ; bx high
    push af

    ; Push ax
    ld hl,(iy+2)       ; ax low+mid
    push hl
    ld a,(iy+4)        ; ax high
    push af

    call _fp_mul       ; HL = ax*bx

    ; Pop 4 pushes (8 bytes)
    pop bc
    pop bc
    pop bc
    pop bc

    ex de, hl           ; DE = partial sum

    ; -------------------------
    ; Y term: ay * by
    ; -------------------------
    ld hl,(iy+18)      ; by low+mid
    push hl
    ld a,(iy+20)       ; by high
    push af

    ld hl,(iy+6)       ; ay low+mid
    push hl
    ld a,(iy+8)        ; ay high
    push af

    call _fp_mul       ; HL = ay*by

    pop bc
    pop bc
    pop bc
    pop bc

    add hl,de          ; accumulate
    ex de, hl

    ; -------------------------
    ; Z term: az * bz
    ; -------------------------
    ld hl,(iy+22)      ; bz low+mid
    push hl
    ld a,(iy+24)       ; bz high
    push af

    ld hl,(iy+10)      ; az low+mid
    push hl
    ld a,(iy+12)       ; az high
    push af

    call _fp_mul       ; HL = az*bz

    pop bc
    pop bc
    pop bc
    pop bc

    add hl,de          ; final sum in HL

    pop de
    pop bc
    pop iy
    pop ix
    ret