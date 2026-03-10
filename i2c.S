; TODO: Setup cursor position and draw an ascii character on screen
; TODO: Choose internal registers to be used to pass data between routines by value
; TODO: Utility routines to handle 4-bit transfers of data 
; TODO: Convert the HITACHI instructions to the P0-7 bits required to send the instructions
; TODO: What data do I have to send to write a char to the lcd display


; TODO: Setup a busy flag read instruction to determine when to call a write instruction
; TODO: Setup entry mode set

; NOTE: Responses and start stop conditions are done via TWCR
; NOTE: Why does writting to DDRAM when AC = 0 not produce the letter H ????
; NOTE: Know where the AC will be after we write to DDRAM

; IMPORTANT: LCD isn't ready for transmission after we've called ReturnHome and are ready to send more data and we can't just wait n amount of
; IMPORTANT: Initi the LCD to 4-bit Interface via FunctionSet routine because default is 8
; NOTE: Read the Documenation more carefully next time


#define RAM_START_H 0x08
#define RAM_START_L 0xff

;stack pointer high/low (relative addresses)bytes
#define SPH 0x3E
#define SPL 0x3D

#define TWCR 0xBC
#define TWDR 0xBB
#define TWSR 0xB9
#define TWBR 0xB8
; ^^^ Two-wire(I2C) Bit rate generator register

;Two-wire control register flags(bit positions)
#define TWINT 7
#define TWEA  6
#define TWSTA 5
#define TWSTO 4
#define TWWC  3
#define TWEN  2
#define TWIE  0

;Relative register addresses (add 0x20 to the register address to get its absolute address)
#define PINB 0x03
#define DDRB 0x04
#define PORTB 0x05

#define PINC 0x06
#define DDRC 0x07
#define PORTC 0x08

#define PIND 0x09
#define DDRD 0x0A
#define PORTD 0x0B

;Master Transmiter Mode Status Codes(when prescaler bits are all 0)
#define PRESCALER_BITS_MASK 0xF8
#define START 0x08

;Slave adresses page.5 7.11 PCF8754 piggyback board address map of manual
#define SLAVE_WRITE_ADDRESS 0x4E
#define SLAVE_READ_ADDRESS 0x4F

#define RECIEVED 0x18
#define NOT_RECIEVED 0x20

#define DATA_RECIEVED 0x28
#define DATA_NOT_RECIEVED 0x30

;Master Reciever Mode Status Codes(when prescaler bits are all 0)
#define REPEATED_START 0x10
#define ARBITRATION_LOST 0x38
#define SLAVE_READ_ADDRESS_RECIEVED 0x40
#define SLAVE_READ_ADDRESS_FAILED 0x48
#define SLAVE_READ_DATA_RECIEVED 0x50
#define SLAVE_READ_DATA_FAILED 0x58

;SLAVE READ/WRITE INST/DATA. LCD Hitachi HD44780U instructions Reference Table 6 on p.24 of manual

#define DRIVER_PINS_VALUE(BackLight, Enable, RegisterSelect, ReadWrite) (BackLight << 3) | (Enable << 2) | (RegisterSelect << 1) | (ReadWrite << 0)
#define BIT_NIBBLE_PACKAGE(B4, B3,B2, B1) (B4 << 7) | (B3 << 6) | (B2 << 5) | (B1 << 4)

;Send instructions to LCD
#define BEGIN_SEND 		DRIVER_PINS_VALUE(1,1,0,0)
#define END_SEND 		  DRIVER_PINS_VALUE(1,0,0,0)

;---RETURN HOME MACROS---
#define RH1 0x00 | DRIVER_PINS_VALUE(1,1,0,0)
#define RH2 0x00 | DRIVER_PINS_VALUE(1,0,0,0)
#define RH3 (1 << 5) | DRIVER_PINS_VALUE(1,1,0,0)
#define RH4 (1 << 5) | DRIVER_PINS_VALUE(1,0,0,0)

;---TURN DISPLAY MACROS---
#define TDH1T 0x00 | DRIVER_PINS_VALUE(1,1,0,0)
#define TDH2T 0x00 | DRIVER_PINS_VALUE(1,0,0,0)
#define TDH3T(Display, Cursor, Blinking) ( 1 << 7) | (Display << 6) | (Cursor << 5) | (Blinking << 4) | DRIVER_PINS_VALUE(1,1,0,0)
#define TDH4T(Display, Cursor, Blinking) ( 1 << 7) | (Display << 6) | (Cursor << 5) | (Blinking << 4) | DRIVER_PINS_VALUE(1,0,0,0)

