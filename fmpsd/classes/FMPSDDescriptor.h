//
//  FMPSDDescriptor.h
//  fmpsd
//
//  Created by August Mueller on 10/27/10.
//  Copyright 2010 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FMPSDStream.h"

@class FMPSD;
@interface FMPSDDescriptor : NSObject {
    
}

@property (weak) FMPSD *psd;
@property (strong) NSMutableDictionary *attributes;

+ (id)descriptorWithStream:(FMPSDStream*)stream psd:(FMPSD*)psd;

@end
