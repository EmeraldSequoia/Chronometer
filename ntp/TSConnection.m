//
//  TSConnection.m
//  TimeSync
//
//  Created by Bill Arnett on 8/10/2008.
//  Adapted from AutoUpdate sample app
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "ECTrace.h"
#import <sys/socket.h>
#import <CoreFoundation/CFSocket.h>
#import "TSConnection.h"
#import "TSSample.h"
#import "TSTime.h"
#import "ntp_fp.h"
#import "ntp.h"
#import "ntp_unixtime.h"

#include <dispatch/dispatch.h>

@implementation TSConnection	    /////////////////////////////////////////////////////////////

static uint32_t _appSignature;

/* Action Methods */

- (TSConnection *)initWithDelegate:(TSConnectionDelegate *)del URL:(NSString *)theurl timeout:(int)timo bytesNeeded:(int)needed {
    if (self = [super init]) {
	delegate = del;
	url = theurl;
	connectionTimeOut = timo;
	bytesNeeded = needed;
	connectionRequest = [[NSURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:connectionTimeOut] retain];
	[delegate performSelector:@selector(startDone:) withObject:self];
    }
    return self;
}

- (void)getOneSample {
    [self sendTimeRequest];
}

/* Connection Management Methods */

- (void)sendTimeRequest {
    assert(false);  // overridden by TSNTPConnection
    // sample = [[TSSample alloc] init];
    // sample.myTransmitTime = [TSTime currentDateRTime];
    // connectionData = [[NSMutableData alloc] initWithCapacity:bytesNeeded];
    // [[[NSURLSession sharedSession] dataTaskWithRequest:connectionRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    //             if (error != nil) {
    //                 //printf("Unable to Connect\n");
    //                 [self endTimeConnection];
    //                 [delegate performSelector:@selector(startDone:) withObject:nil];
    //             } else {
    //                 //printf("Connecting to server '%s'\n", [url UTF8String]);
    //                 [self connection:nil didReceiveResponse:response];
    //             }
    //         }] resume];
}

- (void)cancel {
//    [timeConnection cancel];
}

- (void)stop {
    [self cancel];
    [self endTimeConnection];
}

- (void)endTimeConnection {
    [sample release];
    sample = nil;
    [connectionData release];
    connectionData = nil;
}

/* Static method */

+ (void)setAppSignature:(const char *)fourByteAppSig {
    int sigLength = strlen(fourByteAppSig);
    assert(sigLength <= 4 && sigLength > 0);
    _appSignature = fourByteAppSig[0] << 24;
    if (sigLength > 1) {
        _appSignature |= fourByteAppSig[1] << 16;
        if (sigLength > 2) {
            _appSignature |= fourByteAppSig[2] << 8;
            if (sigLength > 3) {
                _appSignature |= fourByteAppSig[3];
            }
        }
    }
    _appSignature = htonl(_appSignature);
}

/* NSURLConnection Delegate Methods */

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    sample.myReceiveTime = [TSTime currentDateRTime];
    [connectionData setLength:0];
    //printf("Connected to server '%s'\n", [url UTF8String]);
    [delegate performSelector:@selector(startDone:) withObject:self];	    // success
}


/*
 - (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [connectionData appendData:data];
    //printf("didReceiveData %d bytes\n", data.length);
    if (connectionData.length >= bytesNeeded) {
	[connection cancel];	// only need the first bit; remove this to get the  rest of the data and thus eventually call connectionDidFinishLoading
	sample.serversDate = [self parseIt];
	[delegate performSelector:@selector(sampleReady:) withObject:sample];
	[self endTimeConnection];
    }
}
*/

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    // normally processng would be done here but we always cancel so we do it in didReceiveData
    [self endTimeConnection];
    [delegate performSelector:@selector(sampleReady:) withObject:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)err {
#ifndef NDEBUG
    printf("Unable to Connect to '%s': '%s' / '%s'\n", [url UTF8String], [[err localizedDescription] UTF8String], [[err localizedFailureReason] UTF8String]);
#endif
    [self endTimeConnection];
    [delegate performSelector:@selector(sampleReady:) withObject:nil];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil;     // Never cache
}

