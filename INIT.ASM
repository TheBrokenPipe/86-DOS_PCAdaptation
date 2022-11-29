; Disk initialization routine for the IBM PC.
; Runs on 8086 under 86-DOS.  Revised 11-24-81.
;
; Translated from the Z80 on 12-19-80 and subsequently modified to init
; IBM PC disks.
;

CONIN:	EQU	1
OUTSTR:	EQU	9
SELDRV:	EQU	14

RESET:	EQU	0
TRKFMT:	EQU	5

	ORG	100H
	PUT	100H

	JP	INIT
HEADER:
	DB	13,10,'Disk INIT version 1.1',13,10,'$',26
INIT:
	MOV	AH,OUTSTR
	MOV	DX,HEADER
	INT	33
	MOV	DX,WARNING
	INT	33
EACH:
	MOV	SP,STACK
	MOV	AH,OUTSTR
	MOV	DX,DRVMES
	INT	33
	MOV	AH,CONIN
	INT	33		; Get drive letter from console.
	CMP	AL,13		; Return to 86-DOS if CR.
	JNE	CHECKDRIVE
	INT	32
CHECKDRIVE:
	AND	AL,5FH		; Force upper case.
	SUB	AL,'A'
	JC	EACH

; Check if valid drive.

	MOV	DH,AL
	MOV	DL,-1
	MOV	AH,SELDRV
	INT	33		; Get number of drives.
	CMP	DH,AL
	JAE	EACH		; Jump if drive number too big.
	MOV	DL,DH		; Set DL to drive number.
	CALL	FMTDSK
	JNC	EACH
	MOV	AH,OUTSTR
	MOV	DX,ERRMES
	INT	33
	JP	EACH

;
; Format a 5.25" SSDD floppy disk with 8 SPT.
;
FMTDSK:
	MOV	BX,PATTERN
	XOR	AX,AX
	MOV	CX,40		; 40 tracks.
	MOV	DH,3		; Minimum 3 retries.
FMTEACH:
	PUSH	CX
	MOV	CL,8		; 8 sectors per track.
	MOV	CH,2		; 512-byte sectors.
	CALL	FMTTRK
	JC	FMTERR
	INC	AL
	POP	CX
	LOOP	FMTEACH
FMTDONE:
	RET
FMTERR:
	POP	CX
	JP	FMTDONE
;
; Format a track.
;
; This can possibly be turned into a BIOS or DOS function, so we need
; to ensure that all registers are preserved. This function sets track
; address fields automatically, all you need is ES:BX with 4 * SPT bytes.
;
; AL    - track number
; AH    - head number
; CL    - sectors per track
; CH    - sector size (0 = 128, 1 = 256, 2 = 512, 3 = 1024)
; DL    - drive number
; DH    - number of retries on error
; ES:BX - buffer with 4 * CL bytes
;
; On return:
;     CF = 0 <= success
;     CF = 1 <= error
;
FMTTRK:
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSHF
; Build address field list.
	PUSH	CX		; CX - SPT+SIZE, now use as loop counter.
	PUSH	DX		; DX - DRV+RETRIES, now use as sect counter.
	MOV	DH,1		; Sect count starts at 1.
	PUSH	BX		; BX - buffer ptr, will increment it.
	PUSH	DI		; DI - unused, now use as TRK+HEAD.
	MOV	DI,AX
	PUSH	AX		; AX - TRK+HEAD, now use as SIZE backup.
	MOV	AH,CH
	XOR	CH,CH		; Clear high byte, only sect count left.
BLDLIST:
	SEG	ES
	MOV	[BX],DI		; Set track and head number.
	MOV	B,[BX+2],DH	; Set sector number.
	MOV	B,[BX+3],AH	; Set sector size.
	INC	DH
	ADD	BX,4
	LOOP	BLDLIST
	POP	AX		; List built, restore registers.
	POP	DI
	POP	BX
	POP	DX
	POP	CX
; Setup variables for INT 19.
	PUSH	BX
	MOV	BL,CL		; BL = sectors per track.
	MOV	CH,AL		; CH = track number.
	XOR	CL,CL		; Make some oddball clones happy.
	MOV	SI,DX		; SI = DRV+RETRIES.
	MOV	DH,AH		; DH = head number.
	MOV	AL,BL		; AL = sectors per track.
	MOV	BX,SI		; BX = SI.
	XCHG	BL,BH		; Swap bytes.
	XOR	BH,BH		; Clear high byte.
	MOV	SI,BX		; SI = retries.
	POP	BX
TRYFMT:
	MOV	AH,TRKFMT
	INT	19		; Format track.
	JC	TRKERR
	JP	BAKFLAG
TRKERR:
	PUSH	AX
	MOV	AH,RESET
	INT	19		; Reset after error.
	POP	AX
	DEC	SI
	JZ	SETERR		; No retries left.
	CMP	AH,80H		; Check if error is time out.
	JZ	SETERR		; Will take too long, just error out.
	JP	TRYFMT
SETERR:
	POPF
	STC
	JP	TRKDONE
BAKFLAG:
	POPF
TRKDONE:
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET

PATTERN:
	DS	32		; 4*8 bytes.

WARNING:DB	"Completely re-formats any bad disk - "
	DB	"destroying its contents, of course!",13,10,"$"
DRVMES:	DB	13,10,"Initialize disk in which drive? $"
ERRMES:	DB	13,10,10,"ERROR - Not ready or write protected",13,10,"$"
	DS	200H		; Should never overflow again.
	ALIGN
STACK:	EQU	$
