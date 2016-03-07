//
//  main.m
//  fmpsd
//
//  Created by August Mueller on 6/19/13.
//  Copyright (c) 2013 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AppKit/NSWorkspace.h>
#import "FMPSD.h"


void splitPSDFile(NSString *path) {
    
    NSError *err = nil;
    FMPSD *psd = [FMPSD imageWithContetsOfURL:[NSURL fileURLWithPath:path] error:&err];
    
    if (!psd) {
        NSLog(@"Error loading PSD: %@", err);
        return;
    }
    
    for (FMPSDLayer *l in [[psd baseLayerGroup] layers]) {
        
        CGImageRef r = [l image];
        if (!r) {
            continue;
        }
        
        NSLog(@"%@", l);
        
        NSString *layerPath = [NSString stringWithFormat:@"%@-%@.png", path, [l layerName]];
        
        CGImageDestinationRef imageDestination = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:layerPath], kUTTypePNG, 1, NULL);
        CGImageDestinationAddImage(imageDestination, r, (__bridge CFDictionaryRef)[NSDictionary dictionary]);
        CGImageDestinationFinalize(imageDestination);
        CFRelease(imageDestination);
    }
}

void makeComposite(NSString *path) {
    
    NSError *err = nil;
    FMPSD *psd = [FMPSD imageWithContetsOfURL:[NSURL fileURLWithPath:path] error:&err];
    
    if (!psd) {
        NSLog(@"Error loading PSD: %@", err);
        return;
    }
    
    CIImage *comp = [[psd baseLayerGroup] CIImageForComposite];
    
    CGColorSpaceRef releaseMeCS = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    
    CGBitmapInfo options = (CGBitmapInfo)kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    
    size_t bytesPerRow = 0; // let them figure it out
    
    CGContextRef cgcontext = CGBitmapContextCreate(0x00, [psd width], [psd height], 8, bytesPerRow, releaseMeCS, options);
    
    CGColorSpaceRelease(releaseMeCS);
    
    CIContext *context = [CIContext contextWithCGContext:cgcontext options:nil];
    
    CGRect r = CGRectMake(0, 0, [psd width], [psd height]);
    
    [context drawImage:comp inRect:r fromRect:r];
    
    NSString *outImagePath = [[NSTemporaryDirectory() stringByAppendingPathComponent:[path lastPathComponent]] stringByAppendingString:@"-comp.png"];
    
    CGImageRef image = CGBitmapContextCreateImage(cgcontext);
    
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:outImagePath], kUTTypePNG, 1, NULL);
    CGImageDestinationAddImage(imageDestination, image, (__bridge CFDictionaryRef)[NSDictionary dictionary]);
    CGImageDestinationFinalize(imageDestination);
    CFRelease(imageDestination);
    
    CGImageRelease(image);
    
    [[NSWorkspace sharedWorkspace] openFile:outImagePath];
    
}

void printUsage(void) {
    
    printf("Usage: fmpsd [-sc] source_file.psd\n");
    printf("       -s splits out the layers as PNG\n");
    printf("       -c reads in the layers, generates a composite, and opens the result up.\n");
}

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        if (argc < 3) {
            printUsage();
            exit(1);
        }
        
        NSString *cmd  = [NSString stringWithUTF8String:argv[1]];
        
        if ([cmd isEqualToString:@"-s"]) {
            splitPSDFile([NSString stringWithUTF8String:argv[2]]);
        }
        else if ([cmd isEqualToString:@"-c"]) {
            makeComposite([NSString stringWithUTF8String:argv[2]]);
        }
        else {
            printf("Unknown command: %s\n", [cmd UTF8String]);
            printUsage();
            exit(2);
        }
        
    }
    
    return 0;
}

