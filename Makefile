CC :=       clang

NASM :=	    nasm -g -f elf64 -F dwarf

CFLAGS :=   -m64 -std=c99 -march=haswell -pedantic -Wall -Wshadow \
            -Wpointer-arith -Wcast-qual -Wstrict-prototypes \
            -Wmissing-prototypes -fPIC -g -O3

C_SRCS :=   fe10.c \
            fe10_frombytes.c \
            fe10_tobytes.c \
            ge.c \
            ge_frombytes.c \
            ge_tobytes.c \
            scalarmult.c
ASM_SRCS := fe10x4_carry.asm \
            fe10x4_carry_test.asm \
            fe10x4_mul_test.asm \
            fe10x4_square_test.asm \
            ge_add_test.asm
OBJS :=     ${ASM_SRCS:.asm=.o} ${C_SRCS:.c=.o}

all: libcurve13318.so

libcurve13318.so: $(OBJS)
	$(CC) $(CFLAGS) -shared -o $@ $^ $(LDFLAGS) $(LDLIBS)

%.o: %.asm
	$(NASM) -l $(patsubst %.o,%.lst,$@) -o $@ $<

.PHONY: check
check: libcurve13318.so
	sage -python test_all.py -v $(TESTNAME)

.PHONY: clean
clean:
	$(RM) *.o *.gch *.a *.out *.so *.d *.lst

%.d: %.asm
	$(NASM) -MT $(patsubst %.d,%.o,$@) -M $< >$@

%.d: %.c
	$(CC) $(CFLAGS) -M $< >$@

include $(C_SRCS:%.c=%.d)
include $(ASM_SRCS:%.asm=%.d)
