//
//  FMPSDLayer.m
//  fmpsd
//
//  Created by August Mueller on 10/22/10.
//  Copyright 2010 Flying Meat Inc. All rights reserved.
//

#import "FMPSDLayer.h"
#import "FMPSD.h"
#import "FMPSDUtils.h"
#import "FMPSDTextEngineParser.h"
#import "FMPSDPackBits.h"
#import <Accelerate/Accelerate.h>
#import <ImageIO/ImageIO.h>
#import <zlib.h>


@interface FMPSDLayer()
@property (strong) NSMutableArray *packedDatas;
@property (strong) NSMutableArray *readPlaneDatas;
- (BOOL)readLayerInfo:(FMPSDStream*)stream error:(NSError *__autoreleasing *)err;
@end

@implementation FMPSDLayer

+ (instancetype)baseLayer {
    
    FMPSDLayer *ret = [[self alloc] init];
    
    ret->_isBase = YES;
    
    [ret setLayerName:@"<Internal Base Layer>"];
    [ret setIsGroup:YES];
    
    return ret;
}

+ (instancetype)layerWithSize:(CGSize)s psd:(FMPSD*)psd {
    
    FMPSDLayer *ret = [[self alloc] init];
    [ret setPsd:psd];
    
    [ret setWidth:s.width];
    [ret setHeight:s.height];
    
    [ret setRight:s.width];
    
    [ret setBottom:[ret height]];
    
    return ret;
}

+ (instancetype)layerWithStream:(FMPSDStream*)stream psd:(FMPSD*)psd error:(NSError *__autoreleasing *)err {
    
    FMPSDLayer *ret = [[self alloc] init];
    
    [ret setPsd:psd];
    
    if (![ret readLayerInfo:stream error:err]) {
        return 0x00;
    }
    
    return ret;
}

- (id)init {
    self = [super init];
    if (self != nil) {
        _visible = YES;
        _opacity = 255;
        _blendMode = 'norm';
    }
	return self;
}


- (void)dealloc {
    
    if (_image) {
        CGImageRelease(_image);
        _image = nil;
    }
    
}

- (void)writeGroupMarkerToStream:(FMPSDStream*)stream {
    
    [stream writeInt32:0]; // top
    [stream writeInt32:0]; // left
    [stream writeInt32:0]; // bottom
    [stream writeInt32:0]; // right
    [stream writeInt16:4]; // channels
    
    // channel info
    [stream writeSInt16:-1]; // id
    [stream writeInt32:2];   // length
    [stream writeInt16:0];   // id
    [stream writeInt32:2];   // length
    [stream writeInt16:1];   // id
    [stream writeInt32:2];   // length
    [stream writeInt16:2];   // id
    [stream writeInt32:2];   // length
    
    [stream writeInt32:'8BIM'];
    [stream writeInt32:'norm']; // blend mode
    [stream writeInt8:255]; // opactiy
    [stream writeInt8:0]; //clipping Clipping: 0 = base, 1 = non–base
    
    uint8_t flags = 10;
    if (!_transparencyProtected && _visible) {
        flags = 8;
    }
    else if (_transparencyProtected && _visible) {
        flags = 9;
    }
    else if (_transparencyProtected && !_visible) {
        flags = 11;
    }
    [stream writeInt8:flags];
    
    [stream writeInt8:0]; // filler.
    
    FMPSDStream *extraDataStream = [FMPSDStream PSDStreamForWritingToMemory];
    
    // Layer mask data. TABLE 1.18
    [extraDataStream writeInt32:0];
    
    // Layer blending ranges: See Table 1.19.
    [extraDataStream writeInt32:0];
    
    #ifdef DEBUG
    long loc = [extraDataStream location];
    #endif
    NSString *groupEndMarkerName = @"</Layer group>";
    // Layer name: Pascal string, padded to a multiple of 4 bytes.
    [extraDataStream writePascalString:groupEndMarkerName withPadding:4];
    
    FMAssert((([extraDataStream location] - loc) % 4) == 0); // padding has to be to 4!
    
    
    [extraDataStream writeInt32:'8BIM'];
    [extraDataStream writeInt32:'lsct'];
    [extraDataStream writeInt32:sizeof(uint32_t)];
    [extraDataStream writeInt32:3]; // 3 = FMPSDLayerTypeHidden
    
    [extraDataStream writeInt32:'8BIM'];
    [extraDataStream writeInt32:'luni']; // unicode version of string.
    
    NSRange r = NSMakeRange(0, [groupEndMarkerName length]);
    [extraDataStream writeInt32:(uint32_t)(r.length * 2) + 4]; // length of the next bit of data.
    
    // length of our data as a unicode string.
    [extraDataStream writeInt32:(uint32_t)r.length];
    
    unichar *buffer = malloc(sizeof(unichar) * ([groupEndMarkerName length] + 1));
    
    [groupEndMarkerName getCharacters:buffer range:r];
    buffer[([groupEndMarkerName length])] = 0;
    
    for (NSUInteger i = 0; i < [groupEndMarkerName length]; i++) {
        [extraDataStream writeInt16:buffer[i]];
    }
    
    [stream writeDataWithLengthHeader:[extraDataStream outputData]];
    
    free(buffer);
}

- (void)writePSDDescriptorString:(NSString *)string toStream:(FMPSDStream *)stream {
    // PSDString16 format: uint32 length + uint16 chars
    uint32_t len = string ? (uint32_t)[string length] : 0;
    [stream writeInt32:len];
    for (uint32_t i = 0; i < len; i++) {
        [stream writeInt16:[string characterAtIndex:i]];
    }
}

- (void)writeDropShadowDescriptorToStream:(FMPSDStream *)stream {
    FMPSDDescriptor *drsh = [self dropShadow];
    NSDictionary *attrs = [drsh attributes];

    // Descriptor name (empty unicode string)
    [self writePSDDescriptorString:@"" toStream:stream];
    // ClassID for DrSh
    [stream writePSDStringOrFourByteID:'DrSh'];

    // Count the items we'll write
    // enab, Md  , Clr , Opct, uglg, lagl, Dstn, Ckmt, blur = 9 items
    FMPSDDescriptor *colorDesc = [attrs objectForKey:@"Clr "];
    uint32_t itemCount = colorDesc ? 9 : 8;
    [stream writeInt32:itemCount];

    // enab - bool
    [stream writePSDStringOrFourByteID:'enab'];
    [stream writeInt32:'bool'];
    [stream writeInt8:[[attrs objectForKey:@"enab"] boolValue] ? 1 : 0];

    // Md   - enum (blend mode)
    [stream writePSDStringOrFourByteID:'Md  '];
    [stream writeInt32:'enum'];
    [stream writePSDStringOrFourByteID:'BlnM'];
    NSString *modeString = [attrs objectForKey:@"Md  "];
    if (modeString) {
        // Write as a string key
        uint32_t len = (uint32_t)[modeString length];
        [stream writeInt32:len];
        const char *cstr = [modeString UTF8String];
        [stream writeChars:(char *)cstr length:len];
    }
    else {
        [stream writePSDStringOrFourByteID:'Mltp']; // Default to Multiply
    }

    // Clr  - Objc (color descriptor)
    if (colorDesc) {
        [stream writePSDStringOrFourByteID:'Clr '];
        [stream writeInt32:'Objc'];

        // Color descriptor
        [self writePSDDescriptorString:@"" toStream:stream];
        [stream writePSDStringOrFourByteID:'RGBC'];
        [stream writeInt32:3]; // 3 items: Rd, Grn, Bl

        // Rd
        [stream writePSDStringOrFourByteID:'Rd  '];
        [stream writeInt32:'doub'];
        [stream writeDouble64:[[colorDesc.attributes objectForKey:@"Rd  "] doubleValue]];

        // Grn
        [stream writePSDStringOrFourByteID:'Grn '];
        [stream writeInt32:'doub'];
        [stream writeDouble64:[[colorDesc.attributes objectForKey:@"Grn "] doubleValue]];

        // Bl
        [stream writePSDStringOrFourByteID:'Bl  '];
        [stream writeInt32:'doub'];
        [stream writeDouble64:[[colorDesc.attributes objectForKey:@"Bl  "] doubleValue]];
    }

    // Opct - UntF #Prc (percentage)
    [stream writePSDStringOrFourByteID:'Opct'];
    [stream writeInt32:'UntF'];
    [stream writeInt32:'#Prc'];
    [stream writeDouble64:[[attrs objectForKey:@"Opct"] doubleValue]];

    // uglg - bool (use global light)
    [stream writePSDStringOrFourByteID:'uglg'];
    [stream writeInt32:'bool'];
    [stream writeInt8:[[attrs objectForKey:@"uglg"] boolValue] ? 1 : 0];

    // lagl - UntF #Ang (angle in degrees)
    [stream writePSDStringOrFourByteID:'lagl'];
    [stream writeInt32:'UntF'];
    [stream writeInt32:'#Ang'];
    [stream writeDouble64:[[attrs objectForKey:@"lagl"] doubleValue]];

    // Dstn - UntF #Pxl (distance in pixels)
    [stream writePSDStringOrFourByteID:'Dstn'];
    [stream writeInt32:'UntF'];
    [stream writeInt32:'#Pxl'];
    [stream writeDouble64:[[attrs objectForKey:@"Dstn"] doubleValue]];

    // Ckmt - UntF #Pxl (spread/choke)
    [stream writePSDStringOrFourByteID:'Ckmt'];
    [stream writeInt32:'UntF'];
    [stream writeInt32:'#Pxl'];
    [stream writeDouble64:[[attrs objectForKey:@"Ckmt"] doubleValue]];

    // blur - UntF #Pxl (size/blur)
    [stream writePSDStringOrFourByteID:'blur'];
    [stream writeInt32:'UntF'];
    [stream writeInt32:'#Pxl'];
    [stream writeDouble64:[[attrs objectForKey:@"blur"] doubleValue]];
}

