#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <linux/un.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#include <signal.h>
#include <setjmp.h>

using namespace std;

#define REG32(baseptr, offset) (*((volatile uint32_t*)(((uint8_t*)baseptr)+(offset))))

#define FPGA0_BASE 0x50000000
#define FPGA0_SIZE 0x04000000

//#define FPGA1_BASE 0x58000000
#define FPGA1_BASE 0x60000000
#define FPGA1_SIZE 0x04000000

static int fpgaId = -1;
static uint8_t *fpga = NULL;

const unsigned int LAST_TRANS_ERR_ADDR = 0x02401400;
static void* last_trans_err_addr; // last transaction status

extern "C" void rwreg_init(char* device, unsigned int base_address) {
    if (strcmp(device, "FPGA0") == 0) {
        fpgaId = 0;
    } else if (strcmp(device, "FPGA1") == 0) {
        fpgaId = 1;
    } else {
        printf("ERROR: unknown device %s", device);
        exit(-1);
    }

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        printf("ERROR: cannot open /dev/mem");
        exit(-1);
    }

    if (fpgaId == 0) {
        fpga = (uint8_t *)mmap(NULL, FPGA0_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd, FPGA0_BASE + base_address);
    } else if (fpgaId == 1) {
        fpga = (uint8_t *)mmap(NULL, FPGA1_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd, FPGA1_BASE + base_address);
    } else {
        printf("RWREG.SO ERROR: invalid fpgaId");
        exit(-1);
    }

    last_trans_err_addr = fpga + LAST_TRANS_ERR_ADDR;

    close(fd);
}

extern "C" uint32_t getReg(uint32_t addr) {
    uint32_t ret = REG32(fpga, addr);
    uint32_t lastErr = *((uint32_t*) last_trans_err_addr);
    if (lastErr & 0x80000000) {
        return 0xdeaddead;
    } else {
        return ret;
    }
}

extern "C" uint32_t putReg(uint32_t addr, uint32_t val) {
    REG32(fpga, addr) = val;
    uint32_t lastErr = *((uint32_t*) last_trans_err_addr);
    if (lastErr & 0x80000000) {
        return -1;
    } else {
        return 0;
    }
}
