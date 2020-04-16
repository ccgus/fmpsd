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
#import "FMPSDUtils.h"

extern BOOL FMPSDPrintDebugInfo;

@interface FMABR ()

@property (assign) uint16_t version;
@property (assign) uint16_t versionVersion;
@property (assign) uint16_t numberOfBrushes;

@end


@implementation FMABR

+ (id)brushesWithContetsOfURL:(NSURL*)fileURL error:(NSError *__autoreleasing *)err printDebugInfo:(BOOL)debugInfo {
    
    if (![[[NSFileManager alloc] init] fileExistsAtPath:[fileURL path]]) {
        return nil;
    }
    
    
    FMABR *abr = [[self alloc] init];
    
    // defaults write com.flyingmeat.Acorn4 FMPSDDebug 1
    FMPSDPrintDebugInfo = debugInfo || [[NSUserDefaults standardUserDefaults] boolForKey:@"FMPSDDebug"];
    
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

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setBrushes:[NSMutableArray array]];
    }
    return self;
}

- (FMPSBrush*)brushWithId:(NSString*)brushID {
    
    if (!brushID) {
        return nil;
    }
    
    for (FMPSBrush *b in [self brushes]) {
        
        if ([[b sampledDataID] isEqualToString:brushID]) {
            return b;
        }
        
    }
    
    
    return nil;
    
}

