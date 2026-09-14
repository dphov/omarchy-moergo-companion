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
        strcmp(behavior, "&studio_unlock") == 0 || strcmp(behavior, "&layer_td") == 0 ||
        strncmp(behavior, "&bt_", 4) == 0 || strncmp(behavior, "bt_", 3) == 0) {
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
    // 1. Empty / Trans actions (Keep None and unresolved Trans empty)
    if (strcmp(raw, "&none") == 0 || strcmp(raw, "none") == 0) { strcpy(out, ""); return; }
    if (strcmp(raw, "&trans") == 0 || strcmp(raw, "trans") == 0) { strcpy(out, ""); return; }

    // 2. Hardware / Firmware actions
    if (strcmp(raw, "&bootloader") == 0) { strcpy(out, "Boot"); return; }
    if (strcmp(raw, "&sys_reset") == 0) { strcpy(out, "Reset"); return; }
    if (strcmp(raw, "&layer_td") == 0) { strcpy(out, "Layer"); return; }
    if (strncmp(raw, "&magic", 6) == 0) { strcpy(out, "Magic"); return; }

    // 3. Bluetooth profiles (&bt_0, &bt_1, etc.)
    if (strncmp(raw, "&bt_", 4) == 0) {
        int profile = atoi(raw + 4) + 1;
        sprintf(out, "BT\n%d", profile);
        return;
    }
    if (strncmp(raw, "bt_", 3) == 0) {
        int profile = atoi(raw + 3) + 1;
        sprintf(out, "BT\n%d", profile);
        return;
    }
    if (strcmp(raw, "&bt BT_CLR") == 0 || strcmp(raw, "BT_CLR") == 0) { strcpy(out, "BT\nClr"); return; }
    if (strcmp(raw, "&bt BT_CLR_ALL") == 0 || strcmp(raw, "BT_CLR_ALL") == 0) { strcpy(out, "Clr\nAll"); return; }
    if (strncmp(raw, "&bt ", 4) == 0) { sprintf(out, "%s", raw + 4); return; }

    // 4. Output selection (&out OUT_USB, &out OUT_BLE)
    if (strcmp(raw, "&out OUT_USB") == 0) { strcpy(out, "USB"); return; }
    if (strcmp(raw, "&out OUT_BLE") == 0) { strcpy(out, "BLE"); return; }
    if (strncmp(raw, "&out ", 5) == 0) { sprintf(out, "%s", raw + 5); return; }

    // 5. Layer switching (&to FACTORY_TEST, &to DEFAULT)
    if (strcmp(raw, "&to FACTORY_TEST") == 0) { strcpy(out, "Test"); return; }
    if (strcmp(raw, "&to DEFAULT") == 0) { strcpy(out, "Base"); return; }
    if (strncmp(raw, "&to ", 4) == 0) { sprintf(out, "%s", raw + 4); return; }

    // 6. RGB Underglow
    if (strncmp(raw, "&rgb_ug ", 8) == 0 || strncmp(raw, "rgb_ug ", 7) == 0) {
        const char *rgb = raw + (raw[0] == '&' ? 8 : 7);
        if (strcmp(rgb, "RGB_SPI") == 0) { strcpy(out, "RGB\nSpd+"); return; }
        if (strcmp(rgb, "RGB_SPD") == 0) { strcpy(out, "RGB\nSpd-"); return; }
        if (strcmp(rgb, "RGB_SAI") == 0) { strcpy(out, "RGB\nSat+"); return; }
        if (strcmp(rgb, "RGB_SAD") == 0) { strcpy(out, "RGB\nSat-"); return; }
        if (strcmp(rgb, "RGB_HUI") == 0) { strcpy(out, "RGB\nHue+"); return; }
        if (strcmp(rgb, "RGB_HUD") == 0) { strcpy(out, "RGB\nHue-"); return; }
        if (strcmp(rgb, "RGB_BRI") == 0) { strcpy(out, "RGB\nBri+"); return; }
        if (strcmp(rgb, "RGB_BRD") == 0) { strcpy(out, "RGB\nBri-"); return; }
        if (strcmp(rgb, "RGB_TOG") == 0) { strcpy(out, "RGB\nTog"); return; }
        if (strcmp(rgb, "RGB_EFF") == 0) { strcpy(out, "RGB\nEff"); return; }
        sprintf(out, "RGB\n%s", rgb);
        return;
    }

    const char *key = raw;
    if (strncmp(key, "&kp ", 4) == 0) {
        key += 4;
    }

    // 7. Numbers with dual legends: N1 -> !\n1, N2 -> @\n2, etc.
    if (key[0] == 'N' && isdigit((unsigned char)key[1]) && key[2] == '\0') {
        const char *symbols = ")!@#$%^&*(";
        int d = key[1] - '0';
        if (d >= 0 && d <= 9) {
            sprintf(out, "%c\n%d", symbols[d], d);
            return;
        }
    }

    // 8. Keypad symbols and numbers
    if (strcmp(key, "KP_NUM") == 0) { strcpy(out, "NumLk"); return; }
    if (strcmp(key, "KP_EQUAL") == 0) { strcpy(out, "="); return; }
    if (strcmp(key, "KP_DIVIDE") == 0) { strcpy(out, "/"); return; }
    if (strcmp(key, "KP_MULTIPLY") == 0) { strcpy(out, "*"); return; }
    if (strcmp(key, "KP_MINUS") == 0) { strcpy(out, "-"); return; }
    if (strcmp(key, "KP_PLUS") == 0) { strcpy(out, "+"); return; }
    if (strcmp(key, "KP_ENTER") == 0) { strcpy(out, "Enter"); return; }
    if (strcmp(key, "KP_DOT") == 0) { strcpy(out, "."); return; }
    if (strncmp(key, "KP_N", 4) == 0 && isdigit((unsigned char)key[4])) {
        sprintf(out, "%c", key[4]);
        return;
    }

    // 9. Media and system control
    if (strcmp(key, "C_BRI_DN") == 0) { strcpy(out, "Bri -"); return; }
    if (strcmp(key, "C_BRI_UP") == 0) { strcpy(out, "Bri +"); return; }
    if (strcmp(key, "C_PREV") == 0) { strcpy(out, "Prev"); return; }
    if (strcmp(key, "C_NEXT") == 0) { strcpy(out, "Next"); return; }
    if (strcmp(key, "C_PP") == 0) { strcpy(out, "Play"); return; }
    if (strcmp(key, "C_MUTE") == 0) { strcpy(out, "Mute"); return; }
    if (strcmp(key, "C_VOL_DN") == 0) { strcpy(out, "Vol -"); return; }
    if (strcmp(key, "C_VOL_UP") == 0) { strcpy(out, "Vol +"); return; }
    if (strcmp(key, "PAUSE_BREAK") == 0) { strcpy(out, "Pause"); return; }
    if (strcmp(key, "PSCRN") == 0) { strcpy(out, "PrtSc"); return; }
    if (strcmp(key, "SLCK") == 0) { strcpy(out, "ScrLk"); return; }
    if (strcmp(key, "CAPS") == 0) { strcpy(out, "Caps"); return; }
    if (strcmp(key, "INS") == 0) { strcpy(out, "Ins"); return; }
    if (strcmp(key, "K_CMENU") == 0) { strcpy(out, "Menu"); return; }
    if (strcmp(key, "LPAR") == 0) { strcpy(out, "("); return; }
    if (strcmp(key, "RPAR") == 0) { strcpy(out, ")"); return; }
    if (strcmp(key, "PRCNT") == 0) { strcpy(out, "%"); return; }

    // 10. Stacked Dual Legends for symbols
    if (strcmp(key, "EQUAL") == 0) { strcpy(out, "+\n="); return; }
    if (strcmp(key, "MINUS") == 0) { strcpy(out, "_\n-"); return; }
    if (strcmp(key, "BSLH") == 0)  { strcpy(out, "|\n\\"); return; }
    if (strcmp(key, "FSLH") == 0)  { strcpy(out, "?\n/"); return; }
    if (strcmp(key, "SEMI") == 0)  { strcpy(out, ":\n;"); return; }
    if (strcmp(key, "SQT") == 0)   { strcpy(out, "\"\n'"); return; }
    if (strcmp(key, "GRAVE") == 0) { strcpy(out, "~\n`"); return; }
    if (strcmp(key, "COMMA") == 0) { strcpy(out, "<\n,"); return; }
    if (strcmp(key, "DOT") == 0)   { strcpy(out, ">\n."); return; }
    if (strcmp(key, "LBKT") == 0)  { strcpy(out, "{\n["); return; }
    if (strcmp(key, "RBKT") == 0)  { strcpy(out, "}\n]"); return; }

    // 11. Modifiers & standard keys
    if (strcmp(key, "LSHFT") == 0) { strcpy(out, "Shift"); return; }
    if (strcmp(key, "RSHFT") == 0) { strcpy(out, "Shift"); return; }
    if (strcmp(key, "LCTRL") == 0) { strcpy(out, "Control"); return; }
    if (strcmp(key, "RCTRL") == 0) { strcpy(out, "Control"); return; }
    if (strcmp(key, "LALT") == 0) { strcpy(out, "Alt"); return; }
    if (strcmp(key, "RALT") == 0) { strcpy(out, "Alt"); return; }
    if (strcmp(key, "LGUI") == 0) { strcpy(out, "System"); return; }
    if (strcmp(key, "RGUI") == 0) { strcpy(out, "System"); return; }
    if (strcmp(key, "BSPC") == 0) { strcpy(out, "Bksp"); return; }
    if (strcmp(key, "DEL") == 0) { strcpy(out, "Delete"); return; }
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
            *destination++ = *source++;
        } else if (*source == '\n') {
            *destination++ = '\\';
            *destination++ = 'n';
            source++;
        } else {
            *destination++ = *source++;
        }
    }
    *destination = '\0';
}

