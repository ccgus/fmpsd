//
//  fmpsdTests.m
//  fmpsdTests
//
//  Created by August Mueller on 10/3/26.
//  Copyright © 2026 Flying Meat Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FMPSD.h"
#import "FMPSDUtils.h"
#import "FMPSDTextEngineParser.h"
#import <ImageIO/ImageIO.h>

@import XCTest;



@interface FMPSDTests : XCTestCase

@property (strong) NSURL *temporaryDirectory;

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
    if (self.temporaryDirectory) {
        NSError *error = nil;
        XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:self.temporaryDirectory error:&error], @"%@", error);
        self.temporaryDirectory = nil;
    }
    [super tearDown];
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
    
    NSError  *err = nil;
    FMPSD *psd = [FMPSD imageWithContentsOfURL:u error:&err printDebugInfo:false];
    
    XCTAssertNotNil(psd);
    
    XCTAssert([psd depth] == 16);
    XCTAssert([[[psd baseLayerGroup] layers] count] == 2);
    
}


- (NSURL *)roundTripURL {
    if (!self.temporaryDirectory) {
        self.temporaryDirectory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
        NSError *error = nil;
        XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtURL:self.temporaryDirectory withIntermediateDirectories:YES attributes:nil error:&error], @"%@", error);
    }
    return [self.temporaryDirectory URLByAppendingPathComponent:@"roundtrip.psd"];
}

- (FMPSD *)readPSDAtURL:(NSURL *)url {
    NSError *error = nil;
    FMPSD *psd = [FMPSD imageWithContentsOfURL:url error:&error printDebugInfo:YES];
    XCTAssertNotNil(psd, @"Could not read %@: %@", url.lastPathComponent, error);
    XCTAssertNil(error, @"%@", error);
    return psd;
}

// Equivalent to the scripts' FMPSDUtils comparison, without temporary TIFFs or launching ksdiff.
- (void)assertComposite:(FMPSD *)psd matchesURL:(NSURL *)url tolerance:(int)tolerance {
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    CGImageRef reference = source ? CGImageSourceCreateImageAtIndex(source, 0, NULL) : NULL;
    if (source) {
        CFRelease(source);
    }
    if (!reference) {
        // acornsetup.js also excludes PSD composite decoding on macOS 15.7 and 15.8.
        NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
        if (version.majorVersion == 15 && (version.minorVersion == 7 || version.minorVersion == 8)) {
            return;
        }
        XCTFail(@"ImageIO could not decode reference %@", url.lastPathComponent);
        return;
    }
    XCTAssertEqual(CGImageGetWidth(reference), psd.width);
    XCTAssertEqual(CGImageGetHeight(reference), psd.height);
    CGRect bounds = CGRectMake(0, 0, psd.width, psd.height);
    CGContextRef actualContext = FMPSDCGBitmapContextCreate(bounds.size, psd.colorSpace);
    CGContextRef referenceContext = FMPSDCGBitmapContextCreate(bounds.size, psd.colorSpace);
    if (!actualContext || !referenceContext) {
        XCTFail(@"Could not create comparison contexts");
        if (actualContext) CGContextRelease(actualContext);
        if (referenceContext) CGContextRelease(referenceContext);
        CGImageRelease(reference);
        return;
    }
    CIContext *context = [CIContext contextWithCGContext:actualContext options:@{kCIContextOutputColorSpace: (__bridge id)psd.colorSpace}];
    [context drawImage:psd.compositeCIImage inRect:bounds fromRect:bounds];
    CGContextDrawImage(referenceContext, bounds, reference);
    BOOL matches = YES;
    for (NSUInteger y = 0; y < psd.height && matches; y++) {
        for (NSUInteger x = 0; x < psd.width; x++) {
            FMPSDPixel actual = FMPSDPixelForPointInContext(actualContext, CGPointMake(x, y));
            FMPSDPixel expected = FMPSDPixelForPointInContext(referenceContext, CGPointMake(x, y));
            if (actual.a == expected.a && actual.a <= tolerance) {
                continue;
            }
            if (abs(actual.a - expected.a) > tolerance || abs(actual.r - expected.r) > tolerance ||
                abs(actual.g - expected.g) > tolerance || abs(actual.b - expected.b) > tolerance) {
                XCTFail(@"%@ differs at (%lu, %lu): RGBA (%u, %u, %u, %u), expected (%u, %u, %u, %u), tolerance %d",
                        url.lastPathComponent, (unsigned long)x, (unsigned long)y,
                        actual.r, actual.g, actual.b, actual.a, expected.r, expected.g, expected.b, expected.a, tolerance);
                matches = NO;
                break;
            }
        }
    }
    CGContextRelease(actualContext);
    CGContextRelease(referenceContext);
    CGImageRelease(reference);
}