;Write to DDRAM at address (Address Counter)
#define BEGIN_DATA_BYTE_TRANSFER(B4, B3, B2, B1)	BIT_NIBBLE_PACKAGE(B4, B3,B2, B1) | DRIVER_PINS_VALUE(1, 1, 1, 0)
#define END_DATA_BYTE_TRANSFER(B4, B3, B2, B1)	  BIT_NIBBLE_PACKAGE(B4, B3,B2, B1) | DRIVER_PINS_VALUE(1, 0, 1, 0)

;---I2C START/STOP CONDITIONS
#define START_COND 			 (1 << TWINT) | (1 << TWSTA) | (0 << TWSTO) | (1 << TWEN)
#define STOP_COND			   (1 << TWINT) | (0 << TWSTA) | (1 << TWSTO) | (1 << TWEN)
#define SEND_NACK			   (1 << TWINT) | (0 << TWSTA) | (0 << TWSTO) | (1 << TWEN)
#define SEND_ACK				(1 << TWINT) | (1 << TWEA)  | (1 << TWEN)


; ------------------.text Main section START--------------------

Main:
;Set the SCL frequency(It has to be no higher than the max frequency of the slave)
	ldi r16, 4
	sts TWSR, r16
	ldi r16, 18
	sts TWBR, r16

;Initialize the Stack Pointer to point to start(HIGHEST address) of SRAM
	ldi r16, RAM_START_H
	out SPH, r16									   
	ldi r16, RAM_START_L
	out SPL, r16
	sei

;Startup the I2C interface of Atmega328p
	rcall Sleep 								;Give time to LCD to initialize itself
	rcall InitializeTwoWireSerialInterface
	rcall CheckTWINTFlagSet
	rcall CheckTWSR

;Transmit Master->Slave Address
	rcall SendSlaveAddress
	rcall CheckTWINTFlagSet
	rcall CheckAckBit

	rcall FunctionSet
	

;REPEATED START WRITE
	rcall CheckTWINTFlagSet
	rcall CheckRepeatedStartTWSR

	rcall SendSlaveAddress
	rcall CheckTWINTFlagSet
	rcall CheckAckBit

	rcall ClearDisplay

;REPEATED START WRITE
	rcall CheckTWINTFlagSet
	rcall CheckRepeatedStartTWSR

	rcall SendSlaveAddress
	rcall CheckTWINTFlagSet
	rcall CheckAckBit

	rcall TurnDisplay

	rcall SendStopCondition


MainLoop:	
	rjmp MainLoop

; ------------------.text Main section END--------------------


DebugRegState:
	mov r18, r7
	lsl r18
	mov r5, r18
	rcall WriteToSlave

	mov r18, r8
	lsl r18
	mov r5, r18										;Data for SendSlaveData routine
	ldi r17, START_COND
	mov r11, r17			   						;Data for CheckAckBitDataLastByte which sets up the repsonse set to slave
	rcall WriteToSlaveLastByte

	ret

FunctionSet:
	ldi r18, BIT_NIBBLE_PACKAGE(0,0,1,0) | BEGIN_SEND
	mov r5, r18
	rcall WriteToSlave

	ldi r18, BIT_NIBBLE_PACKAGE(0,0,1,0) | END_SEND
	mov r5, r18
	rcall WriteToSlave
	
	ldi r18, BIT_NIBBLE_PACKAGE(1,0,0,0) | BEGIN_SEND
	mov r5, r18
	rcall WriteToSlave

	ldi r18, BIT_NIBBLE_PACKAGE(1,0,0,0) | END_SEND
	mov r5, r18										;Data for SendSlaveData routine
	ldi r17, START_COND
	mov r11, r17			   						;Data for CheckAckBitDataLastByte which sets up the repsonse set to slave
	rcall WriteToSlaveLastByte

	ret

SendStopCondition:
	ldi r16, STOP_COND
	sts TWCR, r16	

	ret

SendStartCondition:
	ldi r16, START_COND
	sts TWCR, r16	

	ret

