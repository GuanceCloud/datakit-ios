//
//  FTInternalConstants.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/1/20.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTInternalConstants.h"
NSString * const FTStatusStringMap[] = {
    [StatusInfo] = @"info",
    [StatusWarning] = @"warning",
    [StatusError] = @"error",
    [StatusCritical] = @"critical",
    [StatusOk] = @"ok",
    [StatusDebug] = @"debug",
};
NSString * const FTNetworkTraceStringMap[] = {
    [ZipkinMultiHeader] = @"zipkin",
    [ZipkinSingleHeader] = @"zipkin",
    [Jaeger] = @"jaeger",
    [DDtrace] = @"ddtrace",
    [SkyWalking] = @"skywalking",
    [TraceParent] = @"traceparent",
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

NSString * const FT_BLACK_LIST_VIEW = @"FT_BLACK_LIST_VIEW";
NSString * const FT_BLACK_LIST_VIEW_ACTION = @"FT_BLACK_LIST_VIEW_ACTION";


NSUInteger const FT_LOGGING_CONTENT_SIZE = 30720;
NSUInteger const FT_TIME_INTERVAL = 100;

int const FT_DB_LOG_MAX_COUNT = 5000;
int const FT_DB_LOG_MIN_COUNT = 1000;

int const FT_DB_RUM_MAX_COUNT = 100000;
int const FT_DB_RUM_MIN_COUNT = 10000;

// 100MB
long const FT_DEFAULT_DB_SIZE_LIMIT = 104857600;
long const FT_MIN_DB_SIZE_LIMIT = 31457280;

NSString * const FT_SCRIPT_MESSAGE_HANDLER_NAME = @"ftMobileSdk";
long const FT_DEFAULT_BLOCK_DURATIONS_MS = 250;
long const FT_MIN_DEFAULT_BLOCK_DURATIONS_MS = 100;
long const FT_ANR_THRESHOLD_MS = 5000;

long long const FT_ANR_THRESHOLD_NS = 5000000000;

NSString * const FT_HTTP_HEADER_X_PKG_ID = @"X-Pkg-Id";
NSString * const FT_HTTP_HEADER_X_CLIENT_TIMESTAMP = @"x-client-timestamp";
