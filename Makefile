CC = clang
CFLAGS += -m64 -std=c99 -pedantic -Wall -Wshadow -Wpointer-arith -Wcast-qual \
          -Wstrict-prototypes -Wmissing-prototypes -fPIC -g -O3
C_SRCS = fe10.c \
         fe10_frombytes.c \
         fe10_tobytes.c \
         ge.c \
         ge_frombytes.c \
         ge_tobytes.c \
         scalarmult.c
ASM_SCRS =
OBJS := ${ASM_SRCS:.c=.o} ${C_SRCS:.c=.o}

all: libcurve13318.so

libcurve13318.so: $(OBJS)
	$(CC) $(CFLAGS) -shared -o $@ $^ $(LDFLAGS) $(LDLIBS)

debug: debug.c $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) $(LDLIBS)

.PHONY: check
check: libcurve13318.so
	sage -python test_all.py -v $(TESTNAME)

.PHONY: clean
clean:
	$(RM) *.o *.gch *.a *.out *.so

%.d: %.asm
	$(NASM) -MT $(patsubst %.d,%.o,$@) -M $< >$@

%.d: %.c
	$(CC) $(CFLAGS) -M $< >$@

include $(ASM_SCRS:%.asm=%.d)
include $(C_SRCS:%.c=%.d)
