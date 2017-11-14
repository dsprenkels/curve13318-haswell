CC = clang
CFLAGS += -m64 -std=c99 -pedantic -Wall -Wshadow -Wpointer-arith -Wcast-qual \
          -Wstrict-prototypes -Wmissing-prototypes -fPIC -g -O3
SRCS = fe_frombytes.c \
       fe_mul.c \
       fe_invert.c \
       ge_frombytes.c \
       scalarmult.c
OBJS := ${SRCS:.c=.o}

all: libcurve13318.so

libcurve13318.so: $(OBJS)
	$(CC) $(CFLAGS) -shared -o $@ $^ $(LDFLAGS) $(LDLIBS)

debug: debug.c $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) $(LDLIBS)

.PHONY: check
check: libcurve13318.so
	sage -python test_all.py -v

.PHONY: clean
clean:
	$(RM) *.o *.gch *.a *.out *.so
