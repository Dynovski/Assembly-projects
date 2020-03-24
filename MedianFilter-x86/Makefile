CC=g++
MAIN_FLAGS=-O2 -L/usr/X11R6/lib -lm -lpthread -lX11

ASM=nasm
AFLAGS=-f elf64

all:filter
	
filter.o: medianFilter.asm
	$(ASM) $(AFLAGS) medianFilter.asm
filter: main.cpp filter.o
	$(CC) main.cpp medianFilter.o -o filter $(MAIN_FLAGS)
clean: 
	rm *.o
	rm filter
	rm *.bmp
