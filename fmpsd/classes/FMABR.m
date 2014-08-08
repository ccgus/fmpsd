//
//  FMABR.m
//  fmpsd
//
//  Created by August Mueller on 8/8/14.
//  Copyright (c) 2014 Flying Meat Inc. All rights reserved.
//

#import "FMABR.h"
#import "FMPSD.h"
#import "FMPSDStream.h"

extern BOOL FMPSDPrintDebugInfo;

@interface FMABR ()

@property (assign) uint16 version;
@property (assign) uint16 versionVersion;
@property (assign) uint16 numberOfBrushes;

@end


@implementation FMABR

+ (id)brushesWithContetsOfURL:(NSURL*)fileURL error:(NSError**)err printDebugInfo:(BOOL)debugInfo {
    
    if (![[[NSFileManager alloc] init] fileExistsAtPath:[fileURL path]]) {
        return nil;
    }
    
    
    FMABR *abr = [[self alloc] init];
    
    // defaults write com.flyingmeat.Acorn4 FMPSDDebug 1
    FMPSDPrintDebugInfo = debugInfo || [[NSUserDefaults standardUserDefaults] boolForKey:@"FMPSDDebug"];
    
    debug(@"FMPSDPrintDebugInfo: %d", FMPSDPrintDebugInfo);
    
    @try {
        
        if (![abr readDataAtURL:fileURL error:err]) {
            debug(@"%s:%d Not a valid ABR, returning nil.", __FUNCTION__, __LINE__);
            return nil;
        }
    }
    @catch (NSException *exception) {
        NSLog(@"%@", exception);
        return nil;
    }
    
    
    return abr;
}

- (BOOL)readDataAtURL:(NSURL*)url error:(NSError**)err {
    
    /*
    
    read version.  better be 6
    some sort of other version.  better be 2.
    "sample count"
    8BIM + samp
    
    */
    
    
    
    
    
    FMPSDStream *stream = [FMPSDStream PSDStreamForReadingURL:url];
    
    
    if (![stream hasLengthToRead:4]) { // makes sure there's actually a minimum amount of data in this file.
        
        NSLog(@"Empty ABR file");
        if (err) {
            *err = [NSError errorWithDomain:@"8BPS" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Empty ABR file"}];
        }
        
        return NO;
    }
    
    
    
    _version = [stream readInt16];
    FMPSDDebug(@"Version %d", _version);
    
    if (_version < 6) {
        NSLog(@"FMABR Doesn't support brush versions less than 6");
        *err = [NSError errorWithDomain:@"8BPS" code:1 userInfo:@{NSLocalizedDescriptionKey: @"ABR format is too old"}];
        return NO;
    }
    
    // This is from the documentation.  It's rubbish
    _numberOfBrushes = [stream readInt16];
    FMPSDDebug(@"Lame version of brushes in file %d", _numberOfBrushes);
    
    _versionVersion = _numberOfBrushes; // it's a version of the version.
    
    uint32 sig;
    FMPSDCheckSig('8BIM', sig, stream, err);
    FMPSDCheckSig('samp', sig, stream, err);
    
    // skip through all the data to find the number of brushes.
    _numberOfBrushes = 0;
    uint32 length = [stream readInt32];
    long currentPosition = [stream location];
    
    long endPosition = currentPosition + length;
    
    FMPSDDebug(@"Finding brush count");
    
    while ([stream hasLengthToRead:0] && [stream location] < endPosition) {
        uint32 brushSize = [stream readInt32];
        
        while (brushSize % 4 != 0) {
            brushSize++;
        }
        
        [stream skipLength:brushSize];
        _numberOfBrushes++;
    }
    
    FMPSDDebug(@"%d brushes in ABR file", _numberOfBrushes);
    
    [stream seekToLocation:currentPosition];
    
    for (uint16 idx = 0; idx < _numberOfBrushes; idx++) {
        
        FMPSDDebug(@"Attempting to load brush %d at location %ld", idx, [stream location]);
        
        if (![self loadBrushInStream:stream error:err]) {
            FMPSDDebug(@"Problem loading brush %d", idx);
            return NO;
        }
        
    }
    
    
    
    return YES;
}

- (BOOL)loadBrushInStream:(FMPSDStream*)stream error:(NSError**)err {
    
    uint32 sectionLength = [stream readInt32];
    
    debug(@"sectionLength: %d", sectionLength);
    
    while (sectionLength % 4 != 0) {
        sectionLength++;
    }
    
    long brushEndLocation = [stream location] + sectionLength;
    
    uint8 stringLength = [stream readInt8];
    assert(stringLength == 36);
    
    NSString *idString = [stream readPSDStringOfLength:stringLength];
    
    FMPSDDebug(@"idString: %@", idString);
    
    if (_versionVersion == 1) {
        FMPSDDebug(@"Reading version version 1 brush?");
        [stream skipLength:10];
    }
    else {
        FMPSDDebug(@"Reading version version %d brush", _versionVersion);
        [stream skipLength:264];
    }
    
    debug(@"loc before things: %ld", [stream location]);
    
    // 1563 wide
    
    size_t t = [stream readInt32];
    size_t l = [stream readInt32];
    size_t b = [stream readInt32];
    size_t r = [stream readInt32];
    uint16 depth = [stream readInt16];
    uint8 compressionType  = [stream readInt8];
    
    FMPSDDebug(@"%d %d %d %d, depth: %d, comp: %d", t, l, b, r, depth, compressionType);
    
    assert(depth == 8);
    assert(compressionType == 1 || compressionType == 0);
    
    size_t width  = r - l;
    size_t height = b - t;
    
    size_t numberOfBytes = width * height;
    
    NSMutableData *bitmap = nil;
    
    if (!compressionType) {
        
        bitmap = [stream readDataOfLength:numberOfBytes];
        
        
    }
    else {
        // better be rle.
        
    }
    
    
    if (bitmap) {
        
        CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
        
        CGContextRef ctx = CGBitmapContextCreate([bitmap mutableBytes], width, height, 8, width, cs, (CGBitmapInfo)kCGImageAlphaNone);
        
        TSViewCGContext(ctx);
        
        CGColorSpaceRelease(cs);
        CGContextRelease(ctx);
    }
    
    [stream seekToLocation:brushEndLocation];
    
    return YES;
    
}



@end
