//
//  FMPSDStream.m
//  fmpsd
//
//  Created by August Mueller on 10/22/10.
//  Copyright 2010 Flying Meat Inc. All rights reserved.
//

#import "FMPSDStream.h"
#import "FMPSD.h"

@interface FMPSDStream ()
- (id)initWithInputURL:(NSURL*)fileURL;
- (id)initWithOutputURL:(NSURL*)fileURL;
- (id)initWithOutputToMemory;
@end

@implementation FMPSDStream

+ (id)PSDStreamForReadingURL:(NSURL*)url {
    
    FMPSDStream *me = [[FMPSDStream alloc] initWithInputURL:url];
    
    return me;
}

+ (id)PSDStreamForWritingToURL:(NSURL*)url {
    
    FMPSDStream *me = [[FMPSDStream alloc] initWithOutputURL:url];
    
    return me;
}


+ (id)PSDStreamForWritingToMemory {
    
    FMPSDStream *me = [[FMPSDStream alloc] initWithOutputToMemory];
    
    return me;
}

+ (id)PSDStreamForReadingData:(NSData*)data {
    
    FMPSDStream *me = [[FMPSDStream alloc] initWithData:data];
    
    return me;
}

- (id)initWithData:(NSData*)data {
    self = [super init];
    if (self != nil) {
        _inputDataStream = data;
    }
    return self;
}

- (id)initWithInputURL:(NSURL*)fileURL {
	self = [super init];
	if (self != nil) {

        NSError *err = nil;
        _inputDataStream = [NSData dataWithContentsOfURL:fileURL options:NSDataReadingMapped error:&err];
        if (!_inputDataStream && err) {
            NSLog(@"err: '%@'", err);
            return nil;
        }
	}
	return self;
}

- (id)initWithOutputURL:(NSURL*)fileURL {
	self = [super init];
	if (self != nil) {
		_outputStream = [NSOutputStream outputStreamWithURL:fileURL append:NO];
        [_outputStream open];
	}
	return self;
}

- (id)initWithOutputToMemory {
	self = [super init];
	if (self != nil) {
		_outputStream = [NSOutputStream outputStreamToMemory];
        [_outputStream open];
	}
	return self;
}


- (void)close {
    
    if (_outputStream) {
        [_outputStream close];
    }
    
}

- (BOOL)hasLengthToRead:(NSUInteger)len {
    if (_location + len > [_inputDataStream length]) {
        return NO;
    }
    
    return YES;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    
    uint8_t *foo = (uint8_t *)[_inputDataStream bytes];
    
    foo += _location;
    
    if (_location + len > [_inputDataStream length]) {
        
        NSString *s = [NSString stringWithFormat:@"Buffer overrun, trying to read to %lu bytes of %lu (%lu length at location %ld)", _location + len, (unsigned long)[_inputDataStream length], (unsigned long)len, _location];
        
        NSLog(@"%@", s);
        
        [NSException raise:@"PSD Buffer Overrun" format:@"%@", s];
        
        return -1;
    }
    
    memcpy(buffer, foo, len);
    
    _location += len;
    
    return len;
}

- (uint8_t)readInt8 {
    
    uint8_t value = 0;
    
    [self read:&value maxLength:1];
    
    return value;
}

- (uint16_t)readInt16 {
    
    uint8_t buffer[2];
    uint16_t value = 0;
    
    if ([self read:buffer maxLength:2] == 2) {
        value  = buffer[0] << 8;
        value |= buffer[1];
    }
    
    
    return value;
}

- (uint32_t)readInt32 {
    
    uint32_t value = 0;
    FMAssert(sizeof(uint32_t) == 4);
    
    if ([self read:(uint8_t*)&value maxLength:sizeof(uint32_t)] == sizeof(uint32_t)) {
        #ifdef __LITTLE_ENDIAN__
            value = CFSwapInt32(value);
        #endif
    }
    
    return value;
    
    
    /*
    And this is my first attempt, until I realized I could just do the above.
    uint32_t value = -1;
    uint32_t byteCount = 4;
    
    if ((NSUInteger)(_location + byteCount) > [_inputDataStream length]) {
        
        NSString *s = [NSString stringWithFormat:@"Buffer overrun, trying to read to %lu bytes of %lu (%lu length at location %ld)", _location + byteCount, (unsigned long)[_inputDataStream length], (unsigned long)byteCount, _location];
        
        NSLog(@"%@", s);
        
        [NSException raise:@"PSD Buffer Overrun" format:@"%@", s];
        
        return -1;
    }
    
    [_inputDataStream getBytes:&value range:NSMakeRange(_location, byteCount)];
    _location += 4;
    */
    
    /*
    This is the old way we were doing things -b ut the Address Sanitizer didn't like it.
    uint8_t buffer[4];
    uint32_t value = -1;
    
    if ([self read:buffer maxLength:4] == 4) {
        value  = buffer[0] << 24;
        value |= buffer[1] << 16;
        value |= buffer[2] << 8;
        value |= buffer[3];
    }
    */
    
    return value;
}


