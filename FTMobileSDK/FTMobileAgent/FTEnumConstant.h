//
//  FTEnumConstant.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/1/20.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "FTConstants.h"

typedef NS_ENUM(NSUInteger, AppState) {
    AppStateUnknown,
    AppStateStartUp,
    AppStateRun,
};

typedef enum FTError : NSInteger {
  NetWorkException = 101,        //网络问题
  InvalidParamsException = 102,  //参数问题
  FileIOException = 103,         //文件 IO 问题
  UnknownException = 104,        //未知问题
} FTError;
extern NSString * const AppStateStringMap[];
extern NSString * const FTStatusStringMap[];
extern NSString * const FTNetworkTraceStringMap[];
extern NSString * const FTEnvStringMap[];
