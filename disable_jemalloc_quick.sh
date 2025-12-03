#!/bin/bash
# Quick fix to disable jemalloc on Ubuntu 24.04
# Run from work directory

cd 3rd/skynet

# Backup
cp Makefile Makefile.backup
cp platform.mk platform.mk.backup

# Disable jemalloc in Makefile
sed -i 's/^all : jemalloc$/all : #jemalloc/' Makefile
sed -i 's/^MALLOC_STATICLIB := $(JEMALLOC_STATICLIB)$/MALLOC_STATICLIB :=/' Makefile

# Disable jemalloc in platform.mk for Linux
if ! grep -q "linux : MALLOC_STATICLIB" platform.mk; then
    sed -i '/^macosx : SKYNET_DEFINES :=-DNOUSE_JEMALLOC$/a linux : MALLOC_STATICLIB :=\nlinux : SKYNET_DEFINES :=-DNOUSE_JEMALLOC' platform.mk
fi

cd ../..

echo "✅ Jemalloc disabled! Now run: make clean && make"

