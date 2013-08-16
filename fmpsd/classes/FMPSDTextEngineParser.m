//
//  FMPSDTextEngineParser.m
//  acorn
//
//  Created by August Mueller on 7/8/13.
//
//

#import "FMPSDTextEngineParser.h"
#import "FMPSD.h"

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
        
        // debug(@"s: %C / %d", s, s);
        
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
//            debug(@"End of name: '%@'", ret);
            break;
        }
        else {
            [ret appendFormat:@"%C", s];
        }
    }
    
    _attString = [[NSMutableAttributedString alloc] initWithString:ret];
    
    return ret;
}

- (NSString*)scanNextWord {
    
    if (_loc >= _len) {
        debug(@"running off the end! at %ld of %ld", _loc, _len);
        return nil;
    }
    
    [self scanTillNextRealChar];
    NSInteger startLoc = _loc, endLoc = 0;
    while (_loc < _len) {
        
        const char c = _base[_loc];
        _loc++;
        
        if (c == ' ' || c == '\r' || c == '\n' || c == '\t') {
            endLoc = _loc - 1;
            break;
        }
    }
    
    if (_loc == _len) {
        debug(@"We're done!");
        return nil;
    }
    
    if (endLoc <= startLoc) {
        [self dumpTill:_loc];
        FMAssert(NO);
        return nil;
    }
    
    
    uint8 *startS =_base + startLoc;
    
    NSString *ret = [[NSString alloc] initWithBytes:startS length:endLoc-startLoc encoding:NSUTF8StringEncoding];
    
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
    while (c != 0x0a && _loc < _len) {
        [ret appendFormat:@"%c", c];
        c = [self nextChar];
    }
    
    return [ret stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (id)parseTag:(NSString*)tag {
    
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
    
    debug(@"arrayName: %@", arrayName);
    
    if ([arrayName isEqualToString:@"/StyleSheetData"]) {
        
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    NSMutableDictionary *currentDict = [NSMutableDictionary dictionary];
    
    char c = [self nextChar];
    
    FMAssert(c == '[');
    
    NSString *restOfLine = [self scanToEndOfLine];
    
    if ([restOfLine isEqualToString:@"]"]) { // empty array.
        return ret;
    }
    
    NSString *nextWord = [self scanNextWord];
    FMAssert([nextWord isEqualToString:@"<<"]);
    
    nextWord = [self scanNextWord];
    while (nextWord && (![nextWord isEqualToString:@"]"])) {
        
        if ([nextWord isEqualToString:@">>"]) {
            
            if ([currentDict count]) {
                [ret addObject:currentDict];
            }
            
            currentDict = [NSMutableDictionary dictionary];
            
            NSString *s = [self scanNextWord];
            if ([s isEqualToString:@"]"]) {
                break;
            }
            
            if ([s isEqualToString:@"<<"]) {
                // continue on.
                nextWord = [self scanNextWord];
            }
            
        }
        
        FMAssert([nextWord hasPrefix:@"/"]);
        
        char nextRealChar = [self peekToNextRealChar];
        
        id value = nil;
        
        if (nextRealChar == '<') {
            value = [self parseDictionaryWithName:nextWord];
        }
        else if ([nextWord hasSuffix:@"Array"] && nextRealChar == '[') {
            value = [self parseArrayWithName:nextWord];
        }
        else {
            value = [self scanSingleLineWithTag:nextWord];
        }
        
        if (value) {
            [currentDict setObject:value forKey:[nextWord substringFromIndex:1]];
        }
        else {
            debug(@"nextWord has no value: ('%@')", nextWord);
        }
        
        nextWord = [self scanNextWord];
    }
    
    
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

- (NSString*)scanSingleLineWithTag:(NSString*)tag {
    
    if ([tag isEqualToString:@"/Text"]) {
        return [self parseTextTag];
    }
    else if ([tag isEqualToString:@"/Name"]) {
        return [self parseTextTag];
    }
    else if ([tag isEqualToString:@"/NoStart"] || [tag isEqualToString:@"/NoEnd"]) {
        return [self parseTextTag];
    }
    
    NSString *s = [[self scanToEndOfLine] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    return s;
}

- (NSDictionary*)parseDictionaryWithName:(NSString*)dictName {
    
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    
    // dicts start out with a << on their own line, and end with a >>?
    
    NSString *startB = [self scanNextWord];
    FMAssert([startB isEqualToString:@"<<"]);
    
    NSString *key = [self scanNextWord];
    while (key && (![key isEqualToString:@">>"])) {
        
        FMAssert([key hasPrefix:@"/"]);
        
        FMAssert(_loc < _len);
        
        char nextRealChar = [self peekToNextRealChar];
        
        FMAssert(_loc < _len);
        
        id value = nil;
        
        if (nextRealChar == '<') {
            value = [self parseDictionaryWithName:key];
        }
        else if ([key hasSuffix:@"/RunArray"] && nextRealChar == '[') {
            value = [self parseArrayWithName:key];
        }
        else if ([key hasSuffix:@"/Children"] && nextRealChar == '[') {
            value = [self parseArrayWithName:key];
        }
        else if ([key hasSuffix:@"Set"] && nextRealChar == '[') {
            value = [self parseArrayWithName:key];
        }
        else {
            value = [self scanSingleLineWithTag:key];
        }
        
        if (value) {
            [ret setObject:value forKey:[key substringFromIndex:1]];
        }
        else {
            debug(@"key has no value: ('%@')", key);
        }
        
        
        key = [self scanNextWord];
    }
    
    return ret;
}

- (char)peekToNextRealChar {
    
    NSInteger currentLoc = _loc;
    
    while (currentLoc < _len) {
        
        char c = _base[currentLoc++];
        
        if (!(c == '\n' || c == '\r' || c == '\t' || c == ' ')) {
            return c;
        }
    }
    
    if (currentLoc >= _len) {
        debug(@"ran off the end in peekToNextRealChar");
    }
    
    return -1;
}

- (void)scanTillNextRealChar {
    
    while (_loc < _len) {
        
        char c = _base[_loc];
        _loc++;
        
        if (!(c == '\n' || c == '\r' || c == '\t' || c == ' ')) {
            _loc--;
            return;
        }
    }
    
    NSLog(@"Fell off the end in scanTillNextRealChar");
    FMAssert(NO);
}

- (void)parseData:(NSData*)engineData {
    _engineData = engineData;
    
    _len = [engineData length];
    _loc = 0;
    
    _base = (uint8 *)[engineData bytes];
    
    
    NSDictionary *d = [self parseDictionaryWithName:@"Base"];
    
    [self setParsedProperties:d];
}

@end