- (void)writeLayerEffectsDescriptorToStream:(FMPSDStream *)stream {
    // Top-level effects descriptor
    // Descriptor name (empty unicode string)
    [self writePSDDescriptorString:@"" toStream:stream];
    // ClassID
    [stream writePSDStringOrFourByteID:'null'];

    // Item count - just DrSh for now
    BOOL hasDrSh = [[_layerEffects attributes] objectForKey:@"DrSh"] != nil;
    uint32_t effectCount = 0;
    if (hasDrSh) {
        effectCount++;
    }
    [stream writeInt32:effectCount];

    if (hasDrSh) {
        // Key for this item
        [stream writePSDStringOrFourByteID:'DrSh'];
        // Type tag
        [stream writeInt32:'Objc'];
        // Write the descriptor
        [self writeDropShadowDescriptorToStream:stream];
    }
}

- (void)writeLayerInfoToStream:(FMPSDStream*)stream {
    
    if (_isGroup) {
        
        [self writeGroupMarkerToStream:stream];
        
        for (FMPSDLayer *layer in [[self layers] reverseObjectEnumerator]) {
            [layer writeLayerInfoToStream:stream];
        }
    }
    
    
    
    [stream writeInt32:_top];
    [stream writeInt32:_left];
    [stream writeInt32:_bottom];
    [stream writeInt32:_right];
    
    [stream writeInt16:_mask ? 5 : 4]; // channels.
    
    /*
     Channel information. Six bytes per channel, consisting of:
     2 bytes for Channel ID: 0 = red, 1 = green, etc.;
     -1 = transparency mask; -2 = user supplied layer mask, -3 real user supplied layer mask (when both a user mask and a vector mask are present)
     4 bytes for length of corresponding channel data. (**PSB** 8 bytes for length of corresponding channel data.) See See Channel image data for structure of channel data.
     
     
     Compression. 0 = Raw Data, 1 = RLE compressed, 2 = ZIP without prediction, 3 = ZIP with prediction.
     */
    
    if ([[self psd] compressLayerData] && ![self isComposite]) {
        
        FMPSDDebug(@"Writing compressed data info at location %ld (%@)", [stream location], _layerName);
        
        [self packBitmapDataForWriting];
        
        NSData *a = _packedDatas[0];
        NSData *r = _packedDatas[1];
        NSData *g = _packedDatas[2];
        NSData *b = _packedDatas[3];
        
        
        FMPSDDebug(@"packed a length %ld", [a length]);
        FMPSDDebug(@"packed r length %ld", [r length]);
        FMPSDDebug(@"packed g length %ld", [g length]);
        FMPSDDebug(@"packed b length %ld", [b length]);
        
        // We need to a length of at least two for empty groups and such when we've got compressed data.
        // Here's how to reproduce the problem if we don't:
        // + Top Level Folder A
        //   - Layer B inside Folder A
        // + Top Level Empty folder C
        //
        // And then we'll have a corrupt PSD file.
        // So that's why we check to see if there is zero bytes.
    
        
        // Note: The channel flag is already included in the packed channel data.
        [stream writeSInt16:-1];
        [stream writeInt32:(uint32_t)([a length] == 0 ? 2 : [a length])];
        [stream writeSInt16:0];
        [stream writeInt32:(uint32_t)([r length] == 0 ? 2 : [r length])];
        [stream writeSInt16:1];
        [stream writeInt32:(uint32_t)([g length] == 0 ? 2 : [g length])];
        [stream writeSInt16:2];
        [stream writeInt32:(uint32_t)([b length] == 0 ? 2 : [b length])];

        if (_mask) {
            FMAssert([_packedDatas count] == 5);
            NSData *m = _packedDatas[4];
            [stream writeInt16:-2];
            [stream writeInt32:(uint32_t)([m length] == 0 ? 2 : [m length])];
        }
        
    }
    else {
    
        // Note: The +2 is for the encoding flag.
        [stream writeSInt16:-1];
        [stream writeInt32:(_width * _height) + 2];
        [stream writeInt16:0];
        [stream writeInt32:(_width * _height) + 2];
        [stream writeInt16:1];
        [stream writeInt32:(_width * _height) + 2];
        [stream writeInt16:2];
        [stream writeInt32:(_width * _height) + 2];
        
        if (_mask) {
            [stream writeInt16:-2];
            [stream writeInt32:(_maskWidth * _maskHeight) + 2];
        }
    }
    
    [stream writeInt32:'8BIM'];
    [stream writeInt32:_blendMode];
    [stream writeInt8:_opacity];
    [stream writeInt8:0]; //clipping Clipping: 0 = base, 1 = non–base
    
    // uint8 f = ((_visible << 0x01) | _transparencyProtected);
    uint8_t flags = 10;
    if (!_transparencyProtected && _visible) {
        flags = 8;
    }
    else if (_transparencyProtected && _visible) {
        flags = 9;
    }
    else if (_transparencyProtected && !_visible) {
        flags = 11;
    }
    
    [stream writeInt8:flags]; // this is the flags stuff.  visible, preserve transparency, etc.
    [stream writeInt8:0]; // filler.
    
    {
        FMPSDStream *extraDataStream = [FMPSDStream PSDStreamForWritingToMemory];
        
        // Layer mask data. TABLE 1.18
        
        if (_mask) {
            [extraDataStream writeInt32:20];
            
            [extraDataStream writeInt32:_maskTop];
            [extraDataStream writeInt32:_maskLeft];
            [extraDataStream writeInt32:_maskBottom];
            [extraDataStream writeInt32:_maskRight];
            [extraDataStream writeInt8:255]; // lcolor
            [extraDataStream writeInt8:0]; // lflags
            [extraDataStream writeInt16:0];
        }
        else {
            [extraDataStream writeInt32:0];
        }
        
        // Layer blending ranges: See Table 1.19.
        [extraDataStream writeInt32:0];
        
        #ifdef DEBUG
        long loc = [extraDataStream location];
        #endif
        
        // Layer name: Pascal string, padded to a multiple of 4 bytes.
        // We check and see if the length is greater than 31 chars and just trim it- because that's what PS does.
        // But that's fine- it'll be written out as a unicode string below and PS will read that instead. So this
        // Little bit of layer name writing is really just compatiblity.
        // FIXME: should we be counting bytes for the pascal version of the layer name?
        NSString *lName = _layerName ? _layerName : @"";
        if ([lName length] > 31) {
            lName = [lName substringToIndex:31];
        }
        
        [extraDataStream writePascalString:lName withPadding:4];
        
        FMAssert((([extraDataStream location] - loc) % 4) == 0); // padding has to be to 4!
        
        
    // Additional Layer Information
        
        // Section divider setting:
        
        if (_isGroup) {
            [extraDataStream writeInt32:'8BIM'];
            [extraDataStream writeInt32:'lsct'];
            [extraDataStream writeInt32:12];
            [extraDataStream writeInt32:1];
            [extraDataStream writeInt32:'8BIM'];
            [extraDataStream writeInt32:'pass']; // blend mode!  AGAIN!
        }
        
        [extraDataStream writeInt32:'8BIM'];
        [extraDataStream writeInt32:'luni']; // unicode version of string.
        
        NSRange r = NSMakeRange(0, [_layerName length]);
        [extraDataStream writeInt32:(uint32_t)(r.length * 2) + 4]; // length of the next bit of data.
        
        // length of our data as a unicode string.
        [extraDataStream writeInt32:(uint32_t)r.length];
        
        unichar *buffer = malloc(sizeof(unichar) * ([_layerName length] + 1));
        
        [_layerName getCharacters:buffer range:r];
        buffer[([_layerName length])] = 0;
        
        for (NSUInteger i = 0; i < [_layerName length]; i++) {
            [extraDataStream writeInt16:buffer[i]];
        }
        
        free(buffer);

        // Layer effects (lfx2) - drop shadow
        if (_layerEffects && [[_layerEffects attributes] objectForKey:@"DrSh"]) {
            [extraDataStream writeInt32:'8BIM'];
            [extraDataStream writeInt32:'lfx2'];

            FMPSDStream *lfx2Stream = [FMPSDStream PSDStreamForWritingToMemory];

            [lfx2Stream writeInt32:0]; // version
            [lfx2Stream writeInt32:16]; // descriptor version

            // Write the effects descriptor
            [self writeLayerEffectsDescriptorToStream:lfx2Stream];

            [extraDataStream writeDataWithLengthHeader:[lfx2Stream outputData]];
            [lfx2Stream close];
        }

    // Write and Close

        [stream writeDataWithLengthHeader:[extraDataStream outputData]];
        [extraDataStream close];
    }
}

