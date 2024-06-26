//
//  FTBaseInfoHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTBaseInfoHandler.h"
#import <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>
#import "NSString+FTAdd.h"
#import "FTConstants.h"
#include <mach-o/dyld.h>
#include <netdb.h>
#include <arpa/inet.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#include <arpa/inet.h>
#import <ifaddrs.h>
#include <net/if.h>
#import <dns_sd.h>
#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IOS_VPN         @"utun0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"
@implementation FTBaseInfoHandler : NSObject

+ (NSString *)convertToStringData:(NSDictionary *)dict{
    __block NSString *str = @"";
    if (dict) {
        [dict.allKeys enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx == dict.allKeys.count-1) {
                str = [str stringByAppendingFormat:@"%@:%@",obj,dict[obj]];
            }else{
                str = [str stringByAppendingFormat:@"%@:%@\n",obj,dict[obj]];
            }
        }];
    }
    return str;
}

+ (NSString *)replaceNumberCharByUrl:(NSURL *)url{
    NSString *relativePath = [url path];
    if (relativePath.length==0 || !relativePath) {
        return @"";
    }
    static NSRegularExpression *regularExpress = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = nil;
        NSString *pattern = @"\\/([^\\/]*)\\d([^\\/]*)";
        regularExpress = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    });
    NSString *string = [regularExpress stringByReplacingMatchesInString:relativePath options:0 range:NSMakeRange(0, [relativePath length]) withTemplate:@"/?"];
    return string;
}
+ (BOOL)randomSampling:(int)sampling{
    if(sampling<=0){
        return NO;
    }
    if(sampling<100){
        int x = arc4random_uniform(100)+1;
        return x <= sampling ? YES:NO;
    }
    return YES;
}
+ (NSString *)randomUUID{
    NSString *uuid = [NSUUID UUID].UUIDString;
    uuid = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return uuid.lowercaseString;
}
#if FT_IOS
+(NSString *)telephonyCarrier
{
    CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier;
    if (@available(iOS 12.0, *)) {
        if (info && [info respondsToSelector:@selector(serviceSubscriberCellularProviders)]) {
            NSDictionary *dic = [info serviceSubscriberCellularProviders];
            if (dic.allKeys.count) {
                carrier = [dic objectForKey:dic.allKeys[0]];
            }
        }
    }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        // 这部分使用到的过期api
        carrier= [info subscriberCellularProvider];
#pragma clang diagnostic pop
        
    }
    if(carrier ==nil){
        return FT_NULL_VALUE;
    }else{
        NSString *mCarrier = [NSString stringWithFormat:@"%@",[carrier carrierName]];
        return mCarrier;
    }
}
#endif

+ (NSString *)cellularIPAddress:(BOOL)preferIPv4
{
    NSArray *searchArray = preferIPv4 ?
    @[ IOS_VPN @"/" IP_ADDR_IPv4, IOS_VPN @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
    @[ IOS_VPN @"/" IP_ADDR_IPv6, IOS_VPN @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;
    
    NSDictionary *addresses = [self ipAddresses];
    
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
        address = addresses[key];
        //筛选出IP地址格式
        if([self isValidatIP:address]) *stop = YES;
    }];
    return address ? address : @"0.0.0.0";
}
+ (BOOL)isValidatIP:(NSString *)ipAddress {
    if (ipAddress.length == 0) {
        return NO;
    }
    NSString *urlRegEx = @"^([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])$";
    
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:urlRegEx options:0 error:&error];
    
    if (regex != nil) {
        NSTextCheckingResult *firstMatch=[regex firstMatchInString:ipAddress options:0 range:NSMakeRange(0, [ipAddress length])];
        
        if (firstMatch) {
            return YES;
        }
    }
    return NO;
}
+ (NSDictionary *)ipAddresses{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}
+ (NSString *)decimalToBase36:(unsigned long)decimalNumber{
    static NSString *const base36Characters = @"0123456789abcdefghijklmnopqrstuvwxyz";
    NSMutableString *result = [NSMutableString string];
    while (decimalNumber > 0) {
        NSUInteger remainder = decimalNumber % 36;
        [result insertString:[base36Characters substringWithRange:NSMakeRange(remainder, 1)] atIndex:0];
        decimalNumber /= 36;
    }
    return result.length > 0 ? result : @"0";
}
static unsigned long rumSerialNumber = 0;
static unsigned long logSerialNumber = 0;

