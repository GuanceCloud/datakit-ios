//
//  FTConstants.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/5/13.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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

#import <Foundation/Foundation.h>
/// SDK constant declarations
#pragma mark ========== agent ==========
/// Data type marker for RUM records.
extern NSString * const FT_DATA_TYPE_RUM;
/// Data type marker for logging records.
extern NSString * const FT_DATA_TYPE_LOGGING;
/// Data type marker for cached RUM records waiting for later upload.
extern NSString * const FT_DATA_TYPE_RUM_CACHE;
/// Field key for the service name associated with an application.
extern NSString * const FT_KEY_SERVICE;
/// Envelope key for a record measurement name.
extern NSString * const FT_MEASUREMENT;
/// Envelope key for record fields.
extern NSString * const FT_FIELDS;
/// Envelope key for record tags.
extern NSString * const FT_TAGS;
/// Envelope key for operation payload data.
extern NSString * const FT_OPDATA;
/// Envelope key for the record operation type.
extern NSString * const FT_OP;
/// Envelope key for the record timestamp.
extern NSString * const FT_TIME;
/// Default iOS RUM service name.
extern NSString * const FT_DEFAULT_SERVICE_NAME;
/// Default tvOS RUM service name.
extern NSString * const FT_TVOS_SERVICE_NAME;
/// iOS SDK collector name.
extern NSString * const FT_IOS_SDK_NAME;
/// Platform-specific SDK collector name used in RUM SDK attributes.
extern NSString * const FT_SDK_NAME_VALUE;
/// Platform-specific User-Agent product name.
extern NSString * const FT_USER_AGENT_NAME;
/// macOS SDK collector name.
extern NSString * const FT_MACOS_SDK_NAME;
/// Flag indicating that the RUM event originated from WebView JSBridge data.
extern NSString * const FT_IS_WEBVIEW;
/// Placeholder value used when an attribute has no available value.
extern NSString * const FT_NULL_VALUE;
/// Generic type field key.
extern NSString * const FT_TYPE;
#pragma mark ----- data source
/// Field key for the data source name.
extern NSString * const FT_KEY_SOURCE;
/// tvOS log source name.
extern NSString * const FT_LOGGER_TVOS_SOURCE;
/// iOS log source name.
extern NSString * const FT_LOGGER_SOURCE;
/// macOS log source name.
extern NSString * const FT_LOGGER_MACOS_SOURCE;
/// RUM resource source name.
extern NSString * const FT_RUM_SOURCE_RESOURCE;
/// RUM error source name.
extern NSString * const FT_RUM_SOURCE_ERROR;
/// RUM action source name.
extern NSString * const FT_RUM_SOURCE_ACTION ;
/// RUM long-task source name.
extern NSString * const FT_RUM_SOURCE_LONG_TASK;
/// RUM view source name.
extern NSString * const FT_RUM_SOURCE_VIEW;
/// SDK version attribute key.
extern NSString * const FT_SDK_VERSION;
/// SDK collector name attribute key.
extern NSString * const FT_SDK_NAME;
/// SDK package information attribute key.
extern NSString * const FT_SDK_PKG_INFO;
#pragma mark ========== BASE PROPERTY ==========
/// Application name attribute key.
extern NSString * const FT_COMMON_PROPERTY_APP_NAME;
/// Operating system version attribute key.
extern NSString * const FT_COMMON_PROPERTY_OS_VERSION;
/// Operating system major version attribute key.
extern NSString * const FT_COMMON_PROPERTY_OS_VERSION_MAJOR;
/// Sign-in state attribute key whose value indicates whether the user is registered.
extern NSString * const FT_IS_SIGNIN;
/// Operating system information attribute key.
extern NSString * const FT_COMMON_PROPERTY_OS;
/// Mobile device vendor attribute key.
extern NSString * const FT_COMMON_PROPERTY_DEVICE;
/// Display resolution attribute key, such as `1920*1080`.
extern NSString * const FT_COMMON_PROPERTY_DISPLAY;
/// Mobile device model attribute key.
extern NSString * const FT_COMMON_PROPERTY_DEVICE_MODEL;
/// Screen resolution attribute key.
extern NSString * const FT_SCREEN_SIZE;
/// CPU architecture attribute key, such as `arm64`.
extern NSString * const FT_CPU_ARCH;
/// Device UUID attribute key.
extern NSString * const FT_COMMON_PROPERTY_DEVICE_UUID;
/// Application UUID attribute key.
extern NSString * const FT_APPLICATION_UUID;
/// Application environment attribute key.
extern NSString * const FT_ENV;
/// Application version attribute key.
extern NSString * const FT_VERSION;
#pragma mark ========== rum ==========
/// Duration field key, reported in nanoseconds for RUM timing metrics.
extern NSString * const FT_DURATION;
/// Terminal type value for app data.
extern NSString * const FT_TERMINAL_APP;
/// RUM application identifier attribute key.
extern NSString * const FT_APP_ID;

