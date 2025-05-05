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
    struct {
        char *type;
        void *value;
    } expr;         // For expression (multi-type: int, float, string...)
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
%type <expr> expression
%type <node> array_declaration
%type <node> array_initializer

%%

program:
    // declarations program
    // | functions program
    // | main_function 
    // ;
    declarations main_function
    | main_function   
    ;

main_function:
    // KW_VOID KW_MAIN DELIM_LPAR DELIM_RPAR block
    // ;
    KW_VOID KW_MAIN DELIM_LPAR DELIM_RPAR DELIM_LBRACE DELIM_RBRACE
    ;

declarations:
    declaration declarations
    | /* empty */
    ;

declaration:
    // single or multiple declaration
    type_specifier declarator_list DELIM_SEMICOLON {
        printf("Declaration without initialization: type=%s\n", $1);    // for debugging

        // traverse declarator_list，insert each one into symbol table
        Node *current = $2;
        while (current != NULL) {
            if (lookupSymbol(currentTable, current->name)) {
                yyerror("Duplicate declaration of variable");
            } else {
                insertSymbol(currentTable, current->name, $1, 0, current->value, 0, 0);
            }
            current = current->next;
        }
    }
    // single or multi const declare
    | KW_CONST type_specifier declarator_list DELIM_SEMICOLON {
        printf("Const declaration: type=%s\n", $2);   // for debugging

        Node *current = $3;
        while (current != NULL) {
            if (lookupSymbol(currentTable, current->name)) {
                yyerror("Duplicate declaration of variable");
            } else if (current->value == NULL) {
                yyerror("Const variable must be initialized");
            } else {
                insertSymbol(currentTable, current->name, $2, 1, current->value, 0, 0); // set as const
                printf("Initialized const variable: %s with value\n", current->name);   // for debugging
            }
            current = current->next;
        }
    }
    //TODO: 陣列宣告
    | array_declaration
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
        // single declaration without initialization
        $$ = (Node *)malloc(sizeof(Node));
        $$->name = strdup($1);
        $$->next = NULL;
        $$->value = NULL; // no initialization
    }
    | ID OP_ASSIGN expression {
        // single declaration with initialization
        $$ = (Node *)malloc(sizeof(Node));
        $$->name = strdup($1);
        $$->next = NULL;
        $$->value = $3.value; // initialization value
    }
    | ID DELIM_COMMA declarator_list {
        // multi declaration without initialization
        $$ = (Node *)malloc(sizeof(Node));
        $$->name = strdup($1);
        $$->next = $3;
        $$->value = NULL;
    }
    | ID OP_ASSIGN expression DELIM_COMMA declarator_list {
        // multi declaration with initialization
        $$ = (Node *)malloc(sizeof(Node));
        $$->name = strdup($1);
        $$->next = $5;
        $$->value = $3.value;
    }
    ;

