percent_diff: percent_diff.o debug_dump.o
	gcc -o percent_diff percent_diff.o debug_dump.o

percent_diff.o: percent_diff.asm
	nasm -o percent_diff.o -f elf64 -g -F stabs percent_diff.asm