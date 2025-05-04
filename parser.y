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

extern int linenum;

void yyerror(const char *s) {
    fprintf(stderr, "Error at line %d: %s\n", linenum, s);
}

const char* token_names[] = {
    "KW_BOOL", "KW_BREAK", "KW_CASE", "KW_CHAR", "KW_CONST", "KW_CONTINUE", "KW_DEFAULT", "KW_DO", "KW_DOUBLE",
    "KW_ELSE", "KW_EXTERN", "KW_FALSE", "KW_FLOAT", "KW_FOR", "KW_FOREACH", "KW_IF", "KW_INT", "KW_MAIN",
    "KW_PRINT", "KW_PRINTLN", "KW_READ", "KW_RETURN", "KW_STRING", "KW_SWITCH", "KW_TRUE", "KW_VOID", "KW_WHILE",
    "ID", "INT", "REAL", "STRING", "OP", "DELIM"
};

%}

// define token
%token KW_BOOL KW_BREAK KW_CASE KW_CHAR KW_CONST KW_CONTINUE KW_DEFAULT KW_DO KW_DOUBLE KW_ELSE KW_EXTERN KW_FALSE KW_FLOAT KW_FOR KW_FOREACH KW_IF KW_INT KW_MAIN KW_PRINT KW_PRINTLN KW_READ KW_RETURN KW_STRING KW_SWITCH KW_TRUE KW_VOID KW_WHILE
%token ID INT REAL STRING
%token OP_INC OP_ADD OP_DEC OP_SUB OP_MUL OP_DIV OP_MOD OP_EQ OP_NEQ OP_LEQ OP_GEQ OP_ASSIGN OP_LT OP_GT OP_OR OP_AND OP_NOT
%token DELIM_LPAR DELIM_RPAR DELIM_LBRACK DELIM_RBRACK DELIM_LBRACE DELIM_RBRACE DELIM_COMMA DELIM_DOT DELIM_COLON DELIM_SEMICOLON

%%

program:
    main_function   // min program, only one main function
    | declarations main_function    // program with globol declarations and main function
    | error { yyerror("Syntax error in program"); }
    ;

declarations:   // one or more declarations
    declaration declarations
    | /* empty */
    ;

declaration:
    type_specifier declarator_list DELIM_SEMICOLON  // declaration without initialization
    | type_specifier declarator_list_with_init DELIM_SEMICOLON  // declaration with initialization
    | KW_CONST type_specifier declarator_list_with_init DELIM_SEMICOLON // constant declaration, have to be with initialization
    ;

type_specifier:
    KW_BOOL
    | KW_INT
    | KW_FLOAT
    | KW_DOUBLE
    | KW_CHAR
    | KW_STRING
    ;

declarator_list:
    ID
    | ID DELIM_COMMA declarator_list
    ;

declarator_list_with_init:
    ID OP_ASSIGN expression
    | ID DELIM_COMMA declarator_list_with_init
    | declarator_list DELIM_COMMA expression
    ;

main_function:
    KW_VOID KW_MAIN DELIM_LPAR DELIM_RPAR block
    ;

block:  //TODO: block scope(table)
    DELIM_LBRACE statements DELIM_RBRACE
    ;

statements:
    statement statements
    | /* empty */
    ;

statement:  //TODO: more statement types
    assignment
    | print_statement
    | conditional
    ;

assignment: //TODO: void const assignment
    ID OP_ASSIGN expression DELIM_SEMICOLON
    ;

print_statement:
    KW_PRINT expression DELIM_SEMICOLON
    ;

conditional:
    KW_IF DELIM_LPAR expression DELIM_RPAR block
    | KW_IF DELIM_LPAR expression DELIM_RPAR block KW_ELSE block
    ;

expression:
    INT
    | REAL
    | STRING
    | ID
    | DELIM_LPAR expression DELIM_RPAR
    | expression operators expression
    ;
    
operators:
    OP_INC
    | OP_ADD
    | OP_DEC
    | OP_SUB
    | OP_MUL
    | OP_DIV
    | OP_MOD
    | OP_EQ
    | OP_NEQ
    | OP_LEQ
    | OP_GEQ
    | OP_ASSIGN
    | OP_LT
    | OP_GT
    | OP_OR
    | OP_AND
    | OP_NOT
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

    // int token;
    // while ((token = yylex()) != 0) {
    //     printf("Line%d, Token: %s, Text: %s\n", linenum, token_names[token - 258], yytext);
    // }
    if (yyparse() == 0) {
        printf("Parsing completed successfully.\n");
    } else {
        printf("Parsing failed.\n");
    }

    fclose(yyin);
    return 0;
}