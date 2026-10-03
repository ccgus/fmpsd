//
//  fmpsdTests.m
//  fmpsdTests
//
//  Created by August Mueller on 10/3/26.
//  Copyright © 2026 Flying Meat Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FMPSD.h"

@import XCTest;



@interface FMPSDTests : XCTestCase

@end


NSURL *FMPSDTestImageNamed(NSString *relativePathName) {
    
    NSString *sourceFilePath = [NSString stringWithUTF8String:__FILE__];
    NSString *sourceDirectory = [sourceFilePath stringByDeletingLastPathComponent];
    NSString *imagesDirectory = [sourceDirectory stringByAppendingPathComponent:@"images"];
    NSString *imagePath       = [imagesDirectory stringByAppendingPathComponent:relativePathName];
    
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:imagePath]);
    
    NSURL *imageURL = [NSURL fileURLWithPath:imagePath isDirectory:NO];
    
    
    debug(@"imageURL: '%@'", imageURL);
    
    return imageURL;
}


@implementation FMPSDTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testPreviewMade {
    
    NSURL *u = FMPSDTestImageNamed(@"preview_made.psd");
    
    NSError  *err = nil;
    FMPSD *psd = [FMPSD imageWithContentsOfURL:u error:&err printDebugInfo:false];
    XCTAssertNotNil(psd);
    
    
    XCTAssert(psd.channels == 4, "Wrong number of channels, got %d", psd.channels);
    XCTAssert(psd.depth == 8, "depth is wrong, got %d", psd.depth);
    XCTAssert(psd.colorMode == FMPSDRGBMode, "wrong color mode %d", psd.colorMode);
    XCTAssert(psd.width == 256, "wrong width got %d", psd.width);
    XCTAssert(psd.height == 256, "wrong height got %d", psd.height);
    XCTAssert(psd.version == 1, "wrong version got %d", psd.version);
    XCTAssert([[[psd baseLayerGroup] layers] count] == 1, "wrong layer count got %ld", [[[psd baseLayerGroup] layers] count]);
    
    
}

- (void)testEmptyPSD {
    
    NSURL *u = FMPSDTestImageNamed(@"Empty.psd");
    
    NSError  *err = nil;
    FMPSD *psd = [FMPSD imageWithContentsOfURL:u error:&err printDebugInfo:false];
    
    XCTAssertNil(psd);
    XCTAssertNotNil(err);
}

- (void)test16BPCImport {
    
    NSURL *u = FMPSDTestImageNamed(@"testoP316bpc.psd");
    
    NSError  *err;
    FMPSD *psd = [FMPSD imageWithContentsOfURL:u error:&err printDebugInfo:false];
    
    XCTAssertNotNil(psd);
    
    XCTAssert([psd depth] == 16);
    XCTAssert([[[psd baseLayerGroup] layers] count] == 2);
    
}

/*
- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}*/

@end
