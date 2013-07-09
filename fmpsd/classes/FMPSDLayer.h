//
//  FMPSDLayer.h
//  fmpsd
//
//  Created by August Mueller on 10/22/10.
//  Copyright 2010 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FMPSDStream.h"
#import "FMPSDDescriptor.h"

@class FMPSD;

@interface FMPSDLayer : NSObject {

    sint32 _maskTop;
    sint32 _maskLeft;
    sint32 _maskBottom;
    sint32 _maskRight;
    sint32 _maskWidth;
    sint32 _maskHeight;
    
    
    sint32 _maskTop2;
    sint32 _maskLeft2;
    sint32 _maskBottom2;
    sint32 _maskRight2;
    sint32 _maskWidth2;
    sint32 _maskHeight2;
    
    uint32 _layerId;
    uint32 _blendMode;
    
    CGImageRef _image;
    CGImageRef _mask;
    
    NSMutableArray *_tags;
    
    BOOL _isBase;
    
    sint16 _channelIds[10];
    uint32 _channelLens[10];
    BOOL _printDebugInfo;
}

@property (assign) sint32 top;
@property (assign) sint32 left;
@property (assign) sint32 bottom;
@property (assign) sint32 right;
@property (assign) uint16 channels;
@property (retain) NSString *layerName;
@property (weak) FMPSD *psd;
@property (retain) FMPSDDescriptor *textDescriptor;
@property (assign) BOOL isComposite;
@property (assign) sint32 width;
@property (assign) sint32 height;
@property (assign) BOOL isGroup;
@property (assign) BOOL isText;
@property (retain) NSMutableArray *layers;
@property (assign) uint32 dividerType;
@property (weak) FMPSDLayer *parent;
@property (assign) BOOL visible;
@property (assign) BOOL transparencyProtected;
@property (assign) uint8 opacity;
@property (assign) BOOL printDebugInfo;
@property (assign) uint32 blendMode;
@property (retain) NSDictionary *textProperties;


+ (id)layerWithStream:(FMPSDStream*)stream psd:(FMPSD*)psd error:(NSError**)err;
+ (id)layerWithSize:(NSSize)s psd:(FMPSD*)psd;
+ (id)baseLayer;

- (BOOL)readImageDataFromStream:(FMPSDStream*)stream lineLengths:(uint16 *)lineLengths needReadPlanInfo:(BOOL)needsPlaneInfo error:(NSError**)err;
- (void)writeLayerInfoToStream:(FMPSDStream*)stream;
- (void)writeImageDataToStream:(FMPSDStream*)stream;

- (NSRect)frame;
- (void)setFrame:(NSRect)frame;
- (void)setMaskFrame:(NSRect)frame;
- (NSRect)maskFrame;
- (CGImageRef)image;
- (void)setImage:(CGImageRef)anImage;
- (CGImageRef)mask;
- (void)setMask:(CGImageRef)value;


- (CIImage*)CIImageForComposite;

- (void)addLayerToGroup:(FMPSDLayer*)layer;
- (void)printTree:(NSString*)spacing;

- (NSInteger)countOfSubLayers;

- (void)setupChannelIdsForCompositeRead;
@end
