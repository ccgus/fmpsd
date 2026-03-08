//
//  FMPSDDescriptor+DropShadow.h
//  fmpsd
//
//  Created by August Mueller on 3/7/26.
//  Copyright 2026 Flying Meat Inc. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import "FMPSDDescriptor.h"

// Category on FMPSDDescriptor for accessing drop shadow properties.
// These methods are intended to be called on a DrSh descriptor obtained
// from FMPSDLayer's -dropShadow method.

@interface FMPSDDescriptor (DropShadow)

@property (nonatomic, readonly) BOOL dropShadowEnabled;
@property (nonatomic, readonly) uint32_t dropShadowBlendMode;
@property (nonatomic, readonly) double dropShadowOpacity;
@property (nonatomic, readonly) BOOL dropShadowUsesGlobalLight;
@property (nonatomic, readonly) double dropShadowAngle; // Uses global light angle when dropShadowUsesGlobalLight is YES.
@property (nonatomic, readonly) double dropShadowDistance;
@property (nonatomic, readonly) double dropShadowSpread;
@property (nonatomic, readonly) double dropShadowSize;
@property (nonatomic, readonly) CGColorRef dropShadowColor;

@end
