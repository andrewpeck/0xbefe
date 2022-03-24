CCFLAGS=-Wall -fPIC
LDFLAGS=-shared
CC ?= gcc

all: librwreg.so

#rwreg.o: rwreg_xdma.cc
rwreg.o: rwreg.cc
	$(CC) $(CCFLAGS) $(INC) -c -o $@ $<

librwreg.so: rwreg.o
	$(CC) $(CCFLAGS) $(LDFLAGS) -o $@ $<

clean:
	-rm -f *.o *~ librwreg.so
