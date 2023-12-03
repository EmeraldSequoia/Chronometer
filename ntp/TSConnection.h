//
//  TSConnection.h
//  TimeSync
//
//  Created by Bill Arnett on 8/10/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import <netinet/in.h>
#import "ntp_fp.h"
#import "ntp.h"

//TSConnection
#define TSNTPTimeOut		9.0		// how long to wait for the response
#define TSResolutionRetries	5		// how many times to try to do the DNS lookup
#define TSResolutionRetryInterval 3		// seconds
#define TSNoNetRetryInterval	10		// 10 seconds

// ntp
#define	JAN_1970		0x83aa7e80	/* 2208988800 1970 - 1900 in seconds */
#define	NTPDATE_PRECISION	(-6)		/* use this precision */
#define NTP_MAXSKW		0x28f		/* 0.01 sec in fp format */
#define NTP_MINDIST		0x51f		/* 0.02 sec in fp format */
#define	NTPDATE_DISTANCE	FP_SECOND	/* distance is 1 sec */
#define	NTPDATE_DISP		FP_SECOND	/* so is the dispersion */
#define	NTPDATE_REFID		(0)		/* reference ID to use */
#define PEER_MAXDISP		(64*FP_SECOND)	/* maximum dispersion (fp 64) */


@class TSSample;
@class TSConnection;

typedef enum TSProtocol {	    // == port number
    TSPNTP	= 123,		    // Network Time Protocol (RFC-
    TSPWeb	= 80,		    // parse an html page
    TSPTime	= 37,		    // Time Protocol (RFC-868)
    TSPDayTime	= 13		    // Daytime Protocol (RFC-867) per NIST definition
} TSProtocol;

@interface TSConnectionDelegate : NSObject {
}
-(void)startDone:(TSConnection*)connection;
-(void)sampleReady:(TSSample*)sample;
@end

@interface TSConnection : NSObject {	    /////////////////////////////////////////////////////////////
    NSURLRequest    *connectionRequest;	    // initialization parameters for the connection
    NSMutableData   *connectionData;	    // raw data from server
    TSSample	    *sample;		    // processed data
    TSConnectionDelegate *delegate;         // caller which responds to startDone and sampleReady:sample
    NSString	    *url;		    // url of server
    int		    connectionTimeOut;	    // how long to wait for the connection
    int		    bytesNeeded;	    // how much data we need
}

@property (readonly) double precision;	    // the minimum non-zero difference between two samples (implemented by each subclass

- (TSConnection *)initWithDelegate:(TSConnectionDelegate *)obj URL:(NSString *)url timeout:(int)timeout bytesNeeded:(int)bytesNeeded;

/* Public Methods */
- (void)getOneSample;
- (NSString *)ipaddr;
- (int)failedResolutions;
- (void)startResolution;
+ (void)setAppSignature:(const char *)fourByteAppSig;

/* Connection Management Methods */
- (void)sendTimeRequest;
- (void)stop;
- (void)cancel;
- (void)endTimeConnection;

/* data interpretation */
- (NSDate *)parseIt;

/* NSURLConnection Delegate Methods */
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
//- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
@end

void resolutionCallBack (CFHostRef theHost, CFHostInfoType typeInfo, const CFStreamError *error, void *info);
void gotData (CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info);

@interface TSNTPConnection : TSConnection	    /////////////////////////////////////////////////////////////

{
    CFSocketRef	sock;		// the real com channel
    CFDataRef	sinData;	// the address data
    NSTimer	*timeOutTimer;	// to handle stubborn servers
    NSTimer	*startResolutionTimer;	// for DNS resolution failure retry
    CFHostRef	host;		    // for DNS resolution
    bool	awaitingResolution; // DNS resolution is not yet finished
    bool	failedResolution;   // DNS resolution failed; nothing good can happen now
    int		failedResolutionCount;	// number of times we've tried and failed
    bool	startWhenReady;	    // start was called; proceed immediately when resolution is finished
    bool	noNet;		// gabriel failed
    int		nSent;		// number of packets sent
    int		nRecv;		// number of packets received
    int		nTimeOut;	// number of time outs
    int		nFail;		// number of erroroneous responses (including time outs)
    
    l_fp	xmitTime;	/* my transmit time stamp */
    l_fp	recvTime;	/* my receive time stamp */
    u_char	leap;		/* local leap indicator */

    // from the received packet:
    u_char	pmode;		/* remote association mode */
    u_char	stratum;	/* remote stratum */
    u_char	ppoll;		/* remote poll interval */
    char	precision;	/* remote clock precision */
    double	rootdelay;	/* roundtrip delay to primary clock */
    double	rootdispersion;	/* dispersion to primary clock */
    u_int32	refid;		/* remote reference ID */
    l_fp	reftime;	/* update epoch */
    l_fp	org;		/* originate time stamp (server's copy of xmitTime)*/
    l_fp	rec;		/* receive time stamp */
    l_fp	xmt;		/* transmit time stamp */
}

@property (readonly, nonatomic) bool noNet;	    // can't proceed because there's no network connectivity

- (TSNTPConnection *)initWithDelegate:(TSConnectionDelegate *)obj hostname:(NSString *)hostname;
- (void)startResolution;
- (void)cleanUpHost;
- (void)sendTimeRequest;
- (void)endTimeConnection;
- (void)startTimeOutMonitor;
- (void)stopTimeOutMonitor;
- (void)failed:(NSString *)msg;
- (void)timeOutMonitor:(NSTimer *)timer;
- (void)interpretResult:(struct pkt *)rpkt length:(int)len from:(struct sockaddr_in *)serverAddr;

@end