ReadBusyFlag:
	rcall CheckTWINTFlagSet
	rcall CheckRepeatedStartTWSR

	rcall SendSlaveReadAddress
	rcall CheckTWINTFlagSet
	rcall CheckReadAckBit

	rcall ReceiveSlaveData
	rcall CheckTWINTFlagSet
	rcall CheckReadAckBitData

	mov r7, r6

	rcall ReceiveSlaveDataLastByte
	rcall CheckTWINTFlagSet
	rcall CheckReadAckBitDataLastByte

	mov r8, r6
	
	rcall SendStartCondition

	ret

SendBLERSRWPinBits:
	sts TWDR, r10
	ldi r16, (1 << TWINT) | (1 << TWEN)
	sts TWCR, r16
	rcall CheckTWINTFlagSet

	ret

InitializeTwoWireSerialInterface:
	ldi r16, (1 << TWINT) | (1 << TWSTA) | (1 << TWEN) | (0 << TWEA)
	sts TWCR, r16			 						;store value in TWCR memory (Extended I/O register)
	ret

CheckTWSR:
	lds r18, TWSR									 ;load data from addr (TWSR) to r18
	andi r18, PRESCALER_BITS_MASK					 ;bitmask used to ignore prescaler  bits
	cpi r18, START									
	brne BlinkCall									;jump to Blink if r18 and START don't match
	ret

CheckTWINTFlagSet:
	lds r16, TWCR
	sbrs r16, TWINT 							 	 ;skip next inst if the bit at pos TWINT is set to 1
	rjmp CheckTWINTFlagSet	    					;if built-in led not blinking then we're stuck in this loop
	ret

CheckRepeatedStartTWSR:
	lds r18, TWSR									 ;load data from addr (TWSR) to r18
	andi r18, PRESCALER_BITS_MASK					 ;bitmask used to ignore prescaler  bits
	cpi r18, REPEATED_START
	brne Blink										;jump to Blink if r18 and START don't match
	ret

SendSlaveAddress:
	ldi r18, SLAVE_WRITE_ADDRESS	    			   	   
	sts TWDR, r18									 ;write to TWDR
	ldi r16, (1 << TWINT) | (1 << TWEN)
	sts TWCR, r16									 ;set TWINT to 1 in TWCR to send data in TWDR  down the SDA line
	ret

SendSlaveReadAddress:
	ldi r18, SLAVE_READ_ADDRESS	    			   	    ;load SLA+R address send over I2C
	sts TWDR, r18									 ;write to TWDR
	ldi r16, (1 << TWINT) | (1 << TWEN)
	sts TWCR, r16									 ;set TWINT to 1 in TWCR to send data in TWDR  down the SDA line
	ret

CheckAckBit:
	lds r18, TWSR
	andi r18, RECIEVED							    ;check if SLA+W byte has been recieved and ACK bit is 1 ( by using an AND mask to check state of specific bits)
	cpi r18, RECIEVED
	brne BlinkFast									;jump to BlinkFast if the bits at positions m,n dont match 0x18 TWSR != 0x18(Status Code for slave address + write bit set recieved by slave)
	ret

CheckReadAckBit:
	lds r18, TWSR
	cpi r18, SLAVE_READ_ADDRESS_RECIEVED
	brne BlinkFast									;jump to BlinkFast if the bits at positions m,n dont match 0x18 TWSR != 0x18(Status Code for slave address + write bit set recieved by slave)
	ret

CheckAckBitData:
	lds r18, TWSR
	cpi r18, DATA_NOT_RECIEVED
	breq BlinkFast
	ret

BlinkCall:
	rjmp Blink

CheckReadAckBitData:
	lds r18, TWSR
	cpi r18, SLAVE_READ_DATA_FAILED
	breq BlinkFast
	ret

CheckReadAckBitDataLastByte:
	lds r18, TWSR
	cpi r18, SLAVE_READ_DATA_FAILED
	brne BlinkCall
	ret

SendSlaveData:
	sts TWDR, r5
	ldi r16, (1 << TWINT) | (1 << TWEN) ;Clear the interrupt flag and enable Two-wire interface
	sts TWCR, r16

	ret

ReceiveSlaveData:
	lds r6, TWDR
	ldi r16, SEND_ACK
	sts TWCR, r16

	ret

ReceiveSlaveDataLastByte:
	lds r6, TWDR
	ldi r16, SEND_NACK
	sts TWCR, r16

	ret

;=================DEBUG ROUTINES USING THE ARDUINO LED======================
Blink:
	ldi r19, 10

Blink1:
	ldi r20, (1 << 5)
	out PORTB, r20 ;out inst works with relative addresses (0x00 has abs.addr 0x20)
	out DDRB, r20	 			
	mov r21, r20