- (void)packBitmapDataForWriting {
    
    if (_packedDatas) {
        FMAssert(NO);
        return;
    }
    
    if (!_image) {
        FMAssert(_isGroup);
        return;
    }
    
    CGImageRef image = CGImageRetain(_image);
    CGColorSpaceRef colorSpace = CGColorSpaceRetain(CGImageGetColorSpace(image));
    if (CGColorSpaceGetNumberOfComponents(colorSpace) < 3) {
        CGImageRef oldImage = image;
        CGColorSpaceRelease(colorSpace);
        colorSpace = CGColorSpaceCreateDeviceRGB();
        image = CGImageCreateCopyWithColorSpace(image, colorSpace);
        CGImageRelease(oldImage);
    }
    // BGRA. The little endian option flips things around.
    CGContextRef ctx = CGBitmapContextCreate(nil, _width, _height, 8, _width * 4, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);

    CGColorSpaceRelease(colorSpace);

    if (!ctx) {
        CGImageRelease(image);
        FMAssert(NO);
        return;
    }
    
    CGContextSetBlendMode(ctx, kCGBlendModeCopy);
    CGContextDrawImage(ctx, CGRectMake(0, 0, _width, _height), image);
    CGImageRelease(image);

    FMPSDPixel *c = CGBitmapContextGetData(ctx);
    
    vImage_Buffer srcBRGA;
    srcBRGA.data = c;
    srcBRGA.width = _width;
    srcBRGA.height = _height;
    srcBRGA.rowBytes = CGBitmapContextGetBytesPerRow(ctx);
    
    
    // let's unpremultiply this guy - but not if we're a composite! That's stored differently. Obviously.
    if (!_isComposite) {
        
        vImage_Error err = vImageUnpremultiplyData_BGRA8888(&srcBRGA, &srcBRGA, 0);

        if (err != kvImageNoError) {
            NSLog(@"FMPSDLayer writeImageDataToStream: vImageUnpremultiplyData_BGRA8888 err: %ld", err);
        }
    }
    
    /*
     2 bytes: Compression. 0 = Raw Data, 1 = RLE compressed, 2 = ZIP without prediction, 3 = ZIP with prediction.
     
     Variable bytes: Image data.
     If the compression code is 0, the image data is just the raw image data, whose size is calculated as (LayerBottom-LayerTop)* (LayerRight-LayerLeft) (from the first field in See Layer records).
     If the compression code is 1, the image data starts with the byte counts for all the scan lines in the channel (LayerBottom-LayerTop) , with each count stored as a two-byte value.(**PSB** each count stored as a four-byte value.) The RLE compressed data follows, with each scan line compressed separately. The RLE compression is the same compression algorithm used by the Macintosh ROM routine PackBits, and the TIFF standard.
     If the layer's size, and therefore the data, is odd, a pad byte will be inserted at the end of the row.
     If the layer is an adjustment layer, the channel data is undefined (probably all white.)
*/
    
    int channelCount = 4;
    vImage_Buffer planarBGRA[channelCount];
    
    for (int i = 0; i < channelCount; i++) {
        vImageBuffer_Init(&planarBGRA[i], _height, _width, 8, kvImageNoFlags);
        planarBGRA[i].rowBytes = _width;
    }
    
    vImage_Error err = vImageConvert_BGRA8888toPlanar8(&srcBRGA, &planarBGRA[0], &planarBGRA[1], &planarBGRA[2], &planarBGRA[3], kvImageNoFlags);
    FMUnused(err);
    FMAssert(err == kvImageNoError);
    
    NSData *packedB = FMPSDEncodedPackBits(planarBGRA[0].data, _width, _height, planarBGRA[0].rowBytes);
    NSData *packedG = FMPSDEncodedPackBits(planarBGRA[1].data, _width, _height, planarBGRA[1].rowBytes);
    NSData *packedR = FMPSDEncodedPackBits(planarBGRA[2].data, _width, _height, planarBGRA[2].rowBytes);
    NSData *packedA = FMPSDEncodedPackBits(planarBGRA[3].data, _width, _height, planarBGRA[3].rowBytes);
    
    for (int i = 0; i < channelCount; i++) {
        free(planarBGRA[i].data);
    }
    
    _packedDatas = [NSMutableArray arrayWithCapacity:4];
    [_packedDatas addObject:packedA];
    [_packedDatas addObject:packedR];
    [_packedDatas addObject:packedG];
    [_packedDatas addObject:packedB];
    
    CGContextRelease(ctx);
    
    if (_mask) {
        
        size_t maskLen  = _maskWidth * _maskHeight;
        char *m = malloc(sizeof(char) * maskLen);
        CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
        CGContextRef maskCTX = CGBitmapContextCreate(m, _maskWidth, _maskHeight, 8, _maskWidth, cs, (CGBitmapInfo)kCGImageAlphaNone);
        CGColorSpaceRelease(cs);
        CGContextSetBlendMode(maskCTX, kCGBlendModeCopy);
        CGContextDrawImage(maskCTX, CGRectMake(0, 0, _maskWidth, _maskHeight), _mask);
        CGContextRelease(maskCTX);
        
        NSData *packedMask = FMPSDEncodedPackBits(m, _maskWidth, _maskHeight, _maskWidth);
        [_packedDatas addObject:packedMask];
    }
}

