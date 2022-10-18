//
//  FTThread.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/12.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTThread.h"

@implementation FTThread
-(void)main{
    self.name = @"com.dataflux.thread";
    [self performSelector:@selector(startRunloop)];
}
-(void)startRunloop{
    CFRunLoopSourceContext context = {0};
    // 创建source
    CFRunLoopSourceRef source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
    // 往Runloop中添加source
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    // 销毁source
    CFRelease(source);
    // 启动
    //参数：模式，过时时间(1.0e10一个很大的值)，是否执行完source后就会退出当前loop
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0e10, false);
}
@end