// Ported from acorn8/tests/scripts/testPSDAcornIconUnlinked.js.
- (void)testPSDAcornIconUnlinked {
    NSURL *imageURL = FMPSDTestImageNamed(@"AcornIcon-unlinked.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    if (!psd) return;
    XCTAssertEqual([psd channels], 4);
    XCTAssertEqual([psd depth], 8);
    XCTAssertEqual([psd colorMode], FMPSDRGBMode);
    XCTAssertEqual([psd width], 256);
    XCTAssertEqual([psd height], 256);
    XCTAssertEqual([psd version], 1);
    XCTAssertTrue([[psd baseLayerGroup] layers]);
    XCTAssertEqual([[[psd baseLayerGroup] layers] count], 1);
    if ([[[psd baseLayerGroup] layers] count] != 1) return;
    FMPSDLayer *layer1 = [[[psd baseLayerGroup] layers] objectAtIndex:0];
    XCTAssertEqualObjects([layer1 layerName], @"Layer 0");
    XCTAssertEqual([layer1 channels], 5);
    XCTAssertTrue([layer1 mask]);
    XCTAssertEqual([layer1 width], 171);
    XCTAssertEqual([layer1 height], 113);
    XCTAssertEqual([layer1 maskFrame].size.width, 174);
    XCTAssertEqual([layer1 maskFrame].size.height, 127);
    [self assertComposite:psd matchesURL:imageURL tolerance:0];
}

// Ported from acorn8/tests/scripts/testPSDCircles-cs4.js.
- (void)testPSDCirclescs4 {
    NSURL *imageURL = FMPSDTestImageNamed(@"circles-cs4.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    if (!psd) return;
    XCTAssertEqual([psd channels], 3);
    XCTAssertEqual([psd depth], 8);
    XCTAssertEqual([psd colorMode], FMPSDRGBMode);
    XCTAssertEqual([psd width], 400);
    XCTAssertEqual([psd height], 400);
    XCTAssertEqual([psd version], 1);
    XCTAssertTrue([[psd baseLayerGroup] layers]);
    XCTAssertEqual([[[psd baseLayerGroup] layers] count], 2);
    if ([[[psd baseLayerGroup] layers] count] != 2) return;
    FMPSDLayer *layer1 = [[[psd baseLayerGroup] layers] objectAtIndex:1];
    XCTAssertEqualObjects([layer1 layerName], @"Layer 1");
    XCTAssertEqual([layer1 width], 400);
    XCTAssertEqual([layer1 height], 400);
    FMPSDLayer *layer2 = [[[psd baseLayerGroup] layers] objectAtIndex:0];
    XCTAssertEqualObjects([layer2 layerName], @"Layer 2");
    XCTAssertEqual([layer2 width], 168);
    XCTAssertEqual([layer2 height], 101);
    XCTAssertEqual([layer2 left], 123);
    XCTAssertEqual([layer2 top], 148);
    XCTAssertNotNil([psd compositeCIImage]);
    [self assertComposite:psd matchesURL:imageURL tolerance:10];
    NSURL *outURL = [self roundTripURL];
    [psd writeToFile:outURL];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:outURL.path]);
    FMPSD *psd2 = [self readPSDAtURL:outURL];
    if (!psd2) return;
    XCTAssertEqual([[[psd2 baseLayerGroup] layers] count], 2);
    if ([[[psd2 baseLayerGroup] layers] count] != 2) return;
}