- (void)writeImageDataToStream:(FMPSDStream*)stream {
    
    
    if (_isGroup) {
        
        // zero for each channel.
        [stream writeInt16:0]; // -1
        [stream writeInt16:0]; // 0
        [stream writeInt16:0]; // 1
        [stream writeInt16:0]; // 2
        
        for (FMPSDLayer *layer in [[self layers] reverseObjectEnumerator]) {
            [layer writeImageDataToStream:stream];
        }
        
        // end folder crap.
        
        [stream writeInt16:0]; // -1
        [stream writeInt16:0]; // 0
        [stream writeInt16:0]; // 1
        [stream writeInt16:0]; // 2
        
        return;
    }
    
    if (!_width || !_height) {
        return;
    }
    
    if (_packedDatas && ![self isComposite]) {
        
        FMPSDDebug(@"Writing layer data at %ld", [stream location]);
        
        // Note: encoding data is already present in the packed channels.
        
        FMPSDDebug(@"-1 at %ld (%@)", [stream location], _layerName);
        [stream writeData:_packedDatas[0]];
        FMPSDDebug(@"0 at %ld (%@)", [stream location], _layerName);
        [stream writeData:_packedDatas[1]];
        FMPSDDebug(@"1 at %ld (%@)", [stream location], _layerName);
        [stream writeData:_packedDatas[2]];
        FMPSDDebug(@"2 at %ld (%@)", [stream location], _layerName);
        [stream writeData:_packedDatas[3]];
        
        if (_mask) {
            FMAssert([_packedDatas count] == 5);
        }
        
        if ([_packedDatas count] == 5) {
            FMAssert(_mask);
            [stream writeData:_packedDatas[4]];
        }
        
        return;
    }
    else {
        
        CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
        
        size_t len      = _width * _height;
        size_t maskLen  = _maskWidth * _maskHeight;
        
        char *m = nil;
        
        CGContextRef ctx = CGBitmapContextCreate(nil, _width, _height, 8, _width * 4, cs, (uint32_t)kCGImageAlphaPremultipliedFirst | (uint32_t)kCGBitmapByteOrder32Little);
        
        CGColorSpaceRelease(cs);
        
        CGContextSetBlendMode(ctx, kCGBlendModeCopy);
        CGContextDrawImage(ctx, CGRectMake(0, 0, _width, _height), _image);
        
        
        FMPSDPixel *c = CGBitmapContextGetData(ctx);
        
        vImage_Buffer srcBRGA;
        srcBRGA.data = c;
        srcBRGA.width = _width;
        srcBRGA.height = _height;
        srcBRGA.rowBytes = CGBitmapContextGetBytesPerRow(ctx);
        
        
        // let's unpremultiply this guy - but not if we're a composite!
        if (!_isComposite) {

            vImage_Error err = vImageUnpremultiplyData_BGRA8888(&srcBRGA, &srcBRGA, 0);
            
            if (err != kvImageNoError) {
                NSLog(@"FMPSDLayer writeImageDataToStream: vImageUnpremultiplyData_BGRA8888 err: %ld", err);
            }
            
        }
        
        
        int channelCount = 4;
        vImage_Buffer planarBGRA[channelCount];
        
        for (int i = 0; i < channelCount; i++) {
            vImageBuffer_Init(&planarBGRA[i], _height, _width, 8, kvImageNoFlags);
            // Reset rowBytes to width, since we don't have any padding when writing the composite.
            planarBGRA[i].rowBytes = _width;
        }
        
#ifdef FMPSD_USE_PLANAR_CONVERSION
        
        vImage_Error err = vImageConvert_BGRA8888toPlanar8(&srcBRGA, &planarBGRA[0], &planarBGRA[1], &planarBGRA[2], &planarBGRA[3], kvImageNoFlags);
        FMAssert(err == kvImageNoError);
        
#else
        char *b = planarBGRA[0].data;
        char *g = planarBGRA[1].data;
        char *r = planarBGRA[2].data;
        char *a = planarBGRA[3].data;
        
        // split it up into planes
        size_t j = 0;
        while (j < len) {
            
            FMPSDPixel p = c[j];
            
            a[j] = p.a;
            r[j] = p.r;
            g[j] = p.g;
            b[j] = p.b;
            
            j++;
        }
#endif
        
        
        CGContextRelease(ctx);
        
        
        if (_mask) {
            
            m   = malloc(sizeof(char) * maskLen);
            cs  = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
            ctx = CGBitmapContextCreate(m, _maskWidth, _maskHeight, 8, _maskWidth, cs, (CGBitmapInfo)kCGImageAlphaNone);
            CGColorSpaceRelease(cs);
            CGContextDrawImage(ctx, CGRectMake(0, 0, _maskWidth, _maskHeight), _mask);
            CGContextRelease(ctx);
            
        }
        
        if (_isComposite) {
            
            [stream writeChars:planarBGRA[2].data length:len];
            [stream writeChars:planarBGRA[1].data length:len];
            [stream writeChars:planarBGRA[0].data length:len];
            [stream writeChars:planarBGRA[3].data length:len];
        }
        else {
            [stream writeInt16:0];
            [stream writeChars:planarBGRA[2].data length:len];
            [stream writeInt16:0];
            [stream writeChars:planarBGRA[1].data length:len];
            [stream writeInt16:0];
            [stream writeChars:planarBGRA[0].data length:len];
            [stream writeInt16:0];
            [stream writeChars:planarBGRA[3].data length:len];
            
            if (m) {
                [stream writeInt16:0];
                [stream writeChars:m length:maskLen];
            }
        }
        
        for (int i = 0; i < channelCount; i++) {
            free(planarBGRA[i].data);
        }
        
        if (m) {
            free(m);
        }
    }
}

