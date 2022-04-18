//
//  FMPSDPackBits.m
//  fmpsd
//
//  Copyright 2019 Flying Meat Inc. All rights reserved.
//


#import "FMPSDPackBits.h"
#import "FMPSD.h"

//  The code below was adapated from:
//    http://blog.foundry376.com/2009/05/packbits-algorithm-in-objective-c/

#define MIN_RUN     3                           // minimum run length to encode
#define MAX_RUN     128                         // maximum run length to encode
#define MAX_COPY    128                         // maximum characters to copy

#define MAX_READ    (MAX_COPY + MIN_RUN - 1)	// maximum that can be read before copy block is written

static void appendUncompressedRun(NSMutableData *data, unsigned char* start, size_t count) {
    assert(count > 0 && count <= MAX_COPY);
    
    SInt8 encodedLen = count - 1;
    [data appendBytes:&encodedLen length:1];
    [data appendBytes:start length:count];
}

static void appendCompressedRun(NSMutableData *data, unsigned char value, size_t count) {
    assert(count > 0 && count <= MAX_RUN);
    
    SInt8 encodedLen = ((int)(1 - (int)(count)));
    [data appendBytes:&encodedLen length:sizeof(SInt8)];
    [data appendBytes:&value length:sizeof(UInt8)];
}

static NSData * FMPSDEncodePackBitsPart(char* bytesIn, size_t bytesLength, off_t skip) {
    NSMutableData *data = [NSMutableData data];
    
    BOOL atEnd = NO;

    int count = 0; // number of characters in a run
    unsigned char charBuf[MAX_READ]; // buffer of already read characters
    
    // prime the read loop
    off_t bytesOffset = 0;
    unsigned char currChar = bytesIn[bytesOffset];
    bytesOffset += skip;
    
    // read input until there’s nothing left
    while (!atEnd) {
        charBuf[count] = (unsigned char) currChar;
        count++;

        if (count >= MIN_RUN) {
            int i;

            // check for run charBuf[count - 1] .. charBuf[count - MIN_RUN]
            for (i = 2; i <= MIN_RUN; i++) {
                if (currChar != charBuf[count - i]) {
                    // no run
                    i = 0;
                    break;
                }
            }

            if (i != 0) {
                // we have a run write out buffer before run
                int nextChar;

                if (count > MIN_RUN) {
                    // block size – 1 followed by contents
                    appendUncompressedRun(data, &charBuf[0], count - MIN_RUN);
                }

                // determine run length (MIN_RUN so far)
                count = MIN_RUN;
                while (true) {
                    if ((size_t)bytesOffset < bytesLength) {
                        nextChar = bytesIn[bytesOffset];
                        bytesOffset += skip;
                    } else {
                        atEnd = YES;
                        nextChar = EOF;
                    }
                    
                    if (atEnd || nextChar != currChar) {
                        break;
                    }

                    count++;
                    if (count == MAX_RUN) {
                        // run is at max length
                        break;
                    }
                }

                // write out encoded run length and run symbol
                appendCompressedRun(data, currChar, count);

                if (!atEnd && count != MAX_RUN) {
                    // make run breaker start of next buffer
                    charBuf[0] = nextChar;
                    count = 1;
                } else {
                    // file or max run ends in a run
                    count = 0;
                }
            }
        }

        if (count == MAX_READ) {
            int i;

            // write out buffer
            appendUncompressedRun(data, &charBuf[0], MAX_COPY);

            // start a new buffer
            count = MAX_READ - MAX_COPY;

            // copy excess to front of buffer
            for (i = 0; i < count; i++) {
                charBuf[i] = charBuf[MAX_COPY + i];
            }
        }

        if ((size_t)bytesOffset < bytesLength) {
            currChar = bytesIn[bytesOffset];
        } else {
            atEnd = YES;
        }
        
        bytesOffset += skip;
    }

    // write out last buffer
    if (0 != count) {
        if (count <= MAX_COPY) {
            // write out entire copy buffer
            appendUncompressedRun(data, &charBuf[0], count);
        } else {
            // we read more than the maximum for a single copy buffer
            appendUncompressedRun(data, &charBuf[0], MAX_COPY);

            // write out remainder
            count -= MAX_COPY;
            appendUncompressedRun(data, &charBuf[MAX_COPY], count);
        }
    }
    
    return data;
}

NSData * FMPSDEncodedPackBits(char* src, size_t w, size_t h, size_t bytesLength) {
    FMAssert(w == bytesLength); // Right now, passing bytesLength breaks things.
    NSMutableArray *lineData = [NSMutableArray arrayWithCapacity:h];
    for (size_t i = 0 ; i < h ; i++) {
        NSData *data = FMPSDEncodePackBitsPart(src + i * w, bytesLength, 1);
        [lineData addObject:data];
    }
    
    FMAssert([lineData count] == h);
    
    FMPSDStream *outputStream = [FMPSDStream PSDStreamForWritingToMemory];
    
    
    [outputStream writeInt16:1]; // The encoding
    
    // NSInteger totalLen = 0;
    for (NSData *line in lineData) {
        NSInteger len = [line length];
        // totalLen += len;
        [outputStream writeInt16:len];
    }
    
    for (NSData *line in lineData) {
        [outputStream writeData:line];
    }
    
//    if (totalLen % 2 == 1) {
//        [outputStream writeInt8:0];
//    }
    
    [outputStream close];
    return [outputStream outputData];
}
