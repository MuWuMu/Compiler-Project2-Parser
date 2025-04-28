lex scanner.l
yacc -d parser.y
gcc lex.yy.c y.tab.c -o parser
./parser test.sd