#pragma mark ---------- session ----------
/// RUM session identifier attribute key.
extern NSString * const FT_RUM_KEY_SESSION_ID;
/// RUM session type attribute key.
extern NSString * const FT_RUM_KEY_SESSION_TYPE;
/// Timestamp key for the error that triggered on-error session sampling.
extern NSString * const FT_SESSION_ERROR_TIMESTAMP;
/// Flag key indicating whether the session was sampled by on-error RUM sampling.
extern NSString * const FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION;
/// RUM on-error session sample rate field key.
extern NSString * const FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE;
/// Session Replay on-error sample rate field key.
extern NSString * const FT_RUM_SESSION_REPLAY_ON_ERROR_SAMPLE_RATE;
/// RUM session sample rate field key.
extern NSString * const FT_RUM_SESSION_SAMPLE_RATE;
/// Session Replay sample rate field key.
extern NSString * const FT_RUM_SESSION_REPLAY_SAMPLE_RATE;
/// Flag key indicating whether the session was sampled by on-error RUM sampling.
extern NSString * const FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION;
/// Flag key indicating whether Session Replay was sampled by on-error sampling.
extern NSString * const FT_RUM_KEY_SAMPLED_FOR_ERROR_REPLAY;
#pragma mark ---------- view ----------
#pragma mark --- tag
/// View active-state field key.
extern NSString * const FT_KEY_IS_ACTIVE;
/// View identifier attribute key.
extern NSString * const FT_KEY_VIEW_ID;
/// View referrer attribute key.
extern NSString * const FT_KEY_VIEW_REFERRER;
/// View name attribute key.
extern NSString * const FT_KEY_VIEW_NAME;
#pragma mark --- field
/// View loading time field key.
extern NSString * const FT_KEY_LOADING_TIME;
/// Time-spent field key for session or view duration.
extern NSString * const FT_KEY_TIME_SPENT;
/// View error count field key.
extern NSString * const FT_KEY_VIEW_ERROR_COUNT;
/// View update count field key.
extern NSString * const FT_KEY_VIEW_UPDATE_TIME;
/// View resource count field key.
extern NSString * const FT_KEY_VIEW_RESOURCE_COUNT;
/// View long-task count field key.
extern NSString * const FT_KEY_VIEW_LONG_TASK_COUNT;
/// View action count field key.
extern NSString * const FT_KEY_VIEW_ACTION_COUNT;
/// View long-task duration ratio field key.
extern NSString * const FT_KEY_VIEW_LONG_TASK_RATE;
#pragma mark --- monitor field
/// View page average CPU tick count per second
extern NSString * const FT_CPU_TICK_COUNT_PER_SECOND;
/// View page CPU tick count
extern NSString * const FT_CPU_TICK_COUNT;
/// Page memory usage average
extern NSString * const FT_MEMORY_AVG;
/// Page memory peak
extern NSString * const FT_MEMORY_MAX;
/// Page minimum frames per second
extern NSString * const FT_FPS_MINI;
/// Page average frames per second
extern NSString * const FT_FPS_AVG;

/// Network connection type attribute key.
extern NSString * const FT_NETWORK_TYPE;

