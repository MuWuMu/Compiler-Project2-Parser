#include "array_utils.h"
#include "symbol_table.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

DimensionInfo* create_dimension_list(int first_dim_size) {
    DimensionInfo *dims = (DimensionInfo*)malloc(sizeof(DimensionInfo));
    if (!dims) {
        perror("Cannot allocate memory for dimension info");
        exit(EXIT_FAILURE);
    }
    dims->num_dimensions = 1;
    dims->sizes = (int*)malloc(sizeof(int));
    if (!dims->sizes) {
        perror("Cannot allocate memory for dimension sizes");
        free(dims);
        exit(EXIT_FAILURE);
    }
    dims->sizes[0] = first_dim_size;
    dims->total_elements = first_dim_size;
    return dims;
}

DimensionInfo* add_dimension_to_list(DimensionInfo *dims, int next_dim_size) {
    if (!dims) return create_dimension_list(next_dim_size);

    dims->num_dimensions++;
    dims->sizes = (int*)realloc(dims->sizes, dims->num_dimensions * sizeof(int));
    if (!dims->sizes) {
        perror("Cannot reallocate memory for dimension sizes");
        // if realloc fail, consider how to free exist dims
        exit(EXIT_FAILURE);
    }
    dims->sizes[dims->num_dimensions - 1] = next_dim_size;
    dims->total_elements *= next_dim_size;
    return dims;
}

void free_dimension_info(DimensionInfo *dims) {
    if (dims) {
        free(dims->sizes);
        free(dims);
    }
}

// 建立多維陣列資料的遞迴輔助函數
static void* create_md_array_recursive(const char* base_type, DimensionInfo *dims, int current_dim_idx) {
    if (current_dim_idx >= dims->num_dimensions) {
        return NULL; // 如果呼叫正確，不應發生
    }

    int current_size = dims->sizes[current_dim_idx];
    if (current_dim_idx == dims->num_dimensions - 1) {
        // 基本情況：為實際資料元素分配空間
        size_t element_size;
        if (strcmp(base_type, "int") == 0) element_size = sizeof(int);
        else if (strcmp(base_type, "float") == 0 || strcmp(base_type, "double") == 0) element_size = sizeof(float);
        else if (strcmp(base_type, "bool") == 0) element_size = sizeof(bool);
        else if (strcmp(base_type, "string") == 0 || strcmp(base_type, "char") == 0) element_size = sizeof(char*); // 字串使用 char 指標陣列
        else {
            fprintf(stderr, "不支援的陣列基礎型別: %s\n", base_type);
            return NULL;
        }
        void* data_segment = calloc(current_size, element_size); // 使用 calloc 初始化為 0/false/NULL
        if (!data_segment) {
            perror("無法為多維陣列分配資料區段");
            return NULL;
        }
        // 對於 string/char 陣列，如果沒有進一步初始化，則將指標初始化為空字串
        if (strcmp(base_type, "string") == 0 || strcmp(base_type, "char") == 0) {
            for (int i = 0; i < current_size; ++i) {
                ((char**)data_segment)[i] = strdup(""); // 預設為空字串
            }
        }
        return data_segment;
    } else {
        // 遞迴步驟：為指向下一個維度的指標分配空間
        void** pointers_segment = (void**)calloc(current_size, sizeof(void*));
        if (!pointers_segment) {
            perror("無法為多維陣列分配指標區段");
            return NULL;
        }
        for (int i = 0; i < current_size; ++i) {
            pointers_segment[i] = create_md_array_recursive(base_type, dims, current_dim_idx + 1);
            if (!pointers_segment[i]) {
                // 如果其中一個失敗，清理先前分配的區段
                for (int j = 0; j < i; ++j) {
                    free_md_array_data(pointers_segment[j], base_type, dims, current_dim_idx + 1);
                }
                free(pointers_segment);
                return NULL;
            }
        }
        return pointers_segment;
    }
}

void* create_md_array_data(const char* base_type, DimensionInfo *dims) {
    if (!dims || dims->num_dimensions == 0) return NULL;
    return create_md_array_recursive(base_type, dims, 0);
}

