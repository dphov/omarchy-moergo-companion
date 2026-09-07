#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdbool.h>

#define MAX_TOKENS 1000
#define LAYER_NAME_MAX 64
#define KEY_STR_MAX 128
#define ESCAPED_KEY_MAX 256

int get_zmk_behavior_arity(const char *behavior) {
    if (strcmp(behavior, "&none") == 0 || strcmp(behavior, "&trans") == 0 || 
        strcmp(behavior, "&sys_reset") == 0 || strcmp(behavior, "&bootloader") == 0 ||
        strcmp(behavior, "&studio_unlock") == 0 || strcmp(behavior, "&layer_td") == 0) {
        return 0;
    }
    
    if (strncmp(behavior, "&mt", 3) == 0 || strncmp(behavior, "&lt", 3) == 0 || 
        strncmp(behavior, "&hm", 3) == 0 || strncmp(behavior, "&as", 3) == 0 ||
        strcmp(behavior, "&magic") == 0) {
        return 2;
    }
    
    if (behavior[0] == '&' || strcmp(behavior, "rgb_ug") == 0) {
        return 1;
    }
    
    return 0; // C macros (bt_0, etc.)
}

void humanize_key_code(const char *raw, char *out) {
    if (strcmp(raw, "&none") == 0) { strcpy(out, ""); return; }
    if (strcmp(raw, "&trans") == 0) { strcpy(out, "▽"); return; }
    if (strcmp(raw, "&bootloader") == 0) { strcpy(out, "Boot"); return; }
    if (strcmp(raw, "&sys_reset") == 0) { strcpy(out, "Reset"); return; }
    if (strcmp(raw, "&layer_td") == 0) { strcpy(out, "Lower"); return; }
    if (strncmp(raw, "&magic", 6) == 0) { strcpy(out, "Magic"); return; }
    if (strncmp(raw, "bt_", 3) == 0) { sprintf(out, "BT %s", raw + 3); return; }
    if (strncmp(raw, "&bt ", 4) == 0) { sprintf(out, "%s", raw + 4); return; }
    if (strncmp(raw, "rgb_ug ", 7) == 0) { sprintf(out, "%s", raw + 7); return; }

    const char *key = raw;
    if (strncmp(key, "&kp ", 4) == 0) {
        key += 4;
    }

    // Numbers: N1 -> 1
    if (key[0] == 'N' && isdigit((unsigned char)key[1]) && key[2] == '\0') {
        sprintf(out, "%c", key[1]);
        return;
    }

    // Common abbreviations
    if (strcmp(key, "EQUAL") == 0) { strcpy(out, "="); return; }
    if (strcmp(key, "MINUS") == 0) { strcpy(out, "-"); return; }
    if (strcmp(key, "BSLH") == 0) { strcpy(out, "\\"); return; }
    if (strcmp(key, "FSLH") == 0) { strcpy(out, "/"); return; }
    if (strcmp(key, "SEMI") == 0) { strcpy(out, ";"); return; }
    if (strcmp(key, "SQT") == 0) { strcpy(out, "'"); return; }
    if (strcmp(key, "GRAVE") == 0) { strcpy(out, "`"); return; }
    if (strcmp(key, "COMMA") == 0) { strcpy(out, ","); return; }
    if (strcmp(key, "DOT") == 0) { strcpy(out, "."); return; }
    if (strcmp(key, "LBKT") == 0) { strcpy(out, "["); return; }
    if (strcmp(key, "RBKT") == 0) { strcpy(out, "]"); return; }
    if (strcmp(key, "LSHFT") == 0) { strcpy(out, "Shift"); return; }
    if (strcmp(key, "RSHFT") == 0) { strcpy(out, "Shift"); return; }
    if (strcmp(key, "LCTRL") == 0) { strcpy(out, "Ctrl"); return; }
    if (strcmp(key, "RCTRL") == 0) { strcpy(out, "Ctrl"); return; }
    if (strcmp(key, "LALT") == 0) { strcpy(out, "Alt"); return; }
    if (strcmp(key, "RALT") == 0) { strcpy(out, "Alt"); return; }
    if (strcmp(key, "LGUI") == 0) { strcpy(out, "Super"); return; }
    if (strcmp(key, "RGUI") == 0) { strcpy(out, "Super"); return; }
    if (strcmp(key, "BSPC") == 0) { strcpy(out, "Bksp"); return; }
    if (strcmp(key, "DEL") == 0) { strcpy(out, "Del"); return; }
    if (strcmp(key, "RET") == 0) { strcpy(out, "Enter"); return; }
    if (strcmp(key, "SPACE") == 0) { strcpy(out, "Space"); return; }
    if (strcmp(key, "TAB") == 0) { strcpy(out, "Tab"); return; }
    if (strcmp(key, "ESC") == 0) { strcpy(out, "Esc"); return; }
    if (strcmp(key, "PG_UP") == 0) { strcpy(out, "PgUp"); return; }
    if (strcmp(key, "PG_DN") == 0) { strcpy(out, "PgDn"); return; }
    if (strcmp(key, "LEFT") == 0) { strcpy(out, "←"); return; }
    if (strcmp(key, "RIGHT") == 0) { strcpy(out, "→"); return; }
    if (strcmp(key, "UP") == 0) { strcpy(out, "↑"); return; }
    if (strcmp(key, "DOWN") == 0) { strcpy(out, "↓"); return; }
    if (strcmp(key, "HOME") == 0) { strcpy(out, "Home"); return; }
    if (strcmp(key, "END") == 0) { strcpy(out, "End"); return; }

    // Fallback: keep key as-is
    strncpy(out, key, KEY_STR_MAX - 1);
    out[KEY_STR_MAX - 1] = '\0';
}

