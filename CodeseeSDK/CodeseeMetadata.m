//
//  CodeseeMetadata.m
//  CodeseeSDK
//
//  Created by Leo Tang on 2019/1/4.
//  Copyright © 2019 Leo Tang. All rights reserved.
//

#import "CodeseeMetadata.h"

@interface CodeseeMetadata()
{
    NSMutableDictionary *dict;
}
@end

@implementation CodeseeMetadata

+ (BOOL)supportsSecureCoding{
    return YES;
}

// Private method
-(void) encodeWithCoder:(NSCoder *) coder
{
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject: dict options: NSJSONWritingPrettyPrinted error: &error];
    NSString *encodeString = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    [coder encodeObject:encodeString forKey:@"dict"];
}

-(id) initWithCoder:(NSCoder *) decoder
{
    self = [super init];
    if (self) {
        NSString *encodeString = [decoder decodeObjectForKey:@"dict"];
        // Parse
        NSError *error;
        NSData *data = [encodeString dataUsingEncoding:NSUTF8StringEncoding];
        dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error: &error];
    }
    return self;
}

// Public method
-(NSString *) getData: (NSString *) key
{
    NSString *value = nil;
    value = [dict objectForKey:key];
    return value;
}

-(void) setData: (NSString *) key Value: (NSString *) value
{
    [dict setValue: value forKey:key];
}

-(void) addImage:(NSString *)filename
{
    NSString *retrievedImages = (NSString *) [dict objectForKey: @"img"];
    if(retrievedImages != nil && [retrievedImages length] != 0) {
        retrievedImages = [NSString stringWithFormat:@"%@,%@", filename, retrievedImages];
    } else {
        retrievedImages = [NSString stringWithFormat:@"%@", filename];
    }
    [dict setValue: retrievedImages forKey: @"img"];
}

-(void) removeImage:(NSString *)filename
{
    NSString *retrievedImages = [dict objectForKey: @"img"];
    NSString *tmp = [[NSString alloc] init];
    long i=0;
    NSArray *array = [retrievedImages componentsSeparatedByString:@","];
    for(i=0;i< [array count];i++) {
        if([filename isEqualToString: array[i]] == NO) {
            if([tmp length] == 0) {
                tmp = [NSString stringWithFormat:@"%@", array[i]];
            } else {
                tmp = [NSString stringWithFormat:@"%@,%@", tmp, array[i]];
            }
        }
    } // end for
    NSLog(@"new string=%@", tmp);
    NSLog(@"remove pic=%@", filename);
    [dict setValue: tmp forKey: @"img"];
}

-(NSArray *) getImages
{
    NSString *retrievedImages = [dict objectForKey: @"img"];
    NSArray *array = [retrievedImages componentsSeparatedByString:@","];
    return array;
}

- (id) init {
    self = [super init];
    if(self) {
        self->dict = [[NSMutableDictionary alloc] init];
    }
    return self;
}
@end
