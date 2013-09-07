//
//  FMPSDUtils.h
//  fmpsd
//
//  Created by August Mueller on 10/26/10.
//  Copyright 2010 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FMPSDUtils : NSObject {

}

@end

typedef uint8_t FMPSDPixelCo;

typedef struct _FMPSDPixel {
#ifdef __LITTLE_ENDIAN__
    FMPSDPixelCo b;
    FMPSDPixelCo g;
    FMPSDPixelCo r;
    FMPSDPixelCo a;
#else
    FMPSDPixelCo a;
    FMPSDPixelCo r;
    FMPSDPixelCo g;
    FMPSDPixelCo b;
#endif
} FMPSDPixel;

NSRect FMPSDCGImageGetRect(CGImageRef img);

CGContextRef FMPSDCGBitmapContextCreate(NSSize size, CGColorSpaceRef cs);

FMPSDPixel FMPSDPixelForPointInContext(CGContextRef context, NSPoint point);

FOUNDATION_STATIC_INLINE FMPSDPixel FMPSDUnPremultiply(FMPSDPixel p) {
    
    if (p.a == 0) {
        return p;
    }
    
    p.r = (p.r * 255 + p.a / 2) / p.a;
    p.g = (p.g * 255 + p.a / 2) / p.a;
    p.b = (p.b * 255 + p.a / 2) / p.a;
    
    return p;
}

FOUNDATION_STATIC_INLINE FMPSDPixel FMPSDPremultiply(FMPSDPixel p) {
    
    vImage_Buffer buf;
    buf.data = &p;
    buf.height = 1;
    buf.width = 1;
    buf.rowBytes = sizeof(FMPSDPixel);
    
    FMPSDPixel ret;
    vImage_Buffer dest;
    dest.data = &ret;
    dest.height = 1;
    dest.width = 1;
    dest.rowBytes = sizeof(FMPSDPixel);
    
    vImagePremultiplyData_ARGB8888(&buf, &dest, 0);
    
    return ret;
    
}
