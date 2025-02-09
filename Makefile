ifeq ($(shell uname),Darwin)
USE_CLANG ?= 1
$(info INFO: Building on Darwin)
BREW ?= $(shell command -v brew)
TOOLCHAIN ?= $(shell $(BREW) --prefix llvm)/bin/
ifeq ($(shell ls $(TOOLCHAIN)/ld.lld 2>/dev/null),)
LLDDIR ?= $(shell $(BREW) --prefix lld)/bin/
else
LLDDIR ?= $(TOOLCHAIN)
endif
$(info INFO: Toolchain path: $(TOOLCHAIN))
endif

ifeq ($(shell uname -m),aarch64)
ARCH ?=
else
ARCH ?= aarch64-linux-gnu-
endif

ifneq ($(TOOLCHAIN),$(LLDDIR))
$(info INFO: LLD path: $(LLDDIR))
endif

ifeq ($(USE_CLANG),1)
CC := $(TOOLCHAIN)clang --target=$(ARCH)
AS := $(TOOLCHAIN)clang --target=$(ARCH)
LD := $(LLDDIR)ld.lld
OBJCOPY := $(TOOLCHAIN)llvm-objcopy
CLANG_FORMAT ?= $(TOOLCHAIN)clang-format
EXTRA_CFLAGS ?=
else
CC := $(TOOLCHAIN)$(ARCH)gcc
AS := $(TOOLCHAIN)$(ARCH)gcc
LD := $(TOOLCHAIN)$(ARCH)ld
OBJCOPY := $(TOOLCHAIN)$(ARCH)objcopy
CLANG_FORMAT ?= clang-format
EXTRA_CFLAGS ?= -Wstack-usage=2048
endif

CFLAGS := -O2 -Wall -Wundef -Werror=strict-prototypes -fno-common -fno-PIE \
    -Werror=implicit-function-declaration -Werror=implicit-int \
    -ffreestanding -fpic
LDFLAGS := -EL -maarch64elf --no-undefined -X -shared -Bsymbolic \
    -z notext --no-apply-dynamic-relocs --orphan-handling=warn --strip-debug \
    -z nocopyreloc \

OBJECTS := bootlogo_128.o bootlogo_256.o fb.o main.o start.o startup.o \
	string.o uart.o utils.o utils_asm.o vsprintf.o

BUILD_OBJS := $(patsubst %,build/%,$(OBJECTS))
NAME := m1n1
TARGET := m1n1.macho
TARGET_RAW := m1n1.bin

DEPDIR := build/.deps

.PHONY: all clean format
all: build/$(TARGET) build/$(TARGET_RAW)
clean:
	rm -rf build/* build/.deps
format:
	$(CLANG_FORMAT) -i src/*.c src/*.h

build/%.o: src/%.S
	@echo "  AS    $@"
	@mkdir -p $(DEPDIR)
	@$(AS) -c $(CFLAGS) -Wp,-MMD,$(DEPDIR)/$(*F).d,-MQ,"$@",-MP -o $@ $<

build/%.o: src/%.c
	@echo "  CC    $@"
	@mkdir -p $(DEPDIR)
	@$(CC) -c $(CFLAGS) -Wp,-MMD,$(DEPDIR)/$(*F).d,-MQ,"$@",-MP -o $@ $<

build/$(NAME).elf: $(BUILD_OBJS) m1n1.ld
	@echo "  LD    $@"
	@$(LD) -T m1n1.ld $(LDFLAGS) -o $@ $(BUILD_OBJS)

build/$(NAME)-raw.elf: $(BUILD_OBJS) m1n1-raw.ld
	@echo "  LDRAW $@"
	@$(LD) -T m1n1-raw.ld $(LDFLAGS) -o $@ $(BUILD_OBJS)
	
build/$(NAME).macho: build/$(NAME).elf
	@echo "  MACHO $@"
	@$(OBJCOPY) -O binary $< $@

build/$(NAME).bin: build/$(NAME)-raw.elf
	@echo "  RAW   $@"
	@$(OBJCOPY) -O binary $< $@

build/build_tag.h:
	@echo "  TAG   $@"
	@echo "#define BUILD_TAG \"$$(git describe --always --dirty)\"" > $@ 

build/%.bin: data/%.png
	@echo "  IMG   $@"
	@convert $< -background black -flatten -depth 8 rgba:$@

build/%.o: build/%.bin
	@echo "  BIN   $@"
	@$(OBJCOPY) -I binary -O elf64-littleaarch64 $< $@

build/main.o: build/build_tag.h src/main.c

-include $(DEPDIR)/*



