#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <string.h>

/*
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <fcntl.h>
#include <ctype.h>
#include <termios.h>
#include <sys/types.h>
#include <sys/mman.h>
*/

using namespace std;

const size_t MAP_SIZE = 0x4000000; //26 bit address

const unsigned int LAST_TRANS_ERR_ADDR = 0x02401400;

static int fd;
static void* map_base;
static void* last_trans_err_addr; // workaround for propper error reporting

extern "C" void rwreg_init(char* sysfile) {
  if((fd = open(sysfile, O_RDWR | O_SYNC)) == -1) {
    printf("ERROR: could not open %s\n", sysfile);
    exit(1);
  }
  printf("RWREG: %s opened.\n", sysfile);
  map_base = mmap(0, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  if(map_base == (void *) -1) {
    printf("ERROR: mmap failed\n");
    exit(1);
  }
  printf("RWREG: PCI Memory mapped to address 0x%08lx.\n", (unsigned long) map_base);
  last_trans_err_addr = map_base + LAST_TRANS_ERR_ADDR; // workaround for propper error reporting
}

extern "C" void rwreg_close() {
  close(fd);
}

extern "C" unsigned int getReg(unsigned int address) {
  void* virt_addr = map_base + address;
  int ret = *((uint32_t*) virt_addr);
  unsigned int lastErr = *((uint32_t*) last_trans_err_addr);
  if (lastErr & 0x80000000) {
    return 0xdeaddead;
  } else {
    return ret;
  }
}

extern "C" unsigned int putReg(unsigned int address, unsigned int value) {
  void* virt_addr = map_base + address;
  *((uint32_t*) virt_addr) = value;
  unsigned int lastErr = *((uint32_t*) last_trans_err_addr);
  if (lastErr & 0x80000000) {
    return -1;
  } else {
    return 0;
  }
}

