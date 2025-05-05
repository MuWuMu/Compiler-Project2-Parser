%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#include "symbol_table.h"

// get token that recognized by scanner
extern int yylex();
extern int yyparse();
extern FILE *yyin;
extern char *yytext;
extern int linenum;

SymbolTable *currentTable = NULL;

void yyerror(const char *s) {
    fprintf(stderr, "Error at line %d: %s\n", linenum, s);
}


%}

%union {
    char *string;   // For type_specifier (int, float...)
    Node *node;     // For declarator_list and declarator_list_with_init
    int intval;     // For integer constants
    float realval;  // For real constants
    bool boolval;    // For boolean constants
    char *text;     // For string constants (ID, string...)
    void *value;    // For expression (multi-type: int, float, string...)
}

// define token
%token <string> KW_BOOL KW_BREAK KW_CASE KW_CHAR KW_CONST KW_CONTINUE KW_DEFAULT KW_DO KW_DOUBLE KW_ELSE KW_EXTERN KW_FLOAT KW_FOR KW_FOREACH KW_IF KW_INT KW_MAIN KW_PRINT KW_PRINTLN KW_READ KW_RETURN KW_STRING KW_SWITCH KW_VOID KW_WHILE
%token <text> ID
%token <intval> INT
%token <realval> REAL
%token <boolval> BOOL
%token <text> STRING
%token <string> OP_INC OP_ADD OP_DEC OP_SUB OP_MUL OP_DIV OP_MOD OP_EQ OP_NEQ OP_LEQ OP_GEQ OP_ASSIGN OP_LT OP_GT OP_OR OP_AND OP_NOT
%token <string> DELIM_LPAR DELIM_RPAR DELIM_LBRACK DELIM_RBRACK DELIM_LBRACE DELIM_RBRACE DELIM_COMMA DELIM_DOT DELIM_COLON DELIM_SEMICOLON

%type <string> type_specifier
%type <node> declarator_list
%type <value> expression

%%

program:
    declarations main_function
    | main_function   
    ;

main_function:  //TODO: statements between DELIM_LBRACE DELIM_RBRACE 
    KW_VOID KW_MAIN DELIM_LPAR DELIM_RPAR DELIM_LBRACE DELIM_RBRACE
    ;

declarations:
    declaration declarations
    | /* empty */
    ;

declaration:
    // single declaration
    // type_specifier ID DELIM_SEMICOLON {
    //     printf("Declaration: type=%s, name=%s\n", $1, $2);  // for debugging
    //     // check if ID already exists in the symbol table
    //     if (lookupSymbol(currentTable, $2)) {
    //         yyerror("Duplicate declaration of variable");
    //     } else {
    //         // add ID to the symbol table
    //         insertSymbol(currentTable, $2, $1, 0, NULL);
    //     }
    // }

    // single or multiple declaration without initialization
    type_specifier declarator_list DELIM_SEMICOLON {
        printf("Declaration without initialization: type=%s\n", $1);    // for debugging

        // traverse declarator_list，insert each one into symbol table
        Node *current = $2;
        while (current != NULL) {
            if (lookupSymbol(currentTable, current->name)) {
                yyerror("Duplicate declaration of variable");
            } else {
                insertSymbol(currentTable, current->name, $1, 0, NULL);
            }
            current = current->next;
        }
    }
    // single or multiple declaration with initialization
    | type_specifier declarator_list OP_ASSIGN expression DELIM_SEMICOLON {
        printf("Declaration with initialization: type=%s\n", $1);   // for debugging

        // traverse declarator_listlet each variable init with same value
        Node *current = $2;
        while (current != NULL) {
            if (lookupSymbol(currentTable, current->name)) {
                yyerror("Duplicate declaration of variable");
            } else {
                insertSymbol(currentTable, current->name, $1, 0, $4);
            }
            current = current->next;
        }
    }
    // single or multi const declare
    | KW_CONST type_specifier declarator_list OP_ASSIGN expression DELIM_SEMICOLON {
        printf("Const declaration: type=%s\n", $2);   // for debugging

        Node *current = $3;
        while (current != NULL) {
            if (lookupSymbol(currentTable, current->name)) {
                yyerror("Duplicate declaration of variable");
            } else {
                insertSymbol(currentTable, current->name, $2, 1, $5); // set as const
                printf("Initialized const variable: %s with value\n", current->name);   // for debugging
            }
            current = current->next;
        }
    }
    | KW_CONST type_specifier declarator_list DELIM_SEMICOLON {
        yyerror("Const declaration must be initialized");
    }
    //TODO: 陣列宣告
    ;

type_specifier:
    KW_INT { $$ = "int";}
    | KW_FLOAT { $$ = "float";}
    | KW_DOUBLE { $$ = "double";}
    | KW_CHAR { $$ = "char";}
    | KW_BOOL { $$ = "bool";}
    | KW_STRING { $$ = "string";}
    ;

declarator_list:
    ID {
        // single declaration no initialization
        $$ = (Node *)malloc(sizeof(Node));
        $$->name = strdup($1);
        $$->next = NULL;
        $$->value = NULL; // no initialization
    }
    | ID DELIM_COMMA declarator_list {
        // multi declaration without initialization
        $$ = (Node *)malloc(sizeof(Node));
        $$->name = strdup($1);
        $$->next = $3;
        $$->value = NULL;
    }
    ;

expression:
    INT {
        $$ = malloc(sizeof(int));
        *(int *)$$ = $1;
    }
    | REAL {
        $$ = malloc(sizeof(float));
        *(float *)$$ = $1;
    }
    | BOOL {
        $$ = malloc(sizeof(bool));
        *(bool *)$$ = $1;
    }
    | STRING {
        $$ = strdup($1);
    }
    ;

// assignments:
//     assignment assignments
//     | /* empty */
//     ;

// assignment: // TODO: array assignment
//     ID OP_ASSIGN expression DELIM_SEMICOLON {   
//     }
//     ;


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

    // Initialize the symbol table
    currentTable = createSymbolTable(NULL);

    // int token;
    // while ((token = yylex()) != 0) {
    //     printf("Line%d, Token: %s, Text: %s\n", linenum, token_names[token - 258], yytext);
    // }

    if (yyparse() == 0) {
        // Dump and delete globol symbol table
        dumpSymbolTable(currentTable);
        deleteSymbolTable(currentTable);
        currentTable = NULL;
        printf("Parsing completed successfully.\n");
    } else {
        printf("Parsing failed.\n");
    }

    fclose(yyin);
    return 0;
}