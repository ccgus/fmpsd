//
//  FMPSDDescriptor+ColorOverlay.m
//  fmpsd
//
//  Created by August Mueller on 10/4/26.
//  Copyright 2026 Flying Meat Inc. All rights reserved.
//

#import "FMPSDDescriptor+ColorOverlay.h"
#import "FMPSD.h"

@implementation FMPSDDescriptor (ColorOverlay)

- (BOOL)colorOverlayEnabled {
    return [[[self attributes] objectForKey:@"enab"] boolValue];
}

- (uint32_t)colorOverlayBlendMode {
    NSString *modeString = [[self attributes] objectForKey:@"Md  "];
    return FMPSDBlendModeFromDescriptorString(modeString);
}

- (double)colorOverlayOpacity {
    
    CGFloat alpha = 1.0;
    if ([[self attributes] objectForKey:@"Opct"]) {
        alpha = [[[self attributes] objectForKey:@"Opct"] doubleValue];
    }
    
    return alpha;
    
}

- (CGColorRef)colorOverlayColor {
    FMPSDDescriptor *colorDesc = [[self attributes] objectForKey:@"Clr "];
    if (!colorDesc || ![colorDesc isKindOfClass:[FMPSDDescriptor class]]) {
        return NULL;
    }

    double r = [[[colorDesc attributes] objectForKey:@"Rd  "] doubleValue] / 255.0;
    double g = [[[colorDesc attributes] objectForKey:@"Grn "] doubleValue] / 255.0;
    double b = [[[colorDesc attributes] objectForKey:@"Bl  "] doubleValue] / 255.0;
    
    CGFloat components[] = { r, g, b, 1.0 };
    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGColorRef color = CGColorCreate(srgb, components);
    CGColorSpaceRelease(srgb);

    return (__bridge CGColorRef)CFBridgingRelease(color);
}

@end