- (int32_t)readSInt32 {
    
    uint8_t buffer[4];
    int32_t value = -1;
    
    if ([self read:buffer maxLength:4] == 4) {
        // Why the cast?
        // Left shift of 255 by 24 places cannot be represented in type 'int'
        value  = ((uint32_t)buffer[0]) << 24;
        value |= buffer[1] << 16;
        value |= buffer[2] << 8;
        value |= buffer[3];
    }
    
    return value;
}

- (double)readDouble64 {
    
    CFSwappedFloat64 sf;
    
    [self read:(uint8_t*)&sf.v maxLength:8];
    
    double f = CFConvertDoubleSwappedToHost(sf);
    
    return f;
}


- (uint64_t)readInt64 {
    
    uint64_t value = 0;
    
    [self read:(uint8_t*)&value maxLength:8];
    
#ifdef __LITTLE_ENDIAN__
    value = CFSwapInt64(value);
#endif
    
    return value;
}

- (NSInteger)readChars:(char *)buffer maxLength:(NSUInteger)len {
    return [self read:(uint8_t*)buffer maxLength:len];
}

- (NSString*)readPSDString16 {
    
    int32_t size = [self readInt32];
    
    if (size <= 0) {
        return @"";
    }
    
    unichar *c = malloc(sizeof(unichar) * (size + 1));
    
    for (int32_t i = 0; i < size; i++) {
        c[i] = [self readInt16];
        
        if (c[i] == 0) {
            size = i;
            break;
        }
    }
    
    
    c[size + 1] = 0;
    
    NSString *s = [[NSString alloc] initWithCharacters:c length:size];
    
    free(c);
    
    return s;
}

// 4 bytes (length), followed either by string or (if length is zero) 4-byte classID
- (NSString*)readPSDStringOrGetFourByteID:(uint32_t*)outId {
    int32_t size = [self readInt32];
    
    if (size <= 0) {
        *outId = [self readInt32];
        return nil;
    }
    
    char *c = malloc(sizeof(char) * (size + 1));
    [self readChars:c maxLength:size];
    c[size] = 0;
    
    NSString *s = [NSString stringWithFormat:@"%s", c];
    
    free(c);
    
    return s;
    
}

- (NSString*)readPSDString {
    
    uint32_t size = [self readInt32];
    
    if (size == 0) {
        size = 4;
    }
    
    return [self readPSDStringOfLength:size];
}

- (NSString*)readPSDStringOfLength:(uint32_t)size {
    
    char *c = malloc(sizeof(char) * (size + 1));
    
    NSInteger read = [self readChars:c maxLength:size];
    c[size] = 0;
    
    (void)read; // be quiet sa
    FMAssert(read == size);
    
    NSString *s = [NSString stringWithFormat:@"%s", c];
    
    free(c);
    
    FMAssert([s length] == size);
    
    return s;
}



- (NSString*)readPascalString {
    
    uint8_t size = [self readInt8];
    // Name: Pascal string, padded to make the size even (a null name consists of two bytes of 0)
    if((size & 0x01) == 0) {
        size ++;
    }
    
    char *c = malloc(sizeof(char) * (size + 1));
    [self readChars:c maxLength:size];
    c[size] = 0;
    
    NSString *s = [NSString stringWithFormat:@"%s", c];
    
    free(c);
    
    return s;
    
}


- (void)skipLength:(NSUInteger)len {
    _location += len;
}

- (long)location {
    return _location;
}

- (void)seekToLocation:(long)newLocation {
    _location = newLocation;
}

- (NSMutableData*)readDataOfLength:(NSUInteger)len {
    
    if (len == 0) {
        return [NSMutableData data];
    }
    
    
    NSUInteger leftToRead   = len;
    NSMutableData *data     = [NSMutableData dataWithLength:len];
    uint8_t *p              = [data mutableBytes];
    
    [self read:p maxLength:leftToRead];
    
    return data;
}

