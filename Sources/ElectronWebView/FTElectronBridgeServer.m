//
//  FTElectronBridgeServer.m
//  GuanceElectronWebView
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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

#import <TargetConditionals.h>

#if TARGET_OS_OSX

#import "FTElectronBridgeServer.h"
#import "FTElectronWebViewHandler.h"
#import "FTInnerLog.h"

#import <dispatch/dispatch.h>
#import <errno.h>
#import <fcntl.h>
#import <sys/socket.h>
#import <sys/stat.h>
#import <sys/un.h>
#import <unistd.h>
#import <string.h>

NSString *const FTElectronBridgeSocketPathEnvironmentKey =
    @"GUANCE_ELECTRON_SOCKET_PATH";
NSString *const FTElectronBridgeAuthenticationTokenEnvironmentKey =
    @"GUANCE_ELECTRON_AUTH_TOKEN";
NSString *const FTElectronBridgeProtocolVersionEnvironmentKey =
    @"GUANCE_ELECTRON_PROTOCOL_VERSION";

static NSString *const FTElectronBridgeServerErrorDomain =
    @"com.guance.electron.bridge-server";
static const NSInteger FTElectronBridgeProtocolVersion = 1;
static const NSUInteger FTElectronBridgeMaximumEnvelopeBytes = 2 * 1024 * 1024;

typedef NS_ENUM(NSInteger, FTElectronBridgeServerErrorCode) {
    FTElectronBridgeServerErrorInvalidSocketPath = 1,
    FTElectronBridgeServerErrorSocketCreation = 2,
    FTElectronBridgeServerErrorSocketBind = 3,
    FTElectronBridgeServerErrorSocketListen = 4,
};

