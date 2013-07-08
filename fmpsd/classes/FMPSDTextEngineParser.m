//
//  FMPSDTextEngineParser.m
//  acorn
//
//  Created by August Mueller on 7/8/13.
//
//

#import "FMPSDTextEngineParser.h"

@interface FMPSDTextEngineParser ()
@property (strong) NSData *engineData;
@property (assign) NSInteger loc;
@property (assign) NSInteger len;
@property (assign) uint8 *base;
@property (strong) NSMutableAttributedString *attString;
@end

@implementation FMPSDTextEngineParser

- (uint8)nextChar {
    char c = _base[_loc];
    _loc++;
    return c;
}

- (uint16)nextShort {
    
    uint16 *u = (uint16*)&(_base[_loc]);
    
    //uint16 c = CFSwapInt16HostToBig(u[0]);
    uint16 c = CFSwapInt16BigToHost(u[0]);
    _loc += 2;
    
    return c;
}

- (NSString*)parseTextTag {
    
    uint8 op = [self nextChar];
    FMAssert(op == '(');
    
    uint16 bom = [self nextShort];
    FMAssert(bom == 0xfeff);
    
    NSMutableString *ret = [NSMutableString string];
    
    // Th\is is\r(a) text läyeז.
    while (_loc < _len) {
        
        uint16 s = [self nextShort];
        
        //debug(@"s: %C / %d", s, s);
        
        if (s == '\\') {
            
            uint8 asc = [self nextChar];
            [ret appendFormat:@"%c", asc];
        }
        else if (s == 0x000d/*\r*/) {
            
            uint8 cp = [self nextChar];
            
            if (cp == ')') {
                // we're done.
                break;
            }
            else {
                [ret appendFormat:@"%C", s];
                _loc--;
            }
        }
        else {
            [ret appendFormat:@"%C", s];
        }
    }
    
    _attString = [[NSMutableAttributedString alloc] initWithString:ret];
    
    debug(@"ret: %@", ret);
    
    return ret;
}

- (NSString*)scanToNextTag {
    
    NSInteger startTagLoc = 0;
    NSInteger endTagLoc = 0;
    
    while (_loc < _len) {
        
        char c = _base[_loc];
        _loc++;
        
        if (c == '/') {
            startTagLoc = _loc;
        }
        else if ((c == '\n' || c == ' ') && startTagLoc) {
            endTagLoc = _loc-1;
            break;
        }
    }
    
    if (!(startTagLoc && endTagLoc)) {
        return nil;
    }
    
    uint8 *startS =_base + startTagLoc;
    
    debug(@"startTagLoc: %ld", startTagLoc);
    debug(@"endTagLoc: %ld", endTagLoc);
    debug(@"endTagLoc-startTagLoc: %ld", endTagLoc-startTagLoc);
    
    
    NSString *ret = [[NSString alloc] initWithBytes:startS length:endTagLoc-startTagLoc encoding:NSUTF8StringEncoding];
    
    if ([ret isEqualToString:@"Text"]) {
        [self parseTextTag];
    }
    
    debug(@"ret: '%@'", ret);
    
    return ret;
}

- (void)parseData:(NSData*)engineData {
    _engineData = engineData;
    
    _len = [engineData length];
    _loc = 0;
    
    _base = (uint8 *)[engineData bytes];
    
    FMAssert(_base[_loc] == '\n');
    _loc++;
    FMAssert(_base[_loc] == '\n');
    _loc++;
    
    NSString *firstTag = [self scanToNextTag];
    
    FMAssert([firstTag isEqualToString:@"EngineDict"]);
    
    debug(@"next: %@", [self scanToNextTag]);
    debug(@"next: %@", [self scanToNextTag]);
    debug(@"next: %@", [self scanToNextTag]);
    debug(@"next: %@", [self scanToNextTag]);
    
    
}

@end
