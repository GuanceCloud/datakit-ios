//
//  FTConstants.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/13.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark ========== agent ==========
extern NSString * const FT_AGENT_MEASUREMENT;
extern NSString * const FT_AGENT_FIELD;
extern NSString * const FT_AGENT_TAGS;
extern NSString * const FT_AGENT_OPDATA;
extern NSString * const FT_AGENT_OP;
extern NSString * const FT_USER_AGENT;
extern NSString * const FT_DEFAULT_SERVICE_NAME;
extern NSString * const FT_NULL_VALUE;
#pragma mark ========== flow ==========
extern NSString * const FT_FLOW_CHART_PRODUCT;
extern NSString * const FT_KEY_DURATION;
extern NSString * const FT_FLOW_TRACEID;
extern NSString * const FT_KEY_NAME;
extern NSString * const FT_FLOW_PARENT;

#pragma mark ========== autotrack  ==========
extern NSString * const FT_AUTO_TRACK_OP_ENTER;
extern NSString * const FT_AUTO_TRACK_OP_LEAVE;
extern NSString * const FT_AUTO_TRACK_OP_CLICK;
extern NSString * const FT_AUTO_TRACK_OP_LAUNCH;
extern NSString * const FT_AUTO_TRACK_OP_VIEW;
extern NSString * const FT_TRACK_OP_CUSTOM;
extern NSString * const FT_TRACK_OP_FLOWCUSTOM;
extern NSString * const FT_AUTO_TRACK_OP_OPEN;
extern NSString * const FT_TRACK_LOGGING_EXCEPTION;
extern NSString * const FT_TRACK_LOGGING_CONSOLELOG;
extern NSString * const FT_AUTOTRACK_MEASUREMENT;
extern NSString * const FT_AUTO_TRACK_EVENT_ID;
extern NSString * const FT_AUTO_TRACK_EVENT;
extern NSString * const FT_AUTO_TRACK_ROOT_PAGE_NAME;
extern NSString * const FT_AUTO_TRACK_CURRENT_PAGE_NAME;
extern NSString * const FT_AUTO_TRACK_VTP;
extern NSString * const FT_AUTO_TRACK_VTP_ID;
extern NSString * const FT_AUTO_TRACK_VTP_DESC;
extern NSString * const FT_AUTO_TRACK_PAGE_DESC;
extern NSString * const FT_AUTO_TRACK_VTP_TREE_PATH;

#pragma mark ========== common property ==========
extern NSString * const FT_COMMON_PROPERTY_DEVICE_UUID;
extern NSString * const FT_COMMON_PROPERTY_APPLICATION_IDENTIFIER;
extern NSString * const FT_COMMON_PROPERTY_APPLICATION_NAME;
extern NSString * const FT_COMMON_PROPERTY_OS;
extern NSString * const FT_COMMON_PROPERTY_OS_VERSION;
extern NSString * const FT_COMMON_PROPERTY_DEVICE_BAND;
extern NSString * const FT_COMMON_PROPERTY_LOCALE;
extern NSString * const FT_COMMON_PROPERTY_DEVICE_MODEL;
extern NSString * const FT_COMMON_PROPERTY_DISPLAY;
extern NSString * const FT_COMMON_PROPERTY_CARRIER;
extern NSString * const FT_COMMON_PROPERTY_AGENT;
extern NSString * const FT_COMMON_PROPERTY_AUTOTRACK;

#pragma mark ========== monitor  ==========
extern NSString * const FT_MONITOR_BATTERY_TOTAL;
extern NSString * const FT_MONITOR_BATTERY_USE;
extern NSString * const FT_MONITOR_BATTERY_STATUS;

extern NSString * const FT_MONITOR_MEMORY_TOTAL;
extern NSString * const FT_MONITOR_MEMORY_USE;

extern NSString * const FT_MONITOR_CPU_NO;
extern NSString * const FT_MONITOR_CPU_HZ;
extern NSString * const FT_MONITOR_CPU_USE;
extern NSString * const FT_MONITOR_GPU_MODEL;
extern NSString * const FT_MONITOR_GPU_RATE;

extern NSString * const FT_MONITOR_CAMERA_FRONT_PX;
extern NSString * const FT_MONITOR_CAMERA_BACK_PX;

extern NSString * const FT_MONITOR_DEVICE_NAME;
extern NSString * const FT_MONITOR_DEVICE_OPEN_TIME;


extern NSString * const FT_MONITOR_PROVINCE;
extern NSString * const FT_MONITOR_CITY;
extern NSString * const FT_MONITOR_COUNTRY;
extern NSString * const FT_MONITOR_LATITUDE;
extern NSString * const FT_MONITOR_LONGITUDE;

#pragma mark ------ NETWORK -------
extern NSString * const FT_MONITOR_WITF_IP;
extern NSString * const FT_MONITOR_WITF_SSID;
extern NSString * const FT_MONITOR_NETWORK_TYPE;
extern NSString * const FT_MONITOR_NETWORK_STRENGTH;
extern NSString * const FT_MONITOR_NETWORK_IN_RATE;
extern NSString * const FT_MONITOR_NETWORK_OUT_RATE;
extern NSString * const FT_MONITOR_NETWORK_DNS_TIME;
extern NSString * const FT_MONITOR_NETWORK_TCP_TIME;
extern NSString * const FT_MONITOR_NETWORK_RESPONSE_TIME;
extern NSString * const FT_MONITOR_NETWORK_ERROR_RATE;
extern NSString * const FT_MONITOR_NETWORK_PROXY;

