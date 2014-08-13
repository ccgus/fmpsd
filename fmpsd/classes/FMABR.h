//
//  FMABR.h
//  fmpsd
//
//  Created by August Mueller on 8/8/14.
//  Copyright (c) 2014 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FMPSDDescriptor;

@interface FMABR : NSObject

@property (strong) NSMutableArray *brushes;

+ (id)brushesWithContetsOfURL:(NSURL*)fileURL error:(NSError**)err printDebugInfo:(BOOL)debugInfo;

@end


@interface FMPSBrush : NSObject

@property (assign) CGImageRef image;
@property (assign) CGRect bounds;
@property (strong) NSString *name;
@property (strong) NSString *sampledDataID;
@property (strong) FMPSDDescriptor *descriptor;
@property (assign) CGFloat angle;
@property (assign) CGFloat spacing;
@property (assign) CGFloat diameter;
@property (assign) CGFloat roundness;
@property (assign) CGFloat hardness;
@property (assign) BOOL computed;
@end


