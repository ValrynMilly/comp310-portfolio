Code:
  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring

  
nam_att:
  .incbin "gates_lvl.nam"
  
;;;;;;;;;;;;;;;
   .rsset $0000  ;;start variables at ram location 0
x1          .rs 4
y1          .rs 1
y2          .rs 1
y3          .rs 1
y4          .rs 1
buttons1    .rs 1  ; player 1 gamepad buttons, one bit per button
CURRENT_DIRECTION      .rs 1  ;current sprite direction
FRAME_RIGHT   .rs 1                  ;start of current meta sprite
CURRENT_SPRITE   .rs 1            ;end of current meta sprite
NEXT_FRAME   .rs 1                  ;number of frames for each animation

FACING_LEFT = $00
FACING_RIGHT = $01
;;;;;;;;;;

    
  .bank 0
  .org $C000 
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0200, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0300, x
  STA CURRENT_DIRECTION
   STA FRAME_RIGHT
   STA CURRENT_SPRITE
   STA NEXT_FRAME
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2


LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $20, decimal 32 - copying 32 bytes = 8 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down
LoadSprites:
  
  LDX #$00              ; start at 0 
LoadSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$10              ; Compare X to hex $10, decimal 16
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero 

  LDA #%10000000   ; enable NMI, sprites from Pattern Table 1
  STA $2000

  LDA #%00010000   ; enable sprites
  STA $2001

Forever:
  JMP Forever     ;jump back to Forever, infinite loop
  
 

NMI:
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer
 
;buttons1 a b select start up down left right 
  JSR ReadController1 


Readup:
  LDA buttons1
  AND #%00001000  ; only look at bit 4 for up button
  BEQ Readupdone  ; branch to Readupdone if button is NOT pressed (0)
                  
  LDX #$00
allup:
  LDA $0200, x       ; load sprite X position
  SEC             ; make sure the carry flag is clear
  SBC #$01        ; A = A + 1
  STA $0200, x       ; save sprite X position
  INX
  INX
  INX
  INX  
  CPX #$10
  BNE allup
Readupdone:

Readdown:
  LDA buttons1
  AND #%00000100  ; only look at bit 3
  BEQ Readdowndone   ; branch to ReadADone if button is NOT pressed (0)

  LDX #$00
alldown:  
  LDA $0200, x       ; load sprite X position
  CLC             ; make sure the carry flag is clear
  ADC #$01        ; A = A + 1
  STA $0200, x       ; save sprite X position
  INX
  INX 
  INX
  INX
  CPX #$10
  BNE alldown
Readdowndone:        ; handling this button is done

Readleft: 
  LDA buttons1       ; player 1 - left
  AND #%00000010  ; only look at bit 0
  BEQ ReadleftDone   ; branch to ReadBDone if button is NOT pressed (0)

  LDX #$00
FlipSprite:
  LDA CURRENT_DIRECTION  ;if already facing left, no need to flip
  CMP #FACING_LEFT
  BEQ endFlip

  LDA $0203      ;To mirror the sprite to the left, must add 16 or $10 to the left half sprites, tiles 32 & 34
  CLC
  ADC #$10
  STA $0203
  LDA $020B
  CLC
  ADC #$10
  STA $020B
endFlip:
allleft:
  LDA $0203, x       ; load sprite X position
  SEC             ; make sure carry flag is set
  SBC #$01        ; A = A - 1
  STA $0203, x       ; save sprite X position
  LDA $0202, x       ;flip the sprite horizontally
  ORA #$40                   ;flip the sprite horizontally
  STA $0202, x        ;flip the sprite horizontally
  INX
  INX
  INX
  INX
  CPX #$10
  BNE allleft

  LDA #FACING_LEFT   ; make sure the saved direction is facing left
  STA CURRENT_DIRECTION
   LDA #$00
   STA FRAME_RIGHT
   STA NEXT_FRAME
   LDA #$10
   STA CURRENT_SPRITE
  
ReadleftDone:        ; handling this button is done

Readright:
 LDA buttons1 ; player 1 -right
 AND #%00000001  ; only look at bit 0
  BNE FlipSpriteRight
  jmp ReadrightDone   ; branch to ReadADone if button is NOT pressed (0)

FlipSpriteRight:
  LDA CURRENT_DIRECTION  ;if already facing right, no need to flip
  CMP #FACING_RIGHT
  BEQ endFlipRight
              ;Otherwise we need to flip the sprites and adjust the position after flipping
  LDA $0203      ;To mirror the sprite to the left, must add 16 or $10 to the left half sprites, tiles 32 & 34
  SEC
  SBC #$10
  STA $0203
  LDA $020B
  SEC
  SBC #$10
  STA $020B
   
   LDX #$00
AddRightMotion:  ; when you switch facing direction, make him move slightly right so it looks like he turned around
   LDA $0203, x
   CLC
   ADC #$08
   STA $0203, x
   INX
   INX
   INX
   INX
   CPX #$10
   BNE AddRightMotion 
endFlipRight:
  
  jsr SaveXPosition
  jsr SaveYPosition
   
