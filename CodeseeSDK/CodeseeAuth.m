//
//  CodeseeAuth.m
//  CodeseeSDK
//
//  Created by Leo Tang on 2019/1/4.
//  Copyright © 2019 Leo Tang. All rights reserved.
//

#import "CodeseeAuth.h"
#import <CommonCrypto/CommonDigest.h>

#define QRCODE_LEN 88

@interface CodeseeAuth()
{
    SecKeyRef privateKey;
    SecKeyAlgorithm algorithm;
}
@end

@implementation CodeseeAuth
// private method
-(SecKeyRef) getRSAPrivateKeyFromPem {
    // 下面是对于 PEM 格式的密钥文件的密钥多余信息的处理，通常 DER 不需要这一步
    //NSString *key = @"PEM 格式的密钥文件";
    // Get the bundle containing the specified private class.
    NSBundle *myBundle = [NSBundle bundleForClass:[CodeseeAuth class]];
    NSString *privateKeyFile = [[myBundle bundlePath] stringByAppendingPathComponent:@"codesee_key.pem"];
    if(privateKeyFile == nil) {
        NSLog(@"privateKeyFile not found");
        return nil;
    }
    NSData *keyData = [NSData dataWithContentsOfFile:privateKeyFile];
    if(keyData == nil) {
        NSLog(@"key load error");
        return nil;
    }
    
    NSString *key = [[NSString alloc] initWithData: keyData encoding:NSUTF8StringEncoding];
    
    NSRange spos;
    NSRange epos;
    spos = [key rangeOfString:@"-----BEGIN RSA PRIVATE KEY-----"];
    if(spos.length > 0){
        epos = [key rangeOfString:@"-----END RSA PRIVATE KEY-----"];
    }else{
        spos = [key rangeOfString:@"-----BEGIN PRIVATE KEY-----"];
        epos = [key rangeOfString:@"-----END PRIVATE KEY-----"];
    }
    if(spos.location != NSNotFound && epos.location != NSNotFound){
        NSUInteger s = spos.location + spos.length;
        NSUInteger e = epos.location;
        NSRange range = NSMakeRange(s, e-s);
        key = [key substringWithRange:range];
    }
    key = [key stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@" "  withString:@""];
    
    // This will be base64 encoded, decode it.
    //NSData *data = base64_decode(key);
    NSData *data = [[NSData alloc] initWithBase64EncodedString: key options:0];
    if(!data){
        return nil;
    }
    
    // 设置属性字典
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    options[(__bridge id)kSecAttrKeyType] = (__bridge id) kSecAttrKeyTypeRSA;
    options[(__bridge id)kSecAttrKeyClass] = (__bridge id) kSecAttrKeyClassPrivate;
    NSNumber *size = @2048;
    options[(__bridge id)kSecAttrKeySizeInBits] = size;
    NSError *error = nil;
    CFErrorRef ee = (__bridge CFErrorRef)error;
    
    // 调用接口获取密钥对象
    SecKeyRef ret = SecKeyCreateWithData((__bridge CFDataRef)data, (__bridge CFDictionaryRef)options, &ee);
    if (error) {
        return nil;
    }
    return ret;
}
// public method
-(id) init
{
    if (self = [super init]) {
        privateKey = [self getRSAPrivateKeyFromPem];
        algorithm = kSecKeyAlgorithmRSAEncryptionPKCS1;
        
        BOOL canDecrypt = SecKeyIsAlgorithmSupported(privateKey,
                                                     kSecKeyOperationTypeDecrypt,
                                                     algorithm);
        if (canDecrypt == NO) {
            NSLog(@"Algorithm doesn't support");
            return nil;
        }
    }
    
    return self;
}

-(NSString *) authenticate: (NSString *) message
{
    NSString *qrcode = nil;
    do {
        if(message.length != QRCODE_LEN) break;
        
        // FIXME: don't know why
        message = [message stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        
        NSData *cipherData = [[NSData alloc] initWithBase64EncodedString: message options:0];
        
        // Verify QR code
        CFErrorRef error = NULL;
        
        NSData *plainData = (NSData*)CFBridgingRelease(// ARC takes ownership
                                                       SecKeyCreateDecryptedData(privateKey,
                                                                                 algorithm,
                                                                                 (__bridge CFDataRef)cipherData,
                                                                                 &error));
        
        if(error) {
            CFBridgingRelease(error);  // ARC takes ownership
            break;
        }
        
        if(!plainData) break;
        
        qrcode = [[NSString alloc] initWithData:plainData encoding:NSUTF8StringEncoding];
        
        if(![qrcode hasPrefix:@"C"]) {
            qrcode = nil;
            break;
        }
    } while(FALSE);
    
    return qrcode;
}
@end
