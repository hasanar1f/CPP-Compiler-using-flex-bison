# CPP-Compiler-using-flex-bison

This is a cpp compiler. It generates equivalent 8086 assembly code from input c code.
The final output of the code will be found by running the source assembly code in 8086 assembler.

Here is the command to compiler your source code:

Assume your parser(yacc/bison) file with .y extention is named simplecalc.y. The followings are the sequence of commands you need to give to compile your parser and scanner. Find the details of the commands used here from manual of flex and bison. 

# bison -d -y -v simplecalc.y	
-d creates the header file y.tab.h that helps in communication(i.e. pass tokens) between parser and scanner; -y is something similar to -o y.tab.c, that is it creates the parser; -v creates an .output file containing verbose descriptions of the parser states and all the conflicts, both those resolved by operator precedence and the unresolved ones

# g++ -w -c -o y.o y.tab.c	
-w stops the list of warnings from showing; -c compiles and assembles the c code, -o creates the y.o output file    


# flex simplecalc.l		
creates the lexical analyzer or scanner named lex.yy.c


# g++ -w -c -o l.o lex.yy.c
if the above command doesn't work try g++ -fpermissive -w -c -o l.o lex.yy.c


# g++ -o a.out y.o l.o -lfl -ly	
compiles the scanner and parser to create output file a.out; -lfl and -ly includes library files 					for lex and yacc(bison)


# ./a.out input.cpp

you will need to provide the source code saved as input.cpp files with ./a.out command as instructed 
