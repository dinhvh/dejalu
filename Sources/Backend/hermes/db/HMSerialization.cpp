// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMSerialization.h"

using namespace mailcore;

enum {
    EncodeFormatDirect = 0, // can be returned as is.
    EncodeFormatSerializable = 1, // needs to be unserialize after decoding.
};

enum {
    EncodeTypeNull = 0,
    EncodeTypeString = 1,
    EncodeTypeHashMap = 2,
    EncodeTypeArray = 3,
    EncodeTypeValue = 4,
};

static inline void encodeInt8(Data * data, int8_t value);
static inline int8_t decodeInt8(Data * data, int * poffset, int * perror);

static void encode(Data * data, Object * object);
static void encodeHashMap(Data * data, HashMap * dict);
static Object * decode(Data * data, int * poffset, int * perror);
static bool canBeEncoded(Object * object);

mailcore::Data * hermes::fastSerializedData(mailcore::Object * object)
{
    if (canBeEncoded(object)) {
        Data * data = Data::data();
        encodeInt8(data, EncodeFormatDirect);
        encode(data, object);
        return data;
    }
    else {
        HashMap * info = object->serializable();
        Data * data = Data::data();
        encodeInt8(data, EncodeFormatSerializable);
        encodeHashMap(data, info);
        return data;
    }
}

mailcore::Object * hermes::objectWithFastSerializedData(mailcore::Data * data)
{
    int offset = 0;
    int error = 0;

    int format = decodeInt8(data, &offset, &error);
    if (error != 0) {
        return NULL;
    }

    Object * info = decode(data, &offset, &error);
    if (info == NULL) {
        return NULL;
    }

    if (format == EncodeFormatSerializable) {
        return Object::objectWithSerializable((HashMap *) info);
    }
    else {
        return info;
    }
}

#pragma mark encoder

__unused static inline void encodeInt64(Data * data, int64_t value)
{
    uint64_t valueToWrite;

    valueToWrite = CFSwapInt64HostToBig(value);
    data->appendBytes((const char *) &valueToWrite, sizeof(valueToWrite));
}

static inline void encodeInt32(Data * data, int32_t value)
{
    uint32_t valueToWrite;

    valueToWrite = CFSwapInt32HostToBig(value);
    //[data appendBytes:&valueToWrite length:sizeof(valueToWrite)];
    data->appendBytes((const char *) &valueToWrite, sizeof(valueToWrite));
}

static inline void encodeInt16(Data * data, int16_t value)
{
    uint16_t valueToWrite;

    valueToWrite = CFSwapInt16HostToBig(value);
    data->appendBytes((const char *) &valueToWrite, sizeof(valueToWrite));
}

static inline void encodeInt8(Data * data, int8_t value)
{
    data->appendBytes((const char *) &value, sizeof(value));
}

__unused static inline void encodeBytes(Data * data, const char * value, size_t len)
{
    data->increaseCapacity((unsigned int) len);
    data->appendBytes(value, (unsigned int) len);
}

static void encodeNull(Data * data)
{
    encodeInt16(data, EncodeTypeNull);
}

static void encodeString(Data * data, String * value)
{
    size_t len;

    encodeInt16(data, EncodeTypeString);
    len = value->length();
    encodeInt32(data, (uint32_t) len);
    const UChar * characters = value->unicodeCharacters();
    data->increaseCapacity((unsigned int) (len * 2));
    for(unsigned int i = 0 ; i < len ; i ++) {
        encodeInt16(data, characters[i]);
    }
}

static void encodeHashMap(Data * data, HashMap * dict)
{
    encodeInt16(data, EncodeTypeHashMap);
    encodeInt32(data, dict->count());
    mc_foreachhashmapKeyAndValue(String, key, Object, value, dict) {
        encode(data, key);
        encode(data, value);
    }
}

static void encodeArray(Data * data, Array * array)
{
    encodeInt16(data, EncodeTypeArray);
    encodeInt32(data, array->count());
    mc_foreacharray(Object, o, array) {
        encode(data, o);
    }
}

