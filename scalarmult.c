#include "scalarmult.h"
#include "ge.h"

int scalarmult(uint8_t *out, const uint8_t *k, const uint8_t *in)
{
    ge p;

    int tmp = ge_frombytes(p, in);
    if (tmp != 0) {
        return -1;
    }

    return 0;
}
