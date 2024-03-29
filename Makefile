NASM :=	    nasm -g -f elf64 -F dwarf

CFLAGS :=   -m64 -std=c99 -march=haswell -pedantic -Wall -Wshadow \
            -Wpointer-arith -Wcast-qual -Wstrict-prototypes \
            -Wmissing-prototypes -fPIC -g -O3 -fno-omit-frame-pointer

C_SRCS :=   fe10.c \
            fe10_frombytes.c \
            fe10_tobytes.c \
            fe51_invert.c \
            ge.c \
            ge_frombytes.c \
            ge_tobytes.c \
            scalarmult.c
ASM_SRCS := fe10x4_carry.asm \
            fe10x4_mul.asm \
            fe10x4_square.asm \
            ge_double.asm \
            ge_add.asm \
            ladder.asm \
            select.asm
S_SRCS :=   fe51_mul.S \
            fe51_nsquare.S \
            fe51_pack.S
OBJS :=     ${ASM_SRCS:.asm=.o} ${S_SRCS:.S=.o} ${C_SRCS:.c=.o}

all: libcurve13318.so

debug: debug.c $(OBJS)

timeit: timeit.c $(OBJS)

libcurve13318.so: $(OBJS)
	$(CC) $(CFLAGS) -shared -o $@ $^ $(LDFLAGS) $(LDLIBS)

%.o: %.asm
	$(NASM) -l $(patsubst %.o,%.lst,$@) -o $@ $<

.PHONY: check
check: libcurve13318.so
	sage -python test_all.py -v $(TESTNAME)

.PHONY: clean
clean:
	$(RM) *.o *.gch *.a *.out *.so *.d *.lst debug timeit

%.d: %.asm
	$(NASM) -MT $(patsubst %.d,%.o,$@) -M $< >$@

%.d: %.c
	$(CC) $(CFLAGS) -M $< >$@

%.d: %.S
	$(CC) $(CFLAGS) -M $< >$@

include $(C_SRCS:%.c=%.d)
include $(ASM_SRCS:%.asm=%.d)
include $(S_SRCS:%.S=%.d)
