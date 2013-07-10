//
//  FMPSDTextEngineParser.h
//  acorn
//
//  Created by August Mueller on 7/8/13.
//
//

#import <Foundation/Foundation.h>

@interface FMPSDTextEngineParser : NSObject {
    
}

@property (strong) NSDictionary *parsedProperties;

- (void)parseData:(NSData*)engineData;

@end
