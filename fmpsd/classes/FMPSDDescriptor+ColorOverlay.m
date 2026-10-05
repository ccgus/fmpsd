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

    if ([string isEqualToString:@"Nrml"] || [string isEqualToString:@"normal"]) { return 'norm'; }
    if ([string isEqualToString:@"Dslv"] || [string isEqualToString:@"dissolve"]) { return 'diss'; }
    if ([string isEqualToString:@"Drkn"] || [string isEqualToString:@"darken"]) { return 'dark'; }
    if ([string isEqualToString:@"Mltp"] || [string isEqualToString:@"multiply"]) { return 'mul '; }
    if ([string isEqualToString:@"CBrn"] || [string isEqualToString:@"colorBurn"]) { return 'idiv'; }
    if ([string isEqualToString:@"linearBurn"]) { return 'lbrn'; }
    if ([string isEqualToString:@"Lghn"] || [string isEqualToString:@"lighten"]) { return 'lite'; }
    if ([string isEqualToString:@"Scrn"] || [string isEqualToString:@"screen"]) { return 'scrn'; }
    if ([string isEqualToString:@"CDdg"] || [string isEqualToString:@"colorDodge"]) { return 'div '; }
    if ([string isEqualToString:@"linearDodge"]) { return 'lddg'; }
    if ([string isEqualToString:@"Ovrl"] || [string isEqualToString:@"overlay"]) { return 'over'; }
    if ([string isEqualToString:@"SftL"] || [string isEqualToString:@"softLight"]) { return 'sLit'; }
    if ([string isEqualToString:@"HrdL"] || [string isEqualToString:@"hardLight"]) { return 'hLit'; }
    if ([string isEqualToString:@"VvdL"] || [string isEqualToString:@"vividLight"]) { return 'vLit'; }
    if ([string isEqualToString:@"LnrL"] || [string isEqualToString:@"linearLight"]) { return 'lLit'; }
    if ([string isEqualToString:@"PnLt"] || [string isEqualToString:@"pinLight"]) { return 'pLit'; }
    if ([string isEqualToString:@"HrdM"] || [string isEqualToString:@"hardMix"]) { return 'hMix'; }
    if ([string isEqualToString:@"Dfrn"] || [string isEqualToString:@"difference"]) { return 'diff'; }
    if ([string isEqualToString:@"Xclu"] || [string isEqualToString:@"exclusion"]) { return 'smud'; }
    if ([string isEqualToString:@"H   "] || [string isEqualToString:@"hue"]) { return 'hue '; }
    if ([string isEqualToString:@"Strt"] || [string isEqualToString:@"saturation"]) { return 'sat '; }
    if ([string isEqualToString:@"Clr "] || [string isEqualToString:@"color"]) { return 'colr'; }
    if ([string isEqualToString:@"Lmns"] || [string isEqualToString:@"luminosity"]) { return 'lum '; }

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