- (BOOL)readLayerInfo:(FMPSDStream*)stream error:(NSError *__autoreleasing *)err {
    uint32_t sig;
    
    BOOL success    = YES;
    
    _top            = [stream readSInt32];
    _left           = [stream readSInt32];
    _bottom         = [stream readSInt32];
    _right          = [stream readSInt32];
    
    _width          = _right - _left;
    _height         = _bottom - _top;
    
    _channels       = [stream readInt16];
    
    FMPSDDebug(@"  _top      %d", _top);
    FMPSDDebug(@"  _left     %d", _left);
    FMPSDDebug(@"  _bottom   %d", _bottom);
    FMPSDDebug(@"  _right    %d", _right);
    FMPSDDebug(@"  _width    %d", _width);
    FMPSDDebug(@"  _height   %d", _height);
    FMPSDDebug(@"  _channels %d", _channels);
    
    FMAssert(_channels <= 10);
    if (_channels > 10) {
        return NO;
    }
    
    for (int chCount = 0; chCount < _channels; chCount++) {
        int16_t chandId = [stream readInt16];
        uint32_t chanLen = [stream readInt32];
        
        // –1 = transparency mask; –2 = user supplied layer mask
        _channelIds[chCount]    = chandId;
        _channelLens[chCount]   = chanLen;
        
        FMPSDDebug(@"  Channel slot %d id: %d len: %d (loc %ld)", chCount, chandId, chanLen, [stream location]);
    }
    
    
    
    FMPSDCheck8BIMSig(sig, stream, err);
    
    _blendMode = [stream readInt32];
    _opacity   = [stream readInt8];
    
    
    //debug(@"opacity: %d", _opacity);
    
    [stream readInt8]; // uint8 clipping
    
    uint8_t flags = [stream readInt8];
    
    _transparencyProtected = flags & 0x01;
    _visible = ((flags >> 1) & 0x01) == 0;
    
    /*
    FMPSDDebug(@"  flags: %d", flags);
    FMPSDDebug(@"  _transparencyProtected: %d", _transparencyProtected);
    FMPSDDebug(@"  __visible:              %d", _visible);
    */
    
    // this guy does thing sa little differently...
    // file://localhost/Volumes/srv/Users/gus/Projects/acorn/plugin/samples/ACPSDLoader/libpsd/libpsd-0.9/src/layer_mask.c
    
    [stream readInt8]; // filler
    
    
    uint32_t lenOfExtraData     = [stream readInt32]; // 84454 - 2600 len Length of the extra data field ( = the total length of the next five fields).
    //lenOfExtraData = (lenOfExtraData % 2 == 0) ? lenOfExtraData : lenOfExtraData + 1;
    //lenOfExtraData = (lenOfExtraData) & ~0x01;
    
    uint32_t foob = lenOfExtraData;
    foob = (foob % 2 == 0) ? foob : foob + 1;
    foob = (foob) & ~0x01;
    
    FMPSDDebug(@"lenOfExtraData: %d / %d", lenOfExtraData, foob);
    
    #ifdef DEBUG
    long endLocation = [stream location] + lenOfExtraData;
    #endif
    
    // layer mask / adjustment layer stuff.
    if (lenOfExtraData) {
        long startExtraLocation   = [stream location];
        
        // LAYER MASK / ADJUSTMENT LAYER DATA
        // Size of the data: 36, 20, or 0. If zero, the following fields are not
        // present
        
        uint32_t lenOfMask = [stream readInt32];
        
        FMPSDDebug(@"  lenOfMask:              %d", lenOfMask);
        
        if (lenOfMask) {
            _maskTop        = [stream readSInt32];
            _maskLeft       = [stream readSInt32];
            _maskBottom     = [stream readSInt32];
            _maskRight      = [stream readSInt32];
            
            
            _maskColor    = [stream readInt8];
            uint8_t lflags    = [stream readInt8];
            
            if (lenOfMask == 20) {
                [stream skipLength:2];
            }
            else if (lenOfMask == 28) { // yes, it can be 28
                // this image, created in cs5: http://blog.marshallbock.com/post/12040410577/iphone-4s-template
                [stream skipLength:10];
            }
            else {
                
                lflags = [stream readInt8]; // Real Flags. Same as Flags information above.
                _maskColor = [stream readInt8]; // Real user mask background. 0 or 255.
                
                // and again. (Rectangle enclosing layer mask: Top, left, bottom, right.)
                // I think this might be for a vector mask?
                _maskTop2    = [stream readSInt32];
                _maskLeft2   = [stream readSInt32];
                _maskBottom2 = [stream readSInt32];
                _maskRight2  = [stream readSInt32];
                
                if (lenOfMask != 36) { // Gus: Bug 43762
                    NSLog(@"%s:%d", __FUNCTION__, __LINE__);
                    NSLog(@"Warning, got an unexpected mask info length: %d", lenOfMask);
                    [stream skipLength:(lenOfMask - 36)];
                }
            }
            
            (void)lflags;
            
            _maskWidth      = _maskRight - _maskLeft;
            _maskHeight     = _maskBottom - _maskTop;
            
            _maskWidth2      = _maskRight - _maskLeft;
            _maskHeight2     = _maskBottom - _maskTop;
        }
        
        FMPSDDebug(@" _maskWidth  %d", _maskWidth);
        FMPSDDebug(@" _maskHeight %d", _maskHeight);
        
        FMPSDDebug(@"location before blend read: %ld", [stream location]);
        
        // Layer blending ranges data
        uint32_t blendLength = [stream readInt32];
        
        // 83446
        if (blendLength == 65535) {
            FMAssert(NO);
        }
        
        FMPSDDebug(@"blendLength: %d", blendLength);
        if (blendLength) {
            FMPSDDebug(@"skipping %d bytes which is the blend length (at location %lld)", blendLength, [stream location]);
            [stream skipLength:blendLength];
        }
        
        
        // Layer name: Pascal string, padded to a multiple of 4 bytes.
        uint8_t psize = [stream readInt8];
        psize = ((psize + 1 + 3) & ~0x03) - 1;
        
        FMPSDDebug(@"Length of layer name is %d", psize);
        
        NSMutableData *layerNameData = [stream readDataOfLength:psize];
        [layerNameData increaseLengthBy:1];
        ((char*)[layerNameData mutableBytes])[psize] = 0;
        
        [self setLayerName:[NSString stringWithFormat:@"%s", (char*)[layerNameData mutableBytes]]];
        
        FMPSDDebug(@"Layer name is '%@'", _layerName);
        
        //_tags = [[NSMutableArray array] retain];
        
        while ([stream location] < startExtraLocation + lenOfExtraData) {
            
            FMPSDCheck8BIMSig(sig, stream, err);
            uint32_t tag  = [stream readInt32];
            uint32_t sigSize = [stream readInt32];
            
            // re sigSize: the official docs say "Length data below, rounded up to an even byte count."
            // but that's complete bullshit, as in the case of Adobe Fireworks CS3 spitting out bad data.
            // see "Theme Template for Photoshop.psd", originally from http://www.vanillasoap.com/2008/09/template-finder-co.html
            
            if (lenOfExtraData % 2 == 0) {
                sigSize = (sigSize) & ~0x01;
            }
            else {
                debug(@"ffffffffffffffffffffffffffffffffffffffffffffffffffff");
            }
            
            FMPSDDebug(@"FMPSDStringForHFSTypeCode(tag): %@:%d", FMPSDStringForHFSTypeCode(tag), sigSize);
            
            if (tag == 'luni') { // layer name as unicode.
                // Chunk begins with A 4-byte length field, representing the
                // number of characters in the string (not bytes).
                // The string of Unicode values follow, two bytes per character.
                uint32_t unicodeCharCount = [stream readInt32];
                uint32_t stringSize = unicodeCharCount * 2;
                NSMutableData *luniData = [stream readDataOfLength:stringSize];
                NSString *unicodeName = [[NSString alloc] initWithBytes:[luniData bytes] length:stringSize encoding:NSUTF16BigEndianStringEncoding];
                [self setLayerName:unicodeName];
                FMPSDDebug(@"Unicode layer name is '%@'", _layerName);
                int32_t skipSize = (int32_t)sigSize - (int32_t)stringSize - 4;
                if (skipSize > 0) {
                    [stream skipLength:skipSize];
                }
            }
            else if (tag == 'lyid') { // layer id.
                _layerId = [stream readInt32];
                
                //debug(@"_layerId: %d", _layerId);
            }
            else if (tag == 'lsct') {
                
                //debug(@"size: %d", size);
                
                int type = [stream readInt32];
                
                if (sigSize == 12) {
                    FMPSDCheck8BIMSig(sig, stream, err);
                    _blendMode = [stream readInt32];
                    
                    //debug(@"xxxxxxxxx: %@", FMPSDStringForHFSTypeCode(_blendMode));
                    
                }
                /*
                else {
                    FMAssert(sizeof(uint32) == sigSize);
                }*/
                
                FMAssert(type < 4 && type >= 0);
                
                //debug(@"type: %d", type);
                
                switch (type) {
                    case 0:
                        _dividerType = FMPSDLayerTypeNormal;
                    case 1:
                    case 2:
                        _dividerType = FMPSDLayerTypeFolder;
                        break;
                    case 3:
                        _dividerType = FMPSDLayerTypeHidden;
                        break;
                    default:
                        assert(NO);
                        _dividerType = FMPSDLayerTypeNormal;
                }
            }

            else if (tag == 'lfx2') {
                // Object-based effects layer info (Photoshop CS6+)
                // Format: version (uint32) + descriptorVersion (uint32) + descriptor
                long lfx2StartLocation = [stream location];

                uint32_t lfx2Version = [stream readInt32];
                FMUnused(lfx2Version);

                uint32_t lfx2DescriptorVersion = [stream readInt32];
                FMUnused(lfx2DescriptorVersion);

                FMPSDDescriptor *effectsDescriptor = [FMPSDDescriptor descriptorWithStream:stream psd:_psd];
                if (effectsDescriptor) {
                    [self setLayerEffects:effectsDescriptor];
                }

                long currentLoc = [stream location];
                long delta = (lfx2StartLocation + sigSize) - currentLoc;
                if (delta > 0) {
                    [stream skipLength:delta];
                }
            }
            else if (tag == 'TySh') {
                // http://www.adobe.com/devnet-apps/photoshop/fileformatashtml/PhotoshopFileFormats.htm#50577409_19762
                long textStartLocation = [stream location];
                
                uint16_t version = [stream readInt16];
                if (version != 1) {
                    NSLog(@"Can't read the text data, we don't understand version %d!", version);
                    return NO;
                }
                
                CGAffineTransform t;
                
                t.a = [stream readDouble64];
                t.b = [stream readDouble64];
                t.c = [stream readDouble64];
                t.d = [stream readDouble64];
                t.tx = [stream readDouble64];
                t.ty = [stream readDouble64];
                
                uint16_t textVersion = [stream readInt16];
                [stream readInt32]; // descriptorVersion
                
                if (textVersion != 50) {
                    NSLog(@"Can't read the text data!");
                    return NO;
                }
                
                [self setTextDescriptor:[FMPSDDescriptor descriptorWithStream:stream psd:_psd]];
                
                uint16_t warpVersion = [stream readInt16];
                FMUnused(warpVersion);
                FMAssert(warpVersion == 1);
                
                uint32_t descriptorVersion = [stream readInt32];
                FMUnused(descriptorVersion);
                FMAssert(descriptorVersion == 16);
                
                [FMPSDDescriptor descriptorWithStream:stream psd:_psd];
                
                long currentLoc = [stream location];
                long delta = (textStartLocation + sigSize) - currentLoc;
                
                // supposidly we've got 24 bytes left for left, top, right, bottom - but that's bulshit.  There's nothing here but padding.
                [stream skipLength:delta];
                
                [self setIsText:YES];
                
            }
            else {
                [stream skipLength:sigSize];
            }
        }
        
        
        if (_dividerType == FMPSDLayerTypeHidden) {
            /*
            debug(@"_blendMode: %d", _blendMode);
            debug(@"FMPSDStringForHFSTypeCode: '%@'", FMPSDStringForHFSTypeCode(_blendMode));
            
            debug(@"_opacity: %d", _opacity);
            debug(@"_visible: %d", _visible);
            */
            
        }
    }
    
    //debug(@"endLocation: %ld vs %ld", endLocation, [stream location]);
    //debug(@"Done reading layer %@ - offset %ld", _layerName, [stream location]);
    
    FMAssert(endLocation == [stream location]); // the layer should end where we expect it to…
    
    return success;
}


// ZIP prediction is horizontal differencing of big endian samples, reset each row.
static void FMPSDDecodePrediction(uint8_t *bytes, size_t width, size_t rows, uint16_t depth) {
    size_t rowBytes = width * (depth / 8);
    for (size_t y = 0; y < rows; y++) {
        uint8_t *row = bytes + y * rowBytes;
        for (size_t x = 1; x < width; x++) {
            if (depth == 16) {
                uint16_t previous = ((uint16_t)row[(x - 1) * 2] << 8) | row[(x - 1) * 2 + 1];
                uint16_t value = (((uint16_t)row[x * 2] << 8) | row[x * 2 + 1]) + previous;
                row[x * 2] = value >> 8;
                row[x * 2 + 1] = value & 255;
            }
            else {
                row[x] += row[x - 1];
            }
        }
    }
}

