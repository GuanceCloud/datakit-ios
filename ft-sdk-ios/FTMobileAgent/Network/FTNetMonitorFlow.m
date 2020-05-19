//
//  FTNetMonitorFlow.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/1/9.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTNetMonitorFlow.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>
#import "FTLog.h"
typedef struct {
    long long iBytes;
    long long oBytes;
} FTNetFlowBytes;
@interface FTNetMonitorFlow ()
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) FTNetFlowBytes lastBytes;
@property (nonatomic, strong) NSThread *thread1;

@end
@implementation FTNetMonitorFlow

-(void)startMonitor{
    self.iflow = 0;
    self.oflow = 0;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf){
            strongSelf.thread1 = [NSThread currentThread];
            strongSelf.lastBytes = [self getInterfaceBytes];
            strongSelf.timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(refreshFlow) userInfo:nil repeats:YES];
            NSRunLoop *runloop = [NSRunLoop currentRunLoop];
            [runloop addTimer:strongSelf.timer forMode:NSDefaultRunLoopMode];
            [runloop run];
        }
    });
}
-(void)stopMonitor{
    if (_timer && self.thread1) {
        [self performSelector:@selector(cancel) onThread:self.thread1 withObject:nil waitUntilDone:YES];
    }
}
- (void)cancel{
    if (self.timer) {
        [_timer setFireDate:[NSDate distantFuture]];
        [_timer invalidate];
    }
    _timer = nil;
}
- (void)refreshFlow{
    long long int irate = 0;
    long long int orate = 0;
    FTNetFlowBytes currentBytes = [self getInterfaceBytes];
    if(self.lastBytes.iBytes) {
        //用上当前的下行总流量减去上一秒的下行流量达到下行速录
        irate  = currentBytes.iBytes -self.lastBytes.iBytes;
        orate = currentBytes.oBytes -self.lastBytes.oBytes;
    }
    self.lastBytes = currentBytes;
    self.iflow  = irate;
    self.oflow = orate;
}
- (FTNetFlowBytes) getInterfaceBytes {
    FTNetFlowBytes flowByte;
    flowByte.iBytes = 0;
    flowByte.oBytes = 0;
    struct ifaddrs *ifa_list = 0, *ifa;
    if (getifaddrs(&ifa_list) == -1) {
        return flowByte;
    }
    uint32_t iBytes = 0;
    uint32_t oBytes = 0;
    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next) {
        if (AF_LINK != ifa->ifa_addr->sa_family)
            continue;
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING))
            continue;
        if (ifa->ifa_data == 0)
            continue;
        /* Not a loopback device. */
        if (strncmp(ifa->ifa_name, "lo", 2)){
            struct if_data *if_data = (struct if_data *)ifa->ifa_data;
            iBytes += if_data->ifi_ibytes;
            oBytes += if_data->ifi_obytes;
        }
    }
    freeifaddrs(ifa_list);
    flowByte.iBytes = iBytes;
    flowByte.oBytes = oBytes;
    return flowByte;
}
-(long long)getGprsWifiFlowIOBytes{
    struct ifaddrs *ifa_list = 0, *ifa;
    if (getifaddrs(&ifa_list) == -1) {
        return 0;
    }
    uint64_t iBytes = 0;
    uint64_t oBytes = 0;
    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next) {
        if (AF_LINK != ifa->ifa_addr->sa_family)
            continue;
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING))
            continue;
        if (ifa->ifa_data == 0)
            continue;
        //Wifi
        if (strncmp(ifa->ifa_name, "lo", 2)) {
            struct if_data *if_data = (struct if_data *)ifa->ifa_data;
            iBytes += if_data->ifi_ibytes;
            oBytes += if_data->ifi_obytes;
        }
        //移动
        if (!strcmp(ifa->ifa_name, "pdp_ip0")){
            struct if_data *if_data = (struct if_data *)ifa->ifa_data;
            iBytes += if_data->ifi_ibytes;
            oBytes += if_data->ifi_obytes;
        }
    }
    freeifaddrs(ifa_list);
    uint64_t bytes = 0;
    bytes = iBytes + oBytes;
    return bytes;
}

@end
