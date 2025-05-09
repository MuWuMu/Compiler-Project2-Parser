#include "symbol_table.h"
#include "array_utils.h"

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
void insertSymbol(SymbolTable *table, const char *name, const char *type, int isConst, int isArray, DimensionInfo *dims, void *data_ptr_or_value_ptr) {
    unsigned int index = hash(name);
    Symbol *symbol = (Symbol *)malloc(sizeof(Symbol));
    symbol->name = strdup(name);
    symbol->type = strdup(type);
    symbol->isConst = isConst;
    symbol->isArray = isArray;
    symbol->dimensions = NULL; // default to NULL
    symbol->arrayData = NULL; // default to NULL

    if (isArray) {
        symbol->dimensions = dims;
        symbol->arrayData = data_ptr_or_value_ptr; // data_ptr_or_value_ptr is result of ceeate_md_array_data
    } else {
        if (dims)
            free_dimension_info(dims);
        
        if (data_ptr_or_value_ptr == NULL) { // no specified value
            if (strcmp(type, "bool") == 0) {
                symbol->value.boolValue = false; // default value for bool
            } else if (strcmp(type, "int") == 0) {
                symbol->value.intValue = 0; // default value for int
            } else if ((strcmp(type, "float") == 0) || (strcmp(type, "double") == 0)) {
                symbol->value.realValue = 0.0f; // default value for real
            } else if ((strcmp(type, "char") == 0) || (strcmp(type, "string") == 0)) {
                symbol->value.stringValue = strdup(""); // default value for string
            } else {
                symbol->value.stringValue = NULL; // default value
            }
        } else {    // has init value
            if (strcmp(type, "bool") == 0) {
                symbol->value.boolValue = *(bool *)data_ptr_or_value_ptr;
            } else if (strcmp(type, "int") == 0) {
                symbol->value.intValue = *(int *)data_ptr_or_value_ptr;
            } else if (strcmp(type, "float") == 0 || strcmp(type, "double") == 0) {
                symbol->value.realValue = *(float *)data_ptr_or_value_ptr;
            } else if (strcmp(type, "char") == 0 || strcmp(type, "string") == 0) {
                symbol->value.stringValue = strdup((char *)data_ptr_or_value_ptr);
            }
        }


        // // if not arr, deal with normal variable
        // if (value == NULL) {
        //     if (strcmp(type, "bool") == 0) {
        //         symbol->value.boolValue = false; // default value for bool
        //     } else if (strcmp(type, "int") == 0) {
        //         symbol->value.intValue = 0; // default value for int
        //     } else if (strcmp(type, "float") == 0) {
        //         symbol->value.realValue = 0.0f; // default value for float
        //     } else if (strcmp(type, "double") == 0) {
        //         symbol->value.realValue = 0.0f; // default value for double
        //     } else if (strcmp(type, "char") == 0){
        //         symbol->value.stringValue = NULL; // default value for char
        //     } else if (strcmp(type, "string") == 0 ) {
        //         symbol->value.stringValue = NULL; // default value for string
        //     }
        // } else {
        //     if (strcmp(type, "bool") == 0) {
        //         symbol->value.boolValue = *(bool *)value;
        //     } else if (strcmp(type, "int") == 0) {
        //         symbol->value.intValue = *(int *)value;
        //     } else if (strcmp(type, "float") == 0) {
        //         symbol->value.realValue = *(float *)value;
        //     } else if (strcmp(type, "double") == 0) {
        //         symbol->value.realValue = *(float *)value;
        //     } else if (strcmp(type, "char") == 0) {
        //         symbol->value.stringValue = strdup((char *)value);
        //     } else if (strcmp(type, "string") == 0) {
        //         symbol->value.stringValue = strdup((char *)value);
        //     }
        // }
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

Symbol* lookupSymbolInCurrentTable(SymbolTable *table, const char *name) {
    unsigned int index = hash(name);
    Symbol *symbol = table->table[index];
    while (symbol != NULL) {
        if (strcmp(symbol->name, name) == 0) {
            return symbol; // find
        }
        symbol = symbol->next;
    }
    return NULL; // not found
}

// Delete symbol table
void deleteSymbolTable(SymbolTable *table) {
    if (table == NULL) return;
    for (int i = 0; i < HASH_SIZE; i++) {
        Symbol *symbol = table->table[i];
        while (symbol != NULL) {
            Symbol *temp = symbol;
            symbol = symbol->next;
            free(temp->name);
            free(temp->type);
            if (temp->isArray && temp->arrayData) {
                free_md_array_data(temp->arrayData, temp->type, temp->dimensions, 0);
                free_dimension_info(temp->dimensions);  // free dimension itself
            } else if (!temp->isArray && (strcmp(temp->type, "string") == 0 || strcmp(temp->type, "char") == 0)) {
                if (temp->value.stringValue) {
                    free(temp->value.stringValue); // free string value
                }
            }
            free(temp);
        }
    }
    free(table);
}

// Dump symbol table
void dumpSymbolTable(SymbolTable *table) {
    if (table == NULL) return;
    printf("Symbol Table:\n");

    for (int i = 0; i < HASH_SIZE; i++) {
        Symbol *symbol = table->table[i];
        if (symbol) {
            while (symbol != NULL) {
                printf(" Name: %s, Type: %s", symbol->name, symbol->type);
                if (symbol->isConst)
                    printf("(const)");
                if (symbol->isArray) {
                    printf(", Array dimensions: [");
                    if (symbol->dimensions) {
                        for (int d = 0; d < symbol->dimensions->num_dimensions; d++) {
                            printf("%d", symbol->dimensions->sizes[d]);
                            if (d < symbol->dimensions->num_dimensions - 1) printf("][");
                        }
                    }
                    printf("], total elements: %ld\n", symbol->dimensions ? symbol->dimensions->total_elements : 0);
                    // TODO: Actual printing data
                } else {
                    if (symbol->isConst) {
                        printf(", Value: ");
                        if (strcmp(symbol->type, "bool") == 0) {
                            printf("%s\n", symbol->value.boolValue ? "true" : "false");
                        } else if (strcmp(symbol->type, "int") == 0) {
                            printf("%d\n", symbol->value.intValue);
                        } else if (strcmp(symbol->type, "float") == 0 || strcmp(symbol->type, "double") == 0) {
                            printf("%f\n", symbol->value.realValue);
                        } else if (strcmp(symbol->type, "string") == 0 || strcmp(symbol->type, "char") == 0) {
                            printf("%s\n", symbol->value.stringValue);
                        }
                    } else {
                        printf("\n");
                    }
                }
                symbol = symbol->next;
            }
        }
    

        // while (symbol != NULL) {
        //     if (symbol->isConst) {
        //         if (symbol->isArray) {
        //             // const array
        //             printf("Name: %s, Type: const %s, Array size: %d, Values: {", 
        //                     symbol->name, symbol->type, symbol->arraySize);
        //             int *array = (int *)symbol->value.arrayValue;
        //             for (int j = 0; j < symbol->arraySize; j++) {
        //             printf("%d", array[j]);
        //             if (j < symbol->arraySize - 1) {
        //                 printf(", ");
        //             }
        //         }
        //         printf("}\n");
        //         } else {
        //             // const value
        //             printf("Name: %s, Type: const %s, Value: ", symbol->name, symbol->type);
        //             if (strcmp(symbol->type, "bool") == 0) {
        //                 printf("%s\n", symbol->value.boolValue ? "true" : "false");
        //             } else if (strcmp(symbol->type, "int") == 0) {
        //                 printf("%d\n", symbol->value.intValue);
        //             } else if (strcmp(symbol->type, "float") == 0 || strcmp(symbol->type, "double") == 0) {
        //                 printf("%f\n", symbol->value.realValue);
        //             } else if (strcmp(symbol->type, "string") == 0 || strcmp(symbol->type, "char") == 0) {
        //                 printf("%s\n", symbol->value.stringValue);
        //             }
        //         }
        //     } else {
        //         if (symbol->isArray) {
        //             // non-const array
        //             printf("Name: %s, Type: %s, Array size: %d\n", 
        //                 symbol->name, symbol->type, symbol->arraySize);
        //         } else {
        //             // Non-const variable
        //             printf("Name: %s, Type: %s\n", symbol->name, symbol->type);
        //         }
        //     }
        //     symbol = symbol->next;
        // }
    }
}