+ (NSString *)rumRequestSerialNumber{
    [self increaseRumRequestSerialNumber];
    return [NSString stringWithFormat:@"%@",[self decimalToBase36:rumSerialNumber]];
}
+ (void)increaseRumRequestSerialNumber{
    if(rumSerialNumber == ULONG_MAX){
        rumSerialNumber = 0;
    }else{
        rumSerialNumber += 1;
    }
}
+ (NSString *)logRequestSerialNumber{
    [self increaseLogRequestSerialNumber];
    return [NSString stringWithFormat:@"%@",[self decimalToBase36:logSerialNumber]];
}
+ (void)increaseLogRequestSerialNumber{
    if(logSerialNumber == ULONG_MAX){
        logSerialNumber = 0;
    }else{
        logSerialNumber += 1;
    }
}
+ (NSString *)urlDomainErrorDescription:(NSError *)error{
    if(error.domain == NSURLErrorDomain){
        switch (error.code) {
            case NSURLErrorCancelled: return @"The connection was cancelled.";
            case NSURLErrorBadURL: return @"The connection failed due to a malformed URL.";
            case NSURLErrorTimedOut: return @"The connection timed out.";
            case NSURLErrorUnsupportedURL: return @"The connection failed due to an unsupported URL scheme.";
            case NSURLErrorCannotFindHost: return @"The connection failed because the host could not be found.";
            case NSURLErrorCannotConnectToHost: return @"The connection failed because a connection cannot be made to the host.";
            case NSURLErrorNetworkConnectionLost: return @"The connection failed because the network connection was lost.";
            case NSURLErrorDNSLookupFailed: return @"The connection failed because the DNS lookup failed.";
            case NSURLErrorHTTPTooManyRedirects: return @"The HTTP connection failed due to too many redirects.";
            case NSURLErrorResourceUnavailable: return @"The connection’s resource is unavailable.";
            case NSURLErrorNotConnectedToInternet: return @"The connection failed because the device is not connected to the internet.";
            case NSURLErrorRedirectToNonExistentLocation: return @"The connection was redirected to a nonexistent location.";
            case NSURLErrorBadServerResponse: return @"The connection received an invalid server response.";
            case NSURLErrorUserCancelledAuthentication: return @"The connection failed because the user cancelled required authentication.";
            case NSURLErrorUserAuthenticationRequired: return @"The connection failed because authentication is required.";
            case NSURLErrorZeroByteResource: return @"The resource retrieved by the connection is zero bytes.";
            case NSURLErrorCannotDecodeRawData: return @"The connection cannot decode data encoded with a known content encoding.";
            case NSURLErrorCannotDecodeContentData: return @"The connection cannot decode data encoded with an unknown content encoding.";
            case NSURLErrorCannotParseResponse: return @"The connection cannot parse the server’s response.";
            case NSURLErrorAppTransportSecurityRequiresSecureConnection: return @"The resource could not be loaded because the App Transport Security policy requires the use of a secure connection.";
            case NSURLErrorFileDoesNotExist: return @"The file operation failed because the file does not exist.";
            case NSURLErrorFileIsDirectory: return @"The file operation failed because the file is a directory.";
            case NSURLErrorNoPermissionsToReadFile: return @"The file operation failed because it does not have permission to read the file.";
            case NSURLErrorDataLengthExceedsMaximum: return @"The file operation failed because the file is too large.";
            case NSURLErrorSecureConnectionFailed: return @"The secure connection failed for an unknown reason.";
            case NSURLErrorServerCertificateHasBadDate: return @"The secure connection failed because the server’s certificate has an invalid date.";
            case NSURLErrorServerCertificateUntrusted: return @"The secure connection failed because the server’s certificate is not trusted.";
            case NSURLErrorServerCertificateHasUnknownRoot: return @"The secure connection failed because the server’s certificate has an unknown root.";
            case NSURLErrorServerCertificateNotYetValid: return @"The secure connection failed because the server’s certificate is not yet valid.";
            case NSURLErrorClientCertificateRejected: return @"The secure connection failed because the client’s certificate was rejected.";
            case NSURLErrorClientCertificateRequired: return @"The secure connection failed because the server requires a client certificate.";
            case NSURLErrorCannotLoadFromNetwork: return @"The connection failed because it is being required to return a cached resource, but one is not available.";
            case NSURLErrorCannotCreateFile: return @"The file cannot be created.";
            case NSURLErrorCannotOpenFile: return @"The file cannot be opened.";
            case NSURLErrorCannotCloseFile: return @"The file cannot be closed.";
            case NSURLErrorCannotWriteToFile: return @"The file cannot be written.";
            case NSURLErrorCannotRemoveFile: return @"The file cannot be removed.";
            case NSURLErrorCannotMoveFile: return @"The file cannot be moved.";
            case NSURLErrorDownloadDecodingFailedMidStream: return @"The download failed because decoding of the downloaded data failed mid-stream.";
            case NSURLErrorDownloadDecodingFailedToComplete: return @"The download failed because decoding of the downloaded data failed to complete.";
            case NSURLErrorInternationalRoamingOff: return @"The connection failed because international roaming is disabled on the device.";
            case NSURLErrorCallIsActive: return @"The connection failed because a call is active.";
            case NSURLErrorDataNotAllowed: return @"The connection failed because data use is currently not allowed on the device.";
            case NSURLErrorRequestBodyStreamExhausted: return @"The connection failed because its request’s body stream was exhausted.";
            default: return error.localizedDescription;
        }
    }
    return error.localizedDescription;
}
@end
