LEX = lex.yy.c
YACC_C = y.tab.c
YACC_H = y.tab.h
SYMBOL_TABLE = symbol_table.c
FUNCTION_TABLE = function_table.c
EXEC = parser

all: $(EXEC)

$(EXEC): $(LEX) $(YACC_C) $(SYMBOL_TABLE) $(FUNCTION_TABLE)
	gcc $(LEX) $(YACC_C) $(SYMBOL_TABLE) $(FUNCTION_TABLE) -o $(EXEC)

$(LEX): scanner.l
	lex scanner.l

$(YACC_C) $(YACC_H): parser.y
	yacc -d parser.y

clean:
	rm -f $(LEX) $(YACC_C) $(YACC_H) $(EXEC)