static NSMutableData *FMPSDInflate(NSData *input, size_t length, NSError **err) {
    NSMutableData *output = [NSMutableData dataWithLength:length];
    uLongf outputLength = length;
    int result = uncompress(output.mutableBytes, &outputLength, input.bytes, input.length);
    if (result != Z_OK || outputLength != length) {
        if (err) {
            *err = [NSError errorWithDomain:@"com.flyingmeat.FMPSD" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Invalid ZIP channel data."}];
        }
        return nil;
    }
    return output;
}

- (char *)readPlaneFromStream:(FMPSDStream *)stream lineLengths:(uint16_t *)lineLengths needReadPlaneInfo:(BOOL)needReadPlaneInfo planeNum:(int)planeNum error:(NSError *__autoreleasing *)err {
    int16_t channelId = _channelIds[planeNum];
    BOOL isMask = channelId == -2;
    if ((isMask && (_maskWidth < 0 || _maskHeight < 0)) || (!isMask && (_width < 0 || _height < 0))) {
        return nil;
    }
    size_t width = isMask ? _maskWidth : _width;
    size_t height = isMask ? _maskHeight : _height;
    size_t rowBytes = width * ([_psd depth] / 8);
    size_t length = rowBytes * height;
    long endLoc = [stream location] + _channelLens[planeNum];
    uint16_t encoding = lineLengths ? 1 : 0;
    NSMutableData *data = nil;
    __attribute__((objc_precise_lifetime)) NSMutableData *counts = nil;
    
    if (needReadPlaneInfo) {
        if (_channelLens[planeNum] < 2 || ![stream hasLengthToRead:_channelLens[planeNum]]) {
            goto invalidData;
        }
        encoding = [stream readInt16];
        if (encoding == 1) {
            if (height > (endLoc - [stream location]) / 2) {
                goto invalidData;
            }
            counts = [NSMutableData dataWithLength:height * sizeof(uint16_t)];
            lineLengths = counts.mutableBytes;
            for (size_t y = 0; y < height; y++) {
                lineLengths[y] = [stream readInt16];
            }
        }
        planeNum = 0;
    }
    
    if (encoding == 0) {
        if (![stream hasLengthToRead:length] || (needReadPlaneInfo && length > endLoc - [stream location])) {
            goto invalidData;
        }
        data = [stream readDataOfLength:length];
    }
    else if (encoding == 1) {
        data = [NSMutableData dataWithLength:length];
        uint8_t *destination = data.mutableBytes;
        for (size_t y = 0; y < height; y++) {
            size_t compressedLength = lineLengths[planeNum * height + y];
            if (![stream hasLengthToRead:compressedLength] || (needReadPlaneInfo && compressedLength > endLoc - [stream location])) {
                goto invalidData;
            }
            NSData *compressed = [stream readDataOfLength:compressedLength];
            const uint8_t *source = compressed.bytes;
            size_t inputIndex = 0, outputIndex = 0;
            while (inputIndex < compressedLength) {
                int8_t code = (int8_t)source[inputIndex++];
                if (code == -128) {
                    continue;
                }
                size_t count = code >= 0 ? code + 1 : 1 - code;
                size_t inputCount = code >= 0 ? count : 1;
                if (count > rowBytes - outputIndex || inputCount > compressedLength - inputIndex) {
                    goto invalidData;
                }
                if (code >= 0) {
                    memcpy(destination + y * rowBytes + outputIndex, source + inputIndex, count);
                }
                else {
                    memset(destination + y * rowBytes + outputIndex, source[inputIndex], count);
                }
                inputIndex += inputCount;
                outputIndex += count;
            }
            if (outputIndex != rowBytes) {
                goto invalidData;
            }
        }
    }
    else if ((encoding == 2 || encoding == 3) && needReadPlaneInfo) {
        data = FMPSDInflate([stream readDataOfLength:endLoc - [stream location]], length, err);
        if (!data) {
            return nil;
        }
        if (encoding == 3) {
            FMPSDDecodePrediction(data.mutableBytes, width, height, [_psd depth]);
        }
    }
    else {
        goto invalidData;
    }
    
    if (needReadPlaneInfo) {
        if ([stream location] > endLoc) {
            goto invalidData;
        }
        [stream seekToLocation:endLoc];
    }
    [self.readPlaneDatas addObject:data];
    return data.mutableBytes;
    
invalidData:
    if (err) {
        *err = [NSError errorWithDomain:@"com.flyingmeat.FMPSD" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Invalid or unsupported PSD channel data."}];
    }
    return nil;
}

- (BOOL)readCompositeImageDataFromStream:(FMPSDStream *)stream encoding:(uint16_t)encoding error:(NSError *__autoreleasing *)err {
    if (encoding == 1) {
        size_t count = (size_t)_height * _channels;
        if (![stream hasLengthToRead:count * sizeof(uint16_t)]) {
            return NO;
        }
        __attribute__((objc_precise_lifetime)) NSMutableData *counts = [NSMutableData dataWithLength:count * sizeof(uint16_t)];
        uint16_t *lineLengths = counts.mutableBytes;
        for (size_t i = 0; i < count; i++) {
            lineLengths[i] = [stream readInt16];
        }
        return [self readImageDataFromStream:stream lineLengths:lineLengths needReadPlanInfo:NO error:err];
    }
    if (encoding == 2 || encoding == 3) {
        size_t length = (size_t)_width * _height * _channels * ([_psd depth] / 8);
        NSMutableData *data = FMPSDInflate([stream readToEOF], length, err);
        if (!data) {
            return NO;
        }
        if (encoding == 3) {
            FMPSDDecodePrediction(data.mutableBytes, _width, (size_t)_height * _channels, [_psd depth]);
        }
        stream = [FMPSDStream PSDStreamForReadingData:data];
    }
    else if (encoding != 0) {
        if (err) {
            *err = [NSError errorWithDomain:@"com.flyingmeat.FMPSD" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Unsupported composite compression."}];
        }
        return NO;
    }
    return [self readImageDataFromStream:stream lineLengths:nil needReadPlanInfo:NO error:err];
}

- (int)channelIdForRow:(int)row {
    return _channelIds[row];
}

- (BOOL)readImageDataFromStream:(FMPSDStream*)stream lineLengths:(uint16_t *)lineLengths needReadPlanInfo:(BOOL)needsPlaneInfo error:(NSError *__autoreleasing *)err {
    // Keep plane buffers alive until Core Graphics has copied the assembled image.
    self.readPlaneDatas = [NSMutableArray array];
    @try {
        return [self assembleImageDataFromStream:stream lineLengths:lineLengths needReadPlanInfo:needsPlaneInfo error:err];
    }
    @finally {
        self.readPlaneDatas = nil;
    }
}

- (BOOL)assembleImageDataFromStream:(FMPSDStream*)stream lineLengths:(uint16_t *)lineLengths needReadPlanInfo:(BOOL)needsPlaneInfo error:(NSError *__autoreleasing *)err {
    
    FMPSDDebug(@"readImageDataFromStream for %@", _layerName);

    // In CMYK mode, the r/g/b planes hold cyan/magenta/yellow, plus a black plane (channel id 3).
    BOOL isCMYK = [_psd colorMode] == FMPSDCMYKMode;

    char* r = nil, *g = nil, *b = nil, *k = nil, *a = nil, *m = nil;

    int j = 0;
    
    for (; j < _channels; j++) {
        
        int channelId = [self channelIdForRow:j];
        
        FMPSDDebug(@"Reading row %d, channel id %d for \"%@\" has lineLengths: %d pos %ld _channelLens[j]: %d", j, channelId, _layerName, (lineLengths != nil), [stream location], _channelLens[j]);
        
        if (_channelLens[j] == 2) {
            FMPSDDebug(@"it's empty…");
            [stream skipLength:2];
            continue;
        }
        
        if (channelId == -1) { // alpha
            FMPSDDebug(@"reading alpha");
            a = [self readPlaneFromStream:stream lineLengths:lineLengths needReadPlaneInfo:needsPlaneInfo planeNum:j error:err];
            if (!a) {
                debug(@"reading alpha failed.");
                return NO;
            }
        }
        else if (channelId == 0) { // r
            FMPSDDebug(@"reading red");
            r = [self readPlaneFromStream:stream lineLengths:lineLengths needReadPlaneInfo:needsPlaneInfo planeNum:j error:err];
            if (!r) {
                debug(@"reading red failed.");
                return NO;
            }
        }
        else if (channelId == 1) { // g
            FMPSDDebug(@"reading green");
            g = [self readPlaneFromStream:stream lineLengths:lineLengths needReadPlaneInfo:needsPlaneInfo planeNum:j error:err];
            if (!g) {
                debug(@"reading green failed.");
                return NO;
            }
        }
        else if (channelId == 2) { // b
            FMPSDDebug(@"reading blue");
            b = [self readPlaneFromStream:stream lineLengths:lineLengths needReadPlaneInfo:needsPlaneInfo planeNum:j error:err];
            if (!b) {
                debug(@"reading blue failed.");
                return NO;
            }
        }
        else if (channelId == 3 && isCMYK) { // k
            FMPSDDebug(@"reading black");
            k = [self readPlaneFromStream:stream lineLengths:lineLengths needReadPlaneInfo:needsPlaneInfo planeNum:j error:err];
            if (!k) {
                debug(@"reading black failed.");
                return NO;
            }
        }
        else if (channelId == -2) { // m
            FMPSDDebug(@"reading mask for %@", _layerName);
            
            long start = [stream location];
            
            long end = _channelLens[j] + start;
            
            m = [self readPlaneFromStream:stream lineLengths:lineLengths needReadPlaneInfo:needsPlaneInfo planeNum:j error:err];
            
            if (!m) {
                debug(@"whoa- m is empty!");
                if ([_psd depth] == 16) {
                    return NO;
                }
            }
            
            long diff = end - [stream location];
            
            [stream skipLength:diff];
            
            /*
            if (diff != 0) {
                
                NSLog(@"expected to read %d bytes, only read %ld (%ld diff)", _channelLens[j], ([stream location] - start), diff);
                
                NSString *s = [NSString stringWithFormat:@"%s:%d Mask ended unexpededly at offset %ld", __FUNCTION__, __LINE__, [stream location]];
                NSLog(@"%@", s);
                if (err) {
                    *err = [NSError errorWithDomain:@"com.flyingmeat.FMPSD" code:2 userInfo:[NSDictionary dictionaryWithObject:s forKey:NSLocalizedDescriptionKey]];
                }
                
                return NO;
            }
            */
        }
        else {
            [stream skipLength:_channelLens[j]];
        }
    }
    
    if ([_psd depth] == 16) {
        if (m && _maskWidth && _maskHeight) {
            NSData *maskData = [NSData dataWithBytes:m length:(size_t)_maskWidth * _maskHeight * 2];
            CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)maskData);
            CGColorSpaceRef gray = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
            _mask = CGImageCreate(_maskWidth, _maskHeight, 16, 16, _maskWidth * 2, gray, kCGImageAlphaNone | kCGBitmapByteOrder16Big, provider, nil, NO, kCGRenderingIntentDefault);
            CGColorSpaceRelease(gray);
            CGDataProviderRelease(provider);
            if (!_mask) {
                return NO;
            }
        }
        if (_width <= 0 || _height <= 0) {
            return YES;
        }
        
        CGContextRef ctx = CGBitmapContextCreate(nil, _width, _height, 16, (size_t)_width * 8, [_psd colorSpace], kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder16Host);
        if (!ctx) {
            return NO;
        }
        uint16_t *pixels = CGBitmapContextGetData(ctx);
        size_t stride = CGBitmapContextGetBytesPerRow(ctx) / sizeof(uint16_t);
        dispatch_apply(_height, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t row) {
            for (size_t x = 0; x < (size_t)_width; x++) {
                size_t offset = (row * _width + x) * 2;
                uint16_t alpha = a ? ((uint16_t)(uint8_t)a[offset] << 8) | (uint8_t)a[offset + 1] : UINT16_MAX;
                char *planes[] = {r, g, b};
                uint16_t *pixel = pixels + row * stride + x * 4;
                for (size_t channel = 0; channel < 3; channel++) {
                    char *plane = planes[channel];
                    uint16_t value = plane ? ((uint16_t)(uint8_t)plane[offset] << 8) | (uint8_t)plane[offset + 1] : 0;
                    pixel[channel] = ((uint32_t)value * alpha + 32767) / UINT16_MAX;
                }
                pixel[3] = alpha;
            }
        });
        _image = CGBitmapContextCreateImage(ctx);
        CGContextRelease(ctx);
        return _image != nil;
    }
    
    if (m) {
        
        CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
        
        CGContextRef alphaMask = CGBitmapContextCreate(m, _maskWidth, _maskHeight, 8, _maskWidth, cs, (CGBitmapInfo)kCGImageAlphaNone);
        
        _mask = CGBitmapContextCreateImage(alphaMask);
                    
        CGColorSpaceRelease(cs);
        CGContextRelease(alphaMask);
        
    }
    
    if ((_height <= 0) || (_width <= 0)) {
        return YES;
    }
    
    size_t n = _width * _height;

    if (!r) {
        r = [[NSMutableData dataWithLength:sizeof(unsigned char) * _width * _height] mutableBytes];
        if (isCMYK) {
            memset(r, 255, n); // the channel data is inverted, so 255 is no ink.
        }
    }

    if (!g) {
        g = [[NSMutableData dataWithLength:sizeof(unsigned char) * _width * _height] mutableBytes];
        if (isCMYK) {
            memset(g, 255, n);
        }
    }

    if (!b) {
        b = [[NSMutableData dataWithLength:sizeof(unsigned char) * _width * _height] mutableBytes];
        if (isCMYK) {
            memset(b, 255, n);
        }
    }

    if (isCMYK && !k) {
        k = [[NSMutableData dataWithLength:sizeof(unsigned char) * _width * _height] mutableBytes];
        memset(k, 255, n);
    }

    if (!a) {
        a = [[NSMutableData dataWithLength:sizeof(unsigned char) * _width * _height] mutableBytes];
        memset(a, 255, _width * _height);
    }
    
    if (n) {
        
        CGContextRef ctx = CGBitmapContextCreate(nil, _width, _height, 8, _width * 4, [_psd colorSpace], (uint32_t)kCGImageAlphaPremultipliedFirst | (uint32_t)kCGBitmapByteOrder32Little);
        
        FMPSDPixel *c = CGBitmapContextGetData(ctx);


        // OK, we're going to de-plane our image, and premultiply it as well.
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

        int32_t width = _width;

        if (isCMYK) {

            // The channel data is stored inverted (0 = 100% ink), which we flip back around
            // while interleaving the planes. Then we hand the result off to CG with the
            // document's CMYK profile so we get a color managed conversion to RGB.
            NSMutableData *cmykData = [NSMutableData dataWithLength:n * 4];
            uint8_t *cmyk = [cmykData mutableBytes];

            dispatch_apply(_height, queue, ^(size_t row) {

                size_t planeStart = (row * width);
                int32_t x = 0;
                while (x < width) {

                    size_t planeLoc = planeStart + x;
                    uint8_t *d = &cmyk[planeLoc * 4];

                    d[0] = 255 - (uint8_t)r[planeLoc];
                    d[1] = 255 - (uint8_t)g[planeLoc];
                    d[2] = 255 - (uint8_t)b[planeLoc];
                    d[3] = 255 - (uint8_t)k[planeLoc];

                    x++;
                }
            });

            CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)cmykData);
            CGImageRef cmykImage = CGImageCreate(_width, _height, 8, 32, _width * 4, [_psd sourceCMYKColorSpace], (CGBitmapInfo)kCGImageAlphaNone, provider, nil, NO, kCGRenderingIntentDefault);
            CGDataProviderRelease(provider);

            CGContextSetBlendMode(ctx, kCGBlendModeCopy);
            CGContextDrawImage(ctx, CGRectMake(0, 0, _width, _height), cmykImage);
            CGImageRelease(cmykImage);

            // The context is opaque RGB now, so bring in the alpha plane (premultiplying as we go).
            dispatch_apply(_height, queue, ^(size_t row) {

                FMPSDPixel *p = &c[width * row];

                size_t planeStart = (row * width);
                int32_t x = 0;
                while (x < width) {

                    FMPSDPixelCo ac = a[planeStart + x];

                    p->a = ac;

                    p->r = (p->r * ac + 127) / 255;
                    p->g = (p->g * ac + 127) / 255;
                    p->b = (p->b * ac + 127) / 255;

                    p++;
                    x++;
                }
            });
        }
        else {

            dispatch_apply(_height, queue, ^(size_t row) {

                FMPSDPixel *p = &c[width * row];

                size_t planeStart = (row * width);
                int32_t x = 0;
                while (x < width) {

                    size_t planeLoc = planeStart + x;

                    FMPSDPixelCo ac = a[planeLoc];
                    FMPSDPixelCo rc = r[planeLoc];
                    FMPSDPixelCo gc = g[planeLoc];
                    FMPSDPixelCo bc = b[planeLoc];

                    p->a = ac;

                    p->r = (rc * ac + 127) / 255;
                    p->g = (gc * ac + 127) / 255;
                    p->b = (bc * ac + 127) / 255;

                    p++;
                    x++;
                }
            });
        }

        _image = CGBitmapContextCreateImage(ctx);
        
        CGContextRelease(ctx);
        
        
    }
    
    return YES;
}

