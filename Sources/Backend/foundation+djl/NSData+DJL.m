// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#import "NSData+DJL.h"

@implementation NSData (DJL)

+ (NSData *) djlDataUsingWebSafeBase64:(NSString *)base64Str
{
    static char decodingTable[128];
    static BOOL hasInited = NO;

    if (!hasInited) {
        char webSafeEncodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
        memset(decodingTable, 0, 128);
        for (unsigned int i = 0; i < sizeof(webSafeEncodingTable); i++) {
            decodingTable[(unsigned int) webSafeEncodingTable[i]] = (char)i;
        }
        hasInited = YES;
    }

    // The input string should be plain ASCII.
    const char *cString = [base64Str cStringUsingEncoding:NSASCIIStringEncoding];
    if (cString == nil) return nil;

    NSInteger inputLength = (NSInteger)strlen(cString);
    // Input length is not being restricted to multiples of 4.
    if (inputLength == 0) return [NSData data];

    while (inputLength > 0 && cString[inputLength - 1] == '=') {
        inputLength--;
    }

    NSInteger outputLength = inputLength * 3 / 4;
    NSMutableData* data = [NSMutableData dataWithLength:(NSUInteger)outputLength];
    uint8_t *output = [data mutableBytes];

    NSInteger inputPoint = 0;
    NSInteger outputPoint = 0;
    char *table = decodingTable;

    while (inputPoint < inputLength - 1) {
        int i0 = cString[inputPoint++];
        int i1 = cString[inputPoint++];
        int i2 = inputPoint < inputLength ? cString[inputPoint++] : 'A'; // 'A' will decode to \0
        int i3 = inputPoint < inputLength ? cString[inputPoint++] : 'A';

        output[outputPoint++] = (uint8_t)((table[i0] << 2) | (table[i1] >> 4));
        if (outputPoint < outputLength) {
            output[outputPoint++] = (uint8_t)(((table[i1] & 0xF) << 4) | (table[i2] >> 2));
        }
        if (outputPoint < outputLength) {
            output[outputPoint++] = (uint8_t)(((table[i2] & 0x3) << 6) | table[i3]);
        }
    }
    
    return data;
}

- (NSString *) djlUTF8String
{
    return [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
}

@end