char* read_file_to_memory(const char* filename) {
    FILE *file = fopen(filename, "r");
    if (!file) return NULL;
    
    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    char *buffer = malloc(length + 1);
    if (buffer) {
        fread(buffer, 1, length, file);
        buffer[length] = '\0';
    }
    fclose(file);
    return buffer;
}

void strip_c_comments(char *source) {
    char *read_ptr = source;
    char *write_ptr = source;
    bool in_line_comment = false;
    bool in_block_comment = false;
    
    while (*read_ptr) {
        if (!in_line_comment && !in_block_comment && *read_ptr == '/' && *(read_ptr+1) == '/') { 
            in_line_comment = true; 
            read_ptr += 2; 
            continue; 
        }
        if (!in_line_comment && !in_block_comment && *read_ptr == '/' && *(read_ptr+1) == '*') { 
            in_block_comment = true; 
            read_ptr += 2; 
            continue; 
        }
        if (in_line_comment && *read_ptr == '\n') { 
            in_line_comment = false; 
        }
        if (in_block_comment && *read_ptr == '*' && *(read_ptr+1) == '/') { 
            in_block_comment = false; 
            read_ptr += 2; 
            continue; 
        }
        
        if (!in_line_comment && !in_block_comment) { 
            *write_ptr++ = *read_ptr; 
        }
        read_ptr++;
    }
    *write_ptr = '\0';
}

void escape_json_string(const char *source, char *destination) {
    while (*source) {
        if (*source == '"' || *source == '\\') { 
            *destination++ = '\\'; 
        }
        *destination++ = *source++;
    }
    *destination = '\0';
}

void extract_layer_name(char *layer_start, char *source_start, char *out_name) {
    strcpy(out_name, "Layer");
    char *brace = layer_start;
    
    while (brace > source_start && *brace != '{') {
        brace--;
    }
    
    if (brace > source_start) {
        char *name_end = brace - 1;
        while (name_end > source_start && isspace((unsigned char)*name_end)) {
            name_end--;
        }
        
        char *name_start = name_end;
        while (name_start > source_start && !isspace((unsigned char)*name_start) && *name_start != '}' && *name_start != ';') {
            name_start--;
        }
        name_start++;
        
        int len = name_end - name_start + 1;
        if (len > 0 && len < LAYER_NAME_MAX - 1) {
            strncpy(out_name, name_start, len);
            out_name[len] = '\0';
        }
    }
}

void parse_and_print_bindings(char *bindings_string) {
    char *tokens[MAX_TOKENS];
    int token_count = 0;
    
    char *token = strtok(bindings_string, " \t\r\n");
    while (token && token_count < MAX_TOKENS) {
        tokens[token_count++] = token;
        token = strtok(NULL, " \t\r\n");
    }

    bool is_first_key = true;
    for (int i = 0; i < token_count; i++) {
        int required_args = get_zmk_behavior_arity(tokens[i]);
        char key_string[KEY_STR_MAX] = {0};
        
        strncpy(key_string, tokens[i], KEY_STR_MAX - 1);
        
        for (int j = 0; j < required_args && (i + 1) < token_count; j++) {
            i++;
            strncat(key_string, " ", KEY_STR_MAX - strlen(key_string) - 1);
            strncat(key_string, tokens[i], KEY_STR_MAX - strlen(key_string) - 1);
        }

        char humanized[KEY_STR_MAX];
        humanize_key_code(key_string, humanized);

        char escaped_key[ESCAPED_KEY_MAX];
        escape_json_string(humanized, escaped_key);

        if (!is_first_key) {
            printf(",\n");
        }
        printf("        \"%s\"", escaped_key);
        is_first_key = false;
    }
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <keymap_file>\n", argv[0]);
        return EXIT_FAILURE;
    }

    char *source_code = read_file_to_memory(argv[1]);
    if (!source_code) {
        fprintf(stderr, "Error: Failed to read file '%s'\n", argv[1]);
        return EXIT_FAILURE;
    }

    strip_c_comments(source_code);

    printf("{\n  \"layers\": [\n");

    char *layer_start = strstr(source_code, "keymap {");
    if (!layer_start) {
        layer_start = source_code;
    }

    int parsed_layer_count = 0;

    while ((layer_start = strstr(layer_start, "bindings = <")) != NULL) {
        if (parsed_layer_count > 0) {
            printf(",\n");
        }
        
        char layer_name[LAYER_NAME_MAX];
        extract_layer_name(layer_start, source_code, layer_name);

        printf("    {\n      \"name\": \"%s\",\n      \"keys\": [\n", layer_name);

        char *bindings_end = strchr(layer_start, '>');
        if (bindings_end) {
            *bindings_end = '\0';
            char *bindings_content = layer_start + 12;
            
            parse_and_print_bindings(bindings_content);
            
            *bindings_end = '>';
            layer_start = bindings_end;
        }

        printf("\n      ]\n    }");
        parsed_layer_count++;
    }

    printf("\n  ]\n}\n");
    
    free(source_code);
    return EXIT_SUCCESS;
}