#pragma mark ---------- resource ----------
#pragma mark --- tag
/// Resource request identifier attribute key.
extern NSString * const FT_KEY_RESOURCE_ID;
/// Resource URL attribute key.
extern NSString * const FT_KEY_RESOURCE_URL;
/// Resource URL host attribute key.
extern NSString * const FT_KEY_RESOURCE_URL_HOST;
/// Resource URL path attribute key.
extern NSString * const FT_KEY_RESOURCE_URL_PATH;
/// Resource URL query attribute key.
extern NSString * const FT_KEY_RESOURCE_URL_QUERY;
/// Resource URL path grouping attribute key.
extern NSString * const FT_KEY_RESOURCE_URL_PATH_GROUP;
/// Resource type attribute key.
extern NSString * const FT_KEY_RESOURCE_TYPE;
/// Resource WebSocket collection-level attribute key.
extern NSString * const FT_KEY_RESOURCE_WEBSOCKET_COLLECTION_LEVEL;
/// Resource WebSocket opening-handshake state attribute key.
extern NSString * const FT_KEY_RESOURCE_WEBSOCKET_HANDSHAKE_STATE;
/// Resource request method attribute key.
extern NSString * const FT_KEY_RESOURCE_METHOD;
/// Resource response status attribute key.
extern NSString * const FT_KEY_RESOURCE_STATUS;
/// Resource response status-group attribute key.
extern NSString * const FT_KEY_RESOURCE_STATUS_GROUP;
/// Response `Connection` header attribute key.
extern NSString * const FT_KEY_RESPONSE_CONNECTION;
/// Response `Content-Type` header attribute key.
extern NSString * const FT_KEY_RESPONSE_CONTENT_TYPE;
/// Response `Content-Encoding` header attribute key.
extern NSString * const FT_KEY_RESPONSE_CONTENT_ENCODING;
/// Resource target IP address attribute key.
extern NSString * const FT_KEY_RESOURCE_HOST_IP;
#pragma mark --- field
/// Resource payload size field key.
extern NSString * const FT_KEY_RESOURCE_SIZE;
/// Resource DNS lookup duration field key.
extern NSString * const FT_KEY_RESOURCE_DNS;
/// Resource TCP connection duration field key.
extern NSString * const FT_KEY_RESOURCE_TCP;
/// Resource SSL handshake duration field key.
extern NSString * const FT_KEY_RESOURCE_SSL;
/// Resource time-to-first-byte duration field key.
extern NSString * const FT_KEY_RESOURCE_TTFB;
/// Resource content transfer duration field key.
extern NSString * const FT_KEY_RESOURCE_TRANS;
/// Resource first-byte duration field key.
extern NSString * const FT_KEY_RESOURCE_FIRST_BYTE;
/// Resource response header field key.
extern NSString * const FT_KEY_RESPONSE_HEADER;
/// Resource request header field key.
extern NSString * const FT_KEY_REQUEST_HEADER;
/// Start offset key inside resource timing phase objects.
extern NSString * const FT_KEY_START;
/// Resource DNS timing phase field key.
extern NSString * const FT_KEY_RESOURCE_DNS_TIME;
/// Resource SSL timing phase field key.
extern NSString * const FT_KEY_RESOURCE_SSL_TIME;
/// Resource download timing phase field key.
extern NSString * const FT_KEY_RESOURCE_DOWNLOAD_TIME;
/// Resource first-byte timing phase field key.
extern NSString * const FT_KEY_RESOURCE_FIRST_BYTE_TIME;
/// Resource connection timing phase field key.
extern NSString * const FT_KEY_RESOURCE_CONNECT_TIME;
/// Resource redirect timing phase field key.
extern NSString * const FT_KEY_RESOURCE_REDIRECT_TIME;
/// Resource HTTP protocol field key.
extern NSString * const FT_KEY_RESOURCE_HTTP_PROTOCOL;
/// Resource request size field key.
extern NSString * const FT_KEY_RESOURCE_REQUEST_SIZE;
/// Resource connection-reuse field key.
extern NSString * const FT_KEY_RESOURCE_CONNECTION_REUSE;
/// Network availability field key captured when the resource starts.
extern NSString * const FT_KEY_NETWORK_AVAILABLE;
/// Resource type value for a WebSocket opening handshake.
extern NSString * const FT_RESOURCE_TYPE_WEBSOCKET;
/// WebSocket collection-level value for opening-handshake-only Resources.
extern NSString * const FT_RESOURCE_WEBSOCKET_COLLECTION_LEVEL_HANDSHAKE;
/// WebSocket opening-handshake success value.
extern NSString * const FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_SUCCESS;
/// WebSocket opening-handshake HTTP rejection value.
extern NSString * const FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_REJECTED;
/// WebSocket opening-handshake transport or protocol failure value.
extern NSString * const FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_FAILED;
#pragma mark --- trace link tag
/// Trace identifier attribute key used to link Resource data with tracing.
extern NSString * const FT_KEY_TRACEID;
/// Span identifier attribute key used to link Resource data with tracing.
extern NSString * const FT_KEY_SPANID;

