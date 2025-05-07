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

%left OP_OR
%left OP_AND
%right OP_NOT
%left OP_LT OP_LEQ OP_EQ OP_NEQ OP_GEQ OP_GT
%left OP_ADD OP_SUB
%left OP_MUL OP_DIV OP_MOD
%right OP_INC OP_DEC

%%

program: //TODO: now just to test the parser
    // declarations program
    // | functions program
    // | main_function 
    // ;
    declarations main_function
    | main_function   
    ;

main_function:
    KW_VOID KW_MAIN DELIM_LPAR DELIM_RPAR block
    ;
    // KW_VOID KW_MAIN DELIM_LPAR DELIM_RPAR DELIM_LBRACE DELIM_RBRACE
    // ;

declarations:
    declaration declarations
    | /* empty */
    ;

declaration:
    // single or multiple declaration
    type_specifier declarator_list DELIM_SEMICOLON {
        // printf("Declaration without initialization: type=%s\n", $1);    // for debugging

        // traverse declarator_list，insert each one into symbol table
        Node *current = $2;
        while (current != NULL) {
            if (lookupSymbolInCurrentTable(currentTable, current->name)) {
                yyerror("Duplicate declaration of variable");
            } else {
                insertSymbol(currentTable, current->name, $1, 0, current->value, 0, 0);
            }
            current = current->next;
        }
    }
    // single or multi const declare
    | KW_CONST type_specifier declarator_list DELIM_SEMICOLON {
        // printf("Const declaration: type=%s\n", $2);   // for debugging

        Node *current = $3;
        while (current != NULL) {
            if (lookupSymbolInCurrentTable(currentTable, current->name)) {
                yyerror("Duplicate declaration of variable");
            } else if (current->value == NULL) {
                yyerror("Const variable must be initialized");
            } else {
                insertSymbol(currentTable, current->name, $2, 1, current->value, 0, 0); // set as const
                // printf("Initialized const variable: %s with value\n", current->name);   // for debugging
            }
            current = current->next;
        }
    }
    // array declaration
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
        // printf("Array declaration: type=%s, name=%s, size=%d\n", $1, $2, $4); // for debugging

        if (lookupSymbolInCurrentTable(currentTable, $2)) {
            yyerror("Duplicate declaration of array");
        } else {
            // init with 0
            void *array = calloc($4, sizeof(int));
            insertSymbol(currentTable, $2, $1, 0, array, 1, $4);
            // printf("Declared array: %s, size=%d\n", $2, $4); // for debugging
        }
    }
    | type_specifier ID DELIM_LBRACK INT DELIM_RBRACK OP_ASSIGN DELIM_LBRACE array_initializer DELIM_RBRACE DELIM_SEMICOLON {
        // arrays with initialization values
        // printf("Array declaration with initialization: type=%s, name=%s, size=%d\n", $1, $2, $4); // for debugging

        if (lookupSymbolInCurrentTable(currentTable, $2)) {
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
            // printf("Declared array: %s, size=%d\n", $2, $4); // for debugging
        }
    }
    | KW_CONST type_specifier ID DELIM_LBRACK INT DELIM_RBRACK OP_ASSIGN DELIM_LBRACE array_initializer DELIM_RBRACE DELIM_SEMICOLON {
        // const array declaration with initialization values
        // printf("Const array declaration with initialization: type=%s, name=%s, size=%d\n", $2, $3, $5); // for debugging

        if (lookupSymbolInCurrentTable(currentTable, $3)) {
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
            // printf("Declared const array: %s, size=%d\n", $3, $5); // for debugging
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
        // printf("Expression type: INT, value: %d\n", $1); // for debugging
    }
    | REAL {
        $$.type = "REAL";
        $$.value = malloc(sizeof(float));
        *(float *)$$.value = $1;
        // printf("Expression type: REAL, value: %f\n", $1); // for debugging
    }
    | BOOL {
        $$.type = "BOOL";
        $$.value = malloc(sizeof(bool));
        *(bool *)$$.value = $1;
        // printf("Expression type: BOOL, value: %s\n", $1 ? "true" : "false"); // for debugging
    }
    | STRING {
        $$.type = "STRING";
        $$.value = strdup($1);
        // printf("Expression type: STRING, value: %s\n", $1); // for debugging
    }
    | ID {
        Symbol *symbol = lookupSymbol(currentTable, $1);
        if (!symbol) {
            yyerror("Variable not declared");
        } else if (symbol->isArray) {
            yyerror("Need specify index for array variable");
        } else {
            if (strcmp(symbol->type, "int") == 0) {
                $$.type = "INT";
                $$.value = malloc(sizeof(int));
                *(int *)$$.value = symbol->value.intValue;
            } else if (strcmp(symbol->type, "float") == 0 || strcmp(symbol->type, "double") == 0) {
                $$.type = "REAL";
                $$.value = malloc(sizeof(float));
                *(float *)$$.value = symbol->value.realValue;
            } else if (strcmp(symbol->type, "bool") == 0) {
                $$.type = "BOOL";
                $$.value = malloc(sizeof(bool));
                *(bool *)$$.value = symbol->value.boolValue;
            } else if (strcmp(symbol->type, "string") == 0 || strcmp(symbol->type, "char") == 0) {
                $$.type = "STRING";
                $$.value = strdup(symbol->value.stringValue);
            }
        }
    }
    | ID DELIM_LBRACK expression DELIM_RBRACK {
        Symbol *symbol = lookupSymbol(currentTable, $1);
        if (!symbol) {
            yyerror("Variable not declared");
        } else if (!symbol->isArray) {
            yyerror("Variable is not an array");
        } else if (strcmp($3.type, "INT") != 0) {
            yyerror("Array index must be an integer");
        } else {
            $$.type = symbol->type;
            $$.value = malloc(sizeof(int));
            int index = *(int *)$3.value;
            if (index < 0 || index >= symbol->arraySize) {
                yyerror("Array index out of bounds");
            } else {
                // get value from array
                int *arr = (int *)symbol->value;
                *(int *)$$.value = arr[index];
            }
        }
    }
    | OP_SUB expression %prec OP_INC {
        // Unary minus
        if (strcmp($2.type, "INT") == 0) {
            $$.type = "INT";
            $$.value = malloc(sizeof(int));
            *(int *)$$.value = -(*(int *)$2.value);
        } else if (strcmp($2.type, "REAL") == 0) {
            $$.type = "REAL";
            $$.value = malloc(sizeof(float));
            *(float *)$$.value = -(*(float *)$2.value);
        } else {
            yyerror("Invalid type for unary minus");
        }
    }
    | expression OP_INC {
        // Increment
        if (strcmp($1.type, "INT") == 0) {
            $$.type = "INT";
            $$.value = malloc(sizeof(int));
            *(int *)$$.value = (*(int *)$1.value) + 1;
        } else if (strcmp($1.type, "REAL") == 0) {
            $$.type = "REAL";
            $$.value = malloc(sizeof(float));
            *(float *)$$.value = (*(float *)$1.value) + 1.0;
        } else {
            yyerror("Invalid type for increment");
        }
    }
    | expression OP_DEC {
        // Decrement
        if (strcmp($1.type, "INT") == 0) {
            $$.type = "INT";
            $$.value = malloc(sizeof(int));
            *(int *)$$.value = (*(int *)$1.value) - 1;
        } else if (strcmp($1.type, "REAL") == 0) {
            $$.type = "REAL";
            $$.value = malloc(sizeof(float));
            *(float *)$$.value = (*(float *)$1.value) - 1.0;
        } else {
            yyerror("Invalid type for decrement");
        }
    }
    | expression OP_MUL expression {
        // Multiplication
        if (strcmp($1.type, "INT") == 0 && strcmp($3.type, "INT") == 0) {
            $$.type = "INT";
            $$.value = malloc(sizeof(int));
            *(int *)$$.value = (*(int *)$1.value) * (*(int *)$3.value);
        } else if ((strcmp($1.type, "REAL") == 0 || strcmp($1.type, "INT") == 0) &&
                   (strcmp($3.type, "REAL") == 0 || strcmp($3.type, "INT") == 0)) {
            $$.type = "REAL";
            $$.value = malloc(sizeof(float));
            *(float *)$$.value = (*(float *)$1.value) * (*(float *)$3.value);
        } else {
            yyerror("Type mismatch in multiplication");
        }
    }
    | expression OP_DIV expression {
        // Division
        if (strcmp($1.type, "INT") == 0 && strcmp($3.type, "INT") == 0) {
            $$.type = "INT";
            $$.value = malloc(sizeof(int));
            *(int *)$$.value = (*(int *)$1.value) / (*(int *)$3.value);
        } else if ((strcmp($1.type, "REAL") == 0 || strcmp($1.type, "INT") == 0) &&
                   (strcmp($3.type, "REAL") == 0 || strcmp($3.type, "INT") == 0)) {
            $$.type = "REAL";
            $$.value = malloc(sizeof(float));
            *(float *)$$.value = (*(float *)$1.value) / (*(float *)$3.value);
        } else {
            yyerror("Type mismatch in division");
        }
    }
    | expression OP_MOD expression {
        // Modulus
        if (strcmp($1.type, "INT") == 0 && strcmp($3.type, "INT") == 0) {
            $$.type = "INT";
            $$.value = malloc(sizeof(int));
            *(int *)$$.value = (*(int *)$1.value) % (*(int *)$3.value);
        } else {
            yyerror("Type mismatch in modulus");
        }
    }
    | expression OP_ADD expression {
        // Addition
        if (strcmp($1.type, "INT") == 0 && strcmp($3.type, "INT") == 0) {
            $$.type = "INT";
            $$.value = malloc(sizeof(int));
            *(int *)$$.value = (*(int *)$1.value) + (*(int *)$3.value);
        } else if ((strcmp($1.type, "REAL") == 0 || strcmp($1.type, "INT") == 0) &&
                   (strcmp($3.type, "REAL") == 0 || strcmp($3.type, "INT") == 0)) {
            $$.type = "REAL";
            $$.value = malloc(sizeof(float));
            float left = (strcmp($1.type, "REAL") == 0) ? *(float *)$1.value : (float)(*(int *)$1.value);
            float right = (strcmp($3.type, "REAL") == 0) ? *(float *)$3.value : (float)(*(int *)$3.value);
            *(float *)$$.value = left + right;
        } else {
            yyerror("Type mismatch in addition");
        }
    }
    | expression OP_SUB expression {
        // Subtraction
        if (strcmp($1.type, "INT") == 0 && strcmp($3.type, "INT") == 0) {
            $$.type = "INT";
            $$.value = malloc(sizeof(int));
            *(int *)$$.value = (*(int *)$1.value) - (*(int *)$3.value);
        } else if ((strcmp($1.type, "REAL") == 0 || strcmp($1.type, "INT") == 0) &&
                   (strcmp($3.type, "REAL") == 0 || strcmp($3.type, "INT") == 0)) {
            $$.type = "REAL";
            $$.value = malloc(sizeof(float));
            *(float *)$$.value = (*(float *)$1.value) - (*(float *)$3.value);
        } else {
            yyerror("Type mismatch in subtraction");
        }
    }
    | expression OP_LT expression {
        // Less than
        $$.type = "BOOL";
        $$.value = malloc(sizeof(bool));
        if (strcmp($1.type, "INT") == 0 && strcmp($3.type, "INT") == 0) {
            *(bool *)$$.value = (*(int *)$1.value) < (*(int *)$3.value);
        } else if ((strcmp($1.type, "REAL") == 0 || strcmp($1.type, "INT") == 0) &&
                   (strcmp($3.type, "REAL") == 0 || strcmp($3.type, "INT") == 0)) {
            *(bool *)$$.value = (*(float *)$1.value) < (*(float *)$3.value);
        } else {
            yyerror("Type mismatch in less than comparison");
        }
    }
    | expression OP_LEQ expression {
        // Less than or equal to
        $$.type = "BOOL";
        $$.value = malloc(sizeof(bool));
        if (strcmp($1.type, "INT") == 0 && strcmp($3.type, "INT") == 0) {
            *(bool *)$$.value = (*(int *)$1.value) <= (*(int *)$3.value);
        } else if ((strcmp($1.type, "REAL") == 0 || strcmp($1.type, "INT") == 0) &&
                   (strcmp($3.type, "REAL") == 0 || strcmp($3.type, "INT") == 0)) {
            *(bool *)$$.value = (*(float *)$1.value) <= (*(float *)$3.value);
        } else {
            yyerror("Type mismatch in less than or equal to comparison");
        }
    }
    | expression OP_EQ expression {
        // Equal to
        $$.type = "BOOL";
        $$.value = malloc(sizeof(bool));
        if (strcmp($1.type, "INT") == 0 && strcmp($3.type, "INT") == 0) {
            *(bool *)$$.value = (*(int *)$1.value) == (*(int *)$3.value);
        } else if ((strcmp($1.type, "REAL") == 0 || strcmp($1.type, "INT") == 0) &&
                   (strcmp($3.type, "REAL") == 0 || strcmp($3.type, "INT") == 0)) {
            *(bool *)$$.value = (*(float *)$1.value) == (*(float *)$3.value);
        } else if (strcmp($1.type, "STRING") == 0 && strcmp($3.type, "STRING") == 0) {
            *(bool *)$$.value = strcmp((char *)$1.value, (char *)$3.value) == 0;
        } else {
            yyerror("Type mismatch in equal to comparison");
        }
    }
    | expression OP_GEQ expression {
        // Greater than or equal to
        $$.type = "BOOL";
        $$.value = malloc(sizeof(bool));
        if (strcmp($1.type, "INT") == 0 && strcmp($3.type, "INT") == 0) {
            *(bool *)$$.value = (*(int *)$1.value) >= (*(int *)$3.value);
        } else if ((strcmp($1.type, "REAL") == 0 || strcmp($1.type, "INT") == 0) &&
                   (strcmp($3.type, "REAL") == 0 || strcmp($3.type, "INT") == 0)) {
            *(bool *)$$.value = (*(float *)$1.value) >= (*(float *)$3.value);
        } else {
            yyerror("Type mismatch in greater than or equal to comparison");
        }
    }
    | expression OP_GT expression {
        // Greater than
        $$.type = "BOOL";
        $$.value = malloc(sizeof(bool));
        if (strcmp($1.type, "INT") == 0 && strcmp($3.type, "INT") == 0) {
            *(bool *)$$.value = (*(int *)$1.value) > (*(int *)$3.value);
        } else if ((strcmp($1.type, "REAL") == 0 || strcmp($1.type, "INT") == 0) &&
                   (strcmp($3.type, "REAL") == 0 || strcmp($3.type, "INT") == 0)) {
            *(bool *)$$.value = (*(float *)$1.value) > (*(float *)$3.value);
        } else {
            yyerror("Type mismatch in greater than comparison");
        }
    }
    | expression OP_NEQ expression {
        // Not equal to
        $$.type = "BOOL";
        $$.value = malloc(sizeof(bool));
        if (strcmp($1.type, "INT") == 0 && strcmp($3.type, "INT") == 0) {
            *(bool *)$$.value = (*(int *)$1.value) != (*(int *)$3.value);
        } else if ((strcmp($1.type, "REAL") == 0 || strcmp($1.type, "INT") == 0) &&
                   (strcmp($3.type, "REAL") == 0 || strcmp($3.type, "INT") == 0)) {
            *(bool *)$$.value = (*(float *)$1.value) != (*(float *)$3.value);
        } else if (strcmp($1.type, "STRING") == 0 && strcmp($3.type, "STRING") == 0) {
            *(bool *)$$.value = strcmp((char *)$1.value, (char *)$3.value) != 0;
        } else {
            yyerror("Type mismatch in not equal to comparison");
        }
    }
    | OP_NOT expression {
        // Logical NOT
        if (strcmp($2.type, "BOOL") == 0) {
            $$.type = "BOOL";
            $$.value = malloc(sizeof(bool));
            *(bool *)$$.value = !(*(bool *)$2.value);
        } else {
            yyerror("Invalid type for logical NOT");
        }
    }
    | expression OP_AND expression {
        // Logical AND
        if (strcmp($1.type, "BOOL") == 0 && strcmp($3.type, "BOOL") == 0) {
            $$.type = "BOOL";
            $$.value = malloc(sizeof(bool));
            *(bool *)$$.value = (*(bool *)$1.value) && (*(bool *)$3.value);
        } else {
            yyerror("Type mismatch in logical AND");
        }
    }
    | expression OP_OR expression {
        // Logical OR
        if (strcmp($1.type, "BOOL") == 0 && strcmp($3.type, "BOOL") == 0) {
            $$.type = "BOOL";
            $$.value = malloc(sizeof(bool));
            *(bool *)$$.value = (*(bool *)$1.value) || (*(bool *)$3.value);
        } else {
            yyerror("Type mismatch in logical OR");
        }
    }
    | DELIM_LPAR expression DELIM_RPAR {
        // Parentheses
        $$.type = $2.type;
        $$.value = $2.value;
    }
    ;

assignment:
    ID OP_ASSIGN expression DELIM_SEMICOLON {   
        Symbol *symbol = lookupSymbol(currentTable, $1);
        if (!symbol) {
            yyerror("Variable not declared");
        } else if (symbol->isConst) {
            yyerror("Cannot assign to a constant variable");
        } else {
            // check if the type of the variable matches the type of the expression
            if (strcmp(symbol->type, "int") == 0 && strcmp($3.type, "INT") == 0) {
                // // int to int assignment
                // symbol->value.intValue = *(int *)$3.value;
            } else if ((strcmp(symbol->type, "float") == 0) || (strcmp(symbol->type, "double") == 0) && strcmp($3.type, "REAL") == 0) {
                // // float to float assignment
                // symbol->value.realValue = *(float *)$3.value;
            } else if (strcmp(symbol->type, "bool") == 0 && strcmp($3.type, "BOOL") == 0) {
                // // bool to bool assignment
                // symbol->value.boolValue = *(bool *)$3.value;
            } else if ((strcmp(symbol->type, "char") == 0) || (strcmp(symbol->type, "string") == 0) && strcmp($3.type, "STRING") == 0) {
                // // string to string assignment
                // free(symbol->value.stringValue); // free old value
                // symbol->value.stringValue = strdup((char *)$3.value);
            } else {
                yyerror("Type mismatch in assignment");
            }
        free($3.value); // 釋放 expression 的值
        }
    }
    ;

statements:
    statement statements
    | /* empty */
    ;

statement:
    block
    | simple
    | expression DELIM_SEMICOLON
    | conditional
    | loop
    | return_statement
    ;

block:
    DELIM_LBRACE {
        //create a new symbol table for block
        SymbolTable *newTable = createSymbolTable(currentTable);
        currentTable = newTable;
    }
    statements
    DELIM_RBRACE{
        // dump and delete the current symbol table, currnet table set to parent table
        SymbolTable *parentTable = currentTable->parent;
        dumpSymbolTable(currentTable);
        deleteSymbolTable(currentTable);
        currentTable = parentTable;
    }
    ;

simple:
    assignment
    | print
    | read
    | increment_decrement
    | semicolon_only
    ;

print:
    KW_PRINT expression DELIM_SEMICOLON {
        // printf("Print statement: %s\n", $2); // for debugging
        if (strcmp($2.type, "INT") == 0) {
            // printf("%d", *(int *)$2.value);
        } else if (strcmp($2.type, "REAL") == 0) {
            // printf("%f", *(float *)$2.value);
        } else if (strcmp($2.type, "BOOL") == 0) {
            // printf("%s", *(bool *)$2.value ? "true" : "false");
        } else if (strcmp($2.type, "STRING") == 0) {
            // printf("%s", (char *)$2.value);
        } else {
            yyerror("Invalid type for print statement");
        }
    }
    | KW_PRINTLN expression DELIM_SEMICOLON {
        // printf("Println statement: %s\n", $2); // for debugging
        if (strcmp($2.type, "INT") == 0) {
            // printf("%d\n", *(int *)$2.value);
        } else if (strcmp($2.type, "REAL") == 0) {
            // printf("%f\n", *(float *)$2.value);
        } else if (strcmp($2.type, "BOOL") == 0) {
            // printf("%s\n", *(bool *)$2.value ? "true" : "false");
        } else if (strcmp($2.type, "STRING") == 0) {
            // printf("%s\n", (char *)$2.value);
        } else {
            yyerror("Invalid type for println statement");
        }
    }
    ;

read:
    KW_READ ID DELIM_SEMICOLON {
        // printf("Read statement: %s\n", $2); // for debugging
        Symbol *symbol = lookupSymbol(currentTable, $2);
        if (!symbol) {
            yyerror("Variable not declared");
        } else if (symbol->isConst) {
            yyerror("Cannot assign to a constant variable");
        } else {
            if (strcmp(symbol->type, "int") == 0) {
                // int value;
                // scanf("%d", &value);
                // symbol->value.intValue = value;
            } else if (strcmp(symbol->type, "float") == 0 || strcmp(symbol->type, "double") == 0) {
                // float value;
                // scanf("%f", &value);
                // symbol->value.realValue = value;
            } else if (strcmp(symbol->type, "bool") == 0) {
                // bool value;
                // scanf("%d", &value);
                // symbol->value.boolValue = value;
            } else if (strcmp(symbol->type, "char") == 0 || strcmp(symbol->type, "string") == 0) {
                // char value[100];
                // scanf("%s", value);
                // free(symbol->value.stringValue); // free old value
                // symbol->value.stringValue = strdup(value);
            } else {
                yyerror("Invalid type for read statement");
            }
        }
    }
    ;

increment_decrement:
    ID OP_INC DELIM_SEMICOLON {
        // printf("Increment statement: %s\n", $1); // for debugging
        Symbol *symbol = lookupSymbol(currentTable, $1);
        if (!symbol) {
            yyerror("Variable not declared");
        } else if (symbol->isConst) {
            yyerror("Cannot assign to a constant variable");
        } else {
            if (strcmp(symbol->type, "int") == 0) {
                // symbol->value.intValue++;
            } else if (strcmp(symbol->type, "float") == 0 || strcmp(symbol->type, "double") == 0) {
                // symbol->value.realValue++;
            } else {
                yyerror("Invalid type for increment statement");
            }
        }
    }
    | ID OP_DEC DELIM_SEMICOLON {
        // printf("Decrement statement: %s\n", $1); // for debugging
        Symbol *symbol = lookupSymbol(currentTable, $1);
        if (!symbol) {
            yyerror("Variable not declared");
        } else if (symbol->isConst) {
            yyerror("Cannot assign to a constant variable");
        } else {
            if (strcmp(symbol->type, "int") == 0) {
                symbol->value.intValue--;
            } else if (strcmp(symbol->type, "float") == 0 || strcmp(symbol->type, "double") == 0) {
                symbol->value.realValue--;
            } else {
                yyerror("Invalid type for decrement statement");
            }
        }
    }
    ;

semicolon_only:
    DELIM_SEMICOLON
    ;

conditional:
    KW_IF DELIM_LPAR expression DELIM_RPAR simple {
        // printf("If statement: %s\n", $3); // for debugging
        if (strcmp($3.type, "BOOL") == 0) {
            // if (*(bool *)$3.value) {
            //     // execute simple statement
            // } else {
            //     // skip simple statement
            // }
        } else {
            yyerror("Invalid type for if condition");
        }
    }
    | KW_IF DELIM_LPAR expression DELIM_RPAR block {
        // printf("If statement\n"); // for debugging
        if (strcmp($3.type, "BOOL") == 0) {
            // if (*(bool *)$3.value) {
            //     // execute block
            // } else {
            //     // skip block
            // }
        } else {
            yyerror("Invalid type for if condition");
        }
    }
    | KW_IF DELIM_LPAR expression DELIM_RPAR simple KW_ELSE simple {
        // printf("If-else statement\n"); // for debugging
        if (strcmp($3.type, "BOOL") == 0) {
            // if (*(bool *)$3.value) {
            //     // execute first block
            // } else {
            //     // execute second block
            // }
        } else {
            yyerror("Invalid type for if condition");
        }
    }
    | KW_IF DELIM_LPAR expression DELIM_RPAR simple KW_ELSE block {
        // printf("If-else statement\n"); // for debugging
        if (strcmp($3.type, "BOOL") == 0) {
            // if (*(bool *)$3.value) {
            //     // execute first block
            // } else {
            //     // execute second block
            // }
        } else {
            yyerror("Invalid type for if condition");
        }
    }
    | KW_IF DELIM_LPAR expression DELIM_RPAR block KW_ELSE simple {
        // printf("If-else statement\n"); // for debugging
        if (strcmp($3.type, "BOOL") == 0) {
            // if (*(bool *)$3.value) {
            //     // execute first block
            // } else {
            //     // execute second block
            // }
        } else {
            yyerror("Invalid type for if condition");
        }
    }
    | KW_IF DELIM_LPAR expression DELIM_RPAR block KW_ELSE block {
        // printf("If-else statement\n"); // for debugging
        if (strcmp($3.type, "BOOL") == 0) {
            // if (*(bool *)$3.value) {
            //     // execute first block
            // } else {
            //     // execute second block
            // }
        } else {
            yyerror("Invalid type for if condition");
        }
    }
    ;

loop:
    KW_WHILE DELIM_LPAR expression DELIM_RPAR simple {
        // printf("While statement: %s\n", $3); // for debugging
        if (strcmp($3.type, "BOOL") == 0) {
            // while (*(bool *)$3.value) {
            //     // execute simple statement
            // }
        } else {
            yyerror("Invalid type for while condition");
        }
    }
    | KW_WHILE DELIM_LPAR expression DELIM_RPAR block {
        // printf("While statement\n"); // for debugging
        if (strcmp($3.type, "BOOL") == 0) {
            // while (*(bool *)$3.value) {
            //     // execute block
            // }
        } else {
            yyerror("Invalid type for while condition");
        }
    }
    | KW_FOR DELIM_LPAR simple DELIM_COMMA expression DELIM_COMMA simple DELIM_RPAR simple {
        // printf("For statement\n"); // for debugging
        if (strcmp($5.type, "BOOL") == 0) {
            // while (*(bool *)$5.value) {
            //     // execute simple statement
            // }
        } else {
            yyerror("Invalid type for for condition");
        }
    }
    | KW_FOR DELIM_LPAR simple DELIM_COMMA expression DELIM_COMMA simple DELIM_RPAR block {
        // printf("For statement\n"); // for debugging
        if (strcmp($5.type, "BOOL") == 0) {
            // while (*(bool *)$5.value) {
            //     // execute simple statement
            // }
        } else {
            yyerror("Invalid type for for condition");
        }
    }
    | KW_FOREACH DELIM_LPAR ID DELIM_COLON expression DELIM_DOT DELIM_DOT expression DELIM_RPAR simple {
        if (strcmp($5.type, "INT") != 0 || strcmp($8.type, "INT") != 0) {
            yyerror("Foreach range must be integers");
        } else {
            // int start = *(int *)$5.value;
            // int end = *(int *)$7.value;

            // for (int i = start; i <= end; i++) {
            //     // execute simple statement
            //     Symbol *symbol = lookupSymbol(currentTable, $3);
            //     if (!symbol) {
            //         yyerror("Variable not declared");
            //     } else if (symbol->isConst) {
            //         yyerror("Cannot assign to a constant variable");
            //     } else {
            //         symbol->value.intValue = i;
            //     }
            //     // execute simple statement
            // }
        }
    }
    | KW_FOREACH DELIM_LPAR ID DELIM_COLON expression DELIM_DOT DELIM_DOT expression DELIM_RPAR block {
        if (strcmp($5.type, "INT") != 0 || strcmp($8.type, "INT") != 0) {
            yyerror("Foreach range must be integers");
        } else {
            // int start = *(int *)$5.value;
            // int end = *(int *)$7.value;

            // for (int i = start; i <= end; i++) {
            //     // execute simple statement
            //     Symbol *symbol = lookupSymbol(currentTable, $3);
            //     if (!symbol) {
            //         yyerror("Variable not declared");
            //     } else if (symbol->isConst) {
            //         yyerror("Cannot assign to a constant variable");
            //     } else {
            //         symbol->value.intValue = i;
            //     }
            //     // execute block
            // }
        }
    }
    ;

return_statement:
    KW_RETURN expression DELIM_SEMICOLON {
        // printf("Return statement: %s\n", $2); // for debugging
        if (strcmp($2.type, "INT") == 0) {
            // return *(int *)$2.value;
        } else if (strcmp($2.type, "REAL") == 0) {
            // return *(float *)$2.value;
        } else if (strcmp($2.type, "BOOL") == 0) {
            // return *(bool *)$2.value;
        } else if (strcmp($2.type, "STRING") == 0) {
            // return (char *)$2.value;
        } else {
            yyerror("Invalid type for return statement");
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
    /* 連夜趕工才發現自己根本越寫越歪，只要做syntax analysis就好，多做了很多沒用的功能，bruh */
}