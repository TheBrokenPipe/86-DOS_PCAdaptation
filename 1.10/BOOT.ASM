; Boot sector for 86-DOS.

	ORG	7C00H

	JMP	INIT		;Intra-segment long jump

;
; Disk layout (BIOS Parameter Block)
;
	DB	"86DOS1.0"	;OEM identifier
	DW	512		;Sector size
	DB	1		;Sectors per block
	DW	16		;Reserved sectors
	DB	2		;Number of FATs
	DW	64		;Number of directory entries
	DW	320		;Total number of sectors
	DB	0FEH		;Media type
	DW	1		;Sectors per FAT
	DW	8		;Sectors per track
	DW	1		;Number of heads
	DW	0		;Number of hidden sectors
	DS	8		;Reserved
	DB	29H		;Extended BPB
	DS	4		;Volume serial number
	DB	"NO NAME    "	;Volume label
	DB	"FAT12   "	;File system ID

;
; Increments the BX pointer by SI sectors
;
INCDSTPTR:
	PUSH	AX		;Save AX
	PUSH	DX		;Save DX
	MOV	AX,SI		;Sectors read
	MOV	DI,200H		;Size of each sector
	MUL	AX,DI		;Bytes read
	ADD	BX,AX		;Add bytes read to BX
	POP	DX		;Restore DX
	POP	AX		;Restore AX
	RET

;
; Init boot loader
;
INIT:
;Setup temp stack
	CLI			;Disable interrupts
	MOV	AX,CS
	MOV	DS,AX		;DS = CS
	MOV	DX,0
	MOV	SS,DX		;SS = 0
	MOV	SP,7C00H	;SP = 7C00H
	STI			;Enable interrupts
;Setup segment registers
	MOV	AX,60H
	MOV	DS,AX		;DS = 60H
	MOV	ES,AX		;ES = 60H
	MOV	DX,0		;Drive 0
	MOV	AX,DX		;Function = reset disk system
	INT	13H		;Call disk BIOS service
	JC	DSKERR

;Load the first sector of the BIOS
	MOV	CX,15		;Sectors to load
	PUSH	CX		;Save it
	MOV	BX,0		;ES:BX = 0060:0000
	XOR	DX,DX		;Drive 0, head 0
	MOV	CX,2		;Track 0, sector 2
	MOV	SI,7		;7 sectors will be read the first time
	PUSH	SI		;Save it
	MOV	AL,7		;Read 7 sectors

READ:		;Reads some sectors to memory
	MOV	AH,2		;Function = disk read
	INT	13H		;Call disk BIOS service
	JC	DSKERR
	POP	SI		;Sectors read
	POP	AX		;Sectors to read
	CALL	INCDSTPTR	;Increment dest pointer
	SUB	AX,SI		;Decrement sectors to read
	JZ	BOOT		;All sectors read, boot it
	INC	CH		;Next track
	MOV	CL,1		;Back to first sector
	MOV	SI,8		;8 sectors to read
	CMP	AX,SI		;Compare sectors left with sectors to read
	JNB	MORELEFT	;Sectors left >= sectors to read
	MOV	SI,AX		;Just read the remaining ones
	JP	READAGAIN

MORELEFT:	;More sectors left than to read
	XCHG	SI,AX		;Swap them

READAGAIN:	;Reads the next group of sectors
	PUSH	SI		;Save sectors left
	PUSH	AX		;Save sectors to read
	JP	READ

BOOT:		;Finished loading, jump to BIOS
	JMP	0,60H		;Long jump to BIOS

DSKERR:		;Disk read error, boot to ROM BASIC
	MOV	SI,BOOTERRMSG	;Load boot error message
	MOV	AX,LDBASIC	;Offset of INT 18H
	PUSH	AX		;RET will return to BASIC

PRINT:	;Prints a string
	LODB			;Fetch char
	OR	AL,AL		;Check for zero
	JZ	PRINTDONE	;Yes, end of string
	PUSH	SI		;Save SI
	MOV	AH,0EH		;Function = write char
	MOV	BX,7		;Light gray and page number = 0
	INT	10H		;Call video BIOS service
	POP	SI		;Restore SI
	JP	PRINT

PRINTDONE:
	RET

;
; Code for loading ROM BASIC
;
LDBASIC:
	INT	18H

;
; Boot failure message
;
BOOTERRMSG:
	DB	13,10,"Disk Boot failure",13,10,0

	DS	7C00H+512-$-2
	DB	055H,0AAH	;Boot sector signature