#pragma mark ---------- error ----------
#pragma mark --- tag
/// Error source attribute key.
extern NSString * const FT_KEY_ERROR_SOURCE;
/// Error type attribute key.
extern NSString * const FT_KEY_ERROR_TYPE;
/// Error situation attribute key, such as startup or runtime.
extern NSString * const FT_KEY_ERROR_SITUATION;
#pragma mark --- field
/// Error message field key.
extern NSString * const FT_KEY_ERROR_MESSAGE;
/// Error stack field key.
extern NSString * const FT_KEY_ERROR_STACK;
/// Foreground crash-free duration field key.
extern NSString * const FT_KEY_FOREGROUND_CRASH_FREE_DURATION;
/// Background crash-free duration field key.
extern NSString * const FT_KEY_BACKGROUND_CRASH_FREE_DURATION;
#pragma mark --- error monitor tag
/// Total memory monitor attribute key.
extern NSString * const FT_MEMORY_TOTAL;
/// Memory usage monitor attribute key.
extern NSString * const FT_MEMORY_USE;
/// CPU usage monitor attribute key.
extern NSString * const FT_CPU_USE;
/// Battery usage monitor attribute key.
extern NSString * const FT_BATTERY_USE;
/// Carrier attribute key for error monitor data.
extern NSString * const FT_KEY_CARRIER;
/// Locale attribute key for error monitor data.
extern NSString * const FT_KEY_LOCALE;

/// Error source value for logger-originated errors.
extern NSString * const FT_LOGGER;
/// Error source value for network-originated errors.
extern NSString * const FT_NETWORK;
/// Error type value for network request failures.
extern NSString * const FT_NETWORK_ERROR;
#pragma mark ---------- long task ----------
/// Long-task stack field key.
extern NSString * const FT_KEY_LONG_TASK_STACK;
#pragma mark ---------- action ----------
#pragma mark --- tag
/// Action identifier attribute key.
extern NSString * const FT_KEY_ACTION_ID;
/// Action name attribute key.
extern NSString * const FT_KEY_ACTION_NAME;
/// Action type attribute key.
extern NSString * const FT_KEY_ACTION_TYPE;
/// Action type value for click actions.
extern NSString * const FT_KEY_ACTION_TYPE_CLICK;
/// Action type value for hot launch actions.
extern NSString * const FT_LAUNCH_HOT;
/// Action type value for cold launch actions.
extern NSString * const FT_LAUNCH_COLD;
/// Action type value for warm launch actions.
extern NSString * const FT_LAUNCH_WARM;

