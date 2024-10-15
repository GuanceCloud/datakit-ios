//
//  NSError+FTDescription.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/27.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "NSError+FTDescription.h"
@implementation NSError (FTDescription)
- (NSString *)ft_description{
    if(self.domain == NSURLErrorDomain){
        return [self ft_URLErrorDomainErrorDescription];
    }
    if(self.domain == NSPOSIXErrorDomain){
        return [self ft_POSIXErrorDomainErrorDescription];
    }
    return self.localizedDescription;
}
- (NSString *)ft_URLErrorDomainErrorDescription{
    switch (self.code) {
        case NSURLErrorUnknown: return @"The URL Loading System encountered an error that it can’t interpret.";
        case NSURLErrorCancelled: return @"An asynchronous load has been canceled.";
        case NSURLErrorBadURL: return @"A malformed URL prevented a URL request from being initiated.";
        case NSURLErrorTimedOut: return @"An asynchronous operation timed out.";
        case NSURLErrorUnsupportedURL: return @"A properly formed URL couldn’t be handled by the framework.";
        case NSURLErrorCannotFindHost: return @"The host name for a URL couldn’t be resolved.";
        case NSURLErrorCannotConnectToHost: return @"An attempt to connect to a host failed.";
        case NSURLErrorNetworkConnectionLost: return @"A client or server connection was severed in the middle of an in-progress load.";
        case NSURLErrorDNSLookupFailed: return @"The host address couldn’t be found via DNS lookup.";
        case NSURLErrorHTTPTooManyRedirects: return @"A redirect loop was detected or the threshold for number of allowable redirects was exceeded (currently 16).";
        case NSURLErrorResourceUnavailable: return @"A requested resource couldn’t be retrieved.";
        case NSURLErrorNotConnectedToInternet: return @"A network resource was requested, but an internet connection has not been established and can’t be established automatically.";
        case NSURLErrorRedirectToNonExistentLocation: return @"A redirect was specified by way of server response code, but the server didn’t accompany this code with a redirect URL.";
        case NSURLErrorBadServerResponse: return @"The URL Loading System received bad data from the server.";
        case NSURLErrorUserCancelledAuthentication: return @"An asynchronous request for authentication has been canceled by the user.";
        case NSURLErrorUserAuthenticationRequired: return @"Authentication was required to access a resource.";
        case NSURLErrorZeroByteResource: return @"A server reported that a URL has a non-zero content length, but terminated the network connection gracefully without sending any data.";
        case NSURLErrorCannotDecodeRawData: return @"Content data received during a connection request couldn’t be decoded for a known content encoding.";
        case NSURLErrorCannotDecodeContentData: return @"Content data received during a connection request had an unknown content encoding.";
        case NSURLErrorCannotParseResponse: return @"A response to a connection request couldn’t be parsed.";
        case NSURLErrorAppTransportSecurityRequiresSecureConnection: return @"App Transport Security disallowed a connection because there is no secure network connection.";
        case NSURLErrorFileDoesNotExist: return @"The specified file doesn’t exist.";
        case NSURLErrorFileIsDirectory: return @"A request for an FTP file resulted in the server responding that the file is not a plain file, but a directory.";
        case NSURLErrorNoPermissionsToReadFile: return @"A resource couldn’t be read because of insufficient permissions.";
        case NSURLErrorDataLengthExceedsMaximum: return @"The length of the resource data exceeded the maximum allowed.";
        case NSURLErrorFileOutsideSafeArea: return @"An internal file operation failed.";
        case NSURLErrorSecureConnectionFailed: return @"An attempt to establish a secure connection failed for reasons that can’t be expressed more specifically.";
        case NSURLErrorServerCertificateHasBadDate: return @"A server certificate is expired, or is not yet valid.";
        case NSURLErrorServerCertificateUntrusted: return @"A server certificate was signed by a root server that isn’t trusted.";
        case NSURLErrorServerCertificateHasUnknownRoot: return @"A server certificate wasn’t signed by any root server.";
        case NSURLErrorServerCertificateNotYetValid: return @"A server certificate isn’t valid yet.";
        case NSURLErrorClientCertificateRejected: return @"A server certificate was rejected.";
        case NSURLErrorClientCertificateRequired: return @"A client certificate was required to authenticate an SSL connection during a connection request.";
        case NSURLErrorCannotLoadFromNetwork: return @"A specific request to load an item only from the cache couldn't be satisfied.";
        case NSURLErrorCannotCreateFile: return @"A download task couldn’t create the downloaded file on disk because of an I/O failure.";
        case NSURLErrorCannotOpenFile: return @"A downloaded file on disk couldn’t be opened.";
        case NSURLErrorCannotCloseFile: return @"A download task couldn’t close the downloaded file on disk.";
        case NSURLErrorCannotWriteToFile: return @"A download task couldn’t write the file to disk.";
        case NSURLErrorCannotRemoveFile: return @"A downloaded file couldn’t be removed from disk.";
        case NSURLErrorCannotMoveFile: return @"A downloaded file on disk couldn’t be moved.";
        case NSURLErrorDownloadDecodingFailedMidStream: return @"A download task failed to decode an encoded file during the download.";
        case NSURLErrorDownloadDecodingFailedToComplete: return @"A download task failed to decode an encoded file after downloading.";
        case NSURLErrorInternationalRoamingOff: return @"The attempted connection required activating a data context while roaming, but international roaming is disabled.";
        case NSURLErrorCallIsActive: return @"A connection was attempted while a phone call was active on a network that doesn’t support simultaneous phone and data communication, such as EDGE or GPRS.";
        case NSURLErrorDataNotAllowed: return @"The cellular network disallowed a connection.";
        case NSURLErrorRequestBodyStreamExhausted: return @"A body stream was needed but the client did not provide one.";
        case NSURLErrorBackgroundSessionRequiresSharedContainer: return @"The shared container identifier of the URL session configuration is needed but hasn’t been set.";
        case NSURLErrorBackgroundSessionInUseByAnotherProcess: return @"An app or app extension attempted to connect to a background session that is already connected to a process.";
        case NSURLErrorBackgroundSessionWasDisconnected: return @"The app is suspended or exits while a background data task is processing.";
        default: return self.localizedDescription;
    }
}
- (NSString *)ft_POSIXErrorDomainErrorDescription{
    switch (self.code) {
        case EPERM: return @"Operation not permitted.";
        case ENOENT: return @"No such file or directory.";
        case ESRCH: return @"No such process.";
        case EINTR: return @"Interrupted system call.";
        case EIO: return @"Input/output error.";
        case ENXIO: return @"Device not configured.";
        case E2BIG: return @"Argument list too long.";
        case ENOEXEC: return @"Exec format error.";
        case EBADF: return @"Bad file descriptor.";
        case ECHILD: return @"No child processes.";
        case EDEADLK: return @"Resource deadlock avoided.";
        case ENOMEM: return @"Cannot allocate memory.";
        case EACCES: return @"Permission denied.";
        case EFAULT: return @"Bad address.";
        case ENOTBLK: return @"Block device required.";
        case EBUSY: return @"Device / Resource busy.";
        case EEXIST: return @"File exists.";
        case EXDEV: return @"Cross-device link.";
        case ENODEV: return @"Operation not supported by device.";
        case ENOTDIR: return @"Not a directory.";
        case EISDIR: return @"Is a directory.";
        case EINVAL: return @"Invalid argument.";
        case ENFILE: return @"Too many open files in system.";
        case EMFILE: return @"Too many open files.";
        case ENOTTY: return @"Inappropriate ioctl for device.";
        case ETXTBSY: return @"Text file busy.";
        case EFBIG: return @"File too large.";
        case ENOSPC: return @"No space left on device.";
        case ESPIPE: return @"Illegal seek.";
        case EROFS: return @"Read-only file system.";
        case EMLINK: return @"Too many links.";
        case EPIPE: return @"Broken pipe.";
        case EDOM: return @"Numerical argument out of domain.";
        case ERANGE: return @"Result too large.";
        case EAGAIN: return @"Resource temporarily unavailable.";
        case EINPROGRESS: return @"Operation now in progress.";
        case EALREADY: return @"Operation already in progress.";
        case ENOTSOCK: return @"Socket operation on non-socket.";
        case EDESTADDRREQ: return @"Destination address required.";
        case EMSGSIZE: return @"Message too long.";
        case EPROTOTYPE: return @"Protocol wrong type for socket.";
        case ENOPROTOOPT: return @"Protocol not available.";
        case EPROTONOSUPPORT: return @"Protocol not supported.";
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
        case ESOCKTNOSUPPORT: return @"Socket type not supported.";
#endif
        case ENOTSUP: return @"Operation not supported.";
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
        case EPFNOSUPPORT: return @"Protocol family not supported.";
#endif
        case EAFNOSUPPORT: return @"Address family not supported by protocol family.";
        case EADDRINUSE: return @"Address already in use.";
        case EADDRNOTAVAIL: return @"Can't assign requested address.";
        case ENETDOWN: return @"Network is down.";
        case ENETUNREACH: return @"Network is unreachable.";
        case ENETRESET: return @"Network dropped connection on reset.";
        case ECONNABORTED: return @"Software caused connection abort.";
        case ECONNRESET: return @"Connection reset by peer.";
        case ENOBUFS: return @"No buffer space available.";
        case EISCONN: return @"Socket is already connected.";
        case ENOTCONN: return @"Socket is not connected.";
            
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
        case ESHUTDOWN: return @"Can't send after socket shutdown.";
        case ETOOMANYREFS: return @"Too many references: can't splice.";
#endif
        case ETIMEDOUT: return @"Operation timed out.";
        case ECONNREFUSED: return @"Connection refused.";
        case ELOOP: return @"Too many levels of symbolic links.";
        case ENAMETOOLONG: return @"File name too long.";
            
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
        case EHOSTDOWN: return @"Host is down.";
#endif
            
        case EHOSTUNREACH: return @"No route to host.";
        case ENOTEMPTY: return @"Directory not empty.";
            
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
        case EPROCLIM: return @"Too many processes.";
        case EUSERS: return @"Too many users.";
#endif
            
        case EDQUOT: return @"Disc quota exceeded.";
        case ESTALE: return @"Stale NFS file handle.";
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
        case EREMOTE:
            return @"Too many levels of remote in path.";
        case EBADRPC:
            return @"RPC struct is bad.";
        case ERPCMISMATCH:
            return @"RPC version wrong.";
        case EPROGUNAVAIL:
            return @"RPC prog. not avail.";
        case EPROGMISMATCH:
            return @"Program version wrong.";
        case EPROCUNAVAIL:
            return @"Bad procedure for program.";
#endif
        case ENOLCK:
            return @"No locks available.";
        case ENOSYS:
            return @"Function not implemented.";
            
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
        case EFTYPE:
            return @"Inappropriate file type or format.";
        case EAUTH:
            return @"Authentication error.";
        case ENEEDAUTH:
            return @"Need authenticator.";
        case EPWROFF:
            return @"Device power is off.";
        case EDEVERR:
            return @"Device error, e.g. paper out.";
#endif
        case EOVERFLOW:
            return @"Value too large to be stored in data type.";
            
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
        case EBADEXEC:
            return @"Bad executable.";
        case EBADARCH:
            return @"Bad CPU type in executable.";
        case ESHLIBVERS:
            return @"Shared library version mismatch.";
        case EBADMACHO:
            return @"Malformed Macho file.";
#endif
        case ECANCELED:
            return @"Operation canceled.";
        case EIDRM:
            return @"Identifier removed.";
        case ENOMSG:
            return @"No message of desired type.";
        case EILSEQ:
            return @"Illegal byte sequence.";
            
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
        case ENOATTR:
            return @"Attribute not found.";
#endif
        case EBADMSG:
            return @"Bad message.";
        case EMULTIHOP:
            return @"Reserved.";
        case ENODATA:
            return @"No message available on STREAM.";
        case ENOLINK:
            return @"Reserved.";
        case ENOSR:
            return @"No STREAM resources.";
        case ENOSTR:
            return @"Not a STREAM.";
        case EPROTO:
            return @"Protocol error.";
        case ETIME:
            return @"STREAM ioctl timeout.";
            
#if __DARWIN_UNIX03 || defined(KERNEL)
        case EOPNOTSUPP:
            return @"Operation not supported on socket.";
#endif /* __DARWIN_UNIX03 || KERNEL */
            
        case ENOPOLICY:
            return @"No such policy registered.";
            
#if __DARWIN_C_LEVEL >= 200809L
        case ENOTRECOVERABLE:
            return @"State not recoverable.";
        case EOWNERDEAD:
            return @"Previous owner died.";
#endif
        default: return self.localizedDescription;
    }
}
@end