static NSError *FTElectronBridgeServerError(
    FTElectronBridgeServerErrorCode code,
    NSString *message
) {
    return [NSError errorWithDomain:FTElectronBridgeServerErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static BOOL FTElectronBridgeSetNonBlocking(int descriptor) {
    int flags = fcntl(descriptor, F_GETFL, 0);
    return flags >= 0 && fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0;
}

@interface FTElectronBridgeServer ()
@property (nonatomic, strong) dispatch_queue_t serverQueue;
@property (nonatomic, strong, nullable) dispatch_source_t acceptSource;
@property (nonatomic, strong, nullable) dispatch_source_t readSource;
@property (nonatomic, assign) int listenDescriptor;
@property (nonatomic, assign) int clientDescriptor;
@property (nonatomic, assign) BOOL runningStorage;
@property (nonatomic, copy, nullable) NSString *socketPathStorage;
@property (nonatomic, copy, nullable) NSString *authenticationTokenStorage;
@property (nonatomic, copy, nullable) NSString *connectionID;
@property (nonatomic, strong) NSMutableData *readBuffer;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *remoteWebContentsIDs;
@property (nonatomic, assign) BOOL authenticated;
@property (nonatomic, assign) int64_t expectedSequence;
@end

@implementation FTElectronBridgeServer

- (instancetype)init {
    self = [super init];
    if (self) {
        _serverQueue = dispatch_queue_create(
            "com.guance.electron.bridge-server",
            DISPATCH_QUEUE_SERIAL
        );
        _listenDescriptor = -1;
        _clientDescriptor = -1;
        _readBuffer = [NSMutableData data];
        _remoteWebContentsIDs = [NSMutableSet set];
        _expectedSequence = 1;
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

- (BOOL)isRunning {
    __block BOOL running = NO;
    dispatch_sync(self.serverQueue, ^{
        running = self.runningStorage;
    });
    return running;
}

- (nullable NSString *)socketPath {
    __block NSString *value = nil;
    dispatch_sync(self.serverQueue, ^{
        value = [self.socketPathStorage copy];
    });
    return value;
}

- (nullable NSString *)authenticationToken {
    __block NSString *value = nil;
    dispatch_sync(self.serverQueue, ^{
        value = [self.authenticationTokenStorage copy];
    });
    return value;
}

- (BOOL)startWithError:(NSError * _Nullable * _Nullable)error {
    __block BOOL result = NO;
    __block NSError *startError = nil;
    dispatch_sync(self.serverQueue, ^{
        if (self.runningStorage) {
            result = YES;
            return;
        }

        NSString *identifier = [[NSUUID UUID].UUIDString
            stringByReplacingOccurrencesOfString:@"-" withString:@""];
        identifier = [identifier substringToIndex:12];
        NSString *socketPath = [NSTemporaryDirectory()
            stringByAppendingPathComponent:[NSString stringWithFormat:
                @"gce-%d-%@.sock", getpid(), identifier]];
        const char *fileSystemPath = socketPath.fileSystemRepresentation;
        if (!fileSystemPath || strlen(fileSystemPath) >=
                sizeof(((struct sockaddr_un *)0)->sun_path)) {
            startError = FTElectronBridgeServerError(
                FTElectronBridgeServerErrorInvalidSocketPath,
                @"The generated Electron Bridge socket path is too long"
            );
            return;
        }

        int descriptor = socket(AF_UNIX, SOCK_STREAM, 0);
        if (descriptor < 0 || !FTElectronBridgeSetNonBlocking(descriptor)) {
            if (descriptor >= 0) {
                close(descriptor);
            }
            startError = FTElectronBridgeServerError(
                FTElectronBridgeServerErrorSocketCreation,
                @"Could not create the Electron Bridge socket"
            );
            return;
        }

        int noSignal = 1;
        setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &noSignal,
            sizeof(noSignal)
        );
        unlink(fileSystemPath);

        struct sockaddr_un address;
        memset(&address, 0, sizeof(address));
        address.sun_family = AF_UNIX;
        strlcpy(address.sun_path, fileSystemPath, sizeof(address.sun_path));
        if (bind(
                descriptor,
                (const struct sockaddr *)&address,
                (socklen_t)SUN_LEN(&address)
            ) != 0) {
            close(descriptor);
            startError = FTElectronBridgeServerError(
                FTElectronBridgeServerErrorSocketBind,
                @"Could not bind the Electron Bridge socket"
            );
            return;
        }
        chmod(fileSystemPath, S_IRUSR | S_IWUSR);
        if (listen(descriptor, 1) != 0) {
            close(descriptor);
            unlink(fileSystemPath);
            startError = FTElectronBridgeServerError(
                FTElectronBridgeServerErrorSocketListen,
                @"Could not listen on the Electron Bridge socket"
            );
            return;
        }

        self.listenDescriptor = descriptor;
        self.socketPathStorage = socketPath;
        self.authenticationTokenStorage = [NSUUID UUID].UUIDString;
        self.runningStorage = YES;

        __weak typeof(self) weakSelf = self;
        self.acceptSource = dispatch_source_create(
            DISPATCH_SOURCE_TYPE_READ,
            (uintptr_t)descriptor,
            0,
            self.serverQueue
        );
        dispatch_source_set_event_handler(self.acceptSource, ^{
            [weakSelf acceptConnections];
        });
        dispatch_resume(self.acceptSource);

        [[FTElectronWebViewHandler sharedInstance]
            startWithCommandHandler:^(int64_t webContentsID,
                                      NSString *command) {
                [weakSelf sendCommand:command
                        webContentsID:webContentsID];
            }];
        FTInnerLogInfo(@"[ElectronBridgeServer] listening at %@", socketPath);
        result = YES;
    });

    if (!result && error) {
        *error = startError;
    }
    return result;
}

- (void)stop {
    dispatch_sync(self.serverQueue, ^{
        if (!self.runningStorage && self.listenDescriptor < 0) {
            return;
        }
        self.runningStorage = NO;
        [self disconnectClient];
        if (self.acceptSource) {
            dispatch_source_cancel(self.acceptSource);
            self.acceptSource = nil;
        }
        if (self.listenDescriptor >= 0) {
            close(self.listenDescriptor);
            self.listenDescriptor = -1;
        }
        if (self.socketPathStorage.length > 0) {
            unlink(self.socketPathStorage.fileSystemRepresentation);
        }
        self.socketPathStorage = nil;
        self.authenticationTokenStorage = nil;
        [[FTElectronWebViewHandler sharedInstance]
            startWithCommandHandler:nil];
        FTInnerLogInfo(@"[ElectronBridgeServer] stopped");
    });
}

- (NSDictionary<NSString *, NSString *> *)environmentByAddingToEnvironment:
    (nullable NSDictionary<NSString *, NSString *> *)environment {
    NSMutableDictionary<NSString *, NSString *> *result =
        environment ? [environment mutableCopy] : [NSMutableDictionary dictionary];
    NSString *path = self.socketPath;
    NSString *token = self.authenticationToken;
    if (path.length > 0 && token.length > 0) {
        result[FTElectronBridgeSocketPathEnvironmentKey] = path;
        result[FTElectronBridgeAuthenticationTokenEnvironmentKey] = token;
        result[FTElectronBridgeProtocolVersionEnvironmentKey] =
            [NSString stringWithFormat:@"%ld",
                (long)FTElectronBridgeProtocolVersion];
    }
    return result.copy;
}

#pragma mark - Socket lifecycle

- (void)acceptConnections {
    while (self.runningStorage) {
        int descriptor = accept(self.listenDescriptor, NULL, NULL);
        if (descriptor < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                return;
            }
            FTInnerLogWarning(@"[ElectronBridgeServer] accept failed: %d", errno);
            return;
        }

        uid_t peerUser = (uid_t)-1;
        gid_t peerGroup = (gid_t)-1;
        BOOL peerAccepted = getpeereid(
            descriptor,
            &peerUser,
            &peerGroup
        ) == 0 && peerUser == geteuid();
        if (!peerAccepted || self.clientDescriptor >= 0 ||
            !FTElectronBridgeSetNonBlocking(descriptor)) {
            close(descriptor);
            continue;
        }

        int noSignal = 1;
        setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &noSignal,
            sizeof(noSignal)
        );
        self.clientDescriptor = descriptor;
        self.authenticated = NO;
        self.expectedSequence = 1;
        self.connectionID = nil;
        [self.readBuffer setLength:0];

        __weak typeof(self) weakSelf = self;
        self.readSource = dispatch_source_create(
            DISPATCH_SOURCE_TYPE_READ,
            (uintptr_t)descriptor,
            0,
            self.serverQueue
        );
        dispatch_source_set_event_handler(self.readSource, ^{
            [weakSelf readAvailableData];
        });
        dispatch_resume(self.readSource);
    }
}

- (void)disconnectClient {
    if (self.readSource) {
        dispatch_source_cancel(self.readSource);
        self.readSource = nil;
    }
    if (self.clientDescriptor >= 0) {
        close(self.clientDescriptor);
        self.clientDescriptor = -1;
    }
    FTElectronWebViewHandler *handler =
        [FTElectronWebViewHandler sharedInstance];
    for (NSNumber *webContentsID in self.remoteWebContentsIDs) {
        [handler unregisterWebContentsID:webContentsID.longLongValue];
    }
    [self.remoteWebContentsIDs removeAllObjects];
    [self.readBuffer setLength:0];
    self.authenticated = NO;
    self.expectedSequence = 1;
    self.connectionID = nil;
}

- (void)readAvailableData {
    uint8_t bytes[8192];
    while (self.clientDescriptor >= 0) {
        ssize_t count = read(self.clientDescriptor, bytes, sizeof(bytes));
        if (count > 0) {
            [self.readBuffer appendBytes:bytes length:(NSUInteger)count];
            if (self.readBuffer.length >
                FTElectronBridgeMaximumEnvelopeBytes) {
                FTInnerLogWarning(@"[ElectronBridgeServer] oversized envelope");
                [self disconnectClient];
                return;
            }
            [self consumeBufferedLines];
            continue;
        }
        if (count == 0) {
            [self disconnectClient];
            return;
        }
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            return;
        }
        [self disconnectClient];
        return;
    }
}