- (uint8_t)maskColor {
    return _maskColor;
}

- (CGImageRef)mask {
    return _mask;
}

- (void)setMask:(CGImageRef)anImage {
    
    if (anImage) {
        CGImageRetain(anImage);
        _maskWidth = (uint32_t)CGImageGetWidth(anImage);
        _maskHeight = (uint32_t)CGImageGetHeight(anImage);
    }
    
    if (_mask) {
        CGImageRelease(_mask);
    }
    
    _mask = anImage;
}



- (CGImageRef)image {
    return _image;
}

- (void)setImage:(CGImageRef)anImage {
    
    if (anImage) {
        CGImageRetain(anImage);
    }
    
    if (_image) {
        CGImageRelease(_image);
    }
    
    _image = anImage;
    
}

- (void)addLayerToGroup:(FMPSDLayer*)layer {
    if (!_layers) {
        _layers = [NSMutableArray array];
    }
    
    [_layers addObject:layer];
}

- (CGRect)frame {
    return CGRectMake(_left, (float)[_psd height] - (float)_bottom, _width, _height);
}

- (void)setFrame:(CGRect)frame {
    
    // the origin is in the top left.
    
    CGFloat psdHeight   = [_psd height];
    
    _width              = frame.size.width;
    _height             = frame.size.height;
    
    _left               = CGRectGetMinX(frame);
    _right              = CGRectGetMaxX(frame);
        
    _top                = psdHeight - CGRectGetMaxY(frame);
    _bottom             = psdHeight - CGRectGetMinY(frame);
}

