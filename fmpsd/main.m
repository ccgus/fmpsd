//
//  main.m
//  fmpsd
//
//  Created by August Mueller on 6/19/13.
//  Copyright (c) 2013 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMPSD.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        
        if (argc != 2) {
            printf("Usage: fmpsd somepsdfile.psd\n");
            exit(1);
        }
        
        NSString *path = [NSString stringWithUTF8String:argv[1]];
        
        NSError *err = nil;
        FMPSD *psd = [FMPSD imageWithContetsOfURL:[NSURL fileURLWithPath:path] error:&err];
        
        if (!psd) {
            NSLog(@"Error loading PSD: %@", err);
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
    
    return 0;
}