// Ported from acorn8/tests/scripts/testPSDFugueScriptTest.js.
- (void)testPSDFugueScriptTest {
    NSURL *imageURL = FMPSDTestImageNamed(@"fugue-script-1.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    if (!psd) return;
    XCTAssertEqual([psd channels], 3);
    XCTAssertEqual([psd depth], 8);
    XCTAssertEqual([psd colorMode], FMPSDRGBMode);
    XCTAssertEqual([psd width], 52);
    XCTAssertEqual([psd height], 262);
    XCTAssertEqual([psd version], 1);
    XCTAssertTrue([[psd baseLayerGroup] layers]);
    XCTAssertEqual([[[psd baseLayerGroup] layers] count], 3);
    if ([[[psd baseLayerGroup] layers] count] != 3) return;
    FMPSDLayer *layer1 = [[[psd baseLayerGroup] layers] objectAtIndex:0];
    FMPSDLayer *layer2 = [[[psd baseLayerGroup] layers] objectAtIndex:1];
    FMPSDLayer *layer3 = [[[psd baseLayerGroup] layers] objectAtIndex:2];
    XCTAssertEqualObjects([layer1 layerName], @"copy1");
    XCTAssertEqualObjects([layer2 layerName], @"script");
    XCTAssertEqual([layer1 channels], 4);
    XCTAssertEqual([layer2 channels], 4);
    XCTAssertEqual([layer1 width], 18);
    XCTAssertEqual([layer1 height], 182);
    XCTAssertEqual([layer3 width], 52);
    XCTAssertEqual([layer3 height], 262);
}

// Ported from acorn8/tests/scripts/testPSDGreenblackTest.js.
- (void)testPSDGreenblackTest {
    NSURL *imageURL = FMPSDTestImageNamed(@"greenblack.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    if (!psd) return;
    XCTAssertEqual([psd channels], 3);
    XCTAssertEqual([psd depth], 8);
    XCTAssertEqual([psd colorMode], FMPSDRGBMode);
    XCTAssertEqual([psd width], 100);
    XCTAssertEqual([psd height], 100);
    XCTAssertEqual([psd version], 1);
    XCTAssertTrue([[psd baseLayerGroup] layers]);
    XCTAssertEqual([[[psd baseLayerGroup] layers] count], 3);
    if ([[[psd baseLayerGroup] layers] count] != 3) return;
    FMPSDLayer *layer1 = [[[psd baseLayerGroup] layers] objectAtIndex:2];
    FMPSDLayer *layer2 = [[[psd baseLayerGroup] layers] objectAtIndex:1];
    XCTAssertEqualObjects([layer1 layerName], @"Background");
    XCTAssertEqualObjects([layer2 layerName], @"Layer one, fool.");
    XCTAssertEqual([layer1 channels], 3);
    XCTAssertEqual([layer2 channels], 4);
    XCTAssertEqual([layer1 width], 100);
    XCTAssertEqual([layer1 height], 100);
    XCTAssertEqual([layer2 width], 76);
    XCTAssertEqual([layer2 height], 52);
    [self assertComposite:psd matchesURL:imageURL tolerance:1];
    NSURL *outURL = [self roundTripURL];
    [psd writeToFile:outURL];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:outURL.path]);
    [self assertComposite:psd matchesURL:outURL tolerance:40];
    FMPSD *psd2 = [self readPSDAtURL:outURL];
    if (!psd2) return;
    XCTAssertEqual([psd2 channels], 4);
    XCTAssertEqual([[[psd2 baseLayerGroup] layers] count], 3);
    if ([[[psd2 baseLayerGroup] layers] count] != 3) return;
}

// Ported from acorn8/tests/scripts/testPSDGreenblackflatTest.js.
- (void)testPSDGreenblackflatTest {
    NSURL *imageURL = FMPSDTestImageNamed(@"greenblackflat.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    
    if (!psd) return;
    XCTAssertEqual([psd channels], 3);
    XCTAssertEqual([psd depth], 8);
    XCTAssertEqual([psd colorMode], FMPSDRGBMode);
    XCTAssertEqual([psd width], 100);
    XCTAssertEqual([psd height], 100);
    XCTAssertEqual([psd version], 1);
    XCTAssertTrue([[psd baseLayerGroup] layers]);
    XCTAssertEqual([[[psd baseLayerGroup] layers] count], 1);
    if ([[[psd baseLayerGroup] layers] count] != 1) return;
    FMPSDLayer *layer1 = [[[psd baseLayerGroup] layers] objectAtIndex:0];
    XCTAssertEqualObjects([layer1 layerName], @"Background");
    XCTAssertEqual([layer1 channels], 3);
    XCTAssertEqual([layer1 width], 100);
    XCTAssertEqual([layer1 height], 100);
    [self assertComposite:psd matchesURL:imageURL tolerance:0];
    NSURL *outURL = [self roundTripURL];
    [psd writeToFile:outURL];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:outURL.path]);
}

