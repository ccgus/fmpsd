//
//  FMPSDCIFilters.h
//  fmpsd
//
//  Created by August Mueller on 10/26/10.
//  Copyright 2010 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#import <QuartzCore/QuartzCore.h>

@interface FMPSDAlphaFilter : CIFilter {
    CIImage *_inputImage;
    NSNumber *_alpha;
}

@property (retain) CIImage *inputImage;
@property (retain) NSNumber *alpha;

@end