- (NSDate *)parseIt {
    assert(false);	// subclasses must override
    return nil;
}

- (void)startResolution {
    assert(false);
}

- (int)failedResolutions {
    return 0;
}

- (NSString *)ipaddr {
    return nil;
}

- (double)precision {
    assert(false);	// subclasses must override
    return 0;
}

- (void)dealloc {
    // [timeConnection cancel];
    // [timeConnection release];
    [self endTimeConnection];
    [super dealloc];
}

@end


@implementation TSNTPConnection	    /////////////////////////////////////////////////////////////

@synthesize noNet;

void timeStampMake (l_fp *ts) {
    struct timeval tv;
    //gettimeofday(&tv, NULL);
    [TSTime gettimeofdayR:&tv];
    ts->l_i = tv.tv_sec + JAN_1970;
    double dtemp = tv.tv_usec / 1e6;
    dtemp *= FRAC;
    ts->l_uf = (u_int32)dtemp;
}

double tsToDouble (l_fp *ts) {
    double d;
    l_fp temp;
    temp.l_ui = ts->l_ui - JAN_1970;
    temp.l_uf = ts->l_uf;
    LFPTOD(&temp, d);
    return d;
}

- (TSNTPConnection *)initWithDelegate:(TSConnectionDelegate *)obj hostname:(NSString*)hostname {
    if (self = [super init]) {
	delegate = obj;
	url = [hostname retain];
	bytesNeeded = 48;
    }
    return self;
}

- (bool)gabriel {
    // Gabriel is an arch-hack to ressurect a dead DNS subsystem:
    // Sometimes after the iPhone has not been accessing the network for a while it seems that subsequent resolution requests fail.
    // It does nothing except try to contact a reliable web site in synchronous mode
    // but that seems to unstick the resolution mechanism.
    // I don't know why but it works.
    
    //[TSTime noteTimeAtPhase:"TSCn: gabriel start"];
    
    // [note stevep 2017/01/01: This looks like it would work, but it never times out, so going with the async solution]
    // NSError *err;
    // [[[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:@"http://www.google.com/"] options:NSDataReadingUncached error:&err] autorelease];

    // Used to convert async call to synchronous:
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);  

    bool returnValue = false;

    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com/"] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30];
    // [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&err];  // Marked deprecated in iOS 9 SDK
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
                if (err == nil) {
#ifndef NDEBUG
                    [TSTime noteTimeAtPhase:"TSCn: gabriel 1 (ok)"];
#endif
                } else {
#ifndef NDEBUG
                    [TSTime noteTimeAtPhase:[[NSString stringWithFormat:@"TSCn: gabriel 2 (error): '%@' / '%@'", [err localizedDescription], [err localizedFailureReason]] UTF8String]];
#endif
                    if ([err code] == NSURLErrorNotConnectedToInternet) {
                        //[TSTime noteTimeAtPhase:"TSCn: gabriel done (false)"];
                        return;
                    }
                }
                //[TSTime noteTimeAtPhase:"TSCn: gabriel done (true)"];
                dispatch_semaphore_signal(sem);  
            }] resume];

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);  

    return returnValue;
}

static int nextNoNetRetryInteval = TSNoNetRetryInterval;

- (void)resolutionFailed:(NSString *)msg {
#ifndef NDEBUG
    [TSTime noteTimeAtPhase:[[NSString stringWithFormat:@"TSCn: resolutionFailed: %@", msg] UTF8String]];
#endif
    [self cleanUpHost];
    failedResolution = true;
    if (startWhenReady) {
	[self sendTimeRequest];	    // which won't get far but will inform the delegate that an error occurred
    }
    if (++failedResolutionCount < TSResolutionRetries) {
	int retryInterval = TSResolutionRetryInterval;
	if (failedResolutionCount > TSResolutionRetries/2) {
	    if (![self gabriel]) {
		//[TSTime noteTimeAtPhase:"TSCn: resolutionFailed 4 (no network)"];
		noNet = true;
#if 0
		[TSTime showECStatusMessage:@"network unreachable"];
#endif
		retryInterval = nextNoNetRetryInteval;
		nextNoNetRetryInteval = min(nextNoNetRetryInteval * 2, 3600);
		//[TSTime showECTimeStatus];
	    }
	}
	// try again later
	tracePrintf1("TSCn: trying again in %d seconds", retryInterval);
	startResolutionTimer = [NSTimer scheduledTimerWithTimeInterval:retryInterval target:self selector:@selector(startResolution) userInfo:nil repeats:false];
    } else  {
	[delegate performSelector:@selector(startDone:) withObject:nil];
    }
}

