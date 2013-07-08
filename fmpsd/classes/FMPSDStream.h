//
//  FMPSDStream.h
//  fmpsd
//
//  Created by August Mueller on 10/22/10.
//  Copyright 2010 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


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

- (uint8)readInt8;
- (uint16)readInt16;
- (uint32)readInt32;
- (sint32)readSInt32;
- (uint64)readInt64;
- (double)readDouble64;
- (NSInteger)readChars:(char *)buffer maxLength:(NSUInteger)len;
- (NSString*)readPSDString;
- (NSString*)readPSDStringOfLength:(uint32)size;
- (NSString*)readPSDStringOrGetFourByteID:(uint32*)outId;
- (NSString*)readPascalString;
- (NSString*)readPSDString16;
- (NSMutableData*)readDataOfLength:(NSUInteger)len;
- (NSData*)readToEOF;

- (BOOL)hasLengthToRead:(NSUInteger)len;
- (void)skipLength:(NSUInteger)len;
- (long)location;

- (void)writeInt64:(uint64)value;
- (void)writeInt32:(uint32)value;
- (void)writeInt16:(uint16)value;
- (void)writeSInt16:(sint16)value;
- (void)writeInt8:(uint8)value;
- (void)writeData:(NSData*)data;
- (void)writeChars:(char*)chars length:(size_t)length;
- (void)writeDataWithLengthHeader:(NSData*)data;
- (void)writePascalString:(NSString*)string withPadding:(int)p;

@end
