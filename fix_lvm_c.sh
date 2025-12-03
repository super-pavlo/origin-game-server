#!/bin/bash
# Fix lvm.c file - remove any -e prefixes and duplicate luai_numdiv functions
# Run from work directory

echo "Fixing lvm.c file..."

cd 3rd/skynet/3rd/lua

# Backup the file
cp lvm.c lvm.c.backup

# Remove any lines starting with -e (including -e followed by function)
sed -i '/^-e /d' lvm.c
sed -i 's/^-e//' lvm.c

# Remove duplicate luai_numdiv functions (keep only the first one at the end)
# Find the line number of the last occurrence
last_line=$(grep -n "^lua_Number luai_numdiv" lvm.c | tail -1 | cut -d: -f1)

if [ -n "$last_line" ]; then
    # Remove all luai_numdiv functions
    sed -i '/^lua_Number luai_numdiv/,/^}/d' lvm.c
    
    # Add it back once at the end (before the last closing brace if any)
    printf "\nlua_Number luai_numdiv(lua_State *L, lua_Number a, lua_Number b) { if(b != cast_num(0)) return (a)/(b); else luaG_runerror(L,\"division by zero\"); }\n" >> lvm.c
fi

# Also remove any standalone -e lines
sed -i '/^-e$/d' lvm.c

cd ../../../../

echo "✅ lvm.c fixed! Backup saved as 3rd/skynet/3rd/lua/lvm.c.backup"
echo "Now try: make clean && make"