- (int)failedResolutions {
    return failedResolutionCount;
}

- (void)cleanUpHost {
    // clean up the no longer needed host object
    if (awaitingResolution) {
	assert(host != nil);
    }
    [startResolutionTimer invalidate];
    startResolutionTimer = nil;
    if (host != nil) {
	CFHostSetClient(host, nil, nil);
	CFRelease(host);
	host = nil;
    }
}

- (void)startResolution {
    failedResolution = false;
    noNet = false;
    startResolutionTimer = nil;
    assert(!awaitingResolution);
    assert(host == nil);
    assert(sock == nil);
    
    // use synchronous resolution
    host = CFHostCreateWithName(nil, (CFStringRef)url);
    // start the resolution process
    CFStreamError error;
    awaitingResolution = true;
    if (CFHostStartInfoResolution(host, kCFHostAddresses, &error)) {
	//[TSTime noteTimeAtPhase:"TSCn: startResolution 5 (ok)"];
    } else {
	awaitingResolution = false;
	[self resolutionFailed:[NSString stringWithFormat:@"failed CFHostStartInfoResolution: error %d, domain %ld: '%s' or '%s'", (int)error.error, error.domain, hstrerror(error.error), gai_strerror(error.error)]];
	return;
    }
 
    assert(awaitingResolution);
    awaitingResolution = false;
    
    if (error.error) {
 	[self resolutionFailed:[NSString stringWithFormat:@"error %d, domain %ld: '%s' or '%s'", (int)error.error, error.domain, hstrerror(error.error), gai_strerror(error.error)]];
	return;
    }

    // get the addressing data and save it in "sinData"
    Boolean resolved;
    CFArrayRef ary = CFHostGetAddressing(host, &resolved);
    if (resolved) {
	//[TSTime noteTimeAtPhase:[[NSString stringWithFormat:@"TSCn: startResolution 9: %d", (uint)CFArrayGetCount(ary)] UTF8String]];
    } else {
	[self resolutionFailed:@"no addressing"];
	return;
    }
    if (sinData != nil) {
	CFRelease(sinData);
    }
    sinData = CFDataCreateCopy(nil, CFArrayGetValueAtIndex(ary, 0));	// just use the first one for now
    struct sockaddr_in *sock_ad= (struct sockaddr_in *)CFDataGetBytePtr(sinData);
    sock_ad->sin_port = htons(NTP_PORT);
    //[TSTime noteTimeAtPhase:[[NSString stringWithFormat:@"TSCn: startResolution c: %@", [self ipaddr]] UTF8String]];
    [self cleanUpHost];
    
    // create the socket
    CFSocketContext context;
    bzero(&context, sizeof(CFSocketContext));
    context.info = self;		    // so gotData can get back into Obj-C mode
    sock = CFSocketCreate(nil, AF_INET, SOCK_DGRAM, IPPROTO_UDP, kCFSocketReadCallBack, &gotData, &context);
    if (sock == nil) {
	[self resolutionFailed:@"unable to create socket"];
	return;
    }
    
    // hook the new socket to the run loop
    CFRunLoopRef cfrl = CFRunLoopGetCurrent();
    CFRunLoopSourceRef source4 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, sock, 0);
    CFRunLoopAddSource(cfrl, source4, kCFRunLoopCommonModes);
    CFRelease(source4);

    [delegate performSelector:@selector(startDone:) withObject:self];	    // success
    nextNoNetRetryInteval = TSNoNetRetryInterval;

    // send the first request if we've already been started
    if (startWhenReady) {
	startWhenReady = false;
	[self sendTimeRequest];
    }
}

