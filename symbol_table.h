#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#define HASH_SIZE 211

typedef struct Node {
    char *name;               // variable name
    struct Node *next;       // pointer to next
    void *value;             // initial value if any
} Node;

// Symbol structure
typedef struct Symbol {
    char *name;       // id name
    char *type;       // id type
    int isConst;      // const or not
    int isArray;     // array or not
    int arraySize;    // size of array if isArray is true
    union {
        bool boolValue;
        int intValue;
        float realValue; 
        char *stringValue;
        void *arrayValue;
    } value;             // value of the symbol
    struct Symbol *next; 
} Symbol;

// Symbol table structure
typedef struct SymbolTable {
    Symbol *table[HASH_SIZE];      // hash table
    struct SymbolTable *parent;    // point to parent table
} SymbolTable;

SymbolTable* createSymbolTable(SymbolTable *parent);
void insertSymbol(SymbolTable *table, const char *name, const char *type, int isConst, void *value, int isArray, int arraySize);
Symbol* lookupSymbol(SymbolTable *table, const char *name);
void deleteSymbolTable(SymbolTable *table);
void dumpSymbolTable(SymbolTable *table);

unsigned int hash(const char *key);

#endif