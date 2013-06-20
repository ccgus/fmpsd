//
//  FMPSDDescriptor.m
//  fmpsd
//
//  Created by August Mueller on 10/27/10.
//  Copyright 2010 Flying Meat Inc. All rights reserved.
//

#import "FMPSDDescriptor.h"
#import "FMPSD.h"

@interface FMPSDDescriptor()
- (BOOL)readStream:(FMPSDStream*)stream;
@end

@implementation FMPSDDescriptor

+ (id)descriptorWithStream:(FMPSDStream*)stream psd:(FMPSD*)psd {
    
    FMPSDDescriptor *ret = [[self alloc] init];
    
    [ret setPsd:psd];
    
    if (![ret readStream:stream]) {
        return 0x00;
    }
    
    return ret;
}

- (id)init {
	self = [super init];
	if (self != nil) {
		_attributes = [NSMutableDictionary dictionary];
	}
	return self;
}


- (BOOL)readStream:(FMPSDStream*)stream {
    
    uint32 nameLen = [stream readInt32] * 2;
    [stream skipLength:nameLen];
    
    [stream readInt32];
    uint32 classId = [stream readInt32];
    uint32 itemsCount = [stream readInt32];
    
    debug(@"classId: '%@'", NSFileTypeForHFSTypeCode(classId));
    debug(@"itemsCount: %d", itemsCount);
    
    if (classId == 'TxLr') {
        debug(@"HOLY HELL IT'S A TEXT LAYER");
        // ...
    }
    
    /*
     00005370  00 00 00 00 54 78 4c 72  00 00 00 06 00 00 00 00  |....TxLr........|
     00005380  54 78 74 20 54 45 58 54  00 00 00 0b 00 6d 00 6f  |Txt TEXT.....m.o|
     00005390  00 61 00 72 00 0d 01 00  00 63 00 6f 00 72 00 6e  |.a.r.....c.o.r.n|
     000053a0  00 00 00 00 00 0c 74 65  78 74 47 72 69 64 64 69  |......textGriddi|
     000053b0  6e 67 65 6e 75 6d 00 00  00 0c 74 65 78 74 47 72  |ngenum....textGr|
     000053c0  69 64 64 69 6e 67 00 00  00 00 4e 6f 6e 65 00 00  |idding....None..|
     000053d0  00 00 4f 72 6e 74 65 6e  75 6d 00 00 00 00 4f 72  |..Orntenum....Or|
     000053e0  6e 74 00 00 00 00 48 72  7a 6e 00 00 00 00 41 6e  |nt....Hrzn....An|
     000053f0  74 41 65 6e 75 6d 00 00  00 00 41 6e 6e 74 00 00  |tAenum....Annt..|
     00005400  00 00 41 6e 43 72 00 00  00 09 54 65 78 74 49 6e  |..AnCr....TextIn|
     00005410  64 65 78 6c 6f 6e 67 00  00 00 00 00 00 00 0a 45  |dexlong........E|
     00005420  6e 67 69 6e 65 44 61 74  61 74 64 74 61 00 00 25  |ngineDatatdta..%|
     00005430  41 0a 0a 3c 3c 0a 09 2f  45 6e 67 69 6e 65 44 69  |A..<<../EngineDi|
     00005440  63 74 0a 09 3c 3c 0a 09  09 2f 45 64 69 74 6f 72  |ct..<<.../Editor|
     00005450  0a 09 09 3c 3c 0a 09 09  09 2f 54 65 78 74 20 28  |...<<..../Text (|
     00005460  fe ff 00 6d 00 6f 00 61  00 72 00 0d 01 00 00 63  |...m.o.a.r.....c|
     00005470  00 6f 00 72 00 6e 00 0d  29 0a 09 09 3e 3e 0a 09  |.o.r.n..)...>>..|
     00005480  09 2f 50 61 72 61 67 72  61 70 68 52 75 6e 0a 09  |./ParagraphRun..|
     00005490  09 3c 3c 0a 09 09 09 2f  44 65 66 61 75 6c 74 52  |.<<..../DefaultR|
     */
     
    for (uint32 i = 0; i < itemsCount; i++) {
        
        NSString *key = [stream readPSDString];// yes, this is really a string.
        uint32 type = [stream readInt32];
        
        #pragma unused(key)
        debug(@"key: '%@'", key);
        debug(@"type: %@", NSFileTypeForHFSTypeCode(type));
        
        if (type == 'TEXT') {
            NSString *s = [stream readPSDString16];
            
            if (s) {
                [_attributes setObject:stream forKey:key];
            }
        }
        else if (type == 'enum') {
            
            NSString *typeId    = [stream readPSDString];
            NSString *typeVal   = [stream readPSDString];
            
            (void)typeId;
            (void)typeVal;
            //debug(@"typeId: '%@' = %@", typeId, typeVal);
        }
        else if (type == 'long') {
            uint32 val = [stream readInt32];
            #pragma unused(val)
            //debug(@"Long val: %d", val);
        }
        else if (type == 'doub') {
            double val = [stream readDouble64];
            #pragma unused(val)
            //debug(@"double val: %f", val);
        }
        else if (type == 'tdta') {
            
            uint32 size = [stream readInt32];
            [stream skipLength:size];
        }
        else if (type == 'Objc') {
            uint32 size = [stream readInt32];
            [stream skipLength:size];
            
            debug(@"size: %uld", size);
        }
        else {
            NSLog(@"Unknown type: %@", NSFileTypeForHFSTypeCode(type));
            exit(0);
            return NO;
        }
    }
    
    return YES;
}

@end
