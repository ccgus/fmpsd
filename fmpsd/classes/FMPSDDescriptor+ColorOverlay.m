//
//  FMPSDDescriptor+ColorOverlay.m
//  fmpsd
//
//  Created by August Mueller on 10/4/26.
//  Copyright 2026 Flying Meat Inc. All rights reserved.
//

#import "FMPSDDescriptor+ColorOverlay.h"
#import "FMPSD.h"

// Photoshop blend mode enum values to four-char codes used elsewhere in fmpsd.
static uint32_t FMPSDBlendModeFromDescriptorString(NSString *string) {
    if (!string) {
        return 'norm';
    }

    if ([string isEqualToString:@"Nrml"]) { return 'norm'; }
    if ([string isEqualToString:@"Dslv"]) { return 'diss'; }
    if ([string isEqualToString:@"Drkn"]) { return 'dark'; }
    if ([string isEqualToString:@"Mltp"]) { return 'mul '; }
    if ([string isEqualToString:@"CBrn"]) { return 'idiv'; }
    if ([string isEqualToString:@"linearBurn"]) { return 'lbrn'; }
    if ([string isEqualToString:@"Lghn"]) { return 'lite'; }
    if ([string isEqualToString:@"Scrn"]) { return 'scrn'; }
    if ([string isEqualToString:@"CDdg"]) { return 'div '; }
    if ([string isEqualToString:@"linearDodge"]) { return 'lddg'; }
    if ([string isEqualToString:@"Ovrl"]) { return 'over'; }
    if ([string isEqualToString:@"SftL"]) { return 'sLit'; }
    if ([string isEqualToString:@"HrdL"]) { return 'hLit'; }
    if ([string isEqualToString:@"VvdL"]) { return 'vLit'; }
    if ([string isEqualToString:@"LnrL"]) { return 'lLit'; }
    if ([string isEqualToString:@"PnLt"]) { return 'pLit'; }
    if ([string isEqualToString:@"HrdM"]) { return 'hMix'; }
    if ([string isEqualToString:@"Dfrn"]) { return 'diff'; }
    if ([string isEqualToString:@"Xclu"]) { return 'smud'; }
    if ([string isEqualToString:@"H   "]) { return 'hue '; }
    if ([string isEqualToString:@"Strt"]) { return 'sat '; }
    if ([string isEqualToString:@"Clr "]) { return 'colr'; }
    if ([string isEqualToString:@"Lmns"]) { return 'lum '; }

    return 'norm';
}

@implementation FMPSDDescriptor (ColorOverlay)

- (BOOL)colorOverlayEnabled {
    return [[[self attributes] objectForKey:@"enab"] boolValue];
}

- (uint32_t)colorOverlayBlendMode {
    NSString *modeString = [[self attributes] objectForKey:@"Md  "];
    return FMPSDBlendModeFromDescriptorString(modeString);
}

- (double)colorOverlayOpacity {
    return [[[self attributes] objectForKey:@"Opct"] doubleValue];
}

- (CGColorRef)colorOverlayColor {
    FMPSDDescriptor *colorDesc = [[self attributes] objectForKey:@"Clr "];
    if (!colorDesc || ![colorDesc isKindOfClass:[FMPSDDescriptor class]]) {
        return NULL;
    }

    double r = [[[colorDesc attributes] objectForKey:@"Rd  "] doubleValue] / 255.0;
    double g = [[[colorDesc attributes] objectForKey:@"Grn "] doubleValue] / 255.0;
    double b = [[[colorDesc attributes] objectForKey:@"Bl  "] doubleValue] / 255.0;
    
    CGFloat alpha = 1.0;
    if ([[self attributes] objectForKey:@"Opct"]) {
        alpha = [[[self attributes] objectForKey:@"Opct"] doubleValue] / 100.0;
    }
    
    CGFloat components[] = { r, g, b, alpha };
    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGColorRef color = CGColorCreate(srgb, components);
    CGColorSpaceRelease(srgb);

    return (__bridge CGColorRef)CFBridgingRelease(color);
}

@end