- (void)sendTimeRequest {
    //[TSTime noteTimeAtPhase:"TSCn: sendTimeRequest start"];
    if (awaitingResolution) {
	startWhenReady = true;
	return;
    }
    if (failedResolution || sock == nil || sinData == nil || !CFSocketIsValid(sock)) {
	[delegate performSelector:@selector(sampleReady:) withObject:nil];
	return;
    }

    // construct the request packet
    struct pkt xpkt;
    xpkt.li_vn_mode = PKT_LI_VN_MODE(LEAP_NOWARNING, NTP_VERSION, MODE_CLIENT);
    xpkt.stratum = STRATUM_TO_PKT(STRATUM_UNSPEC);
    xpkt.ppoll = NTP_MINPOLL;
    xpkt.precision = NTPDATE_PRECISION;
    // Identify packets for tracking on pool servers (see email from leo@leobodnar.com).
    xpkt.rootdelay = htonl('E' << 8 | 'S');                               // Company: ES
    xpkt.rootdispersion = _appSignature;  // Product: Obs, TS, Chro, etc
    xpkt.refid = htonl(NTPDATE_REFID);
    L_CLR(&xpkt.reftime);
    L_CLR(&xpkt.org);
    L_CLR(&xpkt.rec);
    // record the time in our format
    sample = [[TSSample alloc] init];
    sample.myTransmitTime = [TSTime currentDateRTime];
    //[TSTime noteTimeAtPhase:"TSCn: sendTimeRequest 2"];
    timeStampMake(&xmitTime);
    HTONL_FP(&xmitTime, &xpkt.xmt);
    // printf("Sending packet: ");
    // for (int i = 0; i < LEN_PKT_NOMAC; i++) {
    //     char c = ((const UInt8 *)&xpkt)[i];
    //     if (c == '\0') {
    //         printf(" ");
    //     } else if ((UInt8)c < 32 || (UInt8)c > 127) {
    //         printf("?");
    //     } else {
    //         printf("%c", c);
    //     }
    // }
    // printf(" [or]");
    // for (int i = 0; i < LEN_PKT_NOMAC; i++) {
    //     char c = ((const UInt8 *)&xpkt)[i];
    //     printf(" %u", (UInt8)c);
    // }
    // printf("\n");
    CFDataRef xpktData = CFDataCreate(nil, (const UInt8 *)&xpkt, LEN_PKT_NOMAC);
    
    // send it; we'll get a callback to gotData when the response is received
    int err = CFSocketSendData(sock, sinData, xpktData, 3.0);
    if (err == 0) {
	++nSent;
	//[TSTime noteTimeAtPhase:[[NSString stringWithFormat:@"TSCn: sendTimeRequest 4: %d", nSent] UTF8String]];
	//struct sockaddr_in *sin = (struct sockaddr_in *)CFDataGetBytePtr(sinData);
	//printf("request sent to        %s:%d at %+7.6f\n", socktoa(sin), ntohs(sin->sin_port), tsToDouble(&xmitTime));
	[self startTimeOutMonitor];
    } else {
	[self failed:[NSString stringWithFormat:@"sendData failed with err=%d", err]];
    }
    //printf("[%x] send : sock=%x\n", (uint)self, (uint)sock);
    CFRelease(xpktData);
}

- (void)cancel {
    [self cleanUpHost];
    // if we're still waiting for resolution, stop
    if (awaitingResolution) {
	awaitingResolution = false;
	failedResolution = false;
	startWhenReady = false;
	failedResolutionCount = 0;
    }

    // close down the socket
    if (sock != nil) {
	CFSocketInvalidate(sock);	    // also removes from the run loop
	CFRelease(sock);
	sock = nil;
	[self stopTimeOutMonitor];
	nSent = nRecv = nFail = nTimeOut = 0;
    }
}

- (void)endTimeConnection {
    [self stopTimeOutMonitor];
    [super endTimeConnection];
}

- (void)startTimeOutMonitor {
    [timeOutTimer invalidate];
    // if we start getting time outs then wait a little longer each time
    timeOutTimer = [NSTimer scheduledTimerWithTimeInterval:TSNTPTimeOut+nTimeOut target:self selector:@selector(timeOutMonitor:) userInfo:nil repeats:false];
#ifndef NDEBUG
    //printf("[%x] %20s - sent packet %d; sock %x; timer %x ... ", (uint)self, [url UTF8String], nSent, (uint)sock, (uint)timeOutTimer);
#endif
}

