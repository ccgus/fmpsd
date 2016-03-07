//
//  FMPSDCIFilters.m
//  fmpsd
//
//  Created by August Mueller on 10/26/10.
//  Copyright 2010 Flying Meat Inc. All rights reserved.
//

#import "FMPSDCIFilters.h"

static CIKernel *FMPSDAlphaFilterKernel = nil;

@implementation FMPSDAlphaFilter

+ (CIFilter *)filterWithName:(NSString *)name {
    return [[self alloc] init];
}

- (id)init {
    if (FMPSDAlphaFilterKernel == nil) {
        
        NSString *code = @"\
                          kernel vec4 alf(sampler src, float a) {\n\
                          vec4 result = unpremultiply(sample(src, samplerCoord(src)));\n\
                          result.a = result.a * a;\n\
                          return premultiply(result);\n\
                          }";
        
        NSArray *kernels = [CIKernel kernelsWithString:code];
        
        FMPSDAlphaFilterKernel = [kernels objectAtIndex:0];
    }    
    return [super init];
}

- (NSArray *)inputKeys {
    return [NSArray arrayWithObjects:@"inputImage", @"alpha", nil];
}

- (NSDictionary *)customAttributes {
    return [NSDictionary dictionary];
}

- (CIImage *)outputImage {
#if TARGET_OS_IPHONE    
        // FYI: this API also is available on 10.11 and later on Mac OS X
    return [FMPSDAlphaFilterKernel applyWithExtent:_inputImage.extent
                                       roiCallback:^CGRect(int index, CGRect destRect) { return destRect; }
                                         arguments:@[_inputImage, _alpha]];
#else
    CISampler *src = [CISampler samplerWithImage:_inputImage];
    
    return [self apply:FMPSDAlphaFilterKernel, src, _alpha, nil];
#endif
}


@end
