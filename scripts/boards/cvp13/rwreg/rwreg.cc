#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <string.h>
#include <sys/stat.h>
#include <dirent.h>

using namespace std;

const size_t MAP_SIZE = 0x4000000; //26 bit address

const unsigned int LAST_TRANS_ERR_ADDR = 0x02401400;

static int fd;
static void* map_base;
static void* last_trans_err_addr; // workaround for propper error reporting

extern "C" void rwreg_init(char* sysfile, unsigned int base_address) {
  char* realSysfile = sysfile;

  if (strcmp("auto", sysfile) == 0) {
    DIR *dp;
    struct dirent *de;
    struct stat statbuf;
    bool found = false;
    dp = opendir("/sys/bus/pci/devices");

    if (dp != NULL) {
      while (de = readdir (dp)) {
        lstat(de->d_name,&statbuf);
        if(S_ISDIR(statbuf.st_mode)) {
          if(strcmp(".", de->d_name) == 0 || strcmp("..", de->d_name) == 0)
            continue;

          char devFilename[40];
          strcpy(devFilename, "/sys/bus/pci/devices/");
          strcat(devFilename, de->d_name);
          strcat(devFilename, "/device");

          char devId[6];
          FILE *f = fopen(devFilename, "r");
          fscanf(f, "%s", devId);
          fclose(f);
          if (strcmp("0xbefe", devId) == 0) {
            printf("Auto detected CVP13 on PCI bus %s\n", de->d_name);
            char devBar2Res[80];
            strcpy(devBar2Res, "/sys/bus/pci/devices/");
            strcat(devBar2Res, de->d_name);
            strcat(devBar2Res, "/resource2");
            realSysfile = devBar2Res;
            found = true;
            break;
          }
        }
      }

      closedir(dp);
      if (!found) {
        printf("Could not find a CVP13 device. Please use lspci to find the device with device id = 0xbefe, and use that devices resource2 file instead of auto");
        exit(0);
      }
    }
    else {
      perror ("ERROR: Couldn't open /sys/bus/pci/devices directory");
    }
  }

  // write 1 to the enable file (needed on some systems)
  char* enableSysfile = (char*) malloc(strlen(realSysfile) * sizeof(char));
  memset(enableSysfile, 0, strlen(realSysfile));
  char *lastSepPtr = strrchr(realSysfile, '/');
  strncpy(enableSysfile, realSysfile, lastSepPtr - realSysfile);
  strcat(enableSysfile, "/enable");

  if((fd = open(enableSysfile, O_RDWR | O_SYNC)) != -1) {
//    printf("Writing 1 to %s\n", enableSysfile);
    write(fd, "1", strlen("1"));
    close(fd);
  } else {
    printf("WARN: could not open %s\n", enableSysfile);
  }

  // mmap the BAR2
  if((fd = open(realSysfile, O_RDWR | O_SYNC)) == -1) {
    printf("ERROR: could not open %s\n", realSysfile);
    exit(1);
  }
  printf("RWREG: %s opened.\n", realSysfile);
  map_base = mmap(0, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, base_address);
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