extern NSString * const FT_MONITOR_FT_NETWORK_DNS_TIME;
extern NSString * const FT_MONITOR_FT_NETWORK_TCP_TIME;
extern NSString * const FT_MONITOR_FT_NETWORK_RESPONSE_TIME;
extern NSString * const FT_NETWORK_REQUEST_URL;
extern NSString * const FT_NETWORK_REQUEST_CONTENT;
extern NSString * const FT_NETWORK_RESPONSE_CONTENT;
extern NSString * const FT_NETWORK_CONNECT_TIME;
extern NSString * const FT_NETWORK_DURATION_TIME;

extern NSString * const FT_MONITOR_ROTATION_X;
extern NSString * const FT_MONITOR_ROTATION_Y;
extern NSString * const FT_MONITOR_ROTATION_Z;
extern NSString * const FT_MONITOR_ACCELERATION_X;
extern NSString * const FT_MONITOR_ACCELERATION_Y;
extern NSString * const FT_MONITOR_ACCELERATION_Z;
extern NSString * const FT_MONITOR_MAGNETIC_X;
extern NSString * const FT_MONITOR_MAGNETIC_Y;
extern NSString * const FT_MONITOR_MAGNETIC_Z;
extern NSString * const FT_MONITOR_STEPS;
extern NSString * const FT_MONITOR_LIGHT;
extern NSString * const FT_MONITOR_ROAM;
extern NSString * const FT_MONITOR_GPS_OPEN;
extern NSString * const FT_MONITOR_SCREEN_BRIGHTNESS;
extern NSString * const FT_MONITOR_PROXIMITY;
extern NSString * const FT_MONITOR_FPS;
extern NSString * const FT_MONITOR_BT_OPEN;
extern NSString * const FT_MONITOR_TORCH;

#pragma mark ========== device info ==========
extern NSString *  const FTBaseInfoHanderDeviceType;
extern NSString *  const FTBaseInfoHanderDeviceCPUType;
extern NSString *  const FTBaseInfoHanderDeviceCPUClock;
extern NSString *  const FTBaseInfoHanderBatteryTotal;
extern NSString *  const FTBaseInfoHanderDeviceGPUType;
#pragma mark ========== api ==========
extern NSString *  const FTNetworkingTypeMetrics;
extern NSString *  const FTNetworkingTypeObject;
extern NSString *  const FTNetworkingTypeKeyevent;
extern NSString *  const FTNetworkingTypeLogging;

extern NSString *  const FT_NETWORKING_API_METRICS;
extern NSString *  const FT_NETWORKING_API_OBJECT;
extern NSString *  const FT_NETWORKING_API_KEYEVENT;
extern NSString *  const FT_NETWORKING_API_LOGGING;
extern NSString *  const FT_NETWORKING_API_CHECK_TOKEN;

#pragma mark ========== object、keyevent ==========
extern NSString *  const FT_KEYEVENT_MEASUREMENT;
extern NSString *  const FT_KEY_EVENTID;;
extern NSString *  const FT_KEY_SOURCE;
extern NSString *  const FT_KEY_STATUS;
extern NSString *  const FT_KEY_TAGS;
extern NSString *  const FT_KEY_CLASS;
extern NSString *  const FT_KEY_CONTENT;
extern NSString *  const FT_KEY_SERVICENAME;
extern NSString *  const FT_KEY_PARENTID;
extern NSString *  const FT_KEY_OPERATIONNAME;
extern NSString *  const FT_KEY_SPANID;
extern NSString *  const FT_KEY_ISERROR;
extern NSString *  const FT_KEY_RULEID;
extern NSString *  const FT_KEY_RULENAME;
extern NSString *  const FT_KEY_TYPE;
extern NSString *  const FT_KEY_ACTIONTYPE;
extern NSString *  const FT_KEY_TITLE;
extern NSString *  const FT_KEY_SUGGESTION;
extern NSString *  const FT_KEY_DISMENSIONS;

extern NSString *  const FT_DEFAULT_CLASS;
extern NSString *  const FT_APP_VERSION_NAME;

extern NSString *  const FT_NETWORK_ZIPKIN_TRACEID;
extern NSString *  const FT_NETWORK_ZIPKIN_SPANID;
extern NSString *  const FT_NETWORK_ZIPKIN_SAMPLED;

extern NSString *  const FT_NETWORK_JAEGER_TRACEID;

extern NSString *  const FT_NETWORK_HEADERS;
extern NSString *  const FT_NETWORK_BODY;
extern NSString *  const FT_LOGGING_CLASS_TRACING;
extern NSString *  const FT_KEY_TRUE;
extern NSString *  const FT_KET_FALSE;
extern NSString *  const FT_NETWORK_CODE;
extern NSString *  const FT_NETWORK_ERROR;
