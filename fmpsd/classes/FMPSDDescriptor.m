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

- (void)readEnumFromStream:(FMPSDStream*)stream {
    
    /*
     
     00008ce0  00 00 00 0c 74 65 78 74  47 72 69 64 64 69 6e 67  |....textGridding|
     00008cf0  65 6e 75 6d 00 00 00 0c  74 65 78 74 47 72 69 64  |enum....textGrid| classIDString
     00008d00  64 69 6e 67 00 00 00 00  4e 6f 6e 65 00 00 00 00  |ding....None....| ClassID (None) | TypeID Length (0)
     00008d10  4f 72 6e 74 65 6e 75 6d  00 00 00 00 4f 72 6e 74  |Orntenum....Ornt| TypeID (Ornt)
     00008d20  00 00 00 00 48 72 7a 6e  00 00 00 00 41 6e 74 41  |....Hrzn....AntA|
     00008d30  65 6e 75 6d 00 00 00 00  41 6e 6e 74 00 00 00 0e  |enum....Annt....|
     00008d40  61 6e 74 69 41 6c 69 61  73 53 68 61 72 70 00 00  |antiAliasSharp..|
     
     Variable Unicode string: name from ClassID.
     Variable ClassID: 4 bytes (length), followed either by string or (if length is zero) 4-byte classID
     Variable TypeID: 4 bytes (length), followed either by string or (if length is zero) 4-byte typeID
     Variable enum: 4 bytes (length), followed either by string or (if length is zero) 4-byte enum
     */
    
    
    NSString *classIDString    = [stream readPSDString]; // Unicode string: name from ClassID.
    debug(@"enumclassIDString: '%@'", classIDString);
    
    if ([classIDString isEqualToString:@"textGridding"]) {
        [stream skipLength:56];
        return;
    }
    
    // ClassID: 4 bytes (length), followed either by string or (if length is zero) 4-byte classID
    uint32 enumClassID;
    NSString *enumClassIDString   = [stream readPSDStringOrGetFourByteID:&enumClassID];
    
    debug(@"enumClassIDString: '%@'", enumClassIDString);
    debug(@"enumClassID: %@", NSFileTypeForHFSTypeCode(enumClassID));
    
    // TypeID: 4 bytes (length), followed either by string or (if length is zero) 4-byte typeID
    uint32 enumTypeID;
    NSString *enumTypeIDString   = [stream readPSDStringOrGetFourByteID:&enumTypeID];
    
    debug(@"enumTypeIDString: '%@'", enumTypeIDString);
    debug(@"enumTypeID: %@", NSFileTypeForHFSTypeCode(enumTypeID));
    
    // enum: 4 bytes (length), followed either by string or (if length is zero) 4-byte enum
    uint32 enumMarker = [stream readInt32];
    FMAssert(enumMarker == 'enum');
    
    uint32 enumValue;
    NSString *enumValueString   = [stream readPSDStringOrGetFourByteID:&enumValue];
    
    debug(@"enumValueString: '%@'", enumValueString);
    debug(@"enumValue: %@", NSFileTypeForHFSTypeCode(enumValue));
}

- (void)skipDescriptorFromStream:(FMPSDStream*)stream {
    
    uint32 size = [stream readInt32];
    
    if (size == 1) {
        size++;
        debug(@"ARE YOU FUCKING SERIOUS?  WHY WHY WHY?");
    }
    
    [stream skipLength:size];
    
    debug(@"after reading bounds, we are now at offset %ld", [stream location]);
}