// 初始化多維陣列資料的遞迴輔助函數
static void initialize_md_array_recursive(void* current_segment, const char* base_type, DimensionInfo *dims, int current_dim_idx, Node** current_initializer) {
    if (!current_segment || current_dim_idx >= dims->num_dimensions) {
        return;
    }

    int current_size = dims->sizes[current_dim_idx];

    if (current_dim_idx == dims->num_dimensions - 1) { // 最內層維度 (實際資料)
        for (int i = 0; i < current_size; ++i) {
            if (*current_initializer && (*current_initializer)->value) { // 如果有初始化項目
                if (strcmp(base_type, "int") == 0) {
                    ((int*)current_segment)[i] = *(int*)((*current_initializer)->value);
                } else if (strcmp(base_type, "float") == 0 || strcmp(base_type, "double") == 0) {
                    ((float*)current_segment)[i] = *(float*)((*current_initializer)->value);
                } else if (strcmp(base_type, "bool") == 0) {
                    ((bool*)current_segment)[i] = *(bool*)((*current_initializer)->value);
                } else if (strcmp(base_type, "string") == 0 || strcmp(base_type, "char") == 0) {
                    free(((char**)current_segment)[i]); // 釋放預設的空字串
                    ((char**)current_segment)[i] = strdup((char*)((*current_initializer)->value));
                }
                *current_initializer = (*current_initializer)->next; // 移動到下一個初始化項目
            } else {
                // 預設初始化已在 create_md_array_recursive 中由 calloc 或 strdup("") 處理
                // 對於 string/char，如果沒有初始化項目，則保持 strdup("")。
                // 對於數字/布林值，則保持 calloc 設定的 0/false。
            }
        }
    } else { // 指標維度
        for (int i = 0; i < current_size; ++i) {
            initialize_md_array_recursive(((void**)current_segment)[i], base_type, dims, current_dim_idx + 1, current_initializer);
        }
    }
}


void initialize_md_array_data(void* array_data, const char* base_type, DimensionInfo *dims, Node* initializer_list) {
    if (!array_data || !dims) return;
    Node* current_init = initializer_list; // 從初始化列表的頭部開始
    initialize_md_array_recursive(array_data, base_type, dims, 0, &current_init);
}


void free_md_array_data(void* array_segment, const char* base_type, DimensionInfo *dims, int current_dim_idx) {
    if (!array_segment || !dims || current_dim_idx >= dims->num_dimensions) {
        return;
    }

    int current_size = dims->sizes[current_dim_idx];
    if (current_dim_idx == dims->num_dimensions - 1) { // 最內層維度
        if (strcmp(base_type, "string") == 0 || strcmp(base_type, "char") == 0) {
            for (int i = 0; i < current_size; ++i) {
                free(((char**)array_segment)[i]); // 釋放每個字串
            }
        }
        free(array_segment); // 釋放資料區段
    } else { // 指標維度
        for (int i = 0; i < current_size; ++i) {
            free_md_array_data(((void**)array_segment)[i], base_type, dims, current_dim_idx + 1);
        }
        free(array_segment); // 釋放指標區段
    }
}

int count_initializers(Node* init_list) {
    int count = 0;
    Node* current = init_list;
    while (current != NULL) {
        count++;
        current = current->next;
    }
    return count;
}


void* get_md_array_element_ptr(Symbol *array_symbol, IndexAccessInfo *acc_indices) {
    if (!array_symbol || !array_symbol->isArray || !array_symbol->dimensions || !array_symbol->arrayData || !acc_indices) {
        return NULL; // invalid input
    }

    if (array_symbol->dimensions->num_dimensions != acc_indices->num_indices) {
        return NULL; // dimension mismatch
    }

    void *current_ptr = array_symbol->arrayData;
    for (int i = 0; i < acc_indices->num_indices; ++i) {
        int index_val = acc_indices->indices[i];
        if (index_val < 0 || index_val >= array_symbol->dimensions->sizes[i]) {
            return NULL; // index out of bounds
        }

        if (i < acc_indices->num_indices - 1) { // not the last dimension, current_ptr points to an array of pointers
            if (!current_ptr)
                return NULL; // invalid pointer
            current_ptr = ((void**)current_ptr)[index_val]; // move to the next level
        } else {
            if (!current_ptr)
                return NULL; // invalid pointer
            unsigned int element_size;
            if (strcmp(array_symbol->type, "int") == 0) element_size = sizeof(int);
            else if (strcmp(array_symbol->type, "float") == 0 || strcmp(array_symbol->type, "double") == 0) element_size = sizeof(float);
            else if (strcmp(array_symbol->type, "bool") == 0) element_size = sizeof(bool);
            else if (strcmp(array_symbol->type, "string") == 0 || strcmp(array_symbol->type, "char") == 0) element_size = sizeof(char*); // 字串使用 char 指標陣列
            else 
                return NULL; // unsupported type
            // calculate the address of the element within the current data segment
            current_ptr = (char*)current_ptr + index_val * element_size;
            return current_ptr; // return the address of the element
        }
    }
    return NULL; // should not reach here
}
