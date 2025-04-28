%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// get token that recognized by scanner
extern int yylex();
extern int yyparse();
extern FILE *yyin;

// Add a global variable to store the token text
extern char *yytext;

void yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
}
%}

// define token
%token VOID MAIN IF ELSE WHILE PRINT RETURN
%token ID INT REAL STRING OP DELIM
%token KEYWORD

%%

program:
    declarations main_function
    | error { yyerror("Syntax error in program"); }
    ;

declarations:
    declaration declarations
    | /* empty */
    ;

declaration:
    ID ID ';'
    | ID ID '=' expression ';'
    ;

main_function:
    VOID MAIN '(' ')' block
    ;

block:
    '{' statements '}'
    ;

statements:
    statement statements
    | /* empty */
    ;

statement:
    assignment
    | print_statement
    | conditional
    ;

assignment:
    ID '=' expression ';'
    ;

print_statement:
    PRINT expression ';'
    ;

conditional:
    IF '(' expression ')' block
    | IF '(' expression ')' block ELSE block
    ;

expression:
    INT
    | REAL
    | STRING
    | ID
    | '(' expression ')'
    | expression OP expression
    ;

%%

int main(int argc, char **argv) {
    if (argc != 2) {
        printf("Usage: %s <input file>\n", argv[0]);
        return 1;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror("fopen");
        return 1;
    }

    printf("Starting parsing...\n");

    int token;
    while ((token = yylex()) != 0) {
        printf("Token: %d, Text: %s\n", token, yytext);
    }

    fclose(yyin);
    return 0;
}