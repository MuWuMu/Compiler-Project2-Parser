LEX = lex.yy.c
YACC_C = y.tab.c
YACC_H = y.tab.h
EXEC = parser

all: $(EXEC)

$(EXEC): $(LEX) $(YACC_C)
	gcc $(LEX) $(YACC_C) -o $(EXEC)

$(LEX): scanner.l
	lex scanner.l

$(YACC_C) $(YACC_H): parser.y
	yacc -d parser.y

clean:
	rm -f $(LEX) $(YACC_C) $(YACC_H) $(EXEC)