- (BOOL)readDataAtURL:(NSURL*)url error:(NSError *__autoreleasing *)err {
    
    /*
    
    read version.  better be 6
    some sort of other version.  better be 2.
    "sample count"
    8BIM + samp
    brush bitmap data for each brush
    then brush settings?
    
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
        if (err) {
            *err = [NSError errorWithDomain:@"8BPS" code:1 userInfo:@{NSLocalizedDescriptionKey: @"ABR format is too old"}];
        }
        return NO;
    }
    
    // This is from the documentation.  It's rubbish
    _numberOfBrushes = [stream readInt16];
    FMPSDDebug(@"Lame version of brushes in file %d", _numberOfBrushes);
    
    _versionVersion = _numberOfBrushes; // it's a version of the version.
    
    uint32_t sig;
    FMPSDCheckSig('8BIM', sig, stream, err);
    FMPSDCheckSig('samp', sig, stream, err);
    
    // skip through all the data to find the number of brushes.
    _numberOfBrushes = 0;
    uint32_t length = [stream readInt32];
    long currentPosition = [stream location];
    
    long endPosition = currentPosition + length;
    
    FMPSDDebug(@"Finding brush count");
    
    while ([stream hasLengthToRead:0] && [stream location] < endPosition) {
        uint32_t brushSize = [stream readInt32];
        
        // pad it to a multiple of 4
        brushSize = (brushSize + (3)) & ~0x03;
        
        [stream skipLength:brushSize];
        _numberOfBrushes++;
    }
    
    FMPSDDebug(@"%d brushes in ABR file", _numberOfBrushes);
    
    [stream seekToLocation:currentPosition];
    
    for (uint16_t idx = 0; idx < _numberOfBrushes; idx++) {
        
        FMPSDDebug(@"Attempting to load brush %d at location %ld", idx, [stream location]);
        
        if (![self loadBrushInStream:stream error:err]) {
            FMPSDDebug(@"Problem loading brush %d", idx);
            return NO;
        }
        
    }
    
    FMPSDDebug(@"Location after brush bitmap data: %ld", [stream location]);
    
    FMPSDCheckSig('8BIM', sig, stream, err);
    FMPSDCheckSig('patt', sig, stream, err);
    
    uint32_t patternInfoLength = [stream readInt32];
    [stream skipLength:patternInfoLength];
    
    FMPSDCheckSig('8BIM', sig, stream, err);
    FMPSDCheckSig('desc', sig, stream, err);
    
    [stream skipLength:30]; // beats the heck outa me
    
    
    FMPSDCheckSig('Brsh', sig, stream, err);
    FMPSDCheckSig('VlLs', sig, stream, err);
    
    uint32_t brushInfoSectionCount = [stream readSInt32];
    
    for (NSUInteger i = 0; i < brushInfoSectionCount; i++) {
        
        FMPSDCheckSig('Objc', sig, stream, err);
        
        FMPSDDescriptor *d = [FMPSDDescriptor descriptorWithStream:stream psd:nil];
        
        debug(@"d: '%@'", d);
        
        FMPSDDescriptor *brsh = [[d attributes] objectForKey:@"Brsh"];
        FMPSDDescriptor *scatterDynamics = [[d attributes] objectForKey:@"scatterDynamics"];
        
        NSString *brushSampleDataID = [[brsh attributes] objectForKey:@"sampledData"];
        
        FMPSBrush *brush = [self brushWithId:brushSampleDataID];
        if (!brush) {
            brush = [FMPSBrush new];
            [brush setComputed:YES];
            [[self brushes] addObject:brush];
        }
        
        [brush setDescriptor:d];
        
        if (brsh) {
            [brush setName:[[brsh attributes] objectForKey:@"Nm  "]];
            
            [brush setAngle:[[[brsh attributes] objectForKey:@"Angl"] doubleValue]];
            [brush setDiameter:[[[brsh attributes] objectForKey:@"Dmtr"] doubleValue]];
            [brush setSpacing:[[[brsh attributes] objectForKey:@"Spcn"] doubleValue]];
            [brush setHardness:[[[brsh attributes] objectForKey:@"Hrdn"] doubleValue]];
            [brush setRoundness:[[[brsh attributes] objectForKey:@"Rndn"] doubleValue]];
        }
        
        if (scatterDynamics) {
            
            if ([[scatterDynamics attributes] objectForKey:@"jitter"]) {
                [brush setScatterJitter:[[[scatterDynamics attributes] objectForKey:@"jitter"] doubleValue]];
            }
            
        }
        
        
        
        if ([[d attributes] objectForKey:@"Nm  "]) {
            [brush setName:[[d attributes] objectForKey:@"Nm  "]];
        }
    }
    
    
    return YES;
}

- (BOOL)loadBrushInStream:(FMPSDStream*)stream error:(NSError *__autoreleasing *)err {
    
    FMPSBrush *brush = [FMPSBrush new];
    
    uint32_t sectionLength = [stream readInt32];
    
    sectionLength = (sectionLength + (3)) & ~0x03;
    
    long brushEndLocation = [stream location] + sectionLength;
    
    uint8_t stringLength = [stream readInt8];
    assert(stringLength == 36);
    
    NSString *idString = [stream readPSDStringOfLength:stringLength];
    
    FMPSDDebug(@"idString: %@", idString);
    
    [brush setSampledDataID:idString];
    
    if (_versionVersion == 1) { // Elliptical, computed brush:
        FMPSDDebug(@"reading computed brush");
        
        // this is all bs.
        // 4 Miscellaneous. Ignored
        // 2 Spacing: 0...999 where 0 = no spacing
        // 2 Diameter: 1...999
        // 2 Roundness: 0...100
        // 2 Angle: -180...180
        // 2 Hardness: 0...100
        
        [stream skipLength:10];
    }
    else if (_versionVersion == 2) { // 2 = Sampled brush
        
        long endLocation = [stream location] + 264;
        
        [stream seekToLocation:endLocation];
    }
    else {
        debug(@"uknown bursh type: %d", _versionVersion);
    }
    
    size_t t = [stream readInt32];
    size_t l = [stream readInt32];
    size_t b = [stream readInt32];
    size_t r = [stream readInt32];
    uint16_t depth = [stream readInt16];
    uint8_t compressionType  = [stream readInt8];
    
    FMPSDDebug(@"%d %d %d %d, depth: %d, comp: %d", t, l, b, r, depth, compressionType);
    
    assert(depth == 8);
    assert(compressionType == 1 || compressionType == 0);
    
    size_t width  = r - l;
    size_t height = b - t;
    
    size_t bitmapDataLength = width * height;
    
    NSMutableData *bitmap = nil;
    
    if (!compressionType) {
        bitmap = [stream readDataOfLength:bitmapDataLength];
    }
    else {
        // better be rle.
        
        uint16_t *lineLengths  = [[NSMutableData dataWithLength:sizeof(uint16_t) * height] mutableBytes];
        
        for (size_t i = 0; i < height; i++) {
            lineLengths[i] = [stream readInt16];
        }
        
        
        bitmap = [NSMutableData dataWithLength:sizeof(char) * (width * height)];
        char *buffer = [bitmap mutableBytes];
        char *source = [[NSMutableData dataWithLength:sizeof(char) * (width * 2)] mutableBytes];
        
        int pos = 0;
        int lineIndex = 0;
        for (uint32_t i = 0; i < height; i++) {
            uint16_t len = lineLengths[lineIndex++];
            
            FMAssert(!(len > (width * 2)));
            
            [stream readChars:(char*)source maxLength:len];
            
            FMPSDDecodeRLE(source, 0, len, buffer, pos);
            pos += width;
        }
    }
    
    if (bitmap) {
        
        CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
        
        CGContextRef ctx = CGBitmapContextCreate([bitmap mutableBytes], width, height, 8, width, cs, (CGBitmapInfo)kCGImageAlphaNone);
        
        if (!ctx) {
            // FIXME: put an error in here.
            NSLog(@"%s:%d", __FUNCTION__, __LINE__);
            CGColorSpaceRelease(cs);
            return NO;
        }
        
        CGImageRef img = CGBitmapContextCreateImage(ctx);
        
        if (!img) {
            // FIXME: put an error in here.
            NSLog(@"%s:%d", __FUNCTION__, __LINE__);
            CGColorSpaceRelease(cs);
            CGContextRelease(ctx);
            return NO;
        }
        
        [brush setImage:img];
        
        CGImageRelease(img);
        
        // FIXME: set the real x,y here.
        [brush setBounds:CGRectMake(0, 0, width, height)];
        
        
        [[self brushes] addObject:brush];
        
        CGColorSpaceRelease(cs);
        CGContextRelease(ctx);
    }
    
    [stream seekToLocation:brushEndLocation];
    
    return YES;
    
}

@end


@implementation FMPSBrush

- (void)dealloc {
    
    if (_image) {
        CGImageRelease(_image);
    }
    
}

- (void)setImage:(CGImageRef)newImage {
    
    
    if (_image != newImage) {
    
        if (_image) {
            CGImageRelease(_image);
        }
        
        if (newImage) {
            CGImageRetain(newImage);
        }
        
        _image = newImage;
    }
}

- (CGImageRef)image {
    return _image;
}


- (NSString*)description {
    NSString *f = [super description];
    
    f = [f stringByAppendingFormat:@" %@ %@ diameter: %f angle: %f spacing: %f hardness: %f roundness: %f", _name, _computed ? @"computed" : @"sampled", _diameter, _angle, _spacing, _hardness, _roundness];
    
    return f;
}

@end
