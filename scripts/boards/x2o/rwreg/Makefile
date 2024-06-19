rwreg.o:rwreg_no_axi_err.cpp
	g++ -c -fPIC -o rwreg.o rwreg_no_axi_err.cpp

rwreg.so:rwreg.o
	g++ -shared -o librwreg.so rwreg.o

all:rwreg.so