static void encodeFloat(Data * data, float f)
{
    CFSwappedFloat32 valueToWrite;
    valueToWrite = CFConvertFloatHostToSwapped(f);
    data->appendBytes((const char *) &valueToWrite, sizeof(valueToWrite));
}

static void encodeDouble(Data * data, double f)
{
    CFSwappedFloat64 valueToWrite;
    valueToWrite = CFConvertDoubleHostToSwapped(f);
    data->appendBytes((const char *) &valueToWrite, sizeof(valueToWrite));
}

static void encodeValue(Data * data, Value * value)
{
    encodeInt16(data, EncodeTypeValue);
    switch (value->type()) {
        case ValueTypeBool:
            encodeInt8(data, 'B');
            encodeInt8(data, value->boolValue());
            break;
        case ValueTypeChar:
            encodeInt8(data, 'c');
            encodeInt8(data, value->charValue());
            break;
        case ValueTypeUnsignedChar:
            encodeInt8(data, 'C');
            encodeInt8(data, value->unsignedCharValue());
            break;
        case ValueTypeShort:
            encodeInt8(data, 's');
            encodeInt16(data, value->shortValue());
            break;
        case ValueTypeUnsignedShort:
            encodeInt8(data, 'S');
            encodeInt16(data, value->unsignedShortValue());
            break;
        case ValueTypeInt:
            encodeInt8(data, 'i');
            encodeInt32(data, value->intValue());
            break;
        case ValueTypeUnsignedInt:
            encodeInt8(data, 'I');
            encodeInt32(data, value->unsignedIntValue());
            break;
        case ValueTypeLong:
            encodeInt8(data, 'l');
            encodeInt64(data, value->longValue());
            break;
        case ValueTypeUnsignedLong:
            encodeInt8(data, 'L');
            encodeInt64(data, value->unsignedLongValue());
            break;
        case ValueTypeLongLong:
            encodeInt8(data, 'q');
            encodeInt64(data, value->longLongValue());
            break;
        case ValueTypeUnsignedLongLong:
            encodeInt8(data, 'Q');
            encodeInt64(data, value->unsignedLongLongValue());
            break;
        case ValueTypeFloat:
            encodeInt8(data, 'f');
            encodeFloat(data, value->floatValue());
            break;
        case ValueTypeDouble:
            encodeInt8(data, 'd');
            encodeDouble(data, value->doubleValue());
            break;
        case ValueTypePointer:
            MCAssert(0);
            break;
        case ValueTypeData:
            MCAssert(0);
            break;
        default:
            MCAssert(0);
            break;
    }
}

static void encode(Data * data, Object * object)
{
    if (object == Null::null()) {
        encodeNull(data);
    }
    else if (object->className()->isEqual(MCSTR("mailcore::String"))) {
        encodeString(data, (String *) object);
    }
    else if (object->className()->isEqual(MCSTR("mailcore::Array"))) {
        encodeArray(data, (Array *) object);
    }
    else if (object->className()->isEqual(MCSTR("mailcore::HashMap"))) {
        encodeHashMap(data, (HashMap *) object);
    }
    else if (object->className()->isEqual(MCSTR("mailcore::Value"))) {
        encodeValue(data, (Value *) object);
    }
    else {
        fprintf(stderr, "Can't encode %s: %s\n", MCUTF8(object->className()), MCUTF8(object));
        MCAssert(0);
    }
}


static bool canBeEncoded(Object * object)
{
    if (object == Null::null()) {
        return true;
    }
    else if (object->className()->isEqual(MCSTR("mailcore::String"))) {
        return true;
    }
    else if (object->className()->isEqual(MCSTR("mailcore::Array"))) {
        bool result = true;
        mc_foreacharray(Object, o, (Array *) object) {
            if (!canBeEncoded(o)) {
                result = false;
                break;
            }
        }
        return result;
    }
    else if (object->className()->isEqual(MCSTR("mailcore::HashMap"))) {
        bool result = true;
        mc_foreachhashmapKeyAndValue(String, key, Object, value, (HashMap *) object) {
            if (!canBeEncoded(key)) {
                result = false;
                break;
            }
            if (!canBeEncoded(value)) {
                result = false;
                break;
            }
        }
        return result;
    }
    else if (object->className()->isEqual(MCSTR("mailcore::Value"))) {
        return true;
    }
    else {
        //fprintf(stderr, "can't be encoded because %s\n", MCUTF8(object->className()));
        return false;
    }
}

