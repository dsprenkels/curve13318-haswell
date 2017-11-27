#ifndef CURVE13318_CONSTS_H_
#define CURVE13318_CONSTS_H_

#include <inttypes.h>

static const uint64_t CURVE13318_B = 13318;

static const uint64_t MASK25 = 0xFFFFFFFFFE000000;
static const uint64_t MASK26 = 0xFFFFFFFFFC000000;

static const uint64_t _2P0 = 0x07FFFFDA;
static const uint64_t _2PRestB25 = 0x03FFFFFE;
static const uint64_t _2PRestB26 = 0x07FFFFFE;

static const uint64_t _4P0 = 0x0FFFFFB4;
static const uint64_t _4PRestB25 = 0x07FFFFFC;
static const uint64_t _4PRestB26 = 0x0FFFFFFC;

#endif // CURVE13318_CONSTS_H_