- (void)stopTimeOutMonitor {
    [timeOutTimer invalidate];
    timeOutTimer = nil;
}

- (void)failed:(NSString *)msg {
    ++nFail;
#ifndef NDEBUG
    [TSTime noteTimeAtPhase:[[NSString stringWithFormat:@"TSCn: failed: %s - s:%d r:%d f:%d t:%d\t", [msg UTF8String], nSent, nRecv, nFail, nTimeOut] UTF8String]];
#endif
    [self endTimeConnection];
    [delegate performSelector:@selector(sampleReady:) withObject:nil];
}

- (void)timeOutMonitor:(NSTimer *)timer {
    ++nTimeOut;
    [self failed:[NSString stringWithFormat:@"no response"]];
    timeOutTimer = nil;
}

void gotData (CFSocketRef s,
	      CFSocketCallBackType callbackType,
	      CFDataRef address,
	      const void *data,
	      void *info) {
    //printf("[%x] gotData sock=%x\n", (uint)info, (uint)s);
    struct pkt response;
    struct sockaddr_in serverAddr;
    socklen_t slen = sizeof(struct sockaddr);
    bzero(&serverAddr, sizeof(struct sockaddr));
    int len = recvfrom(CFSocketGetNative(s), (char *)&response, sizeof(response), 0, (struct sockaddr *)&serverAddr, &slen);
    [(id)info interpretResult:&response length:len from:&serverAddr];
}

