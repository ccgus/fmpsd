//
//  FMPSD.m
//  fmpsd
//
//  Created by August Mueller on 11/6/09.
//  Copyright 2009 Flying Meat Inc. All rights reserved.
//


#import "FMPSD.h"
#import "FMPSDStream.h"
#import <QuartzCore/QuartzCore.h>

BOOL FMPSDPrintDebugInfo = NO;

@interface NSData (private)
- (id)initWithBase64Encoding:(NSString*)s;
@end

@interface FMPSD ()
- (BOOL)readDataAtURL:(NSURL*)url error:(NSError**)err;
@end


@implementation FMPSD

@synthesize baseLayerGroup=_baseLayerGroup;
@synthesize width=_width;
@synthesize height=_height;
@synthesize depth=_depth;
@synthesize colorMode=_colorMode;
@synthesize compositeLayer=_compositeLayer;

+ (id)imageWithContetsOfURL:(NSURL*)fileURL error:(NSError**)err printDebugInfo:(BOOL)debugInfo {
    
    if (![[[NSFileManager alloc] init] fileExistsAtPath:[fileURL path]]) {
        return nil;
    }
    
    FMPSD *psd = [[self alloc] init];
    
    // defaults write com.flyingmeat.Acorn4 FMPSDDebug 1
    FMPSDPrintDebugInfo = debugInfo || [[NSUserDefaults standardUserDefaults] boolForKey:@"FMPSDDebug"];
    
    @try {
        
        if (![psd readDataAtURL:fileURL error:err]) {
            debug(@"%s:%d Not a valid PSD, returning nil.", __FUNCTION__, __LINE__);
            return nil;
        }
    }
    @catch (NSException *exception) {
        NSLog(@"%@", exception);
        return nil;
    }
    
    
    return psd;
    
}

+ (id)imageWithContetsOfURL:(NSURL*)fileURL error:(NSError**)err {
    return [self imageWithContetsOfURL:fileURL error:err printDebugInfo:NO];
}


- (id)init {
	self = [super init];
    
    if (self != nil) {
        [self setBaseLayerGroup:[FMPSDLayer baseLayer]];
	}
    
	return self;
}

- (void)dealloc {
    
    _baseLayerGroup = nil;
    
    _resourceTags = nil;
    
    _compositeLayer = nil;
    
    _iccProfile = nil;
    
    if (_savingCompositeImageRef) {
        CGImageRelease(_savingCompositeImageRef);
        _savingCompositeImageRef = nil;
    }
    
    if (_colorSpace) {
        CGColorSpaceRelease(_colorSpace);
        _colorSpace = nil;
    }
    
}

- (NSData*)resoultionData {
    
    // we're always 72 right now.
    
    unsigned char resInfo[] = {
        0x00, 0x48, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x48, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01
    };
    
    FMAssert(sizeof(resInfo) == 16);
    
    return [NSData dataWithBytes:resInfo length:sizeof(resInfo)];
}

- (NSData*)iccProfile {
    
    if (_colorSpace) {
        
        NSData *d = (__bridge_transfer NSData*)CGColorSpaceCopyICCProfile(_colorSpace);
        
        if (d) {
            return d;
        }
        
        debug(@"crap, no icc profile for %@", _colorSpace);
    }
    
    unsigned char c[] = {
        0x0, 0x0, 0x2, 0x28, 0x41, 0x44, 0x42, 0x45, 0x2, 0x10, 0x0, 0x0, 0x6D, 0x6E, 0x74, 0x72, 0x52, 0x47, 0x42, 0x20, 0x58, 0x59, 0x5A, 0x20, 0x7, 0xCF, 0x0, 0x6, 0x0, 0x3, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x61, 0x63, 0x73, 0x70, 0x41, 0x50, 0x50, 0x4C, 0x0, 0x0, 0x0, 0x0, 0x6E, 0x6F, 0x6E, 0x65, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0xF6, 0xD6, 0x0, 0x1, 0x0, 0x0, 0x0, 0x0, 0xD3, 0x2D, 0x41, 0x44, 0x42, 0x45, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0A, 0x63, 0x70, 0x72, 0x74, 0x0, 0x0, 0x0, 0xFC, 0x0, 0x0, 0x0, 0x32, 0x64, 0x65, 0x73, 0x63, 0x0, 0x0, 0x1, 0x30, 0x0, 0x0, 0x0, 0x64, 0x77, 0x74, 0x70, 0x74, 0x0, 0x0, 0x1, 0x94, 0x0, 0x0, 0x0, 0x14, 0x62, 0x6B, 0x70, 0x74, 0x0, 0x0, 0x1, 0xA8, 0x0, 0x0, 0x0, 0x14, 0x72, 0x54, 0x52, 0x43, 0x0, 0x0, 0x1, 0xBC, 0x0, 0x0, 0x0, 0x0E, 0x67, 0x54, 0x52, 0x43, 0x0, 0x0, 0x1, 0xCC, 0x0, 0x0, 0x0, 0x0E, 0x62, 0x54, 0x52, 0x43, 0x0, 0x0, 0x1, 0xDC, 0x0, 0x0, 0x0, 0x0E, 0x72, 0x58, 0x59, 0x5A, 0x0, 0x0, 0x1, 0xEC, 0x0, 0x0, 0x0, 0x14, 0x67, 0x58, 0x59, 0x5A, 0x0, 0x0, 0x2, 0x0, 0x0, 0x0, 0x0, 0x14, 0x62, 0x58, 0x59, 0x5A, 0x0, 0x0, 0x2, 0x14, 0x0, 0x0, 0x0, 0x14, 0x74, 0x65, 0x78, 0x74, 0x0, 0x0, 0x0, 0x0, 0x43, 0x6F, 0x70, 0x79, 0x72, 0x69, 0x67, 0x68, 0x74, 0x20, 0x31, 0x39, 0x39, 0x39, 0x20, 0x41, 0x64, 0x6F, 0x62, 0x65, 0x20, 0x53, 0x79, 0x73, 0x74, 0x65, 0x6D, 0x73, 0x20, 0x49, 0x6E, 0x63, 0x6F, 0x72, 0x70, 0x6F, 0x72, 0x61, 0x74, 0x65, 0x64, 0x0, 0x0, 0x0, 0x64, 0x65, 0x73, 0x63, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0A, 0x41, 0x70, 0x70, 0x6C, 0x65, 0x20, 0x52, 0x47, 0x42, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x58, 0x59, 0x5A, 0x20, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xF3, 0x51, 0x0, 0x1, 0x0, 0x0, 0x0, 0x1, 0x16, 0xCC, 0x58, 0x59, 0x5A, 0x20, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x63, 0x75, 0x72, 0x76, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1, 0x1, 0xCD, 0x0, 0x0, 0x63, 0x75, 0x72, 0x76, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1, 0x1, 0xCD, 0x0, 0x0, 0x63, 0x75, 0x72, 0x76, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1, 0x1, 0xCD, 0x0, 0x0, 0x58, 0x59, 0x5A, 0x20, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x79, 0xBD, 0x0, 0x0, 0x41, 0x52, 0x0, 0x0, 0x4, 0xB9, 0x58, 0x59, 0x5A, 0x20, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x56, 0xF8, 0x0, 0x0, 0xAC, 0x2F, 0x0, 0x0, 0x1D, 0x3, 0x58, 0x59, 0x5A, 0x20, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x26, 0x22, 0x0, 0x0, 0x12, 0x7F, 0x0, 0x0, 0xB1, 0x70
    };
    
    FMAssert(sizeof(c) == 552);
    
    return [NSData dataWithBytes:c length:sizeof(c)];
}


- (NSData*)exifData {
    
    NSString *s = @"TU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAZKADAAQAAAABAAAAZAAAAAA=";
    
    NSData *data = [[NSData alloc] initWithBase64Encoding:s];
    
    return data;
}

- (CGColorSpaceRef)colorSpace {
    
    if (!_colorSpace) {
        _colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    }
    
    return _colorSpace;
}

- (void)loadColorSpaceFromURL:(NSURL*)url {
    
    FMAssert(!_colorSpace);
    
    CGImageSourceRef imageSourceRef = CGImageSourceCreateWithURL((__bridge CFURLRef)url, nil);
    
    if (!imageSourceRef) {
        NSLog(@"Could not read colorspace from %@", url);
        return ;
    }
    
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSourceRef, 0, (__bridge CFDictionaryRef)[NSDictionary dictionary]);
    
    CFRelease(imageSourceRef);
    
    _colorSpace = CGColorSpaceRetain(CGImageGetColorSpace(imageRef));
    
    CGImageRelease(imageRef);
}

- (BOOL)readDataAtURL:(NSURL*)url error:(NSError**)err {
    
    FMPSDDebug(@"Opening stream at %@", [url path]);
    
    [self loadColorSpaceFromURL:url];
    
    FMPSDStream *stream = [FMPSDStream PSDStreamForReadingURL:url];
    
    
    if (![stream hasLengthToRead:4]) { // makes sure there's actually a minimum amount of data in this file.
        
        NSLog(@"Empty PSD file");
        if (err) {
            *err = [NSError errorWithDomain:@"8BPS" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Empty PSD file"}];
        }
        
        return NO;
    }
    
    // make sure it's a psd file, or at least has the right signature.
    uint32 sig;
    if ((sig = [stream readInt32]) != '8BPS') {
        
        NSString *s = [NSString stringWithFormat:@"%s:%d invalid start signature %@", __FUNCTION__, __LINE__, NSFileTypeForHFSTypeCode(sig)];
        NSLog(@"%@", s);
        if (err) {
            *err = [NSError errorWithDomain:@"8BPS" code:1 userInfo:[NSDictionary dictionaryWithObject:s forKey:NSLocalizedDescriptionKey]];
        }
        
        return NO;
    }
    
    _version = [stream readInt16];
    FMPSDDebug(@"Version %d", _version);
    
    if (_version != 1) {
        NSLog(@"Not a valid psd, version number is wrong (%d)", _version);
        return NO;
    }
    
    // reserved stuff that we just ignore
    char _reserved[6];
    [stream readChars:_reserved maxLength:6];
    
    _channels   = [stream readInt16];
    
    _height     = [stream readInt32];
    _width      = [stream readInt32];
    
    _depth      = [stream readInt16];
    _colorMode  = [stream readInt16];
    
    FMPSDDebug(@"_channels:  %d", _channels);
    FMPSDDebug(@"_height:    %d", _height);
    FMPSDDebug(@"_width:     %d", _width);
    FMPSDDebug(@"_depth:     %d", _depth);
    FMPSDDebug(@"_colorMode: %d", _colorMode);
    
    if (_colorMode != FMPSDRGBMode) {
        NSLog(@"Unsupported color mode (%d)", _colorMode);
        return NO;
    }
    
    uint32 colorMapLen = [stream readInt32];
    _colormapData = [stream readDataOfLength:colorMapLen];
    
    
    FMPSDDebug(@"colorMapLen: %d", colorMapLen);
    
    // we're reading in the resource bits for the PSD file
    uint32 length = [stream readInt32];
    long endLoc   = [stream location] + length;
    
    FMPSDDebug(@"doc resource length: %d", length);
    
    
    while ([stream location] < endLoc) {
        
        // Image Resource Blocks. 2, 2, variable pascal, 4, variable
                
        FMPSDCheck8BIMSig(sig, stream, err);
        
        uint16 uID  = [stream readInt16];
        NSString *s = [stream readPascalString];
        
        // Actual size of resource data that follows
        uint32 sizeofdata = [stream readInt32];
        
        FMPSDDebug(@" + %d '%@' len: %d", uID, s, sizeofdata);
        
        // resource data must be even
        if(sizeofdata & 0x01) {
            sizeofdata ++;
        }
        
        if (uID == 1005) { // resolution info.
            /*NSData *d = */[stream readDataOfLength:sizeofdata];
        }
        else if (uID == 1039) { // icc profile.
            _iccProfile = [stream readDataOfLength:sizeofdata];
        }
        else if (uID == 1026) { // Layers group information.
            //debug(@"[Layers group information]: '%@'", [stream readDataOfLength:sizeofdata]);
            [stream skipLength:sizeofdata];
        }
        else {
            [stream skipLength:sizeofdata];
        }
    }
    
    FMAssert(endLoc == [stream location]);
    
    // Layer and Mask Information Section
    uint32 layerAndMaskInformationSectionLength = [stream readInt32];
    long pos = [stream location];
    
    FMPSDDebug(@"layer and mask info length: %d", layerAndMaskInformationSectionLength);
    
    if (layerAndMaskInformationSectionLength > 0) {
        
        uint32 layerInfoLen = [stream readInt32]; // Length of the layers info section, rounded up to a multiple of 2
        
        if ((layerInfoLen & 0x01) != 0) {
            layerInfoLen++;
        }
        
        FMPSDDebug(@"layerInfoLen length: %d", layerInfoLen);
        
        if (layerInfoLen > 0) {
            
            sint16 layerCt = [stream readInt16]; // Layer count. If it is a negative number, its absolute value is the number of layers and the first alpha channel contains the transparency data for the merged result.
            
            layerCt = abs(layerCt);
            
            FMPSDDebug(@"layer count: %d", layerCt);
            
            if (layerCt) {
                
                NSMutableArray *layers = [NSMutableArray array];
                
                for (int i = 0; i < layerCt; i++) {
                    
                    FMPSDLayer *layer = [FMPSDLayer layerWithStream:stream psd:self error:err];
                    
                    if (layer) {
                        [layers addObject:layer];
                    }
                    else {
                        debug(@"Could not read layer %d", i);
                    }
                    
                    
                }
                
                int idx = 0;
                for (FMPSDLayer *layer in layers) {
                    if (![layer readImageDataFromStream:stream lineLengths:nil needReadPlanInfo:YES error:err]) {
                        NSLog(@"Could not read data for layer #%d '%@'", idx, [layer layerName]);
                        return NO;
                    }
                }
                
                _baseLayerGroup = [FMPSDLayer baseLayer];
                
                FMPSDLayer *currentGroup = _baseLayerGroup;
                
                // now organize the groups.
                for (FMPSDLayer *layer in [layers reverseObjectEnumerator]) {
                    
                    //debug(@"[layer dividerType]: %d", [layer dividerType]);
                    
                    switch ([layer dividerType]) {
                        
                        case FMPSDLayerTypeNormal:
                            debug(@"NORMAL %@", [layer layerName]);
                            [currentGroup addLayerToGroup:layer];
                            break;
                        case FMPSDLayerTypeFolder:
                            debug(@"FOLDER %@", [layer layerName]);
                            [layer setIsGroup:YES];
                            [currentGroup addLayerToGroup:layer];
                            [layer setParent:currentGroup];
                            
                            currentGroup = layer;
                            
                            break;
                        case FMPSDLayerTypeHidden:
                            debug(@"HIDDEN %@", [layer layerName]);
                            
                            currentGroup = [currentGroup parent];
                            
                            break;
                        
                        default:
                            debug(@"[layer dividerType]: %d", [layer dividerType]);
                            FMAssert(NO);
                    }
                    
                }
                
                [_baseLayerGroup printTree:@""];
                
            }
        }
        
        long globalMaskSize = layerAndMaskInformationSectionLength - ([stream location] - pos);
        FMPSDDebug(@"globalMaskSize: %ld", globalMaskSize);
        
        if (globalMaskSize > 0) { // we had a file that would crash on this guy ("320_skyline_header.psd") - message id: <DA2BE636-DB95-418E-A9BC-3127AB44FF0A@hassetthome.org> in Gus's mu.org email- December 14, 2011
            [stream skipLength:globalMaskSize];
        }
        
    }
    
    BOOL isRuningUnitTest = [[[[NSThread currentThread] threadDictionary] objectForKey:@"TSTesting"] boolValue];
    
    
    if (!isRuningUnitTest && ![[_baseLayerGroup layers] count]) {
        // let the system take care of it- There's no layers, it's probably just the composite layer, and it's pretty funky sometimes.
        // https://flyingmeat.fogbugz.com/default.asp?16104#152097 for example
        return NO;
    }
    
    FMPSDDebug(@"location when reading in composite: %ld", [stream location]);
    
    FMPSDLayer *layer = [FMPSDLayer layerWithSize:NSMakeSize(_width, _height) psd:self];
    
    [layer setChannels:_channels];
    [layer setupChannelIdsForCompositeRead];
    
    // rgba for composites
    
    BOOL rle = [stream readInt16] == 1;
    
    FMPSDDebug(@"rle composite: %d", rle);
    
    if (rle) {
        uint32 nLines = _height * _channels;
        uint16 *lineLengths = malloc(sizeof(uint16) * nLines);
        
        for (uint32 i = 0; i < nLines; i++) {
            lineLengths[i] = [stream readInt16];
        }
        
        [layer readImageDataFromStream:stream lineLengths:lineLengths needReadPlanInfo:NO error:err];
        
        free(lineLengths);
    }
    else {
        [layer readImageDataFromStream:stream lineLengths:0x00 needReadPlanInfo:NO error:err];
    }
    
    
    if (![[_baseLayerGroup layers] count]) {
        [layer setLayerName:@"Background"];
        [_baseLayerGroup addLayerToGroup:layer];
    }
    
    [self setCompositeLayer:layer];
    
    return YES;
}

- (void)writeToFile:(NSURL*)fileURL {
    
    _channels = 4; // we're always 4.  sorry about that!
    
    FMPSDStream *stream = [FMPSDStream PSDStreamForWritingToURL:fileURL];
    
    [stream writeInt32:'8BPS']; // sig
    [stream writeInt16:1]; // version
    
    // now we write 6 bytes of reserved nothing.
    [stream writeInt32:0];
    [stream writeInt16:0];
    
    [stream writeInt16:_channels]; // channels
    [stream writeInt32:_height]; // height
    [stream writeInt32:_width]; // width
    
    [stream writeInt16:_depth];
    [stream writeInt16:FMPSDRGBMode];
    
    [stream writeInt32:0]; // colormap data.
    //[stream writeDataWithLengthHeader:_colormapData];
    
    {   // time for the image resource blocks!
        FMPSDStream *resourceInfoStream = [FMPSDStream PSDStreamForWritingToMemory];
        
        [resourceInfoStream writeInt32:'8BIM'];
        [resourceInfoStream writeInt16:1039]; // ICC Profile
        [resourceInfoStream writePascalString:@"" withPadding:2];
        [resourceInfoStream writeDataWithLengthHeader:[self iccProfile]];
        
        [resourceInfoStream writeInt32:'8BIM'];
        [resourceInfoStream writeInt16:1005]; // resolution info.
        [resourceInfoStream writePascalString:@"" withPadding:2];
        [resourceInfoStream writeDataWithLengthHeader:[self resoultionData]];
        
        [resourceInfoStream writeInt32:'8BIM'];
        [resourceInfoStream writeInt16:1026]; // layer group info
        [resourceInfoStream writePascalString:@"" withPadding:2];
        
        FMPSDStream *groupInfo = [FMPSDStream PSDStreamForWritingToMemory];
        
        for (int i = 0; i < [_baseLayerGroup countOfSubLayers]; i++) {
            [groupInfo writeInt16:0];
        }
        [resourceInfoStream writeDataWithLengthHeader:[groupInfo outputData]];
        
        [stream writeDataWithLengthHeader:[resourceInfoStream outputData]];
    }
    
    
    // Layer and Mask Information Section
    
    FMPSDStream *layerAndGlobalMaskStream = [FMPSDStream PSDStreamForWritingToMemory];
    
    {
        FMPSDStream *layerInfoStream = [FMPSDStream PSDStreamForWritingToMemory];
        
        // the number of layers.
        [layerInfoStream writeSInt16:([_baseLayerGroup countOfSubLayers] * -1)];
        
        for (FMPSDLayer *layer in [[_baseLayerGroup layers] reverseObjectEnumerator]) {
            [layer writeLayerInfoToStream:layerInfoStream];
        }
        
        for (FMPSDLayer *layer in [[_baseLayerGroup layers] reverseObjectEnumerator]) {
            [layer writeImageDataToStream:layerInfoStream];
        }
        
        // Length of the layers info section is rounded up to a multiple of 2.
        while ([[layerInfoStream outputData] length] % 2 != 0) {
            [layerInfoStream writeInt8:0];
        }
        
        [layerAndGlobalMaskStream writeDataWithLengthHeader:[layerInfoStream outputData]];
    }
    
    [layerAndGlobalMaskStream writeInt32:0]; // Length of global layer mask info section.
    //[layerAndGlobalMaskStream writeInt32:0]; // apple seems to get away with this.
    
    /*
    [layerAndGlobalMaskStream writeInt16:0];  // Overlay color space (undocumented).
    [layerAndGlobalMaskStream writeInt64:0]; // 4 * 2 byte color components
    [layerAndGlobalMaskStream writeInt16:100]; // Opacity. 0 = transparent, 100 = opaque.
    [layerAndGlobalMaskStream writeInt8:0]; // Kind.
    [layerAndGlobalMaskStream writeInt8:0]; // filler
    */
    
    [stream writeDataWithLengthHeader:[layerAndGlobalMaskStream outputData]];
    layerAndGlobalMaskStream = nil;
    
    FMPSDLayer *composite = [FMPSDLayer layerWithSize:NSMakeSize(_width, _height) psd:self];
    
    if (_savingCompositeImageRef) {
        [composite setImage:_savingCompositeImageRef];
    }
    else {
        CIImage *img = [self compositeCIImage];
        
        CIContext *ctx = [[CIContext alloc] init];
        
        CGImageRef ref = [ctx createCGImage:img fromRect:CGRectMake(0, 0, _width, _height)];
        
        [composite setImage:ref];
        
        CGImageRelease(ref);
    }
    
    [stream writeInt16:0];
    [composite setIsComposite:YES];
    [composite writeImageDataToStream:stream];
    
    [stream close];
    
}

- (uint16_t)version {
    return _version;
}

- (uint16_t)channels {
    return _channels;
}

- (void)setSavingCompositeImageRef:(CGImageRef)img {
    if (img) {
        CGImageRetain(img);
    }
    
    if (_savingCompositeImageRef) {
        CGImageRelease(_savingCompositeImageRef);
    }
    
    _savingCompositeImageRef = img;
    
}

- (CIImage*)compositeCIImage {
    
    CIImage *i = [[CIImage emptyImage] imageByCroppingToRect:NSMakeRect(0, 0, _width, _height)];
    
    
    CIFilter *sourceOver = [CIFilter filterWithName:@"CISourceOverCompositing"];
    [sourceOver setValue:[_baseLayerGroup CIImageForComposite] forKey:kCIInputImageKey];
    [sourceOver setValue:i forKey:kCIInputBackgroundImageKey];
    
    i = [sourceOver valueForKey:kCIOutputImageKey];
    
    return i;
    
}

+ (void)printDebugInfoForFileAtURL:(NSURL*)fileURL {
    
    FMPSD *psd = [[self alloc] init];
    
    FMPSDPrintDebugInfo = YES;
    
    NSError *err = nil;
    
    if (![psd readDataAtURL:fileURL error:&err]) {
        NSLog(@"Not a valid PSD!");
        NSLog(@"err: %@", err);
        return;
    }
    
    
    NSLog(@"channels: %d", [psd channels]);
    NSLog(@"depth: %d", [psd depth]);
    NSLog(@"colorMode: %d", [psd colorMode]);
    NSLog(@"width: %d", [psd width]);
    NSLog(@"height: %d", [psd height]);
    NSLog(@"version: %d", [psd version]);
    NSLog(@"first group layer count: %ld", [[[psd baseLayerGroup] layers] count]);
    
}

@end


void FMPSDDebug(NSString *format, ...) {
    if (FMPSDPrintDebugInfo) {
        va_list args;
        va_start(args, format);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"
        NSString *body =  [[NSString alloc] initWithFormat:format arguments:args];
#pragma clang diagnostic pop
        fprintf(stdout,"%s\n",[body UTF8String]);
        
        //NSLog(format, args);
        
        va_end(args);
    }
}
