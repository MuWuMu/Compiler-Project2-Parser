#include "symbol_table.h"

// Hash function
unsigned int hash(const char *key) {
    unsigned int hash = 0;
    while (*key) {
        hash = (hash << 5) + *key++;
    }
    return hash % HASH_SIZE;
}

// New symbol table
SymbolTable* createSymbolTable(SymbolTable *parent) {
    SymbolTable *table = (SymbolTable *)malloc(sizeof(SymbolTable));
    for (int i = 0; i < HASH_SIZE; i++) {
        table->table[i] = NULL;
    }
    table->parent = parent;
    printf("Create new symbol table\n"); // for debugging
    return table;
}

// Insert a symbol into a symbol table
void insertSymbol(SymbolTable *table, const char *name, const char *type, int isConst, void *value) {
    unsigned int index = hash(name);
    Symbol *symbol = (Symbol *)malloc(sizeof(Symbol));
    symbol->name = strdup(name);
    symbol->type = strdup(type);
    symbol->isConst = isConst;

    // set value
    if (value == NULL) {
        if (strcmp(type, "bool") == 0) {
            symbol->value.boolValue = false; // default value for bool
        } else if (strcmp(type, "int") == 0) {
            symbol->value.intValue = 0; // default value for int
        } else if (strcmp(type, "float") == 0) {
            symbol->value.realValue = 0.0f; // default value for float
        } else if (strcmp(type, "double") == 0) {
            symbol->value.realValue = 0.0f; // default value for double
        } else if (strcmp(type, "char") == 0){
            symbol->value.stringValue = NULL; // default value for char
        } else if (strcmp(type, "string") == 0 ) {
            symbol->value.stringValue = NULL; // default value for string
        }
    } else {
        if (strcmp(type, "bool") == 0) {
            symbol->value.boolValue = *(bool *)value;
        } else if (strcmp(type, "int") == 0) {
            symbol->value.intValue = *(int *)value;
        } else if (strcmp(type, "float") == 0) {
            symbol->value.realValue = *(float *)value;
        } else if (strcmp(type, "double") == 0) {
            symbol->value.realValue = *(float *)value;
        } else if (strcmp(type, "char") == 0) {
            symbol->value.stringValue = strdup((char *)value);
        } else if (strcmp(type, "string") == 0) {
            symbol->value.stringValue = strdup((char *)value);
        } else {
            symbol->value.stringValue = NULL;
        }
    }
    

    // Insert into hash table
    symbol->next = table->table[index];
    table->table[index] = symbol;
}

// Lookup a symbol in the symbol table
Symbol* lookupSymbol(SymbolTable *table, const char *name) {
    unsigned int index = hash(name);
    SymbolTable *current = table;
    while (current != NULL) {
        Symbol *symbol = current->table[index];
        while (symbol != NULL) {
            if (strcmp(symbol->name, name) == 0) {
                return symbol; // find
            }
            symbol = symbol->next;
        }
        current = current->parent; // keep search in parent table
    }
    return NULL; // not found
}

// Delete symbol table
void deleteSymbolTable(SymbolTable *table) {
    for (int i = 0; i < HASH_SIZE; i++) {
        Symbol *symbol = table->table[i];
        while (symbol != NULL) {
            Symbol *temp = symbol;
            symbol = symbol->next;
            free(temp->name);
            free(temp->type);
            if (strcmp(temp->type, "string") == 0) {
                free(temp->value.stringValue);
            }
            free(temp);
        }
    }
    free(table);
}

// Dump symbol table
void dumpSymbolTable(SymbolTable *table) {
    printf("Symbol Table:\n");
    for (int i = 0; i < HASH_SIZE; i++) {
        Symbol *symbol = table->table[i];
        while (symbol != NULL) {
            printf("Name: %s, Type: %s, Const: %d, Value: ", symbol->name, symbol->type, symbol->isConst);
            if (strcmp(symbol->type, "bool") == 0) {
                printf("%s\n", symbol->value.boolValue ? "true" : "false");
            } else if (strcmp(symbol->type, "int") == 0) {
                printf("%d\n", symbol->value.intValue);
            } else if (strcmp(symbol->type, "float") == 0) {
                printf("%f\n", symbol->value.realValue);
            } else if (strcmp(symbol->type, "double") == 0) {
                printf("%f\n", symbol->value.realValue);
            } else if (strcmp(symbol->type, "char") == 0) {
                printf("%s\n", symbol->value.stringValue);
            } else if (strcmp(symbol->type, "string") == 0) {
                printf("%s\n", symbol->value.stringValue);
            }
            symbol = symbol->next;
        }
    }
}