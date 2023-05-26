//
//  FTEnumConstant.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/1/20.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTEnumConstant.h"
NSString * const AppStateStringMap[] = {
    [AppStateUnknown] = @"unknown",
    [AppStateStartUp] = @"startup",
    [AppStateRun] = @"run",
};
NSString * const FTStatusStringMap[] = {
    [StatusInfo] = @"info",
    [StatusWarning] = @"warning",
    [StatusError] = @"error",
    [StatusCritical] = @"critical",
    [StatusOk] = @"ok",
    [StatusDebug] = @"debug"
};
NSString * const FTNetworkTraceStringMap[] = {
    [ZipkinMultiHeader] = @"zipkin",
    [ZipkinSingleHeader] = @"zipkin",
    [Jaeger] = @"jaeger",
    [DDtrace] = @"ddtrace",
    [Skywalking] = @"skywalking",
    [Traceparent] = @"traceparent",
};
NSString * const FTEnvStringMap[] = {
    [Prod] = @"prod",
    [Gray] = @"gray",
    [Pre] = @"pre",
    [Common] = @"common",
    [Local] = @"local",
};

NSTimeInterval const MonitorFrequencyMap[] = {
    [MonitorFrequencyDefault] = 0.5,
    [MonitorFrequencyRare] = 1.0,
    [MonitorFrequencyFrequent] = 0.1
};