// Ported from acorn8/tests/scripts/testPSDOddWidthTest.js.
- (void)testPSDOddWidthTest {
    NSURL *imageURL = FMPSDTestImageNamed(@"2layer-101width.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    if (!psd) return;
    XCTAssertEqual([psd channels], 3);
    XCTAssertEqual([psd depth], 8);
    XCTAssertEqual([psd colorMode], FMPSDRGBMode);
    XCTAssertEqual([psd width], 101);
    XCTAssertEqual([psd height], 101);
    XCTAssertEqual([psd version], 1);
    XCTAssertTrue([[psd baseLayerGroup] layers]);
    XCTAssertEqual([[[psd baseLayerGroup] layers] count], 2);
    if ([[[psd baseLayerGroup] layers] count] != 2) return;
    FMPSDLayer *layer1 = [[[psd baseLayerGroup] layers] objectAtIndex:1];
    FMPSDLayer *layer2 = [[[psd baseLayerGroup] layers] objectAtIndex:0];
    XCTAssertEqual([layer1 channels], 4);
    XCTAssertEqual([layer2 channels], 4);
    XCTAssertEqual([layer1 width], 101);
    XCTAssertEqual([layer1 height], 101);
    XCTAssertEqual([layer2 width], 52);
    XCTAssertEqual([layer2 height], 47);
    [self assertComposite:psd matchesURL:imageURL tolerance:0];
    NSURL *outURL = [self roundTripURL];
    [psd writeToFile:outURL];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:outURL.path]);
    [self assertComposite:psd matchesURL:outURL tolerance:40];
    FMPSD *psd2 = [self readPSDAtURL:outURL];
    if (!psd2) return;
    XCTAssertEqual([psd2 channels], 4);
    XCTAssertEqual([[[psd2 baseLayerGroup] layers] count], 2);
    if ([[[psd2 baseLayerGroup] layers] count] != 2) return;
}

// Ported from acorn8/tests/scripts/testPSDOddWidthTest2.js.
- (void)testPSDOddWidthTest2 {
    NSURL *imageURL = FMPSDTestImageNamed(@"2layer-101width2.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    if (!psd) return;
    XCTAssertEqual([psd channels], 4);
    XCTAssertEqual([psd depth], 8);
    XCTAssertEqual([psd colorMode], FMPSDRGBMode);
    XCTAssertEqual([psd width], 215);
    XCTAssertEqual([psd height], 3);
    XCTAssertEqual([psd version], 1);
    XCTAssertTrue([[psd baseLayerGroup] layers]);
    XCTAssertEqual([[[psd baseLayerGroup] layers] count], 2);
    if ([[[psd baseLayerGroup] layers] count] != 2) return;
    FMPSDLayer *layer1 = [[[psd baseLayerGroup] layers] objectAtIndex:1];
    FMPSDLayer *layer2 = [[[psd baseLayerGroup] layers] objectAtIndex:0];
    XCTAssertEqual([layer1 channels], 4);
    XCTAssertEqual([layer2 channels], 4);
    XCTAssertEqual([layer1 width], 101);
    XCTAssertEqual([layer1 height], 101);
    XCTAssertEqual([layer2 width], 52);
    XCTAssertEqual([layer2 height], 47);
    [self assertComposite:psd matchesURL:imageURL tolerance:1];
    NSURL *outURL = [self roundTripURL];
    [psd writeToFile:outURL];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:outURL.path]);
    FMPSD *psd2 = [self readPSDAtURL:outURL];
    if (!psd2) return;
    XCTAssertEqual([psd2 channels], 4);
    XCTAssertEqual([[[psd2 baseLayerGroup] layers] count], 2);
    if ([[[psd2 baseLayerGroup] layers] count] != 2) return;
    [self assertComposite:psd matchesURL:outURL tolerance:37];
}