- (NSData*)readToEOF {
    
    NSMutableData *data = [NSMutableData data];
    
    int buffSize = 1024;
    NSInteger read;
    char *c = malloc(sizeof(char) * buffSize);
    
    while ((read = [self readChars:c maxLength:buffSize]) > 0) {
        [data appendBytes:c length:read];
    }
    
    free(c);
    
    return data;
}

- (void)writeInt64:(uint64_t)value {
    uint64_t writeV = CFSwapInt64HostToBig(value);
    [_outputStream write:(const uint8_t *)&writeV maxLength:8];
    _location += 8;
}

- (void)writeInt32:(uint32_t)value {
    uint32_t writeV = CFSwapInt32HostToBig(value);
    [_outputStream write:(const uint8_t *)&writeV maxLength:4];
    _location += 4;
}

- (void)writeInt16:(uint16_t)value {
    uint32_t writeV = CFSwapInt16HostToBig(value);
    [_outputStream write:(const uint8_t *)&writeV maxLength:2];
    _location += 2;
}


- (void)writeSInt16:(int16_t)value {
    uint32_t writeV = CFSwapInt16HostToBig(value);
    [_outputStream write:(const uint8_t *)&writeV maxLength:2];
    _location += 2;
}


- (void)writeSInt32:(int32_t)value {
    int32_t writeV = CFSwapInt32HostToBig(value);
    [_outputStream write:(const uint8_t *)&writeV maxLength:4];
    _location += 4;
}

- (void)writeInt8:(uint8_t)value {
    [_outputStream write:(const uint8_t *)&value maxLength:1];
    _location += 1;
}

- (void)writeDataWithLengthHeader:(NSData*)data {
    
    [self writeInt32:(uint32_t)[data length]];
    
    if ([data length] == 0) {
        return;
    }
    
    NSInteger wrote = [_outputStream write:[data bytes] maxLength:[data length]];
    
    if (wrote != (NSInteger)[data length]) {
        NSLog(@"%s:%d", __FUNCTION__, __LINE__);
        NSLog(@"didn't write enough data!");
        FMAssert(NO);
    }
    
    _location += [data length];
}


- (void)writeData:(NSData*)data {
    NSInteger wrote = [_outputStream write:[data bytes] maxLength:[data length]];
    
    if (wrote != (NSInteger)[data length]) {
        NSLog(@"%s:%d", __FUNCTION__, __LINE__);
        NSLog(@"didn't write enough data!");
        FMAssert(NO);
    }
    
    _location += [data length];
}

- (void)writeChars:(char*)chars length:(size_t)length {
    
    if (!length) {
        return;
    }
    
    NSInteger wrote = [_outputStream write:(const uint8_t *)chars maxLength:length];
    
    if (wrote != (NSInteger)length) {
        NSLog(@"%s:%d", __FUNCTION__, __LINE__);
        NSLog(@"didn't write enough data!");
        FMAssert(NO);
    }
    
    _location += length;
}

- (void)writePascalString:(NSString*)string withPadding:(int)p {
    
    // we don't have a null terminated string.
    
    FMAssert(string);
    
    
    if (![string canBeConvertedToEncoding:NSMacOSRomanStringEncoding]) {
        
        NSData *what = [string dataUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES];
        
        NSString *foo = [[NSString alloc] initWithData:what encoding:NSMacOSRomanStringEncoding];
        
        if (!foo) {
            NSLog(@"Could not convert %@ to NSMacOSRomanStringEncoding", string);
        }
        
        string = foo;
        
        FMAssert(string);
    }
    
    CFIndex len = CFStringGetLength((CFStringRef)string) + 1;
    
	unsigned char *buffer = malloc(sizeof(unsigned char) * len);
	if (CFStringGetPascalString((CFStringRef)string, buffer, len, kCFStringEncodingMacRoman)) {
        [_outputStream write:(const uint8_t *)buffer maxLength:len];
        _location += len;
    }
    else {
        NSLog(@"Could not write layer name!");
        FMAssert(NO);
    }
    
    
    while (len % p) {
        [self writeInt8:0];
        len++;
    }
    
    free(buffer);
}


- (NSData*)outputData {
    return [_outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
}


@end
