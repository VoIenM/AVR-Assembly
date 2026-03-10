# avrdude note: -P allows you to specify the port to connect to
# Not a ip address port but a motherboard port (which is where I was confused)
# ttyUSB0 file is used an interface. 
# We write data to this file to communicate to devices that are connected to our motherboard using USB.
# src file names: i2c.S , debugreg.S

SourceCode=i2c.S
filename=mn

avr-gcc -DF_CPU=16000000UL $SourceCode -c -o debug/$filename.o

avr-ld debug/$filename.o --format=atmega328P -nostdlib --output debug/$filename.elf

avr-size --format=berkley -d --target=elf32-little debug/$filename.elf

avr-objcopy debug/$filename.elf debug/$filename.hex -O ihex

avrdude -D -v -p ATmega328p -c arduino -P /dev/ttyUSB0 -U flash:w:debug/$filename.hex:i