void humanize_layer_name(const char *raw, char *out) {
    if (strcmp(raw, "default_layer") == 0 || strcmp(raw, "default") == 0) {
        strcpy(out, "Base");
        return;
    }
    if (strcmp(raw, "lower_layer") == 0 || strcmp(raw, "lower") == 0) {
        strcpy(out, "Lower");
        return;
    }
    if (strcmp(raw, "magic_layer") == 0 || strcmp(raw, "magic") == 0) {
        strcpy(out, "Magic");
        return;
    }
    if (strcmp(raw, "factory_test_layer") == 0 || strcmp(raw, "factory_test") == 0) {
        strcpy(out, "Test");
        return;
    }

    char buf[LAYER_NAME_MAX];
    strncpy(buf, raw, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';

    int len = strlen(buf);
    if (len > 6 && strcmp(buf + len - 6, "_layer") == 0) {
        buf[len - 6] = '\0';
    }

    int out_idx = 0;
    bool cap_next = true;
    for (int i = 0; buf[i] && out_idx < LAYER_NAME_MAX - 1; i++) {
        if (buf[i] == '_') {
            out[out_idx++] = ' ';
            cap_next = true;
        } else {
            out[out_idx++] = cap_next ? toupper((unsigned char)buf[i]) : buf[i];
            cap_next = false;
        }
    }
    out[out_idx] = '\0';
}

void describe_key_code(const char *raw, const char *humanized, char *out_title, char *out_desc) {
    out_title[0] = '\0';
    out_desc[0] = '\0';

    if (raw == NULL || raw[0] == '\0') return;

    // 1. Output selection
    if (strcmp(raw, "&out OUT_USB") == 0 || strcmp(raw, "out OUT_USB") == 0) {
        strcpy(out_title, "Output Selection USB");
        strcpy(out_desc, "Allows selecting whether keyboard output is sent to the USB or bluetooth connection when both are connected.");
        return;
    }
    if (strcmp(raw, "&out OUT_BLE") == 0 || strcmp(raw, "out OUT_BLE") == 0) {
        strcpy(out_title, "Output Selection BLE");
        strcpy(out_desc, "Allows selecting whether keyboard output is sent to the USB or bluetooth connection when both are connected.");
        return;
    }

    // 2. Bluetooth profiles
    if (strncmp(raw, "&bt_", 4) == 0 || strncmp(raw, "bt_", 3) == 0) {
        int profile = atoi(raw + (raw[0] == '&' ? 4 : 3)) + 1;
        sprintf(out_title, "Bluetooth Profile %d", profile);
        sprintf(out_desc, "Switches active Bluetooth connection to profile %d.", profile);
        return;
    }
    if (strcmp(raw, "&bt BT_CLR") == 0 || strcmp(raw, "BT_CLR") == 0) {
        strcpy(out_title, "Bluetooth Clear Profile");
        strcpy(out_desc, "Clears the pairing record for the currently selected Bluetooth profile.");
        return;
    }
    if (strcmp(raw, "&bt BT_CLR_ALL") == 0 || strcmp(raw, "BT_CLR_ALL") == 0) {
        strcpy(out_title, "Bluetooth Clear All Profiles");
        strcpy(out_desc, "Clears all saved Bluetooth pairing records on the keyboard.");
        return;
    }

    // 3. Firmware / Hardware actions
    if (strcmp(raw, "&bootloader") == 0) {
        strcpy(out_title, "Bootloader Mode");
        strcpy(out_desc, "Reboots keyboard into UF2 mass-storage bootloader mode for firmware flashing.");
        return;
    }
    if (strcmp(raw, "&sys_reset") == 0) {
        strcpy(out_title, "System Reset");
        strcpy(out_desc, "Performs a hardware reset on the keyboard controller.");
        return;
    }
    if (strncmp(raw, "&magic", 6) == 0) {
        strcpy(out_title, "Magic Layer");
        strcpy(out_desc, "Momentary switch to Glove80 hardware configuration and pairing layer.");
        return;
    }
    if (strcmp(raw, "&layer_td") == 0) {
        strcpy(out_title, "Layer Tap-Dance");
        strcpy(out_desc, "Tap to toggle layer, hold to temporarily access the Lower layer.");
        return;
    }
    if (strcmp(raw, "&to FACTORY_TEST") == 0) {
        strcpy(out_title, "To Layer: Test");
        strcpy(out_desc, "Switches keyboard layer to the factory test layer.");
        return;
    }
    if (strcmp(raw, "&to DEFAULT") == 0) {
        strcpy(out_title, "To Layer: Base");
        strcpy(out_desc, "Switches keyboard layer back to the default Base layer.");
        return;
    }

    // 4. RGB Underglow
    if (strncmp(raw, "&rgb_ug ", 8) == 0 || strncmp(raw, "rgb_ug ", 7) == 0) {
        const char *rgb = raw + (raw[0] == '&' ? 8 : 7);
        if (strcmp(rgb, "RGB_TOG") == 0) {
            strcpy(out_title, "RGB Underglow Toggle");
            strcpy(out_desc, "Toggles underglow RGB lighting on or off.");
            return;
        }
        if (strcmp(rgb, "RGB_EFF") == 0) {
            strcpy(out_title, "RGB Underglow Effect");
            strcpy(out_desc, "Cycles through underglow RGB animation effects.");
            return;
        }
        if (strcmp(rgb, "RGB_BRI") == 0) {
            strcpy(out_title, "RGB Brightness Up");
            strcpy(out_desc, "Increases underglow RGB brightness.");
            return;
        }
        if (strcmp(rgb, "RGB_BRD") == 0) {
            strcpy(out_title, "RGB Brightness Down");
            strcpy(out_desc, "Decreases underglow RGB brightness.");
            return;
        }
        if (strcmp(rgb, "RGB_HUI") == 0) {
            strcpy(out_title, "RGB Hue Up");
            strcpy(out_desc, "Increases underglow RGB color hue.");
            return;
        }
        if (strcmp(rgb, "RGB_HUD") == 0) {
            strcpy(out_title, "RGB Hue Down");
            strcpy(out_desc, "Decreases underglow RGB color hue.");
            return;
        }
        if (strcmp(rgb, "RGB_SAI") == 0) {
            strcpy(out_title, "RGB Saturation Up");
            strcpy(out_desc, "Increases underglow RGB color saturation.");
            return;
        }
        if (strcmp(rgb, "RGB_SAD") == 0) {
            strcpy(out_title, "RGB Saturation Down");
            strcpy(out_desc, "Decreases underglow RGB color saturation.");
            return;
        }
        if (strcmp(rgb, "RGB_SPI") == 0) {
            strcpy(out_title, "RGB Speed Up");
            strcpy(out_desc, "Increases animation speed of underglow RGB effects.");
            return;
        }
        if (strcmp(rgb, "RGB_SPD") == 0) {
            strcpy(out_title, "RGB Speed Down");
            strcpy(out_desc, "Decreases animation speed of underglow RGB effects.");
            return;
        }
        sprintf(out_title, "RGB Underglow %s", rgb);
        return;
    }

    const char *key = raw;
    if (strncmp(key, "&kp ", 4) == 0) key += 4;

    // 5. Media keys
    if (strcmp(key, "C_BRI_UP") == 0) { strcpy(out_title, "Brightness Up"); strcpy(out_desc, "Increases display brightness."); return; }
    if (strcmp(key, "C_BRI_DN") == 0) { strcpy(out_title, "Brightness Down"); strcpy(out_desc, "Decreases display brightness."); return; }
    if (strcmp(key, "C_VOL_UP") == 0) { strcpy(out_title, "Volume Up"); strcpy(out_desc, "Increases audio output volume."); return; }
    if (strcmp(key, "C_VOL_DN") == 0) { strcpy(out_title, "Volume Down"); strcpy(out_desc, "Decreases audio output volume."); return; }
    if (strcmp(key, "C_MUTE") == 0)   { strcpy(out_title, "Mute Audio"); strcpy(out_desc, "Mutes or unmutes audio output."); return; }
    if (strcmp(key, "C_PP") == 0)     { strcpy(out_title, "Play / Pause"); strcpy(out_desc, "Toggles media playback."); return; }
    if (strcmp(key, "C_NEXT") == 0)   { strcpy(out_title, "Next Track"); strcpy(out_desc, "Skips to the next media track."); return; }
    if (strcmp(key, "C_PREV") == 0)   { strcpy(out_title, "Previous Track"); strcpy(out_desc, "Skips to the previous media track."); return; }
    if (strcmp(key, "PSCRN") == 0)    { strcpy(out_title, "Print Screen"); strcpy(out_desc, "Captures screenshot of the screen."); return; }
    if (strcmp(key, "PAUSE_BREAK") == 0) { strcpy(out_title, "Pause / Break"); strcpy(out_desc, "Sends standard Pause/Break scancode."); return; }
    if (strcmp(key, "SLCK") == 0)     { strcpy(out_title, "Scroll Lock"); strcpy(out_desc, "Toggles scroll lock."); return; }
    if (strcmp(key, "CAPS") == 0)     { strcpy(out_title, "Caps Lock"); strcpy(out_desc, "Toggles uppercase lock."); return; }
    if (strcmp(key, "INS") == 0)      { strcpy(out_title, "Insert"); strcpy(out_desc, "Toggles insert or overwrite mode."); return; }
    if (strcmp(key, "K_CMENU") == 0)  { strcpy(out_title, "Context Menu"); strcpy(out_desc, "Opens application context menu."); return; }

    // 6. Navigation and edit keys
    if (strcmp(key, "BSPC") == 0)     { strcpy(out_title, "Backspace"); strcpy(out_desc, "Deletes character before the cursor."); return; }
    if (strcmp(key, "DEL") == 0)      { strcpy(out_title, "Delete"); strcpy(out_desc, "Deletes character after the cursor."); return; }
    if (strcmp(key, "RET") == 0)      { strcpy(out_title, "Enter / Return"); strcpy(out_desc, "Sends Return / Enter key."); return; }
    if (strcmp(key, "SPACE") == 0)    { strcpy(out_title, "Space"); strcpy(out_desc, "Inserts a space character."); return; }
    if (strcmp(key, "TAB") == 0)      { strcpy(out_title, "Tab"); strcpy(out_desc, "Advances focus or inserts tab space."); return; }
    if (strcmp(key, "ESC") == 0)      { strcpy(out_title, "Escape"); strcpy(out_desc, "Sends Escape key."); return; }
    if (strcmp(key, "PG_UP") == 0)    { strcpy(out_title, "Page Up"); strcpy(out_desc, "Scrolls up one page."); return; }
    if (strcmp(key, "PG_DN") == 0)    { strcpy(out_title, "Page Down"); strcpy(out_desc, "Scrolls down one page."); return; }
    if (strcmp(key, "HOME") == 0)     { strcpy(out_title, "Home"); strcpy(out_desc, "Moves cursor to the start of the line."); return; }
    if (strcmp(key, "END") == 0)      { strcpy(out_title, "End"); strcpy(out_desc, "Moves cursor to the end of the line."); return; }
    if (strcmp(key, "LEFT") == 0)     { strcpy(out_title, "Left Arrow"); strcpy(out_desc, "Moves cursor left."); return; }
    if (strcmp(key, "RIGHT") == 0)    { strcpy(out_title, "Right Arrow"); strcpy(out_desc, "Moves cursor right."); return; }
    if (strcmp(key, "UP") == 0)       { strcpy(out_title, "Up Arrow"); strcpy(out_desc, "Moves cursor up."); return; }
    if (strcmp(key, "DOWN") == 0)     { strcpy(out_title, "Down Arrow"); strcpy(out_desc, "Moves cursor down."); return; }

    // 7. Modifiers
    if (strcmp(key, "LSHFT") == 0 || strcmp(key, "RSHFT") == 0) { strcpy(out_title, "Shift Modifier"); strcpy(out_desc, "Shift key modifier."); return; }
    if (strcmp(key, "LCTRL") == 0 || strcmp(key, "RCTRL") == 0) { strcpy(out_title, "Control Modifier"); strcpy(out_desc, "Control key modifier."); return; }
    if (strcmp(key, "LALT") == 0 || strcmp(key, "RALT") == 0)   { strcpy(out_title, "Alt Modifier"); strcpy(out_desc, "Alt / Option key modifier."); return; }
    if (strcmp(key, "LGUI") == 0 || strcmp(key, "RGUI") == 0)   { strcpy(out_title, "GUI / Super"); strcpy(out_desc, "Command / Windows / Super key."); return; }

    // 8. Keypad
    if (strcmp(key, "KP_NUM") == 0)   { strcpy(out_title, "Num Lock"); strcpy(out_desc, "Toggles numeric keypad lock."); return; }
    if (strcmp(key, "KP_ENTER") == 0) { strcpy(out_title, "Keypad Enter"); strcpy(out_desc, "Sends keypad Enter key."); return; }
    if (strncmp(key, "KP_N", 4) == 0 && isdigit((unsigned char)key[4])) {
        sprintf(out_title, "Keypad %c", key[4]);
        sprintf(out_desc, "Types keypad number %c.", key[4]);
        return;
    }

    // Default title from clean humanized legend (replacing \n with space)
    if (humanized && humanized[0] != '\0') {
        char clean[KEY_STR_MAX];
        strncpy(clean, humanized, KEY_STR_MAX - 1);
        clean[KEY_STR_MAX - 1] = '\0';
        for (int i = 0; clean[i]; i++) {
            if (clean[i] == '\n') clean[i] = ' ';
        }
        sprintf(out_title, "Key: %s", clean);
    }
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
            char raw_name[LAYER_NAME_MAX];
            strncpy(raw_name, name_start, len);
            raw_name[len] = '\0';
            humanize_layer_name(raw_name, out_name);
        }
    }
}

