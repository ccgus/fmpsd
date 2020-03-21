//
//  FMPSDLayer.h
//  fmpsd
//
//  Created by August Mueller on 10/22/10.
//  Copyright 2010 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreImage/CoreImage.h>
#import "FMPSDStream.h"
#import "FMPSDDescriptor.h"

@class FMPSD;

@interface FMPSDLayer : NSObject {

    int32_t _maskTop;
    int32_t _maskLeft;
    int32_t _maskBottom;
    int32_t _maskRight;
    int32_t _maskWidth;
    int32_t _maskHeight;
    
    
    int32_t _maskTop2;
    int32_t _maskLeft2;
    int32_t _maskBottom2;
    int32_t _maskRight2;
    int32_t _maskWidth2;
    int32_t _maskHeight2;
    uint8_t  _maskColor;
    
    uint32_t _layerId;
    uint32_t _blendMode;
    
    CGImageRef _image;
    CGImageRef _mask;
    
    NSMutableArray *_tags;
    
    BOOL _isBase;
    
    int16_t _channelIds[10];
    uint32_t _channelLens[10];
    BOOL _printDebugInfo;
}

@property (assign) int32_t top;
@property (assign) int32_t left;
@property (assign) int32_t bottom;
@property (assign) int32_t right;
@property (assign) uint16_t channels;
@property (retain) NSString *layerName;
@property (weak) FMPSD *psd;
@property (retain) FMPSDDescriptor *textDescriptor;
@property (assign) BOOL isComposite;
@property (assign) int32_t width;
@property (assign) int32_t height;
@property (assign) BOOL isGroup;
@property (assign) BOOL isText;
@property (retain) NSMutableArray *layers;
@property (assign) uint32_t dividerType;
@property (weak) FMPSDLayer *parent;
@property (assign) BOOL visible;
@property (assign) BOOL transparencyProtected;
@property (assign) uint8_t opacity;
@property (assign) BOOL printDebugInfo;
@property (assign) uint32_t blendMode;
@property (retain) NSDictionary *textProperties;
@property CGImageRef image;

+ (instancetype)layerWithStream:(FMPSDStream*)stream psd:(FMPSD*)psd error:(NSError *__autoreleasing *)err;
+ (instancetype)layerWithSize:(CGSize)s psd:(FMPSD*)psd;
+ (instancetype)baseLayer;

- (BOOL)readImageDataFromStream:(FMPSDStream*)stream lineLengths:(uint16_t *)lineLengths needReadPlanInfo:(BOOL)needsPlaneInfo error:(NSError *__autoreleasing *)err;
- (void)writeLayerInfoToStream:(FMPSDStream*)stream;
- (void)writeImageDataToStream:(FMPSDStream*)stream;

- (CGRect)frame;
- (void)setFrame:(CGRect)frame;
- (void)setMaskFrame:(CGRect)frame;
- (CGRect)maskFrame;
- (CGImageRef)mask;
- (void)setMask:(CGImageRef)value;
- (uint8_t)maskColor;

- (CIImage*)CIImageForComposite;

- (void)addLayerToGroup:(FMPSDLayer*)layer;
- (void)printTree:(NSString*)spacing;

- (NSInteger)countOfSubLayers;

- (void)setupChannelIdsForCompositeRead;


@end
