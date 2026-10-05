//
//  FMPSDDescriptor+DropShadow.m
//  fmpsd
//
//  Created by August Mueller on 3/7/26.
//  Copyright 2026 Flying Meat Inc. All rights reserved.
//

#import "FMPSDDescriptor+DropShadow.h"
#import "FMPSD.h"

@implementation FMPSDDescriptor (DropShadow)

- (BOOL)dropShadowEnabled {
    return [[[self attributes] objectForKey:@"enab"] boolValue];
}

- (uint32_t)dropShadowBlendMode {
    NSString *modeString = [[self attributes] objectForKey:@"Md  "];
    return FMPSDBlendModeFromDescriptorString(modeString);
}

- (double)dropShadowOpacity {
    return [[[self attributes] objectForKey:@"Opct"] doubleValue];
}

- (BOOL)dropShadowUsesGlobalLight {
    return [[[self attributes] objectForKey:@"uglg"] boolValue];
}

- (double)dropShadowAngle {
    if ([self dropShadowUsesGlobalLight] && [self psd]) {
        return [[self psd] globalLightAngle];
    }
    return [[[self attributes] objectForKey:@"lagl"] doubleValue];
}

- (double)dropShadowDistance {
    return [[[self attributes] objectForKey:@"Dstn"] doubleValue];
}

- (double)dropShadowSpread {
    return [[[self attributes] objectForKey:@"Ckmt"] doubleValue];
}

- (double)dropShadowSize {
    return [[[self attributes] objectForKey:@"blur"] doubleValue];
}

- (CGColorRef)dropShadowColor {
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
