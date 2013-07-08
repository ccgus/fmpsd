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
        
        debug(@"s: %C / %d", s, s);
        
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
        else if (s == 0x290A) { // FFS.  The "Name" tag in /ParagraphSheet comes close to being like a /Text tag, but not quite. 290A is )\r
            break;
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
        else if (c == '>') {
            c = [self nextChar];
            FMAssert(c == '>');
            return nil;
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
    
    NSString *ret = [[NSString alloc] initWithBytes:startS length:endTagLoc-startTagLoc encoding:NSUTF8StringEncoding];
    
    return ret;
}

- (void)scanToChar:(char)searchChar {
    char c = [self nextChar];
    while (c != searchChar && _loc < _len) {
        c = [self nextChar];
    }
}

- (NSString*)scanToEndOfLine {
    NSMutableString *ret = [NSMutableString string];
    char c = [self nextChar];
    while (c != 0x0a) {
        [ret appendFormat:@"%c", c];
        c = [self nextChar];
    }
    
    return [ret stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (id)parseTag:(NSString*)tag {
    
    debug(@"tag: %@", tag);
    
    if ([tag isEqualToString:@"Editor"]) {
        return [self parseDictionaryWithName:tag];
    }
    else if ([tag isEqualToString:@"ParagraphRun"]) {
        return [self parseDictionaryWithName:tag];
    }
    else if ([tag isEqualToString:@"DefaultRunData"]) {
        return [self parseDictionaryWithName:tag];
    }
    else if ([tag isEqualToString:@"ParagraphSheet"]) {
        return [self parseDictionaryWithName:tag];
    }
    else if ([tag isEqualToString:@"Properties"]) {
        return [self parseDictionaryWithName:tag];
    }
    else if ([tag isEqualToString:@"Adjustments"]) {
        return [self parseDictionaryWithName:tag];
    }
    else if ([tag isEqualToString:@"DefaultStyleSheet"]) {
        return [self scanToEndOfLine];
    }
    else if ([tag isEqualToString:@"Axis"]) {
        return [self scanToEndOfLine];
    }
    else if ([tag isEqualToString:@"XY"]) {
        return [self scanToEndOfLine];
    }
    else if ([tag isEqualToString:@"AutoKerning"]) {
        return [self scanToEndOfLine];
    }
    else if ([tag isEqualToString:@"Kerning"]) {
        return [self scanToEndOfLine];
    }
    else if ([tag isEqualToString:@"FontSize"]) {
        return [self scanToEndOfLine];
    }
    else if ([tag isEqualToString:@"RunArray"]) {
        return [self parseArrayWithName:tag];
    }
    else if ([tag isEqualToString:@"Text"]) {
        return [self parseTextTag];
    }
    else if ([tag isEqualToString:@"Name"]) {
        return [self parseTextTag];
    }
    else if ([tag isEqualToString:@"StyleSheet"]) {
        return [self parseDictionaryWithName:tag];
    }
    else if ([tag isEqualToString:@"StyleSheetData"]) {
        return [self parseDictionaryWithName:tag];
    }
    else {
        debug(@"not sure how to parse %@", tag);
    }
    
    return nil;
}

- (void)scanToDoubleLessThan {
    
    [self scanToChar:'<'];
    char c = [self nextChar];
    FMAssert(c == '<');
    
}

- (void)scanToDoubleGreaterThan {
    [self scanToChar:'>'];
    char c = [self nextChar];
    FMAssert(c == '>');
}

- (NSArray*)parseArrayWithName:(NSString*)arrayName {
    
    NSMutableArray *ret = [NSMutableArray array];
    
    char c = [self nextChar];
    
    FMAssert(c == '[');
    
    [self scanToDoubleLessThan];
    
    
    NSString *nextTag = [self scanToNextTag];
    
    while (nextTag) {
        
        id o = [self parseTag:nextTag];
        
        if (o) {
            [ret addObject:o];
        }
    }
    
    [self scanToDoubleGreaterThan];
    [self scanToChar:']'];
    
    return ret;
}

- (void)dumpTillEnd {
    
    while (_loc < _len) {
        printf("%c", [self nextChar]);
    }
    
    printf("\n");
}

- (void)dumpTill:(NSInteger)endLoc {
    
    NSInteger idx = 0;
    
    while (idx < endLoc) {
        printf("%c", _base[idx++]);
    }
    
    printf("\n");
}

- (NSDictionary*)parseDictionaryWithName:(NSString*)dictName {
    
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    
    
    // dicts start out with a << on their own line, and end with a >>?
    [self scanToDoubleLessThan];
    
    char c = [self nextChar];
    
    debug(@"c: %d", c);
    
    while ((c != '>' || c != '/') && _loc < _len) {
        
        // we're done with the dict.
        if (c == '>') {
            c = [self nextChar];
            FMAssert(c == '>');
            break;
        }
        
        if (c == '\n' || c == '\t') {
            c = [self nextChar];
            continue;
        }
        
        if (c != '/') {
            debug(@"_loc: %ld", _loc);
            [self dumpTill:_loc];
            debug(@"ret: %@", ret);
        }
        
        FMAssert(c == '/');
        _loc--;
        
        NSString *workingTag = [self scanToNextTag];
        
        debug(@"workingTag: %@", workingTag);
        
        id o = nil;
        
        if ([dictName isEqualToString:@"Properties"]) {
            o = [self scanToEndOfLine];
        }
        else {
            o = [self parseTag:workingTag];
        }
        
        if (o) {
            [ret setObject:o forKey:workingTag];
        }
        
        c = [self nextChar];
    }
    
    debug(@"c: %c", c);
    
    
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
    
    NSDictionary *d = [self parseDictionaryWithName:firstTag];
    
    debug(@"d: %@", d);
    
    exit(0);
}

@end