// Ported from acorn8/tests/scripts/testPSDOffsetsTest.js.
- (void)testPSDOffsetsTest {
    NSURL *imageURL = FMPSDTestImageNamed(@"offsets.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    if (!psd) return;
    XCTAssertEqual([psd channels], 4);
    XCTAssertEqual([psd depth], 8);
    XCTAssertEqual([psd colorMode], FMPSDRGBMode);
    XCTAssertEqual([psd width], 100);
    XCTAssertEqual([psd height], 100);
    XCTAssertEqual([psd version], 1);
    XCTAssertTrue([[psd baseLayerGroup] layers]);
    XCTAssertEqual([[[psd baseLayerGroup] layers] count], 3);
    if ([[[psd baseLayerGroup] layers] count] != 3) return;
    XCTAssertNotNil([psd compositeCIImage]);
}

// Ported from acorn8/tests/scripts/testPSDRed-100x100Test.js.
- (void)testPSDRed100x100Test {
    NSURL *imageURL = FMPSDTestImageNamed(@"red-100x100.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    if (!psd) return;
    XCTAssertEqual([psd channels], 4);
    XCTAssertEqual([psd depth], 8);
    XCTAssertEqual([psd colorMode], FMPSDRGBMode);
    XCTAssertEqual([psd width], 100);
    XCTAssertEqual([psd height], 100);
    XCTAssertEqual([psd version], 1);
    XCTAssertTrue([[psd baseLayerGroup] layers]);
    XCTAssertEqual([[[psd baseLayerGroup] layers] count], 1);
    if ([[[psd baseLayerGroup] layers] count] != 1) return;
    FMPSDLayer *layer = [[[psd baseLayerGroup] layers] objectAtIndex:0];
    XCTAssertEqualObjects([layer layerName], @"Layer 1");
    XCTAssertNotNil([psd compositeCIImage]);
    [self assertComposite:psd matchesURL:imageURL tolerance:0];
    NSURL *outURL = [self roundTripURL];
    [psd writeToFile:outURL];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:outURL.path]);
}