- (void)interpretResult:(struct pkt *)rpkt length:(int)len from:(struct sockaddr_in *)serverAddr {
    //[TSTime noteTimeAtPhase:"TSCn: interpretResult start"];
    if (sample == nil) {
	// we're already timed out
	//[TSTime noteTimeAtPhase:"TSCn: interpretResult 2 (ignoring)"];
	return;
    }
    // major portions of this routine were lifted from ntpdate.c
    
    // record the received timestamp
    sample.myReceiveTime = [TSTime currentDateRTime];
    timeStampMake(&recvTime);
    
    //extern char *socktoa();
    //printf("received response from %s     at %+7.6f\n", socktoa(&serverAddr), tsToDouble(&recvTime));
    // printf("%x: got  packet %d; timer %x; host:%s\n", self, nRecv, timeOutTimer, [url UTF8String]);
    
    /*
     * Basic sanity checks
     */
    if (len != LEN_PKT_NOMAC) {
	[self failed:[NSString stringWithFormat:@"got %d bytes", len]];
	return;
    }
    struct sockaddr_in *sock_ad = (struct sockaddr_in *)CFDataGetBytePtr(sinData);
    if (sock_ad->sin_addr.s_addr != serverAddr->sin_addr.s_addr) {
	[self failed:@"wrong server"];
	return;	
    }
    if (PKT_VERSION(rpkt->li_vn_mode) < NTP_OLDVERSION || PKT_VERSION(rpkt->li_vn_mode) > NTP_VERSION) {
	[self failed:@"bad version"];
	return;
    }
    if ((PKT_MODE(rpkt->li_vn_mode) != MODE_SERVER && PKT_MODE(rpkt->li_vn_mode) != MODE_PASSIVE) || rpkt->stratum >= STRATUM_UNSPEC) {
	[self failed:[NSString stringWithFormat:@"received mode %d stratum %d", PKT_MODE(rpkt->li_vn_mode), rpkt->stratum]];
	return;
    }
    
    /*
     * Decode the org timestamp and make sure we're getting a response
     * to our last request.
     */
    NTOHL_FP(&rpkt->org, &org);
    if (!L_ISEQU(&org, &xmitTime)) {
	[self failed:@"received pkt.org and xmitTime differ"];	    // happens frequently on Reset
	return;
    }
    
    /*
     * Looks good.	Record info from the packet.
     */
    leap = PKT_LEAP(rpkt->li_vn_mode);
    stratum = PKT_TO_STRATUM(rpkt->stratum);
    precision = rpkt->precision;
    rootdelay = ntohl(rpkt->rootdelay);
    rootdispersion = ntohl(rpkt->rootdispersion);
    refid = rpkt->refid;
    NTOHL_FP(&rpkt->reftime, &reftime);
    NTOHL_FP(&rpkt->rec, &rec);
    NTOHL_FP(&rpkt->xmt, &xmt);
    
    /*
     * Make sure the server is at least somewhat sane.
     */
    if (L_ISZERO(&rec)) {
	[self failed:@"rec is zero"];
	return;
    }
    
    if (!L_ISHIS(&xmt, &rec) && !L_ISEQU(&xmt, &rec)) {
	[self failed:@"rec before xmt"];
	return;
    }
    
    l_fp t10, t23, tmp;
    l_fp ci;
    /*
     * Calculate the round trip delay (di) and the clock offset (ci).
     * We use the equations (reordered from those in the spec):
     *
     * d = (t2 - t3) - (t1 - t0)
     * c = ((t2 - t3) + (t1 - t0)) / 2
     // t0 = my       time when I  received the response
     // t1 = server's time when he sent his response
     // t2 = server's time when he received the request
     // t3 = my time  time when I  sent the request     
     */
    t10 = xmt;			/* pkt.xmt == t1 */
    L_SUB(&t10, &recvTime);	/* recv_time == t0*/
    
    t23 = rec;			/* pkt.rec == t2 */
    L_SUB(&t23, &org);		/* pkt->org == t3 */
    
    double d10, d23;
    LFPTOD(&t10, d10);
    LFPTOD(&t23, d23);
    // printf("d10=%7.6f; d23=%7.6f\n", d10, d23);
    
    /* now have (t2 - t3) and (t0 - t1).	Calculate (ci) and (di) */
    /*
     * Calculate (ci) = ((t1 - t0) / 2) + ((t2 - t3) / 2)
     * For large offsets this may prevent an overflow on '+'
     */
    ci = t10;
    L_RSHIFT(&ci);
    tmp = t23;
    L_RSHIFT(&tmp);
    L_ADD(&ci, &tmp);
    
    /*
     * Calculate di in t23 in full precision, then truncate
     * to an s_fp.
     */
    L_SUB(&t23, &t10);
    
    double offsetThisTime;
    LFPTOD(&ci,offsetThisTime);
    // rttThisTime = FPTOD(di);
    // printf("offset: %7.6f, delay %7.6f\n", offsetThisTime, rttThisTime);
    
    // construct the sample for our delegate
    sample.clockSkew = offsetThisTime;		    // this is the thing that matters, no need for a serversDate
    // printf("  skew: %+7.6f,  rtt: %6.5f;\n", sample.clockSkew, sample.roundTripTime);
    
    // let him have it (which may trigger another request)
    ++nRecv;
    [self stopTimeOutMonitor];
    [delegate performSelector:@selector(sampleReady:) withObject:sample];
    
    // release the sample; but the socket structure remains intact
    [self endTimeConnection];
}

- (NSString *)ipaddr {
    if (!sinData) {
	return nil;
    }
    struct sockaddr_in *sock_ad = (struct sockaddr_in *)CFDataGetBytePtr(sinData);
    return [NSString stringWithFormat:@"%d.%d.%d.%d ", sock_ad->sin_addr.s_addr&0xff, (sock_ad->sin_addr.s_addr&0xff00)>>8, (sock_ad->sin_addr.s_addr&0xff0000)>>16, (sock_ad->sin_addr.s_addr&0xff000000)>>24];
}

- (double)precision {
    return 0.0001;	// 100 microseconds    
}

- (void)dealloc {
    //printf("dealloc [%x]: sock=%x\n", self, sock);
    [self endTimeConnection];
    [self stopTimeOutMonitor];
    if (sock != nil) {
	CFSocketInvalidate(sock);
	CFRelease(sock);
    }
    if (sinData != nil) {
	CFRelease(sinData);
    }
    [startResolutionTimer invalidate];
    startResolutionTimer = nil;
    [url release];
    [super dealloc];
}

@end