- (CGRect)maskFrame {
    return CGRectMake(_maskLeft, (float)[_psd height] - (float)_maskBottom, _maskWidth, _maskHeight);
}

- (void)setMaskFrame:(CGRect)frame {
    CGFloat psdHeight   = [_psd height];
    
    _maskWidth  = frame.size.width;
    _maskHeight = frame.size.height;
    
    _maskLeft   = CGRectGetMinX(frame);
    _maskRight  = CGRectGetMaxX(frame);
    
    _maskTop    = psdHeight - CGRectGetMaxY(frame);
    _maskBottom = psdHeight - CGRectGetMinY(frame);
}


- (CIImage*)CIImageForComposite {
    
    //debug(@"compositeCIImage: %@", _layerName);
    
    
    if (!_visible) {
        return [CIImage emptyImage];
    }
    
    if (_isGroup) {
        
        CIImage *i = [[CIImage emptyImage] imageByCroppingToRect:CGRectMake(0, 0, [_psd width], [_psd height])];
        
        for (FMPSDLayer *layer in [_layers reverseObjectEnumerator]) {
            
            if ([layer visible]) {
                
                CIFilter *sourceOver = [CIFilter filterWithName:@"CISourceOverCompositing"];
                [sourceOver setValue:[layer CIImageForComposite] forKey:kCIInputImageKey];
                [sourceOver setValue:i forKey:kCIInputBackgroundImageKey];
                
                i = [sourceOver valueForKey:kCIOutputImageKey];
            }
            
        }
        
        return i;
    }
    
    
    CIImage *img = nil;
    
    if (!_image) {
        img = [[CIImage emptyImage] imageByCroppingToRect:CGRectMake(0, 0, _width, _height)];
    }
    else {
        img = [CIImage imageWithCGImage:_image];
    }
    
    
    CGRect r = [self frame];
    img = [img imageByApplyingTransform:CGAffineTransformMakeTranslation(r.origin.x, r.origin.y)];
    
    if (_opacity < 255) {
        
        CIFilter *colorMatrix = [CIFilter filterWithName:@"CIColorMatrix"];
        
        CIVector *v = [CIVector vectorWithX:0 Y:0 Z:0 W:_opacity / 255.0];
        
        [colorMatrix setValue:v forKey:@"inputAVector"];
        [colorMatrix setValue:img forKey:kCIInputImageKey];
        
        img = [colorMatrix outputImage];
    }
    
    if (_mask) {
        
        CIImage *maskImage = [CIImage imageWithCGImage:_mask];
        CGRect maskFrame = [self maskFrame];
        maskImage = [maskImage imageByApplyingTransform:CGAffineTransformMakeTranslation(maskFrame.origin.x, maskFrame.origin.y)];
        
        CIFilter *filter = [CIFilter filterWithName:@"CIColorInvert"];
        [filter setValue:maskImage forKey:@"inputImage"];
        maskImage = [filter valueForKey: @"outputImage"];
        
        
        CIFilter *blendFilter       = [CIFilter filterWithName:@"CIBlendWithMask"];
        
        [blendFilter setValue:[CIImage emptyImage] forKey:@"inputImage"];
        [blendFilter setValue:img forKey:@"inputBackgroundImage"];
        [blendFilter setValue:maskImage forKey:@"inputMaskImage"];
        
        
        
        img = [blendFilter valueForKey:kCIOutputImageKey];
    }
    
    
    
    return img;
}

- (void)writeToFileAsPSD:(NSString *)path {
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], (CFStringRef)@"com.adobe.photoshop-image", 1, NULL);
    CGImageDestinationAddImage(destination, _image, (__bridge CFDictionaryRef)[NSDictionary dictionary]);
    CGImageDestinationFinalize(destination);
    CFRelease(destination);
}

- (void)printTree:(NSString*)spacing {
    
    debug(@"%@%@%@", spacing, _isGroup ? @"+" : @"*", _layerName);
    
    spacing = [spacing stringByAppendingString:@"  "];
    
    for (FMPSDLayer *layer in _layers) {
        [layer printTree:spacing];
    }
}

- (NSInteger)countOfSubLayers {
    
    NSInteger count = 0;
    
    for (FMPSDLayer *layer in _layers) {
        
        count++;
        
        if ([layer isGroup]) {
            count += [layer countOfSubLayers];
            count ++; // division layer
        }
    }
    
    return count;
}

- (void)setupChannelIdsForCompositeRead {

    if ([_psd colorMode] == FMPSDCMYKMode) {
        _channelIds[0] = 0; // cyan
        _channelIds[1] = 1; // magenta
        _channelIds[2] = 2; // yellow
        _channelIds[3] = 3; // black
        if (_channels > 4) {
            _channelIds[4] = -1; // alpha
        }
    }
    else {
        _channelIds[0] = 0;
        _channelIds[1] = 1;
        _channelIds[2] = 2;
        _channelIds[3] = -1;
    }

    _isComposite = YES;
}

- (void)setDropShadowEnabled:(BOOL)enabled color:(CGColorRef)color opacity:(double)opacity angle:(double)angle distance:(double)distance size:(double)size {

    if (!_layerEffects) {
        _layerEffects = [[FMPSDDescriptor alloc] init];
        [_layerEffects setAttributes:[NSMutableDictionary dictionary]];
    }

    FMPSDDescriptor *drsh = [[FMPSDDescriptor alloc] init];
    [drsh setAttributes:[NSMutableDictionary dictionary]];

    [[drsh attributes] setObject:@(enabled) forKey:@"enab"];
    [[drsh attributes] setObject:@"Mltp" forKey:@"Md  "]; // Multiply blend mode
    [[drsh attributes] setObject:@(opacity) forKey:@"Opct"];
    [[drsh attributes] setObject:@(NO) forKey:@"uglg"]; // Don't use global light
    [[drsh attributes] setObject:@(angle) forKey:@"lagl"];
    [[drsh attributes] setObject:@(distance) forKey:@"Dstn"];
    [[drsh attributes] setObject:@(0.0) forKey:@"Ckmt"]; // Spread
    [[drsh attributes] setObject:@(size) forKey:@"blur"];

    if (color) {
        const CGFloat *components = CGColorGetComponents(color);
        NSUInteger numComponents = CGColorGetNumberOfComponents(color);

        FMPSDDescriptor *colorDesc = [[FMPSDDescriptor alloc] init];
        [colorDesc setAttributes:[NSMutableDictionary dictionary]];

        if (numComponents >= 3) {
            [[colorDesc attributes] setObject:@(components[0] * 255.0) forKey:@"Rd  "];
            [[colorDesc attributes] setObject:@(components[1] * 255.0) forKey:@"Grn "];
            [[colorDesc attributes] setObject:@(components[2] * 255.0) forKey:@"Bl  "];
        }
        else {
            // Grayscale
            [[colorDesc attributes] setObject:@(components[0] * 255.0) forKey:@"Rd  "];
            [[colorDesc attributes] setObject:@(components[0] * 255.0) forKey:@"Grn "];
            [[colorDesc attributes] setObject:@(components[0] * 255.0) forKey:@"Bl  "];
        }

        [[drsh attributes] setObject:colorDesc forKey:@"Clr "];
    }

    [[_layerEffects attributes] setObject:drsh forKey:@"DrSh"];
}

- (BOOL)hasDropShadow {
    if (!_layerEffects) {
        return NO;
    }
    
    FMPSDDescriptor *drsh = [[_layerEffects attributes] objectForKey:@"DrSh"];
    if (drsh && [drsh isKindOfClass:[FMPSDDescriptor class]]) {
        NSNumber *enabled = [[drsh attributes] objectForKey:@"enab"];
        return [enabled boolValue];
    }
    
    return NO;
}

- (FMPSDDescriptor *)dropShadow {
    if (!_layerEffects) {
        return nil;
    }
    
    FMPSDDescriptor *drsh = [[_layerEffects attributes] objectForKey:@"DrSh"];
    if (drsh && [drsh isKindOfClass:[FMPSDDescriptor class]]) {
        return drsh;
    }
    
    return nil;
}

@end
