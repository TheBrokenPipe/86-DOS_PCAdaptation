FCB	EQU	5CH

	ORG	100H
	JMP	START
SECS:
	DW	4	;Patch for different configs

; Creates an unopened FCB.
; All registers preserved. All flags destroyed.
;
; BP	Pointer to FCB
; BX	Filename
; DL	Drive number (A = 1; B = 2; ...)
; Req.	CS = DS = ES

MAKEFCB:
	PUSH	CX
	PUSH	SI
	PUSH	DI
	CALL	UNOPENFCB
	MOV	[BP],DL
	MOV	CX,11
	MOV	SI,BX
	MOV	DI,BP
	INC	DI
	REP
	MOVB
	POP	DI
	POP	SI
	POP	CX


; Unopens a FCB.
; All registers preserved. All flags destroyed.
;
; BP	Pointer to FCB
; Req.	CS = DS

UNOPENFCB:
	PUSH	BP
	PUSH	CX
	ADD	BP,12		;Skip to after file name
	MOV	CX,24		;24 bytes to zero

ZEROFCB:
	MOV	B,[BP],0
	INC	BP
	LOOP	ZEROFCB
	POP	CX
	POP	BP
	RET


; Checks for the existence of a file.
; All registers except for AX preserved. All flags destroyed.
;
; BX	Filename
; DL	Drive number (A = 1; B = 2; ...)
; Req.	CS = DS = ES
;
; AL = 0 if file is found, otherwise AL = 0FFH.

CHECKEXIST:
	PUSH	BP
	MOV	BP,SRCFCB
	CALL	MAKEFCB
	POP	BP
	PUSH	DX
	MOV	AH,0FH
	MOV	DX,SRCFCB
	INT	21H
	TEST	AL,AL
	JNZ	NOTFOUND
	XOR	AL,AL
	POP	DX
	RET

NOTFOUND:
	MOV	AL,0FFH
	POP	DX
	RET


; Compares 2 FCB-styled file names.
; All registers except for AX preserved. All flags destroyed.
;
; SI	File name 1
; DI	File name 2
; Req.	DS = ES
;
; AL = 0 if 2 names match, otherwise AL = 0FFH.

NAMECMP:
	PUSH	CX
	PUSH	SI
	PUSH	DI
	MOV	CX,11
	REPE
	CMPB
	MOV	AL,0
	JE	MATCH
	DEC	AL
MATCH:
	POP	DI
	POP	SI
	POP	CX
	RET


; Checks whether a disk has room for system files.
; All registers except for AX preserved. All flags destroyed.
;
; DL	Drive number (A = 1; B = 2; ...)
; Req.	CS = DS = ES
;
; AL = 0FFH if disk is empty, AL = 0 if disk has room for system
; files and otherwise AL = 1.

CHECKDISK:
	MOV	[SEARCHFCB],DL
	PUSH	BP
	MOV	BP,SEARCHFCB
	CALL	UNOPENFCB
	POP	BP
	PUSH	DX
	MOV	DX,NAMEFCB
	MOV	AH,26
	INT	21H
	MOV	DX,SEARCHFCB	;Load search FCB
	MOV	AH,11H
	INT	21H		;Search for files
	POP	DX
	OR	AL,AL
	JNZ	RET		;Nothing on disk, return -1
	PUSH	SI
	PUSH	DI
	MOV	DI,BIONAME
	MOV	SI,NAMEFCB	;+1 for 0.34
	CALL	NAMECMP
	POP	DI
	POP	SI
	OR	AL,AL
	JNZ	BADSYS		;Not IO.SYS, return 1
	PUSH	DX
	MOV	DX,SEARCHFCB
	MOV	AH,12H
	INT	21H
	POP	DX
	OR	AL,AL
	JNZ	BADSYS		;No next file, return 1
	PUSH	SI
	PUSH	DI
	MOV	DI,DOSNAME
	MOV	SI,NAMEFCB	;+1 for 0.34
	CALL	NAMECMP
	POP	DI
	POP	SI
	OR	AL,AL
	JNZ	BADSYS		;Not 86DOS.SYS
	RET

BADSYS:
	MOV	AL,1
	RET


; Copies a file from SRCFCB to DSTFCB.
; AX, BX, CX, DX destroyed. All flags destroyed.
;
; AL = 0 if copy succeeded, otherwise 0FFH.

COPY:
	MOV	DX,SRCFCB
	MOV	AH,0FH		;Open
	INT	33
	MOV	DX,DSTFCB
	MOV	AH,22		;Create
	INT	33
	MOV	DX,END
	MOV	AH,26
	INT	33
	MOV	W,[SRCFCB+33],0
	MOV	W,[DSTFCB+33],0