#pragma mark decoder

static inline int16_t decodeInt16(Data * data, int * poffset, int * perror);

static int decodeType(Data * data, int * poffset, int * perror)
{
    return decodeInt16(data, poffset, perror);
}

static inline int8_t decodeInt8(Data * data, int * poffset, int * perror)
{
    if (* perror < 0) {
        return 0;
    }

    if (* poffset + 1 > data->length()) {
        * perror = -1;
        return 0;
    }

    int8_t result;

    memcpy(&result, data->bytes() + (* poffset), sizeof(result));
    * poffset += sizeof(result);
    return result;
}

static inline int16_t decodeInt16(Data * data, int * poffset, int * perror)
{
    if (* perror < 0) {
        return 0;
    }

    if (* poffset + 2 > data->length()) {
        * perror = -1;
        return 0;
    }

    int16_t result;
    uint16_t valueToRead;

    memcpy(&valueToRead, data->bytes() + (* poffset), sizeof(valueToRead));
    * poffset += sizeof(valueToRead);
    result = CFSwapInt16BigToHost(valueToRead);
    return result;
}

static inline int32_t decodeInt32(Data * data, int * poffset, int * perror)
{
    if (* perror < 0) {
        return 0;
    }

    if (* poffset + 4 > data->length()) {
        * perror = -1;
        return 0;
    }

    int32_t result;
    uint32_t valueToRead;

    memcpy(&valueToRead, data->bytes() + (* poffset), sizeof(valueToRead));
    * poffset += sizeof(valueToRead);
    result = CFSwapInt32BigToHost(valueToRead);
    return result;
}

__unused static inline int64_t decodeInt64(Data * data, int * poffset, int * perror)
{
    if (* perror < 0) {
        return 0;
    }

    if (* poffset + 8 > data->length()) {
        * perror = -1;
        return 0;
    }

    int64_t result;
    uint64_t valueToRead;

    memcpy(&valueToRead, data->bytes() + (* poffset), sizeof(valueToRead));
    * poffset += sizeof(valueToRead);
    result = CFSwapInt64BigToHost(valueToRead);
    return result;
}

static String * decodeString(Data * data, int * poffset, int * perror)
{
    if (* perror < 0) {
        return NULL;
    }

    size_t len = decodeInt32(data, poffset, perror);
    if (* perror < 0) {
        return NULL;
    }
    if (* poffset + len * 2 > data->length()) {
        * perror = -1;
        return NULL;
    }

    UChar * characters = (UChar *) malloc(len * sizeof(UChar));
    for(unsigned int i = 0 ; i < len ; i ++) {
        characters[i] = decodeInt16(data, poffset, perror);
    }
    if (* perror < 0) {
        free(characters);
        return NULL;
    }

    String * result = String::stringWithCharacters(characters, (unsigned int) len);
    free(characters);

    return result;
}

static HashMap * decodeHashMap(Data * data, int * poffset, int * perror)
{
    if (* perror < 0) {
        return NULL;
    }

    unsigned int count = decodeInt32(data, poffset, perror);
    if (* perror < 0) {
        return NULL;
    }

    HashMap * result = HashMap::hashMap();

    for(unsigned int i = 0 ; i < count ; i ++) {
        String * key = (String *) decode(data, poffset, perror);
        Object * value = decode(data, poffset, perror);
        if (* perror < 0) {
            return NULL;
        }

        result->setObjectForKey(key, value);
    }

    return result;
}

