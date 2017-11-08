CC = clang
CFLAGS += -m64 -std=c99 -pedantic -Wall -Wshadow -Wpointer-arith -Wcast-qual \
          -Wstrict-prototypes -Wmissing-prototypes -fPIC -g -O3
SRCS = fe_frombytes.c \
       fe_mul.c \
       ge_frombytes.c \
       scalarmult.c
OBJS := ${SRCS:.c=.o}

all: $(OBJS)

.PHONY: clean
clean:
	$(RM) *.o *.gch *.a *.out *.so