- (void)consumeBufferedLines {
    const uint8_t newline = '\n';
    while (self.clientDescriptor >= 0 && self.readBuffer.length > 0) {
        NSRange range = [self.readBuffer
            rangeOfData:[NSData dataWithBytes:&newline length:1]
                 options:0
                   range:NSMakeRange(0, self.readBuffer.length)];
        if (range.location == NSNotFound) {
            return;
        }
        if (range.location == 0 ||
            range.location > FTElectronBridgeMaximumEnvelopeBytes) {
            [self disconnectClient];
            return;
        }
        NSData *line = [self.readBuffer subdataWithRange:
            NSMakeRange(0, range.location)];
        [self.readBuffer replaceBytesInRange:
            NSMakeRange(0, range.location + 1)
                                    withBytes:NULL
                                       length:0];
        [self processLine:line];
    }
}

#pragma mark - Protocol

- (void)processLine:(NSData *)line {
    NSError *error = nil;
    id decoded = [NSJSONSerialization JSONObjectWithData:line
                                                 options:0
                                                   error:&error];
    if (error || ![decoded isKindOfClass:NSDictionary.class]) {
        [self disconnectClient];
        return;
    }
    NSDictionary *message = decoded;
    if (!self.authenticated) {
        [self processHello:message];
        return;
    }

    NSNumber *version = [message[@"protocolVersion"]
        isKindOfClass:NSNumber.class] ? message[@"protocolVersion"] : nil;
    NSString *connectionID = [message[@"connectionID"]
        isKindOfClass:NSString.class] ? message[@"connectionID"] : nil;
    NSNumber *sequence = [message[@"sequence"]
        isKindOfClass:NSNumber.class] ? message[@"sequence"] : nil;
    if (version.integerValue != FTElectronBridgeProtocolVersion ||
        ![connectionID isEqualToString:self.connectionID] ||
        sequence.longLongValue != self.expectedSequence) {
        [self disconnectClient];
        return;
    }
    self.expectedSequence += 1;

    NSString *type = [message[@"type"] isKindOfClass:NSString.class]
        ? message[@"type"] : nil;
    NSNumber *webContentsID = [message[@"webContentsID"]
        isKindOfClass:NSNumber.class] ? message[@"webContentsID"] : nil;
    BOOL success = NO;
    NSNumber *slotID = nil;

    if ([type isEqualToString:@"register"] && webContentsID.longLongValue > 0) {
        BOOL visible = [message[@"visible"]
            isKindOfClass:NSNumber.class] ? [message[@"visible"] boolValue] : YES;
        slotID = [[FTElectronWebViewHandler sharedInstance]
            registerStandaloneWebContentsID:webContentsID.longLongValue
                                     visible:visible];
        success = slotID != nil;
        if (success) {
            [self.remoteWebContentsIDs addObject:webContentsID];
        }
    } else if ([type isEqualToString:@"update"] &&
               [self.remoteWebContentsIDs containsObject:webContentsID]) {
        BOOL visible = [message[@"visible"]
            isKindOfClass:NSNumber.class] ? [message[@"visible"] boolValue] : NO;
        success = [[FTElectronWebViewHandler sharedInstance]
            updateStandaloneWebContentsID:webContentsID.longLongValue
                                   visible:visible];
    } else if ([type isEqualToString:@"event"] &&
               [self.remoteWebContentsIDs containsObject:webContentsID]) {
        NSString *payload = [message[@"payload"] isKindOfClass:NSString.class]
            ? message[@"payload"] : nil;
        success = payload.length > 0 &&
            [payload lengthOfBytesUsingEncoding:NSUTF8StringEncoding] <=
                FTElectronBridgeMaximumEnvelopeBytes &&
            [[FTElectronWebViewHandler sharedInstance]
                receiveMessageQueue:payload
                       webContentsID:webContentsID.longLongValue];
    } else if ([type isEqualToString:@"unregister"] &&
               [self.remoteWebContentsIDs containsObject:webContentsID]) {
        [[FTElectronWebViewHandler sharedInstance]
            unregisterWebContentsID:webContentsID.longLongValue];
        [self.remoteWebContentsIDs removeObject:webContentsID];
        success = YES;
    } else if ([type isEqualToString:@"ping"]) {
        success = YES;
    } else if ([type isEqualToString:@"close"]) {
        [self sendAcknowledgementForMessage:message
                                    success:YES
                                     slotID:nil];
        [self disconnectClient];
        return;
    } else {
        [self sendAcknowledgementForMessage:message
                                    success:NO
                                     slotID:nil];
        [self disconnectClient];
        return;
    }

    [self sendAcknowledgementForMessage:message
                                success:success
                                 slotID:slotID];
}

