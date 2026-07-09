//
//  FTInternalConstants.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/1/20.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
NSString * const FT_HTTP_HEADER_X_SDK_INTERNAL_REQUEST = @"X-FT-SDK-Internal-Request";
NSString * const FT_HTTP_HEADER_X_CLIENT_TIMESTAMP = @"x-client-timestamp";