#define MAX_LAYERS 32
#define MAX_KEYS_PER_LAYER 128

typedef struct {
    char text[KEY_STR_MAX];
    char title[KEY_STR_MAX];
    char desc[256];
    bool is_trans;
} ParsedKey;

typedef struct {
    char name[LAYER_NAME_MAX];
    ParsedKey keys[MAX_KEYS_PER_LAYER];
    int key_count;
} ParsedLayer;

static ParsedLayer g_layers[MAX_LAYERS];
static int g_layer_count = 0;

void parse_layer_bindings(char *bindings_string, ParsedLayer *layer) {
    char *tokens[MAX_TOKENS];
    int token_count = 0;
    
    char *token = strtok(bindings_string, " \t\r\n");
    while (token && token_count < MAX_TOKENS) {
        tokens[token_count++] = token;
        token = strtok(NULL, " \t\r\n");
    }

    layer->key_count = 0;
    for (int i = 0; i < token_count && layer->key_count < MAX_KEYS_PER_LAYER; i++) {
        int behavior_idx = i;
        int required_args = get_zmk_behavior_arity(tokens[behavior_idx]);
        char key_string[KEY_STR_MAX] = {0};
        
        strncpy(key_string, tokens[behavior_idx], KEY_STR_MAX - 1);
        
        for (int j = 0; j < required_args && (i + 1) < token_count; j++) {
            i++;
            strncat(key_string, " ", KEY_STR_MAX - strlen(key_string) - 1);
            strncat(key_string, tokens[i], KEY_STR_MAX - strlen(key_string) - 1);
        }

        ParsedKey *pk = &layer->keys[layer->key_count];
        pk->is_trans = (strcmp(tokens[behavior_idx], "&trans") == 0 || strcmp(tokens[behavior_idx], "trans") == 0);

        humanize_key_code(key_string, pk->text);
        describe_key_code(key_string, pk->text, pk->title, pk->desc);
        layer->key_count++;
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

    char *layer_start = strstr(source_code, "keymap {");
    if (!layer_start) {
        layer_start = source_code;
    }

    g_layer_count = 0;
    while ((layer_start = strstr(layer_start, "bindings = <")) != NULL && g_layer_count < MAX_LAYERS) {
        ParsedLayer *layer = &g_layers[g_layer_count];
        extract_layer_name(layer_start, source_code, layer->name);

        char *bindings_end = strchr(layer_start, '>');
        if (bindings_end) {
            *bindings_end = '\0';
            char *bindings_content = layer_start + 12;
            
            parse_layer_bindings(bindings_content, layer);
            
            *bindings_end = '>';
            layer_start = bindings_end;
        }

        g_layer_count++;
    }

    // Resolve transparent fall-through keys
    for (int l = 0; l < g_layer_count; l++) {
        for (int k = 0; k < g_layers[l].key_count; k++) {
            if (g_layers[l].keys[k].is_trans) {
                for (int prev = l - 1; prev >= 0; prev--) {
                    if (k < g_layers[prev].key_count && !g_layers[prev].keys[k].is_trans && g_layers[prev].keys[k].text[0] != '\0') {
                        strncpy(g_layers[l].keys[k].text, g_layers[prev].keys[k].text, KEY_STR_MAX - 1);
                        g_layers[l].keys[k].text[KEY_STR_MAX - 1] = '\0';
                        strncpy(g_layers[l].keys[k].title, g_layers[prev].keys[k].title, KEY_STR_MAX - 1);
                        g_layers[l].keys[k].title[KEY_STR_MAX - 1] = '\0';
                        strncpy(g_layers[l].keys[k].desc, g_layers[prev].keys[k].desc, sizeof(g_layers[l].keys[k].desc) - 1);
                        g_layers[l].keys[k].desc[sizeof(g_layers[l].keys[k].desc) - 1] = '\0';
                        break;
                    }
                }
            }
        }
    }

    // Output JSON
    printf("{\n  \"layers\": [\n");
    for (int l = 0; l < g_layer_count; l++) {
        if (l > 0) printf(",\n");
        printf("    {\n      \"name\": \"%s\",\n      \"keys\": [\n", g_layers[l].name);
        for (int k = 0; k < g_layers[l].key_count; k++) {
            if (k > 0) printf(",\n");
            char escaped_key[ESCAPED_KEY_MAX];
            char escaped_title[ESCAPED_KEY_MAX];
            char escaped_desc[512];
            escape_json_string(g_layers[l].keys[k].text, escaped_key);
            escape_json_string(g_layers[l].keys[k].title, escaped_title);
            escape_json_string(g_layers[l].keys[k].desc, escaped_desc);
            printf("        {\"text\": \"%s\", \"title\": \"%s\", \"desc\": \"%s\", \"trans\": %s}",
                   escaped_key, escaped_title, escaped_desc, g_layers[l].keys[k].is_trans ? "true" : "false");
        }
        printf("\n      ]\n    }");
    }
    printf("\n  ]\n}\n");

    free(source_code);
    return EXIT_SUCCESS;
}
