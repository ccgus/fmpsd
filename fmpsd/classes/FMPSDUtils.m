//
//  FMPSDUtils.m
//  fmpsd
//
//  Created by August Mueller on 10/26/10.
//  Copyright 2010 Flying Meat Inc. All rights reserved.
//

#import "FMPSD.h"
#import "FMPSDUtils.h"
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/ImageIO.h>

#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#else
#import <AppKit/NSGraphics.h>   // for NSBeep
#endif

@implementation FMPSDUtils

+ (id)stringWithUUID {
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    //[uuidString autorelease];
    return [uuidString lowercaseString];
}


+ (void)writeComposite:(CIImage*)img colorSpace:(CGColorSpaceRef)cs withBounds:(CGRect)bounds toPath:(NSString*)path {
    
    //kCIImageColorSpace
    
    //[img setValue:(id)cs forKey:kCIImageColorSpace];
    
    NSMutableDictionary *contextOptions = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                           (__bridge id)cs, kCIContextOutputColorSpace,
                                           nil];
    
    CGContextRef cgContextToMakeClangBeQuiet = FMPSDCGBitmapContextCreate(bounds.size, cs);
    
    CIContext *ctx = [CIContext contextWithCGContext:cgContextToMakeClangBeQuiet options:contextOptions];
    
    [ctx drawImage:img inRect:bounds fromRect:bounds];
    
    CGImageRef ref = CGBitmapContextCreateImage(cgContextToMakeClangBeQuiet);
    FMAssert(ref);
    
    NSURL *u = [NSURL fileURLWithPath:path];
    
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithURL((__bridge CFURLRef)u, (__bridge CFStringRef)UTTypeTIFF.identifier, 1, NULL);
    FMAssert(imageDestination);
    
    CGImageDestinationAddImage(imageDestination, ref, nil);//(__bridge CFDictionaryRef)[NSDictionary dictionary]);
    BOOL b = CGImageDestinationFinalize(imageDestination);
    (void)b;
    
    FMAssert(b);
    
    CFRelease(imageDestination);
    CGImageRelease(ref);
    CGContextRelease(cgContextToMakeClangBeQuiet);
    
}

+ (BOOL)compareComposite:(FMPSD*)psd toImageAtURL:(NSURL*)pathURL tolerance:(int)tolerance {
    
    if (![psd isKindOfClass:[FMPSD class]]) {
        debug(@"HEY WHY IS A NON FMPSD BEING PASSED TO ME?");
        abort();
    }
    
    //CGColorSpaceRef linearCS = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGBLinear);
    
    CIImage *compareTo = [CIImage imageWithContentsOfURL:pathURL options:nil];
    CGRect r = CGRectMake(0, 0, compareTo.extent.size.width, compareTo.extent.size.height);
    
    NSString *tempPath = [NSString stringWithFormat:@"/private/tmp/%@.tiff", [self stringWithUUID]];
    
    [self writeComposite:[psd compositeCIImage] colorSpace:[psd colorSpace] withBounds:r toPath:tempPath];
    
    NSData *dataA = [NSData dataWithContentsOfFile:tempPath];
    NSData *dataB = [NSData dataWithContentsOfURL:pathURL];
    
    FMAssert(dataA);
    FMAssert(dataB);
    
    
    CGImageSourceRef imageSourceRefA = CGImageSourceCreateWithData((__bridge CFDataRef)dataA, (__bridge CFDictionaryRef)[NSDictionary dictionary]);
    CGImageRef imageRefA = CGImageSourceCreateImageAtIndex(imageSourceRefA, 0, (__bridge CFDictionaryRef)[NSDictionary dictionary]);
    CFRelease(imageSourceRefA);
    
    
    CGImageSourceRef imageSourceRefB = CGImageSourceCreateWithData((__bridge CFDataRef)dataB, (__bridge CFDictionaryRef)[NSDictionary dictionary]);
    CGImageRef imageRefB = CGImageSourceCreateImageAtIndex(imageSourceRefB, 0, (__bridge CFDictionaryRef)[NSDictionary dictionary]);
    CFRelease(imageSourceRefB);
    
    CGSize size         = CGSizeMake(CGImageGetWidth(imageRefA), CGImageGetHeight(imageRefA));
    CGContextRef ctxA   = FMPSDCGBitmapContextCreate(size, CGImageGetColorSpace(imageRefA));
    CGContextRef ctxB   = FMPSDCGBitmapContextCreate(size, CGImageGetColorSpace(imageRefB));
    
    CGContextDrawImage(ctxA, FMPSDCGImageGetRect(imageRefA), imageRefA);
    CGContextDrawImage(ctxB, FMPSDCGImageGetRect(imageRefB), imageRefB);
    
    BOOL bad = NO;
    
    if ((CGImageGetWidth(imageRefA) != CGImageGetWidth(imageRefB)) || (CGImageGetHeight(imageRefA) != CGImageGetHeight(imageRefB))) {
        NSLog(@"Sizes are wrong!");
        bad = YES;
        goto cleanup;
    }
    
    int x, y;
    
    for (x = 0; x < size.width; x++) {
        
        for (y = 0; y < size.height; y++) {
            FMPSDPixel a = FMPSDPixelForPointInContext(ctxA, CGPointMake(x, y));
            FMPSDPixel b = FMPSDPixelForPointInContext(ctxB, CGPointMake(x, y));
            
            int keyA = a.a;
            int keyR = a.r;
            int keyG = a.g;
            int keyB = a.b;
            
            int testA = b.a;
            int testR = b.r;
            int testG = b.g;
            int testB = b.b;
            
            
            if ((keyA == testA) && (keyA <= tolerance)) { // we're 100% transparent.  Dont' bother comparing the colors.
                continue;
            }
            
            
            //if ((keyA != testA) or (keyR != testR) or (keyG != testG) or (keyB != testB)) {
            if ((abs(keyA - testA) > tolerance) ||
                (abs(keyR - testR) > tolerance) ||
                (abs(keyG - testG) > tolerance) ||
                (abs(keyB - testB) > tolerance)) {
                NSLog(@"different pixel at: %d,%d tolerance is %d", x, y, tolerance);
                
                bad = YES;
                
                debug(@"A: %d %d (%d diff)", keyA, testA, abs(keyA - testA));
                debug(@"R: %d %d (%d diff)", keyR, testR, abs(keyR - testR));
                debug(@"G: %d %d (%d diff)", keyG, testG, abs(keyG - testG));
                debug(@"B: %d %d (%d diff)", keyB, testB, abs(keyB - testB));
                
                goto cleanup;
            }
        }
    }
    
    
cleanup:
    
    CGImageRelease(imageRefA);
    CGImageRelease(imageRefB);
    CGContextRelease(ctxA);
    CGContextRelease(ctxB);
    //CGColorSpaceRelease(linearCS);
    
    if (bad) {
        
#if !TARGET_OS_IPHONE
    	NSBeep();
        
        @try {
            system([[NSString stringWithFormat:@"/usr/local/bin/ksdiff %@ %@", [pathURL path], tempPath] UTF8String]);
        }
        @catch (NSException *exception) {
            NSLog(@"%@", exception);
        }
#endif
        
        
        debug(@"Compare failure!");
        
        return NO;
    }
    
    return YES;
}