Repeat:
	eor r20, r21		   ;set LED bit on/off
	out PORTB, r20
	ldi r22, 255
	ldi r23, 255
	mov r24, r19

Delay:
	dec r22
	brne Delay
	dec r23
	brne Delay
	dec r24
	brne Delay
	rjmp Repeat

BlinkSlow:
	ldi r19, 100
	rjmp Blink1

BlinkFast:
	ldi r19, 2
	rjmp Blink1

BCall:
	rjmp BlinkSlow
;=====================================================================================

WriteToSlave:
	rcall SendSlaveData
	rcall CheckTWINTFlagSet
	rcall CheckAckBitData

	ret

WriteToSlaveLastByte:
	rcall SendSlaveData
	rcall CheckTWINTFlagSet
	rcall CheckAckBitDataLastByte

	ret

CheckAckBitDataLastByte:
	lds r18, TWSR
	cpi r18, DATA_RECIEVED
	brne BCall
	mov r16, r11
	sts TWCR, r16

	ret

ClearDisplay:
	ldi r18, 0x00 | BEGIN_SEND
	mov r5, r18
	rcall WriteToSlave

	ldi r18, 0x00 | END_SEND
	mov r5, r18
	rcall WriteToSlave
	
	ldi r18, (1 << 4) | BEGIN_SEND
	mov r5, r18
	rcall WriteToSlave

	ldi r18, (1 << 4) | BEGIN_SEND
	mov r5, r18				;Data for SendSlaveData routine
	ldi r17, START_COND
	mov r11, r17			   ;Data for CheckAckBitDataLastByte which sets up the repsonse set to slave
	rcall WriteToSlaveLastByte

	ret

TurnDisplay:
	ldi r18, TDH1T
	mov r5, r18
	rcall WriteToSlave

	ldi r18, TDH2T
	mov r5, r18
	rcall WriteToSlave
	
	ldi r18, TDH3T(1, 1, 1)
	mov r5, r18
	rcall WriteToSlave

	ldi r18, TDH4T(1, 1, 1)
	mov r5, r18				;Data for SendSlaveData routine
	ldi r17, START_COND
	mov r11, r17			   ;Data for CheckAckBitDataLastByte which sets up the repsonse set to slave
	rcall WriteToSlaveLastByte

	ret

EntryModeSet:
	ldi r18, 0x00 | BEGIN_SEND
	mov r5, r18
	rcall WriteToSlave

	ldi r18, 0x00 | END_SEND
	mov r5, r18
	rcall WriteToSlave
	
	ldi r18, (1 << 6 ) | (1 << 5 ) | BEGIN_SEND
	mov r5, r18
	rcall WriteToSlave

	ldi r18, (1 << 6 ) | (1 << 5 ) | END_SEND
	mov r5, r18				;Data for SendSlaveData routine
	ldi r17, START_COND
	mov r11, r17			   ;Data for CheckAckBitDataLastByte which sets up the repsonse set to slave
	rcall WriteToSlaveLastByte

	ret

ReturnHome:
	ldi r18, RH1
	mov r5, r18
	rcall WriteToSlave

	ldi r18, RH2
	mov r5, r18
	rcall WriteToSlave

	ldi r18, RH3
	mov r5, r18
	rcall WriteToSlave

	ldi r18, RH4
	mov r5, r18
	ldi r17, START_COND
	mov r11, r17
	rcall WriteToSlaveLastByte

	ret

WriteCharacter:
	; send 4 HIGH bits
	ldi r18, BEGIN_DATA_BYTE_TRANSFER(0,1,0,0)
	mov r5, r18
	rcall WriteToSlave

	ldi r18, END_DATA_BYTE_TRANSFER(0,1,0,0)
	mov r5, r18
	rcall WriteToSlave

	; send 4 LOW bits
	ldi r18, BEGIN_DATA_BYTE_TRANSFER(1,0,0,0)
	mov r5, r18
	rcall WriteToSlave

	ldi r18, END_DATA_BYTE_TRANSFER(1,0,0,0)
	mov r5, r18
	ldi r17, STOP_COND
	mov r11, r17
	rcall WriteToSlaveLastByte

	;By end of transfer AC has been incremented by 1

	ret

Sleep:
	ldi r22, 255
	ldi r23, 255
	ldi r24, 100
Loop:
	dec r22
	brne Loop
	dec r23
	brne Loop
	dec r24
	brne Loop

	ret