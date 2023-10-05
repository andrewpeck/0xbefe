CC ?= gcc

CFLAGS += -g
#CFLAGS += -O2 -fno-inline -Wall -Wstrict-prototypes
CFLAGS += -I. -I../include -I../dma-utils -I../rwreg
CFLAGS += $(EXTRA_FLAGS)

CSC-EMUL = csc-emulator
DMA-UTILS_OBJS := $(patsubst %.c,%.o,$(wildcard ../dma-utils/*.c))
CSC-EMUL_OBJS := csc_emulator.o
CSC-EMUL_OBJS += $(DMA-UTILS_OBJS)

ifneq ($(CROSS_COMPILE_FLAG),)
	CC=$(CROSS_COMPILE_FLAG)gcc
endif

all: clean csc-emulator

csc-emulator: $(CSC-EMUL_OBJS)
	$(CC) -lrt -o $@ $< -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE -D_LARGE_FILE_SOURCE -lrwreg -L../rwreg

%.o: %.c
	$(CC) $(CFLAGS) -c -std=c99 -o $@ $< -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE -D_LARGE_FILE_SOURCE -D_AIO_AIX_SOURCE

install: csc-emulator
	scp csc_emulator.c bench:~/0xBEFE/scripts/boards/cvp13/csc_emulator/
	scp csc-emulator bench:~/0xBEFE/scripts/boards/cvp13/csc_emulator/

clean:
	@rm -f *.o */*.o ../dma-utils/*.o
	rm -rf *.o *.bin csc-emulator