- (void)processHello:(NSDictionary *)message {
    NSString *type = [message[@"type"] isKindOfClass:NSString.class]
        ? message[@"type"] : nil;
    NSNumber *version = [message[@"protocolVersion"]
        isKindOfClass:NSNumber.class] ? message[@"protocolVersion"] : nil;
    NSString *token = [message[@"authenticationToken"]
        isKindOfClass:NSString.class] ? message[@"authenticationToken"] : nil;
    NSString *connectionID = [message[@"connectionID"]
        isKindOfClass:NSString.class] ? message[@"connectionID"] : nil;
    if (![type isEqualToString:@"hello"] ||
        version.integerValue != FTElectronBridgeProtocolVersion ||
        token.length == 0 ||
        ![token isEqualToString:self.authenticationTokenStorage] ||
        connectionID.length == 0 || connectionID.length > 128) {
        [self disconnectClient];
        return;
    }

    self.authenticated = YES;
    self.connectionID = connectionID;
    NSDictionary *configuration =
        [[FTElectronWebViewHandler sharedInstance] bridgeConfiguration];
    [self sendJSON:@{
        @"protocolVersion": @(FTElectronBridgeProtocolVersion),
        @"type": @"ready",
        @"connectionID": connectionID,
        @"configuration": configuration,
    }];
}