@end

CGRect FMPSDCGImageGetRect(CGImageRef img) {
    if (!img) {
        return CGRectZero;
    }
    
    return CGRectMake(0, 0, CGImageGetWidth(img), CGImageGetHeight(img));
}


CGContextRef FMPSDCGBitmapContextCreate(CGSize size, CGColorSpaceRef cs) {
    
    FMAssert(cs);
    
    CGBitmapInfo options = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    CGContextRef context = CGBitmapContextCreate(0x00, size.width, size.height, 8, 0, cs, options);
    
    return context;
}

FMPSDPixel *FMPSDPixelAddressForPointInLocalContext(CGContextRef context, CGPoint p);
FMPSDPixel *FMPSDPixelAddressForPointInLocalContext(CGContextRef context, CGPoint p) {
    
    FMPSDPixel *basePtr   = CGBitmapContextGetData(context);
    
    if (!basePtr) {
        return 0;
    }
    
    
    size_t height     = CGBitmapContextGetHeight(context);
    size_t bpr        = CGBitmapContextGetBytesPerRow(context);
    size_t rwidth     = bpr / sizeof(FMPSDPixel);
    
    
    //debug(@"CGColorSpaceGetNumberOfComponents(cs): %d", CGColorSpaceGetNumberOfComponents(cs));
    
    size_t flipY      = height - p.y - 1;
    NSUInteger pt     = ((rwidth * flipY)) + p.x;
    
    return (FMPSDPixel *)(basePtr + pt);
}

FMPSDPixel FMPSDPixelForPointInContext(CGContextRef context, CGPoint point) {
    
    FMAssert(CGBitmapContextGetData(context));
    
    FMPSDPixel *p = FMPSDPixelAddressForPointInLocalContext(context, point);
    
    FMAssert(p);
    
    if (!p) {
        return (FMPSDPixel){0x00, 0x00, 0x00, 0x00};
    }
    
    return FMPSDUnPremultiply(*p);
    
}



void FMPSDDecodeRLE(char *src, int sindex, int slen, char *dst, int dindex) {
    
    int max = sindex + slen;
    
    while (sindex < max) {
        char b = src[sindex++];
        
        int n = (int) b;
        if (n < 0) {
            n = 1 - n;
            b = src[sindex++];
            for (int i = 0; i < n; i++) {
                dst[dindex++] = b;
            }
        }
        else {
            n = n + 1;
            
            // arraycopy(Object src, int srcPos, Object dest, int destPos, int length)
            // Copies an array from the specified source array, beginning at the specified position, to the specified position of the destination array
            // System.arraycopy(src, sindex, dst, dindex, n);
            //memcpy((void *)dst[dindex], (void *)src[sindex], n);
            
            for (int x = 0; x < n; x++) {
                dst[dindex + x] = src[sindex + x];
            }
            
            dindex += n;
            sindex += n;
        }
    }
}

NSString * FMPSDStringForHFSTypeCode(OSType hfsFileTypeCode) {
    
    return [NSString stringWithFormat:@"%c%c%c%c",
                (int) (hfsFileTypeCode >> 24) & 0xFF,
                (int) (hfsFileTypeCode >> 16) & 0xFF,
                (int) (hfsFileTypeCode >>  8) & 0xFF,
                (int) (hfsFileTypeCode      ) & 0xFF];
    
}