static Array * decodeArray(Data * data, int * poffset, int * perror)
{
    if (* perror < 0) {
        return NULL;
    }

    unsigned int count = decodeInt32(data, poffset, perror);
    if (* perror < 0) {
        return NULL;
    }

    Array * result = Array::array();

    for(unsigned int i = 0 ; i < count ; i ++) {
        Object * value = decode(data, poffset, perror);
        if (* perror < 0) {
            return NULL;
        }

        result->addObject(value);
    }

    return result;
}

static float decodeFloat(Data * data, int * poffset, int * perror)
{
    if (* perror < 0) {
        return 0;
    }

    if (* poffset + 4 > data->length()) {
        * perror = -1;
        return 0;
    }

    CFSwappedFloat32 valueToRead;
    float result;

    memcpy(&valueToRead, data->bytes() + (* poffset), sizeof(valueToRead));
    * poffset += sizeof(valueToRead);
    result = CFConvertFloatSwappedToHost(valueToRead);
    return result;
}

static double decodeDouble(Data * data, int * poffset, int * perror)
{
    if (* perror < 0) {
        return 0;
    }

    if (* poffset + 8 > data->length()) {
        * perror = -1;
        return 0;
    }

    CFSwappedFloat64 valueToRead;
    double result;

    memcpy(&valueToRead, data->bytes() + (* poffset), sizeof(valueToRead));
    * poffset += sizeof(valueToRead);
    result = CFConvertDoubleSwappedToHost(valueToRead);
    return result;
}

static Value * decodeValue(Data * data, int * poffset, int * perror)
{
    if (* perror < 0) {
        return NULL;
    }

    char type = decodeInt8(data, poffset, perror);
    if (* perror < 0) {
        return NULL;
    }

    Value * result = NULL;
    switch (type) {
        case 'B':
            result = Value::valueWithBoolValue(decodeInt8(data, poffset, perror));
            break;
        case 'c':
            result = Value::valueWithCharValue(decodeInt8(data, poffset, perror));
            break;
        case 'C':
            result = Value::valueWithUnsignedCharValue(decodeInt8(data, poffset, perror));
            break;
        case 's':
            result = Value::valueWithShortValue(decodeInt16(data, poffset, perror));
            break;
        case 'S':
            result = Value::valueWithUnsignedShortValue(decodeInt16(data, poffset, perror));
            break;
        case 'i':
            result = Value::valueWithIntValue(decodeInt32(data, poffset, perror));
            break;
        case 'I':
            result = Value::valueWithUnsignedIntValue(decodeInt32(data, poffset, perror));
            break;
        case 'l':
            result = Value::valueWithLongValue(decodeInt64(data, poffset, perror));
            break;
        case 'L':
            result = Value::valueWithUnsignedLongValue(decodeInt64(data, poffset, perror));
            break;
        case 'q':
            result = Value::valueWithLongLongValue(decodeInt64(data, poffset, perror));
            break;
        case 'Q':
            result = Value::valueWithUnsignedLongLongValue(decodeInt64(data, poffset, perror));
            break;
        case 'f':
            result = Value::valueWithFloatValue(decodeFloat(data, poffset, perror));
            break;
        case 'd':
            result = Value::valueWithDoubleValue(decodeDouble(data, poffset, perror));
            break;
        default:
            * perror = -1;
            return NULL;
    }

    if (* perror < 0) {
        return NULL;
    }

    return result;
}

static Object * decode(Data * data, int * poffset, int * perror)
{
    if (* perror < 0) {
        return NULL;
    }

    int type = decodeType(data, poffset, perror);
    if (* perror < 0) {
        return NULL;
    }

    switch (type) {
        case EncodeTypeNull:
            return Null::null();
        case EncodeTypeString:
            return decodeString(data, poffset, perror);
        case EncodeTypeHashMap:
            return decodeHashMap(data, poffset, perror);
        case EncodeTypeArray:
            return decodeArray(data, poffset, perror);
        case EncodeTypeValue:
            return decodeValue(data, poffset, perror);
        default:
            break;
    }

    return NULL;
}
