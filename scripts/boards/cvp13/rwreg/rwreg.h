#ifndef RWREG_H
#define RWREG_H

void rwreg_init(char* sysfile, unsigned int base_address);
void rwreg_close();
unsigned int getReg(unsigned int address);
unsigned int putReg(unsigned int address, unsigned int value);

#endif /* RWREG_H */
