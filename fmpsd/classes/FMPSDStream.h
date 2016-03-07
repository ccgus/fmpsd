//
//  FMPSDStream.h
//  fmpsd
//
//  Created by August Mueller on 10/22/10.
//  Copyright 2010 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface FMPSDStream : NSObject {

    NSOutputStream *_outputStream;
    
    NSData *_inputDataStream;
    
    long _location;
}

+ (id)PSDStreamForReadingURL:(NSURL*)url;
+ (id)PSDStreamForWritingToURL:(NSURL*)url;
+ (id)PSDStreamForWritingToMemory;

- (void)close;
- (NSData*)outputData;

- (uint8_t)readInt8;
- (uint16_t)readInt16;
- (uint32_t)readInt32;
- (int32_t)readSInt32;
- (uint64_t)readInt64;
- (double)readDouble64;
- (NSInteger)readChars:(char *)buffer maxLength:(NSUInteger)len;
- (NSString*)readPSDString;
- (NSString*)readPSDStringOfLength:(uint32_t)size;
- (NSString*)readPSDStringOrGetFourByteID:(uint32_t*)outId;
- (NSString*)readPascalString;
- (NSString*)readPSDString16;
- (NSMutableData*)readDataOfLength:(NSUInteger)len;
- (NSData*)readToEOF;

- (BOOL)hasLengthToRead:(NSUInteger)len;
- (void)skipLength:(NSUInteger)len;
- (long)location;
- (void)seekToLocation:(long)newLocation;

- (void)writeInt64:(uint64_t)value;
- (void)writeInt32:(uint32_t)value;
- (void)writeInt16:(uint16_t)value;
- (void)writeSInt16:(int16_t)value;
- (void)writeInt8:(uint8_t)value;
- (void)writeData:(NSData*)data;
- (void)writeChars:(char*)chars length:(size_t)length;
- (void)writeDataWithLengthHeader:(NSData*)data;
- (void)writePascalString:(NSString*)string withPadding:(int)p;

@end