#pragma mark --- field
/// Action long-task count field key.
extern NSString * const FT_KEY_ACTION_LONG_TASK_COUNT;
/// Action resource count field key.
extern NSString * const FT_KEY_ACTION_RESOURCE_COUNT;
/// Action error count field key.
extern NSString * const FT_KEY_ACTION_ERROR_COUNT;
/// App first-frame render timing phase field key.
extern NSString * const FT_KEY_LAUNCH_FIRST_FRAME_RENDER_TIME;
/// App application initialization timing phase field key.
extern NSString * const FT_KEY_LAUNCH_APP_INIT_TIME;
/// App UIKit initialization timing phase field key.
extern NSString * const FT_KEY_LAUNCH_UIKITI_INIT_TIME;
/// App pre-runtime initialization timing phase field key.
extern NSString * const FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME;
/// App runtime initialization timing phase field key.
extern NSString * const FT_KEY_LAUNCH_RUNTIME_INIT_TIME;
/// Cold launch role field key.
extern NSString * const FT_KEY_APP_LAUNCH_TYPE;
/// Cold launch role value for foreground launches.
extern NSString * const FT_APP_LAUNCH_TYPE_FOREGROUND;
/// Cold launch role value for background launches.
extern NSString * const FT_APP_LAUNCH_TYPE_BACKGROUND;

#pragma mark ========== Session Replay ==========
/// Flag key indicating whether the current session has associated Session Replay data.
extern NSString * const FT_SESSION_HAS_REPLAY;
/// Session Replay statistics field key.
extern NSString * const FT_SESSION_REPLAY_STATS;
/// Session Replay record count field key.
extern NSString * const FT_RECORDS_COUNT;
/// Session Replay segment count field key.
extern NSString * const FT_SEGMENTS_COUNT;
/// Total raw size field key for Session Replay segments.
extern NSString * const FT_SEGMENTS_TOTAL_RAW_SIZE;
/// Linkage key used to bind Session Replay data to RUM context.
extern NSString * const FT_LINK_RUM_KEYS;

#pragma mark ========== logging ==========
/// Log status field key.
extern NSString * const FT_KEY_STATUS;
/// Log content field key.
extern NSString * const FT_KEY_CONTENT;
/// Log message field key.
extern NSString * const FT_KEY_MESSAGE;

/// RUM custom property key-list field key.
extern NSString * const FT_RUM_CUSTOM_KEYS;
#pragma mark ========== tracing ==========
/// Zipkin B3 trace identifier header key.
extern NSString * const FT_NETWORK_ZIPKIN_TRACEID;
/// Zipkin B3 span identifier header key.
extern NSString * const FT_NETWORK_ZIPKIN_SPANID;
/// Zipkin B3 parent span identifier header key.
extern NSString * const FT_NETWORK_ZIPKIN_PARENTSPANID;
/// Zipkin B3 sampled header key.
extern NSString * const FT_NETWORK_ZIPKIN_SAMPLED;
/// SkyWalking v3 propagation header key.
extern NSString * const FT_NETWORK_SKYWALKING_V3;
/// SkyWalking v2 propagation header key.
extern NSString * const FT_NETWORK_SKYWALKING_V2;
/// Jaeger propagation header key.
extern NSString * const FT_NETWORK_JAEGER_TRACEID;
/// Datadog trace identifier header key.
extern NSString * const FT_NETWORK_DDTRACE_TRACEID;
/// Datadog parent span identifier header key.
extern NSString * const FT_NETWORK_DDTRACE_SPANID;
/// Datadog origin header key.
extern NSString * const FT_NETWORK_DDTRACE_ORIGIN;
/// Datadog sampled header key.
extern NSString * const FT_NETWORK_DDTRACE_SAMPLED;
/// Datadog sampling priority header key.
extern NSString * const FT_NETWORK_DDTRACE_SAMPLING_PRIORITY;
/// W3C Trace Context `traceparent` header key.
extern NSString * const FT_NETWORK_TRACEPARENT_KEY;
/// Zipkin single-header B3 propagation key.
extern NSString * const FT_NETWORK_ZIPKIN_SINGLE_KEY;

#pragma mark ========== user info key ==========
/// User identifier attribute key.
extern NSString * const FT_USER_ID;
/// User email attribute key.
extern NSString * const FT_USER_EMAIL;
/// User name attribute key.
extern NSString * const FT_USER_NAME;
/// User extra attributes key.
extern NSString * const FT_USER_EXTRA;