CPYBLK:
	MOV	DX,SRCFCB
	MOV	CX,[NUMREC]
	MOV	AH,39
	INT	33
	JCXZ	CPYDONE
	MOV	DX,DSTFCB
	MOV	AH,40
	INT	33
	OR	AL,AL
	JZ	CPYBLK		;Write succeeded
	MOV	DX,DSTFCB
	MOV	AH,16		;Close
	INT	33
	MOV	AL,0FFH
	RET

CPYDONE:
	MOV	DX,DSTFCB
	MOV	AH,16
	INT	33
	XOR	AL,AL
	RET


START:
	MOV	SP,STACK
	CLD
	MOV	AX,CS
	MOV	SS,AX
	MOV	ES,AX
	MOV	DS,AX
	MOV	CX,[6]
	SUB	CX,END
	AND	CL,80H		;Round down
	ROL	CX
	XCHG	CH,CL
	MOV	[NUMREC],CX	;Number of records each time
	MOV	AL,[FCB]
	OR	AL,AL
	JNZ	TMPA
	JMP	BADDRV

TMPA:
	DEC	AL
	JNZ	TMPB
	JMP	BADDRV

TMPB:
	MOV	BX,BIONAME
	MOV	DL,1
	CALL	CHECKEXIST
	OR	AL,AL
	JNZ	NOSYSONSRC	;No A:IO.SYS
	MOV	BX,DOSNAME
	CALL	CHECKEXIST
	OR	AL,AL
	JNZ	NOSYSONSRC	;No A:86DOS.SYS
	MOV	DL,[FCB]
	CALL	CHECKDISK	;Check dest disk
	CMP	AL,1
	JZ	NOROOMDST	;No room, error out
	OR	AL,AL
	JNZ	DOCOPY		;Nothing on dest, copy
	MOV	BP,DSTFCB
	MOV	BX,BIONAME
	MOV	DL,[FCB]
	CALL	MAKEFCB
	MOV	AH,13H		;Delete IO.SYS
	MOV	DX,BP
	INT	21H
	MOV	BX,DOSNAME
	MOV	DL,[FCB]
	CALL	MAKEFCB
	MOV	AH,13H		;Delete 86DOS.SYS
	MOV	DX,BP
	INT	21H
	JP	DOCOPY

NOROOMDST:
	MOV	DX,NOROOM
	JP	QUIT

NOSYSONSRC:
	MOV	DX,NOSRC
	JP	QUIT

DOCOPY:
	MOV	BX,BIONAME
	MOV	BP,SRCFCB
	MOV	DL,1
	CALL	MAKEFCB
	MOV	BP,DSTFCB
	MOV	DL,[FCB]
	CALL	MAKEFCB
	CALL	COPY
	OR	AL,AL
	JZ	TMPC
	JMP	NOROOM

TMPC:
	MOV	BX,DOSNAME
	MOV	BP,SRCFCB
	MOV	DL,1
	CALL	MAKEFCB
	MOV	BP,DSTFCB
	MOV	DL,[FCB]
	CALL	MAKEFCB
	CALL	COPY
	OR	AL,AL
	JZ	TMPD
	JMP	NOROOM

TMPD:
;Original code
	MOV	AL,[FCB]
	DEC	AL
	MOV	[FCB],AL
	MOV	CX,[SECS]
	MOV	DX,0
	MOV	BX,END
	MOV	AL,0
	INT	37
	JC	RDERR
	POPF
	MOV	CX,[SECS]
	MOV	DX,0
	MOV	BX,END
	MOV	AL,[FCB]
	MOV	AH,1
	INT	38
	JC	WRERR
	MOV	DX,TRANSOK
	JP	QUIT

RDERR:
	MOV	DX,RDERMSG

QUIT:
	MOV	AH,9
	INT	33
	INT	32

WRERR:
	MOV	DX,WRERMSG
	JP	QUIT

BADDRV:
	MOV	DX,BADDRVMSG
	JP	QUIT

TRANSOK:
	DB	"System transfered$"
RDERMSG:
	DB	"Disk read error$"
WRERMSG:
	DB	"Disk write error$"
BADDRVMSG:
	DB	"Bad drive specification$"
NOSRC:
	DB	"No system on drive A$"
NOROOM:
	DB	"No room for system$"

BIONAME:
	DB	"IO      SYS"

DOSNAME:
	DB	"86DOS   SYS"

SEARCHFCB:
	DB	0
	DB	"???????????"
	DS	24

SRCFCB:
	DS	36

DSTFCB:
	DS	36

NAMEFCB:
	DS	36

	DS	128
STACK:

NUMREC:
	DS	2

END:
