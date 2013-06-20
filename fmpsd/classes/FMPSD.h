//
//  FMPSD.h
//  fmpsd
//
//  Created by August Mueller on 11/6/09.
//  Copyright 2009 Flying Meat Inc. All rights reserved.
//

#define NS_BUILD_32_LIKE_64 1

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Accelerate/Accelerate.h>
#import "FMPSDLayer.h"

#ifdef DEBUG
    #define debug(...) NSLog(__VA_ARGS__)
    #define PXAssert assert
    #define FMAssert assert
#else
    #define debug(...)
    #define PXAssert(...)
    #define FMAssert(...)
#endif


#define TSDebug(...) { if (TSDebugOn) { NSLog(__VA_ARGS__); } }

enum {
    FMPSDBitmapMode = 0,
    FMPSDGrayscaleMode = 1,
    FMPSDIndexedMode = 2,
    FMPSDRGBMode = 3,
    FMPSDCMYKMode = 4,
    FMPSDMultichannelMode = 7,
    FMPSDDuotoneMode = 8,
    FMPSDLabMode = 9
} FMPSDMode;


enum {
    FMPSDLayerTypeNormal,
    FMPSDLayerTypeFolder,
    FMPSDLayerTypeHidden
} FMPSDLayerType;


extern BOOL FMPSDPrintDebugInfo;

@interface FMPSD : NSObject {
    
    uint16_t _version;
    uint16_t _channels;
    
    uint32_t _width;
    uint32_t _height;
    
    uint16_t _depth;
    uint16_t _colorMode;
    
    FMPSDLayer *_baseLayerGroup;
    NSMutableArray *_resourceTags;
    
    NSData *_colormapData;
    NSData *_iccProfile;
    
    FMPSDLayer *_compositeLayer;
    
    BOOL _printDebugInfo;
    
    CGImageRef _savingCompositeImageRef;
    
    CGColorSpaceRef _colorSpace;
}


@property (assign) uint32_t width;
@property (assign) uint32_t height;
@property (assign) uint16_t depth;
@property (assign) uint16_t colorMode;
@property (retain) FMPSDLayer *compositeLayer;
@property (retain) FMPSDLayer *baseLayerGroup;

+ (id)imageWithContetsOfURL:(NSURL*)fileURL error:(NSError**)err;
+ (id)imageWithContetsOfURL:(NSURL*)fileURL error:(NSError**)err printDebugInfo:(BOOL)debugInfo;
+ (void)printDebugInfoForFileAtURL:(NSURL*)fileURL;

- (uint16_t)version;
- (uint16_t)channels;

- (void)writeToFile:(NSURL*)fileURL;
- (CIImage*)compositeCIImage;

- (void)setSavingCompositeImageRef:(CGImageRef)img;

- (CGColorSpaceRef)colorSpace;

@end

#define FMPSDCheck8BIMSig(psd__sig__, psd__stream__, err__) { \
psd__sig__ = [psd__stream__ readInt32];\
if (!((psd__sig__ == '8BIM') || (psd__sig__ == 'MeSa'))) { \
NSString *s = [NSString stringWithFormat:@"%s:%d invalid signature at loc %ld %@", __FUNCTION__, __LINE__, [psd__stream__ location],  NSFileTypeForHFSTypeCode(psd__sig__)];\
NSLog(@"%@", s);\
if (err) { *err__ = [NSError errorWithDomain:@"8BIM" code:1 userInfo:[NSDictionary dictionaryWithObject:s forKey:NSLocalizedDescriptionKey]]; }\
return NO;\
}}\

void FMPSDDebug(NSString *format, ...);