array_declaration:
    type_specifier ID DELIM_LBRACK INT DELIM_RBRACK DELIM_SEMICOLON {
        // declare with no initialization
        printf("Array declaration: type=%s, name=%s, size=%d\n", $1, $2, $4); // for debugging

        if (lookupSymbol(currentTable, $2)) {
            yyerror("Duplicate declaration of array");
        } else {
            // init with 0
            void *array = calloc($4, sizeof(int));
            insertSymbol(currentTable, $2, $1, 0, array, 1, $4);
            printf("Declared array: %s, size=%d\n", $2, $4); // for debugging
        }
    }
    | type_specifier ID DELIM_LBRACK INT DELIM_RBRACK OP_ASSIGN DELIM_LBRACE array_initializer DELIM_RBRACE DELIM_SEMICOLON {
        // arrays with initialization values
        printf("Array declaration with initialization: type=%s, name=%s, size=%d\n", $1, $2, $4); // for debugging

        if (lookupSymbol(currentTable, $2)) {
            yyerror("Duplicate declaration of array");
        } else {
            // 初始化陣列
            void *array = calloc($4, sizeof(int));
            int *arr = (int *)array;
            int i = 0;
            Node *init = $8;
            while (init != NULL && i < $4) {
                arr[i++] = *(int *)init->value;
                init = init->next;
            }
            insertSymbol(currentTable, $2, $1, 0, array, 1, $4);
            printf("Declared array: %s, size=%d\n", $2, $4); // for debugging
        }
    }
    | KW_CONST type_specifier ID DELIM_LBRACK INT DELIM_RBRACK OP_ASSIGN DELIM_LBRACE array_initializer DELIM_RBRACE DELIM_SEMICOLON {
        // const array declaration with initialization values
        printf("Const array declaration with initialization: type=%s, name=%s, size=%d\n", $2, $3, $5); // for debugging

        if (lookupSymbol(currentTable, $3)) {
            yyerror("Duplicate declaration of array");
        } else {
            // init array with initialization values
            void *array = calloc($5, sizeof(int));
            int *arr = (int *)array;
            int i = 0;
            Node *init = $9;
            while (init != NULL && i < $5) {
                arr[i++] = *(int *)init->value;
                init = init->next;
            }
            insertSymbol(currentTable, $3, $2, 1, array, 1, $5); // set as const
            printf("Declared const array: %s, size=%d\n", $3, $5); // for debugging
        }
    }
    | KW_CONST type_specifier ID DELIM_LBRACK INT DELIM_RBRACK DELIM_SEMICOLON {
        // const array declaration without initialization (invalid)
        yyerror("Const array must be initialized");
    }
    ;

array_initializer:
    expression {
        // single initialization value
        $$ = (Node *)malloc(sizeof(Node));
        $$->value = $1.value;
        $$->next = NULL;
    }
    | expression DELIM_COMMA array_initializer {
        // multi initialization values
        $$ = (Node *)malloc(sizeof(Node));
        $$->value = $1.value;
        $$->next = $3;
    }
    ;

expression:
    INT {
        $$.type = "INT";
        $$.value = malloc(sizeof(int));
        *(int *)$$.value = $1;
        printf("Expression type: INT, value: %d\n", $1); // for debugging
    }
    | REAL {
        $$.type = "REAL";
        $$.value = malloc(sizeof(float));
        *(float *)$$.value = $1;
        printf("Expression type: REAL, value: %f\n", $1); // for debugging
    }
    | BOOL {
        $$.type = "BOOL";
        $$.value = malloc(sizeof(bool));
        *(bool *)$$.value = $1;
        printf("Expression type: BOOL, value: %s\n", $1 ? "true" : "false"); // for debugging
    }
    | STRING {
        $$.type = "STRING";
        $$.value = strdup($1);
        printf("Expression type: STRING, value: %s\n", $1); // for debugging
    }
    ;

assignments:
    assignment assignments
    | /* empty */
    ;

assignment: // TODO: array assignment
    ID OP_ASSIGN expression DELIM_SEMICOLON {   
        Symbol *symbol = lookupSymbol(currentTable, $1);
        if (!symbol) {
            yyerror("Variable not declared");
        } else if (symbol->isConst) {
            yyerror("Cannot assign to a constant variable");
        } else {
            // check if the type of the variable matches the type of the expression
            if (strcmp(symbol->type, "int") == 0 && strcmp($3.type, "INT") == 0) {
                // int to int assignment
                symbol->value.intValue = *(int *)$3.value;
            } else if ((strcmp(symbol->type, "float") == 0) || (strcmp(symbol->type, "double") == 0) && strcmp($3.type, "REAL") == 0) {
                // float to float assignment
                symbol->value.realValue = *(float *)$3.value;
            } else if (strcmp(symbol->type, "bool") == 0 && strcmp($3.type, "BOOL") == 0) {
                // bool to bool assignment
                symbol->value.boolValue = *(bool *)$3.value;
            } else if ((strcmp(symbol->type, "char") == 0) || (strcmp(symbol->type, "string") == 0) && strcmp($3.type, "STRING") == 0) {
                // string to string assignment
                free(symbol->value.stringValue); // free old value
                symbol->value.stringValue = strdup((char *)$3.value);
            } else {
                yyerror("Type mismatch in assignment");
        }
        free($3.value); // 釋放 expression 的值
        }
    }
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