- (void)sendAcknowledgementForMessage:(NSDictionary *)message
                               success:(BOOL)success
                                slotID:(nullable NSNumber *)slotID {
    NSMutableDictionary *response = [@{
        @"protocolVersion": @(FTElectronBridgeProtocolVersion),
        @"type": @"ack",
        @"connectionID": self.connectionID ?: @"",
        @"sequence": message[@"sequence"] ?: @0,
        @"ok": @(success),
    } mutableCopy];
    id requestID = message[@"requestID"];
    if ([requestID isKindOfClass:NSString.class] &&
        [requestID length] <= 128) {
        response[@"requestID"] = requestID;
    }
    if (slotID) {
        response[@"slotID"] = slotID;
    }
    [self sendJSON:response];
}

- (void)sendCommand:(NSString *)command
       webContentsID:(int64_t)webContentsID {
    if (![command isEqualToString:
            FTElectronWebViewCommandTakeSubsequentFullSnapshot]) {
        return;
    }
    dispatch_async(self.serverQueue, ^{
        if (!self.authenticated ||
            ![self.remoteWebContentsIDs containsObject:@(webContentsID)]) {
            return;
        }
        [self sendJSON:@{
            @"protocolVersion": @(FTElectronBridgeProtocolVersion),
            @"type": @"command",
            @"connectionID": self.connectionID ?: @"",
            @"webContentsID": @(webContentsID),
            @"command": command,
        }];
    });
}

- (void)sendJSON:(NSDictionary *)object {
    if (self.clientDescriptor < 0) {
        return;
    }
    NSError *error = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:object
                                                   options:0
                                                     error:&error];
    if (error || json.length == 0 ||
        json.length > FTElectronBridgeMaximumEnvelopeBytes) {
        [self disconnectClient];
        return;
    }
    NSMutableData *line = [json mutableCopy];
    const uint8_t newline = '\n';
    [line appendBytes:&newline length:1];

    const uint8_t *bytes = line.bytes;
    NSUInteger offset = 0;
    while (offset < line.length) {
        ssize_t sent = send(
            self.clientDescriptor,
            bytes + offset,
            line.length - offset,
            0
        );
        if (sent > 0) {
            offset += (NSUInteger)sent;
            continue;
        }
        [self disconnectClient];
        return;
    }
}

@end

#endif
