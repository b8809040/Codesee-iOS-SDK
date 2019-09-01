//
//  CodeseeUtilities.m
//  CodeseeSDK
//
//  Created by Leo Tang on 2019/1/6.
//  Copyright © 2019 Leo Tang. All rights reserved.
//

#import "CodeseeUtilities.h"

@implementation CodeseeUtilities
// Class method
+ (NSString *) getDocPath: (NSString *) subPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [[paths objectAtIndex:0] stringByAppendingFormat:@"/Codesee/%@",subPath];
    return documentsDirectory;
}

+ (UIImage *) getThumbnail:(NSString *) path
{
    UIImage *image = [UIImage imageNamed: path];
    
    NSData *imageData = UIImageJPEGRepresentation(image, 0.3);
    
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    CFDictionaryRef options = (__bridge CFDictionaryRef) @{
                                                           (id) kCGImageSourceCreateThumbnailWithTransform : @YES,
                                                           (id) kCGImageSourceCreateThumbnailFromImageAlways : @YES,
                                                           (id) kCGImageSourceThumbnailMaxPixelSize : @300
                                                           };
    
    CGImageRef scaledImageRef = CGImageSourceCreateThumbnailAtIndex(src, 0, options);
    UIImage *thumbnail = [UIImage imageWithCGImage:scaledImageRef];
    CGImageRelease(scaledImageRef);
    
    return thumbnail;
}

+ (UIImage *) getUIImage:(NSString *) path
{
    NSError *error;
    NSData *data = [NSData dataWithContentsOfFile: path options:NSDataReadingUncached error:&error];
    return [UIImage imageWithData:data];
}
@end
