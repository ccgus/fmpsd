//
//  FMPSDDescriptor+ColorOverlay.h
//  fmpsd
//
//  Copyright 2026 Flying Meat Inc. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import "FMPSDDescriptor.h"

// Call these methods on the SoFi descriptor returned by FMPSDLayer's -colorOverlay.
@interface FMPSDDescriptor (ColorOverlay)

@property (nonatomic, readonly) BOOL colorOverlayEnabled;
@property (nonatomic, readonly) uint32_t colorOverlayBlendMode;
@property (nonatomic, readonly) double colorOverlayOpacity; // Percentage (0–100).
@property (nonatomic, readonly) CGColorRef colorOverlayColor;

@end