// Ported from acorn8/tests/scripts/testPSDResolutionCM.js.
- (void)testPSDResolutionCM {
    NSURL *imageURL = FMPSDTestImageNamed(@"513dpiFromCM.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    if (!psd) return;
    XCTAssertEqual(floorf([psd dpi]), 513);
}

// Ported from acorn8/tests/scripts/testPSDResolutionDPI.js.
- (void)testPSDResolutionDPI {
    NSURL *imageURL = FMPSDTestImageNamed(@"512dpi.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    if (!psd) return;
    XCTAssertEqual(floorf([psd dpi]), 512);
}

// Ported from acorn8/tests/scripts/testPSDSimplegroupTest.js.
- (void)testPSDSimplegroupTest {
    NSURL *imageURL = FMPSDTestImageNamed(@"simplegroup.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    if (!psd) return;
    XCTAssertEqual([psd channels], 4);
    XCTAssertEqual([psd depth], 8);
    XCTAssertEqual([psd colorMode], FMPSDRGBMode);
    XCTAssertEqual([psd width], 53);
    XCTAssertEqual([psd height], 47);
    XCTAssertEqual([psd version], 1);
    XCTAssertTrue([[psd baseLayerGroup] layers]);
    XCTAssertEqual([[[psd baseLayerGroup] layers] count], 5);
    if ([[[psd baseLayerGroup] layers] count] != 5) return;
    FMPSDLayer *topLayer = [[[psd baseLayerGroup] layers] objectAtIndex:0];
    XCTAssertEqualObjects([topLayer layerName], @"Layer 2");
    XCTAssertTrue([topLayer transparencyProtected]);
    XCTAssertEqualObjects([[[[psd baseLayerGroup] layers] objectAtIndex:1] layerName], @"Third Group With One Layer!");
    XCTAssertTrue([[[[psd baseLayerGroup] layers] objectAtIndex:1] isGroup]);
    XCTAssertEqual([[[[[psd baseLayerGroup] layers] objectAtIndex:1] layers] count], 1);
    if ([[[[[psd baseLayerGroup] layers] objectAtIndex:1] layers] count] != 1) return;
    XCTAssertEqual([[[[[psd baseLayerGroup] layers] objectAtIndex:3] layers] count], 3);
    if ([[[[[psd baseLayerGroup] layers] objectAtIndex:3] layers] count] != 3) return;
    XCTAssertEqual([[[[[[[psd baseLayerGroup] layers] objectAtIndex:3] layers] objectAtIndex:1] layers] count], 1);
    if ([[[[[[[psd baseLayerGroup] layers] objectAtIndex:3] layers] objectAtIndex:1] layers] count] != 1) return;
    [self assertComposite:psd matchesURL:imageURL tolerance:0];
}

// Ported from acorn8/tests/scripts/testPSDSingleSolidGreenTest.js.
- (void)testPSDSingleSolidGreenTest {
    NSURL *imageURL = FMPSDTestImageNamed(@"singleSolidGreen.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    if (!psd) return;
    XCTAssertEqual([psd channels], 3);
    XCTAssertEqual([psd depth], 8);
    XCTAssertEqual([psd colorMode], FMPSDRGBMode);
    XCTAssertEqual([psd width], 100);
    XCTAssertEqual([psd height], 100);
    XCTAssertEqual([psd version], 1);
    XCTAssertTrue([[psd baseLayerGroup] layers]);
    XCTAssertEqual([[[psd baseLayerGroup] layers] count], 1);
    if ([[[psd baseLayerGroup] layers] count] != 1) return;
    XCTAssertNotNil([psd compositeCIImage]);
    [self assertComposite:psd matchesURL:imageURL tolerance:0];
}

// Ported from acorn8/tests/scripts/testPSDSingleSolidTransparentGreenTest.js.
- (void)testPSDSingleSolidTransparentGreenTest {
    NSURL *imageURL = FMPSDTestImageNamed(@"singleSolidTransparentGreen.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    if (!psd) return;
    XCTAssertEqual([psd channels], 4);
    XCTAssertEqual([psd depth], 8);
    XCTAssertEqual([psd colorMode], FMPSDRGBMode);
    XCTAssertEqual([psd width], 100);
    XCTAssertEqual([psd height], 100);
    XCTAssertEqual([psd version], 1);
    XCTAssertTrue([[psd baseLayerGroup] layers]);
    XCTAssertEqual([[[psd baseLayerGroup] layers] count], 1);
    if ([[[psd baseLayerGroup] layers] count] != 1) return;
    XCTAssertNotNil([psd compositeCIImage]);
}

// Ported from acorn8/tests/scripts/testPSDTextText.js.
- (void)testPSDTextText {
    NSURL *imageURL = FMPSDTestImageNamed(@"text.psd");
    FMPSD *psd = [self readPSDAtURL:imageURL];
    if (!psd) return;
    XCTAssertEqual([psd channels], 4);
    XCTAssertEqual([psd depth], 8);
    XCTAssertEqual([psd colorMode], FMPSDRGBMode);
    XCTAssertEqual([psd width], 100);
    XCTAssertEqual([psd height], 100);
    XCTAssertEqual([psd version], 1);
    XCTAssertTrue([[psd baseLayerGroup] layers]);
    XCTAssertEqual([[[psd baseLayerGroup] layers] count], 1);
    if ([[[psd baseLayerGroup] layers] count] != 1) return;
    FMPSDLayer *layer = [[[psd baseLayerGroup] layers] objectAtIndex:0];
    XCTAssertEqualObjects([layer layerName], @"moar Acorn");
    FMPSDTextEngineParser *p = [layer.textDescriptor.attributes objectForKey:@"EngineData"];
    XCTAssertNotNil(p);
    NSDictionary *textProps = p.parsedProperties;
    NSString *text = [textProps valueForKeyPath:@"EngineDict.Editor.Text"];
    XCTAssertEqualObjects(text, @"moar Acorn");
}

// Ported from acorn8/tests/scripts/testPSDLayerFrame.js.
- (void)testPSDLayerFrame {
    XCTSkip(@"Requires Acorn to export testPSDLayerFrame.acorn; no exported PSD fixture is available.");
}

// Ported from acorn8/tests/scripts/testPSDTrimLayerExport.js.
- (void)testPSDTrimLayerExport {
    XCTSkip(@"Requires Acorn to export testPSDTrimLayerExport.acorn; no exported PSD fixture is available.");
}

/*
- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}*/

@end
