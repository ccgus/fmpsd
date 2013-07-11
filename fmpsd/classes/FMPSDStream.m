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
        NSLog(@"wrote %ld", _location);
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

- (uint8)readInt8 {
    
    uint8 value = 0;
    
    [self read:&value maxLength:1];
    
    return value;
}

- (uint16)readInt16 {
    
    unsigned char buffer[2];
    uint16 value = 0;
    
    if ([self read:buffer maxLength:2] == 2) {
        value  = buffer[0] << 8;
        value |= buffer[1];
    }
    
    
    return value;
}

- (uint32)readInt32 {
    
    unsigned char buffer[4];
    uint32 value = -1;
    
    if ([self read:buffer maxLength:4] == 4) {
        value  = buffer[0] << 24;
        value |= buffer[1] << 16;
        value |= buffer[2] << 8;
        value |= buffer[3];
    }
    
    return value;
}


- (sint32)readSInt32 {
    
    unsigned char buffer[4];
    sint32 value = -1;
    
    if ([self read:buffer maxLength:4] == 4) {
        value  = buffer[0] << 24;
        value |= buffer[1] << 16;
        value |= buffer[2] << 8;
        value |= buffer[3];
    }
    
    return value;
}

- (double)readDouble64 {
    
    unsigned char buffer[8];
    double value = 0;
    
    if ([self read:buffer maxLength:8] == 8) {
        value = (double)*buffer;
    }
    
    return value;
}


- (uint64)readInt64 {
    
    uint64 value = 0;
    
    [self read:(uint8*)&value maxLength:8];
    
#ifdef __LITTLE_ENDIAN__
    value = CFSwapInt64(value);
#endif
    
    return value;
}

- (NSInteger)readChars:(char *)buffer maxLength:(NSUInteger)len {
    return [self read:(uint8*)buffer maxLength:len];
}

- (NSString*)readPSDString16 {
    
    sint32 size = [self readInt32];
    
    if (size <= 0) {
        return @"";
    }
    
    unichar *c = malloc(sizeof(unichar) * (size + 1));
    
    for (sint32 i = 0; i < size; i++) {
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
- (NSString*)readPSDStringOrGetFourByteID:(uint32*)outId {
    sint32 size = [self readInt32];
    
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
    
    uint32 size = [self readInt32];
    
    if (size == 0) {
        size = 4;
    }
    
    return [self readPSDStringOfLength:size];
}

- (NSString*)readPSDStringOfLength:(uint32)size {
    
    char *c = malloc(sizeof(char) * (size + 1));
    
    NSInteger read = [self readChars:c maxLength:size];
    c[size] = 0;
    
    FMAssert(read == size);
    
    NSString *s = [NSString stringWithFormat:@"%s", c];
    
    free(c);
    
    FMAssert([s length] == size);
    
    return s;
}



- (NSString*)readPascalString {
    
    uint8 size = [self readInt8];
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

- (void)writeInt64:(uint64)value {
    uint64 writeV = CFSwapInt64HostToBig(value);
    [_outputStream write:(const uint8_t *)&writeV maxLength:8];
    _location += 8;
}

- (void)writeInt32:(uint32)value {
    uint32 writeV = CFSwapInt32HostToBig(value);
    [_outputStream write:(const uint8_t *)&writeV maxLength:4];
    _location += 4;
}

- (void)writeInt16:(uint16)value {
    uint32 writeV = CFSwapInt16HostToBig(value);
    [_outputStream write:(const uint8_t *)&writeV maxLength:2];
    _location += 2;
}


- (void)writeSInt16:(sint16)value {
    uint32 writeV = CFSwapInt16HostToBig(value);
    [_outputStream write:(const uint8_t *)&writeV maxLength:2];
    _location += 2;
}

- (void)writeInt8:(uint8)value {
    [_outputStream write:(const uint8_t *)&value maxLength:1];
    _location += 1;
}

- (void)writeDataWithLengthHeader:(NSData*)data {
    
    [self writeInt32:(uint32)[data length]];
    
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
    
    CFIndex len = CFStringGetLength((CFStringRef)string) + 1;
    
	unsigned char *buffer = malloc(sizeof(unsigned char) * len);
	if (CFStringGetPascalString((CFStringRef)string, buffer, len, kCFStringEncodingMacRoman)) {
        [_outputStream write:(const uint8_t *)buffer maxLength:len];
        _location += len;
    }
    else {
        NSLog(@"Could not write layer name!");
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