LoadSprites2:
  
  LDX FRAME_RIGHT             ; start animation frame 
  LDY #$00
   
LoadSpritesLoop2:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, y          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1 
  INY 
  CPX CURRENT_SPRITE             ; Compare X to end of current meta sprite
  BNE LoadSpritesLoop2   ; Branch to LoadSpritesLoop if compare was Not Equal to zero

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  jsr RestoreXPosition
  jsr RestoreYPosition
  LDX #$00
allright:
  LDA $0203, x       ; load sprite X position
  CLC             ; make sure the carry flag is clear
  ADC #$02        ; A = A + 1
  STA $0203, x       ; save sprite X position
  INX
  INX
  INX
  INX
  CPX #$10
  BNE allright
   
   LDA NEXT_FRAME  ;animate the character
   ;EOR #$FF
   ;STA NEXT_FRAME
   ;CMP #$00
   ;BEQ continue
   CLC
   ADC #$01
   STA NEXT_FRAME
   CMP #$03         
   BMI keep_frame
   
   LDA FRAME_RIGHT      ;Move on to the next meta sprite
   CLC
   ADC #$10
   STA FRAME_RIGHT
   CLC
   ADC #$10
   STA CURRENT_SPRITE  ;Also move the comparison so we only load 1 meta sprite
   LDA FRAME_RIGHT
   CMP #$30
   BNE next_frame
   
reset_frame:
  LDA #$00               ;the initial meta sprite
   STA FRAME_RIGHT
   LDA #$10
   STA CURRENT_SPRITE  ;the end of the initial meta sprite
  
next_frame:
   LDY #$00
   STY NEXT_FRAME
keep_frame:
  LDA #FACING_RIGHT   
  STA CURRENT_DIRECTION
ReadrightDone:        ; handling this button is done
  

NoButton:  
  LDA buttons1
  AND #%11111111      ; no buttons were pressed so A = 00000000
  BNE NoButtonDone
  
  LDA CURRENT_DIRECTION              ;if facing left, then leave facing left
  CMP #FACING_LEFT
  BEQ NoButtonDone 
  
  LDY #FACING_RIGHT    ;save the current facing direction
  STY CURRENT_DIRECTION
  
  ;store again the x & y coordinates of all sprites
  jsr SaveXPosition
  jsr SaveYPosition
   
StandStill:
  LDX #$00              ; start at 0 
StandSprites:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$10              ; Compare X to hex $10, decimal 16
  BNE StandSprites   ; Branch to LoadSpritesLoop if compare was Not Equal to zero

  jsr RestoreXPosition
  jsr RestoreYPosition
   
   LDA #$00
   STA FRAME_RIGHT
   STA NEXT_FRAME
   LDA #$10
   STA CURRENT_SPRITE
 
NoButtonDone:
  
  RTI             ; return from interrupt
 
 
ReadController1:
  LDA #$01   ; latch controller
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
ReadController1Loop:
  LDA $4016
  LSR A            ; bit0 -> Carry
  ROL buttons1     ; bit0 <- Carry
  DEX
  BNE ReadController1Loop
  RTS
  
SaveXPosition:
  LDA $0203
  STA x1
  LDA $0207
  STA x1+1
  LDA $020B
  STA x1+2
  LDA $020F
  STA x1+3
  rts
  
SaveYPosition:
  LDA $0200
  STA y1
  LDA $0204
  STA y2
  LDA $0208
  STA y3
  LDA $020C
  STA y4
  rts
  
RestoreXPosition:
  LDA x1
  STA $0203
  LDA x1+1
  STA $0207
  LDA x1+2
  STA $020B
  LDA x1+3
  STA $020F
  rts
  
RestoreYPosition:
  LDA y1
  STA $0200
  LDA y2
  STA $0204
  LDA y3
  STA $0208
  LDA y4
  STA $020C
  rts
  
  
  .bank 1
  .org $E000
palette:
  .db $0F,$17,$28,$39,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$0F
  .db $0F,$17,$28,$39,$31,$02,$38,$3C,$0F,$1C,$15,$14,$31,$02,$38,$3C

sprites:
     ;vert tile attr horiz
  .db $80, $00, $00, $80   ;sprite 0
  .db $80, $01, $00, $88   ;sprite 1
  .db $88, $34, $00, $80   ;sprite 2
  .db $88, $35, $00, $88   ;sprite 3
  .db $80, $36, $00, $90   ;sprite 4
  .db $80, $37, $00, $98   ;sprite 5
  .db $88, $38, $00, $90   ;sprite 6
  .db $88, $39, $00, $98   ;sprite 7
  .db $80, $3A, $00, $90   ;sprite 8
  .db $80, $3B, $00, $98   ;sprite 9
  .db $88, $3C, $00, $90   ;sprite 10
  .db $88, $3D, $00, $98   ;sprite 11

  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial
  
  
;;;;;;;;;;;;;;  
  
  
  .bank 2
  .org $0000
  .incbin "GatesR2.chr"   ;includes 8KB graphics file from SMB1