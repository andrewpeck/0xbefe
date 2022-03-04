rwreg.o:rwreg.cpp
	g++ -c -fPIC -o rwreg.o rwreg.cpp

rwreg.so:rwreg.o
	g++ -shared -o librwreg.so rwreg.o

all:rwreg.so