- (BOOL)readStream:(FMPSDStream*)stream {
    
    NSString *t = [stream readPSDString16];
    debug(@"[stream location]: %ld", [stream location]);
    debug(@"t: '%@'", t);
    
    // http://www.adobe.com/devnet-apps/photoshop/fileformatashtml/PhotoshopFileFormats.htm#50577411_21585
    //uint32 nameLen = [stream readInt32] * 2;
    //[stream skipLength:nameLen];
    
    uint32 classId;
    NSString *classIdString = [stream readPSDStringOrGetFourByteID:&classId];
    uint32 itemsCount = [stream readInt32];
    
    debug(@"classIdString: '%@'", classIdString);
    debug(@"classId: '%@'", NSFileTypeForHFSTypeCode(classId));
    debug(@"itemsCount: %d", itemsCount);
    
    if (classId == 'TxLr') {
        //debug(@"HOLY HELL IT'S A TEXT LAYER");
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
        
        debug(@"reading key/type #%d at offset %ld", i+1, [stream location]);
        
        // Key: 4 bytes ( length) followed either by string or (if length is zero) 4-byte key
        uint32 type = 0;
        NSString *key = [stream readPSDStringOrGetFourByteID:&type];
        
        #pragma unused(key)
        debug(@"%d key: '%@'", i, key);
        debug(@"type: %@", NSFileTypeForHFSTypeCode(type));
        
        /*
        if (type == 'TEXT') {
            NSString *s = [stream readPSDString16];
            debug(@"s: '%@'", s);
            if (s) {
                [_attributes setObject:stream forKey:key];
            }
        }
        else
            */if (type == 'Txt ') {
            
            uint32 textTag = [stream readInt32];
            debug(@"textTag: %@", NSFileTypeForHFSTypeCode(textTag));
            FMAssert(textTag == 'TEXT');
            
            NSString *layerText = [stream readPSDString16];
            
            if (layerText) {
                [_attributes setObject:layerText forKey:@"layerText"];
            }
            
            debug(@"layerText: '%@'", layerText);
            // ok...
        }
        else if (type == 'enum') {
            [self readEnumFromStream:stream];
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
        else if (type == 'Ornt') {
            
            
            uint32 enumTag = [stream readInt32];
            FMAssert(enumTag == 'enum');
            
            uint32 junkIntKey = 0;
            NSString *junkStringKey = [stream readPSDStringOrGetFourByteID:&junkIntKey];
            
            FMAssert(junkIntKey == 'Ornt'); // ok, what other types might this be?
            
            junkIntKey = 0;
            junkStringKey = [stream readPSDStringOrGetFourByteID:&junkIntKey];
            
            FMAssert(junkIntKey == 'Hrzn'); // ok, what other types might this be?
            
        }
        else if (type == 'AntA') {
            
            uint32 enumTag = [stream readInt32];
            FMAssert(enumTag == 'enum');
            
            uint32 junkIntKey = 0;
            NSString *junkStringKey = [stream readPSDStringOrGetFourByteID:&junkIntKey];
            
            FMAssert(junkIntKey == 'Annt'); // ok, what other types might this be?
            
            // we don't do anything with this value right now - (antiAliasSharp(the 4 char key is null of course)|'Anno'(None)|'AnCr'(crisp)|'AnSt'(strong)|'AnSm'(smooth))
            junkIntKey = 0;
            junkStringKey = [stream readPSDStringOrGetFourByteID:&junkIntKey];
            
            debug(@"junkIntKey: %@", NSFileTypeForHFSTypeCode(junkIntKey));
            debug(@"junkStringKey: '%@'", junkStringKey);
            
        }
        else if ([key isEqualToString:@"textGridding"]) {
            FMAssert(!type);
            
            uint32 enumTag = [stream readInt32];
            FMAssert(enumTag == 'enum');
            
            NSString *textGriddingString = [stream readPSDString];
            FMAssert([textGriddingString isEqualToString:@"textGridding"]);
            
            enumTag = 0;
            NSString *textGriddingTagTypeStringWhatever = [stream readPSDStringOrGetFourByteID:&enumTag];
            
            FMAssert(textGriddingTagTypeStringWhatever == NULL);
            
            FMAssert(enumTag == 'None'); // OK, what other text gridding types are there?
                     
        }
        else if ([key isEqualToString:@"bounds"] || [key isEqualToString:@"boundingBox"]) {
            
            uint32 boundsKey = [stream readInt32];
            
            if (boundsKey == 'Objc') {
                [self skipDescriptorFromStream:stream];
            }
            else if (boundsKey == 4) { // WTF REALLY?
                
                for (int boundsIndex = 0; boundsIndex < 4; boundsIndex++) {
                    
                    
                    uint32 boundsTag = 0;
                    NSString *boundsJunk = [stream readPSDStringOrGetFourByteID:&boundsTag];
                    FMAssert(!boundsJunk); // when is this ever the case?
                    
                    uint32 boundsTypeTag = [stream readInt32];
                    FMAssert(boundsTypeTag == 'UntF'); // Unit float
                    
                    /*Units the following value is in. One of the following:
                     '#Ang' = angle: base degrees
                     '#Rsl' = density: base per inch
                     '#Rlt' = distance: base 72ppi
                     '#Nne' = none: coerced.
                     '#Prc'= percent: unit value
                     '#Pxl' = pixels: tagged unit value
                     
                    Actual value (double)
                     
                     */
                    
                    uint32 unitType = [stream readInt32];
                    NSLog(@"unitType: %@", NSFileTypeForHFSTypeCode(unitType));
                    
                    // #Pnt isn't documented, but I'm going to assume it means "point".
                    
                    FMAssert(unitType == '#Pnt');
                    
                    double location = [stream readDouble64];
                    debug(@"location: %f", location);
                    //
                    
                    
                }
                
            }
            else {
                NSLog(@"Unknown boundsKey: %@ / %u", NSFileTypeForHFSTypeCode(boundsKey), boundsKey);
                FMAssert(NO);
            }
            
            
        }
        else {
            NSLog(@"Unknown type: %@ / '%@'", NSFileTypeForHFSTypeCode(type), key);
            exit(0);
            return NO;
        }
    }
    
    return YES;
}

@end
