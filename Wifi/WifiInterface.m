/*
 Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.
*/

//
//  WifiInterface.m
//
#import "WifiInterface.h"
#include <ifaddrs.h>
#include <arpa/inet.h>


// The thread all requests will run on:
// It hangs around forever, but will be blocked unless there are requests underway
static NSThread*	workThread = nil;
const unsigned short zeroes[] = {'0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0'};

@interface WifiInterface (PrivateMethods)
- (void)performBlockOnMainThread:(BasicBlock)bblock;
- (void)callBlock:(BasicBlock)bblock;

- (void)performSetCommandAddress:(NSString*)ipAddress;
- (void)performSendCommand:(NSString *)command;

- (void)setState:(WifiState)newState;
- (void)doNotifyWifiResultListeners:(WifiResult)result;
@end

@implementation WifiInterface
{
	dispatch_queue_t socketQueue;
	GCDAsyncSocket *listenSocket;
//	NSMutableArray *connectedSockets;
}

@synthesize _wifiResultlistenerList, _wifiStateListenerList, _centerFrequencyChangeListenerList, _wifiRadioInfoListenerList;
@synthesize menuCenterFrequencyChange;
@synthesize commandPort, dataPort, frequencyShift;
@synthesize state = _state;
@synthesize wifiIsAvailable = _wifiIsAvailable;
@synthesize lastFrequencyCommand;
@synthesize lastIPAddressReceived;
@synthesize gcdSocket;


static WifiInterface* sharedInstance = nil;
NSTimeInterval lastMessageSentTime = 0;

// Get the shared instance and create it if necessary.
+ (WifiInterface *)sharedInstance
{
    static WifiInterface *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}


+ (BOOL)exists
{
	return (sharedInstance != nil);
}

// We can still have a regular init method, that will get called the first time the Singleton is used.
- (id)init
{
    self = [super init];

    if (self != nil)
	{
		state = Uninitialized; // set state to an initially "illegal" value

		// Setup our socket.
		// The socket will invoke our delegate methods using the usual delegate paradigm.
		// However, it will invoke the delegate methods on a specified GCD delegate dispatch queue.
		//
		// Now we can configure the delegate dispatch queues however we want.
		// We could simply use the main dispatc queue, so the delegate methods are invoked on the main thread.
		// Or we could use a dedicated dispatch queue, which could be helpful if we were doing a lot of processing.
		//
		// The best approach for your application will depend upon convenience, requirements and performance.

		socketQueue = dispatch_queue_create("socketQueue", NULL);

		listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue];

		// Setup an array to store all accepted client connections
		//connectedSockets = [[NSMutableArray alloc] initWithCapacity:1];
    }

    return self;
}


///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// Incoming Request Methods: Outsiders access wifi with calls to these methods
//
// All methods here:
//   Return: Returns TRUE if the command was successfully scheduled to be sent.
//   Wifi results are return to registered listeners for
//
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

/*
 Outside request to establish a wifi connection.
 Returns TRUE if the command was successfully scheduled to be sent.
 */

- (BOOL)establishWifiConnection:(NSString *)ipAddress
{
	if(ipAddress == nil) return FALSE;

	if(lastIPAddressReceived == nil)
	{
		NSMutableString* ms = [NSMutableString new];
		self.lastIPAddressReceived = ms;
	}

	[lastIPAddressReceived setString:ipAddress];
	if(commandPort == nil) return FALSE;

	if(gcdSocket == nil)
	{
		self.gcdSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
	}

	NSError *err = nil;
	if(![gcdSocket connectToHost:ipAddress onPort:[commandPort integerValue] error:&err]) // Asynchronous!
	{
		// If there was an error, it's likely something like "already connected" or "no delegate set"
		WIFI_DEBUGPRINT(("Error: failed to connect with host: %s", [[err localizedDescription] UTF8String]));
		return FALSE;
	}

	[self setState:Searching]; // set the state on the caller's thread

	return TRUE;
}


/*
 Outside request to send a CAT set frequency command to the radio via wifi.
 Returns RadioMessageSent if the command was successfully scheduled to be sent.
 */
- (RadioMessageResult)sendCommand_FA:(frequencyType)frequencyKHZ stepmode:(BOOL)isStep
{
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// This is a crude governor to limit how often messages can be sent via wifi. It is crude in that, if an attempt is made to
	// send messages too often, some messages will be dropped (never sent). It would be better to implement a queue for
	// storing any messages that cannot be sent yet.
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	NSTimeInterval interval =  now - lastMessageSentTime;
	BOOL wifiIsReady = (interval > MINIMUM_WIFI_MESSAGE_INTERVAL_S);

	if(lastFrequencyCommand == nil)
	{
		self.lastFrequencyCommand = [NSMutableString new];
	}
	//
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	if(!(state & SocketEstablished))
	{
		WIFI_DEBUGPRINT(("\nsendCommand_FA: Error - attempt to send command before connection established.\n"));
		wifiIsReady = FALSE;
	}

	NSString* commandString;
	Message* command = nil;

	if(frequencyKHZ > 0.)
	{
		// Prevent illegal frequencies from being sent
		frequencyKHZ = CLAMP(MINIMUM_SETTABLE_RADIO_FREQUENCY_KHZ, frequencyKHZ, MAXIMUM_SETTABLE_RADIO_FREQUENCY_KHZ);

		commandString = [NSString stringWithFormat:@"%0.0lf", frequencyKHZ * 1000.]; // resolution is supported only down to 1 Hz
		NSInteger len = [commandString length];
		NSString* z = [NSString stringWithCharacters:zeroes length:(11-len)];
		commandString = [NSString stringWithFormat:@"FA%@%@;", z, commandString];

		WIFI_DEBUGPRINT(("Freq FA command %s\n", [commandString UTF8String]));

		// Don't send repeat messages
		if([commandString isEqualToString:lastFrequencyCommand])
		{
			SDR_DEBUGPRINT(("Duplicate command discarded: %s == %s\n", [commandString UTF8String], [lastFrequencyCommand UTF8String]));
			return RadioMessageDupe;
		}

		[lastFrequencyCommand setString:commandString];

		command = [[Message alloc] initWithMessage:commandString];
		command.messageType = SetCenterFrequencyCommand;
		command.stepping = isStep;
		command.freqData = frequencyKHZ;

		// If there are listeners inform them of the center frequency change regardless whether a wifi command can be sent
		if(_wifiCenterFreqListenersCount)
		{
			__block frequencyType newFreq = command.freqData;
			__block BOOL step = command.stepping;

			[self performBlockOnMainThread:^{
                @synchronized(self->_centerFrequencyChangeListenerList)
				{
                    for(id listener in self->_centerFrequencyChangeListenerList)
					{
						[listener centerFrequencyChanged:newFreq spectrumShifted:YES stepped:step radioInitiated:FALSE];
					}
				}
			}];
		}
	}
	else
	{
		commandString = @"FA;";
		wifiIsReady = TRUE; // don't throttle this info request
	}

	[NSObject cancelPreviousPerformRequestsWithTarget:self]; // cancel any pending "last" setting request

	if(wifiIsReady)
	{
		[gcdSocket writeData:[commandString dataUsingEncoding:NSUTF8StringEncoding]  withTimeout:WRITE_TIMEOUT tag:SetCenterFrequencyCommand];
		[gcdSocket readDataToData:[WifiInterface Semicolon] withTimeout:-1 tag:0];
	}
	else if(command)
	{
		// The very last frequency setting should always be sent in order to keep the radio and iSDR in accurate frequency sync. So
		// never throw away the last setting, instead schedule it to be sent after a delay.
		[self performSelector:@selector(performSendCommandAsync:) withObject:command afterDelay:0.2];
	}

	return RadioMessageSent;
}


/*
 Outside request to send an Option Module Query:
 Returns RadioMessageSent if the command was successfully scheduled to be sent.
 */
- (RadioMessageResult)sendCommand_OM
{
	RadioMessageResult result = RadioMessageSent;

	if(!(state & SocketEstablished))
	{
		WIFI_DEBUGPRINT(("\nsendCommand_OM: Error - attempt to send command before connection established.\n"));
		return RadioMessageNotReady;
	}

	NSString* commandString = @"OM;";

	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	NSTimeInterval interval =  now - lastMessageSentTime;
	BOOL radioReady = (interval > MINIMUM_WIFI_MESSAGE_INTERVAL_S);

	if(radioReady)
	{
		[gcdSocket writeData:[commandString dataUsingEncoding:NSUTF8StringEncoding] withTimeout:WRITE_TIMEOUT tag:RetrieveOMInformation];
		[gcdSocket readDataToData:[WifiInterface Semicolon] withTimeout:-1 tag:0];
	}
	else
	{
		[self performSelector:@selector(sendCommand_OM) withObject:nil afterDelay:0.3];
		result = RadioMessageDelayed;
	}

	return result;
}


/*
 Outside request to send an Mode Setting Query:
 Returns RadioMessageSent if the command was successfully scheduled to be sent.
 */
- (RadioMessageResult)sendCommand_MD
{
	RadioMessageResult result = RadioMessageSent;

	if(!(state & SocketEstablished))
	{
		WIFI_DEBUGPRINT(("\nsendCommand_OM: Error - attempt to send command before connection established.\n"));
		return RadioMessageNotReady;
	}

	NSString* commandString = @"MD;";

	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	NSTimeInterval interval =  now - lastMessageSentTime;
	BOOL radioReady = (interval > MINIMUM_WIFI_MESSAGE_INTERVAL_S);

	if(radioReady)
	{
		[gcdSocket writeData:[commandString dataUsingEncoding:NSUTF8StringEncoding] withTimeout:WRITE_TIMEOUT tag:RetrieveModeInformation];
		[gcdSocket readDataToData:[WifiInterface Semicolon] withTimeout:-1 tag:0];
	}
	else
	{
		[self performSelector:@selector(sendCommand_MD) withObject:nil afterDelay:0.3];
		result = RadioMessageDelayed;
	}

	return result;
}


/*
 Outside request to send an OM request:
 Returns RadioMessageSent if the command was successfully scheduled to be sent.
 */
- (RadioMessageResult)sendCommand_K3
{
	RadioMessageResult result = RadioMessageSent;

	if(!(state & SocketEstablished))
	{
		WIFI_DEBUGPRINT(("\nsendCommand_K3: Error - attempt to send command before connection established.\n"));
		return RadioMessageNotReady;
	}

	NSString* commandString = @"K3;";

	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	NSTimeInterval interval =  now - lastMessageSentTime;
	BOOL radioReady = (interval > MINIMUM_WIFI_MESSAGE_INTERVAL_S);

	if(radioReady)
	{
		[gcdSocket writeData:[commandString dataUsingEncoding:NSUTF8StringEncoding] withTimeout:WRITE_TIMEOUT tag:RetrieveK3Information];
		[gcdSocket readDataToData:[WifiInterface Semicolon] withTimeout:-1 tag:0];
	}
	else
	{
		[self performSelector:@selector(sendCommand_K3) withObject:nil afterDelay:0.3];
		result = RadioMessageDelayed;
	}

	return result;
}

/*
 Outside request to send an AI Auto-info mode command:
 Returns RadioMessageSent if the command was successfully scheduled to be sent.
 */
- (RadioMessageResult)sendCommand_AI:(NSInteger)parameter
{
	if(!(state & SocketEstablished))
	{
		WIFI_DEBUGPRINT(("\nsendCommand_AI: Error - attempt to send command before connection established.\n"));
		return RadioMessageNotReady;
	}

	if(parameter > 3) return RadioMessageError;

	NSString* commandString;

	if(parameter < 0)
	{
		commandString = @"AI;";
	}
	else
	{
		commandString = [NSString stringWithFormat:@"AI%ld;", (long)parameter];
	}

	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	NSTimeInterval interval =  now - lastMessageSentTime;
	BOOL radioReady = (interval > MINIMUM_WIFI_MESSAGE_INTERVAL_S);

	if(radioReady)
	{
		[gcdSocket writeData:[commandString dataUsingEncoding:NSUTF8StringEncoding] withTimeout:WRITE_TIMEOUT tag:SetAutoInformation];
		[gcdSocket readDataToData:[WifiInterface Semicolon] withTimeout:-1 tag:0];
	}
	else
	{
		Message* command = [[Message alloc] initWithMessage:commandString];
		command.messageType = SetAutoInformation;
		[self performSelector:@selector(performSendCommandAsync:) withObject:command afterDelay:0.3];
	}

	return RadioMessageSent;
}



/*
 Outside request to send an Option Module Query:
 Returns RadioMessageSent if the command was successfully scheduled to be sent.
 */
- (RadioMessageResult)sendCommand_IS
{
	RadioMessageResult result = RadioMessageSent;

	if(!(state & SocketEstablished))
	{
		WIFI_DEBUGPRINT(("\nsendCommand_IS: Error - attempt to send command before connection established.\n"));
		return RadioMessageNotReady;
	}

	NSString* commandString = @"IS;";

	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	NSTimeInterval interval =  now - lastMessageSentTime;
	BOOL radioReady = (interval > MINIMUM_WIFI_MESSAGE_INTERVAL_S);

	if(radioReady)
	{
		[gcdSocket writeData:[commandString dataUsingEncoding:NSUTF8StringEncoding] withTimeout:WRITE_TIMEOUT tag:RetrieveIFOffsetInformation];
		[gcdSocket readDataToData:[WifiInterface Semicolon] withTimeout:-1 tag:0];
	}
	else
	{
		[self performSelector:@selector(sendCommand_IS) withObject:nil afterDelay:0.3];
		result = RadioMessageDelayed;
	}

	return result;
}


///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
// Start: TCP Delegate Methods
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	lastMessageSentTime = [[NSDate date] timeIntervalSince1970]; // record the time of transmission

/*
	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
			WIFI_DEBUGPRINT(("Wrote data with tag %ld\n", tag));
		}
	});
*/
}


- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	// This method is executed on the socketQueue (not the main thread)

	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {

			NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length])];
			__block NSString *msg = [[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding];

/*
			if(msg)
			{
				WIFI_DEBUGPRINT(("Received %s with tag %ld\n", [msg UTF8String], tag));
			}
			else
			{
				WIFI_DEBUGPRINT(("Error converting received data into UTF-8 String. tag %ld\n", tag));
			}
*/

			BOOL keepSearching = TRUE;
			NSRange r = [msg rangeOfString:@"FA"];

			if((r.location == 0) && ([msg length] == 14))
			{
				keepSearching = FALSE;
                if(self->_wifiCenterFreqListenersCount)
				{
					NSString* s = [msg substringWithRange:NSMakeRange(2, 11)];
					__block frequencyType newFreqKHz = [s doubleValue] / 1000.;
					__block BOOL step = NO;

					[self performBlockOnMainThread:^{
                        @synchronized(self->_centerFrequencyChangeListenerList)
						{
                            for(id listener in self->_centerFrequencyChangeListenerList)
							{
								[listener centerFrequencyChanged:newFreqKHz spectrumShifted:YES stepped:step radioInitiated:TRUE];
							}
						}
					}];
				}

                if(self->state == SocketEstablished) self.state = ConnectedWithRadio;
			}

			if(keepSearching)
			{
				NSRange r = [msg rangeOfString:@"AI"];

				if((r.location == 0) && ([msg length] == 4))
				{
					keepSearching = FALSE;
                    if(self->_wifiRadioInfoListenersCount)
					{
						[self performBlockOnMainThread:^{
                            @synchronized(self->_wifiRadioInfoListenerList)
							{
                                for(id listener in self->_wifiRadioInfoListenerList)
								{
									[listener radioDataReceived:CAT_AI payload:msg];
								}
							}
						}];
					}
				}
			}

			if(keepSearching)
			{
				NSRange r = [msg rangeOfString:@"MD"];

				if((r.location == 0) && ([msg length] == 4)) // VFO A only (ignores $)
				{
					//					keepSearching = FALSE;
                    if(self->_wifiRadioInfoListenersCount)
					{
						[self performBlockOnMainThread:^{
                            @synchronized(self->_wifiRadioInfoListenerList)
							{
                                for(id listener in self->_wifiRadioInfoListenerList)
								{
									[listener radioDataReceived:CAT_MD payload:msg];
								}
							}
						}];
					}
				}
			}

			if(keepSearching)
			{
				NSRange r = [msg rangeOfString:@"K3"];

				if((r.location == 0) && ([msg length] == 4)) //
				{
					//					keepSearching = FALSE;
                    if(self->_wifiRadioInfoListenersCount)
					{
						[self performBlockOnMainThread:^{
                            @synchronized(self->_wifiRadioInfoListenerList)
							{
                                for(id listener in self->_wifiRadioInfoListenerList)
								{
									[listener radioDataReceived:CAT_K3 payload:msg];
								}
							}
						}];
					}
				}
			}

			if(keepSearching)
			{
				NSRange r = [msg rangeOfString:@"OM"];

				if((r.location == 0) && ([msg length] >= 4)) //
				{
					//					keepSearching = FALSE;
                    if(self->_wifiRadioInfoListenersCount)
					{
						[self performBlockOnMainThread:^{
                            @synchronized(self->_wifiRadioInfoListenerList)
							{
                                for(id listener in self->_wifiRadioInfoListenerList)
								{
									[listener radioDataReceived:CAT_OM payload:msg];
								}
							}
						}];
					}
				}
			}

			if(keepSearching)
			{
				NSRange r = [msg rangeOfString:@"IS"];

				if((r.location == 0) && ([msg length] >= 4)) //
				{
					//					keepSearching = FALSE;
                    if(self->_wifiRadioInfoListenersCount)
					{
						[self performBlockOnMainThread:^{
                            @synchronized(self->_wifiRadioInfoListenerList)
							{
                                for(id listener in self->_wifiRadioInfoListenerList)
								{
									[listener radioDataReceived:CAT_IS payload:msg];
								}
							}
						}];
					}
				}
			}

#ifdef WIFI_DEBUG
			if(keepSearching)
			{
				if([msg length] > 0)
				{
//					keepSearching = FALSE;
					if(_wifiRadioInfoListenersCount)
					{
						[self performBlockOnMainThread:^{
							@synchronized(_wifiRadioInfoListenerList)
							{
								for(id listener in _wifiRadioInfoListenerList)
								{
									[listener radioDataReceived:CAT_IGNORED_DATA payload:msg];
								}
							}
						}];
					}
				}
			}
#endif // WIFI_DEBUG
		}
	});

	// Echo message back to client
	[sock readDataToData:[WifiInterface Semicolon] withTimeout:-1 tag:0];
}


- (void)socket:(GCDAsyncSocket *)sender didConnectToHost:(NSString *)host port:(UInt16)port
{
	[self setState:SocketEstablished];

	// Inform any listeners of the result
	WIFI_DEBUGPRINT(("SocketEstablished to port %d. Notifying listeners.\n", port));
	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
            if(self->_wifiResultlistenersCount) [self doNotifyWifiResultListeners:WifiSuccessEstablishedConnection];
		}
	});
}



/**
 * This method is called if a read has timed out.
 * It allows us to optionally extend the timeout.
 * We use this method to issue a warning to the user prior to disconnecting them.
 **/
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
				 elapsed:(NSTimeInterval)elapsed
			   bytesDone:(NSUInteger)length
{
	WIFI_DEBUGPRINT(("TCP read timed out!\n"));

	if(elapsed <= READ_TIMEOUT)
	{
		//		NSString *warningMsg = @"Are you still there?\r\n";
		//		NSData *warningData = [warningMsg dataUsingEncoding:NSUTF8StringEncoding];
		//		[sock writeData:warningData withTimeout:-1 tag:WARNING_MSG];

		return READ_TIMEOUT_EXTENSION;
	}

	return 0.0;
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
				 elapsed:(NSTimeInterval)elapsed
			   bytesDone:(NSUInteger)length
{
	WIFI_DEBUGPRINT(("TCP write timed out!\n"));

	if(elapsed <= WRITE_TIMEOUT)
	{
		//		NSString *warningMsg = @"Are you still there?\r\n";
		//		NSData *warningData = [warningMsg dataUsingEncoding:NSUTF8StringEncoding];
		//		[sock writeData:warningData withTimeout:-1 tag:WARNING_MSG];

		return WRITE_TIMEOUT_EXTENSION;
	}
	else
	{
//		[sock disconnect];
		self.state = Disconnected;
	}

	return 0.0;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	if(sock != listenSocket)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			@autoreleasepool {

				WIFI_DEBUGPRINT(("Radio disconnected!\n"));

                if(self->state != Disconnected)
				{
					self.state = Disconnected;
				}

			}
		});

//		@synchronized(connectedSockets)
//		{
//			[connectedSockets removeObject:sock];
//		}
	}
}



// Method to support calling performSendCommand after a delay
- (void)performSendCommandAsync:(Message *)command
{
	NSString* commandString = command.messageString;

	[gcdSocket writeData:[commandString dataUsingEncoding:NSUTF8StringEncoding] withTimeout:WRITE_TIMEOUT tag:command.messageType];
	[gcdSocket readDataToData:[WifiInterface Semicolon] withTimeout:-1 tag:0];
}


///////////////////////////////////////////////////////////////////////////////
// External Control Methods
///////////////////////////////////////////////////////////////////////////////
/*
 The purpose of this method is to make sure everything is working after the app becomes active after having spent
 some time in the background (minimized)
 */
- (void)prepInterface:(BOOL)reinit
{
	wifiIsAvailable = [iSDRAppDelegate wifiIsEnabled]; // update wifi status

	if(reinit)
	{
		self.state = Uninitialized;
	}
	else
	{
		if(state == Searching) self.state = Disconnected;
	}
}

- (void)startWifiInterface
{
	wifiIsAvailable = [iSDRAppDelegate wifiIsEnabled]; // update wifi status
}

// Call this if the run loop needs to be interrupted for some reason
- (void)stopWifiInterface
{
	if(state != Disconnected) [self disableWifiInterface:YES]; // disable wifi first
}

- (void)disableWifiInterface:(BOOL)force; // generally this should get called only as the result of some user action
{
	if(force)
	{
		state = Uninitialized;
	}
	else
	{
		if(state == Disconnected) return;
	}

	self.state = Disconnected;
}

// The following are simply setters for some wifi configuration settings

- (void)setCommandPort:(NSString *)portNumber
{
	if(portNumber)
	{
		WIFI_DEBUGPRINT(("wifi: command port set: %s\n", [portNumber UTF8String]));

		commandPort = [[NSString alloc] initWithString:portNumber];
	}
}

- (void)setDataPort:(NSString *)portNumber
{
	if(portNumber)
	{
		WIFI_DEBUGPRINT(("wifi: data port set: %s\n", [portNumber UTF8String]));
		dataPort = [[NSString alloc] initWithString:portNumber];
	}
}

- (void)setWifiAvailability:(BOOL)availability
{
	wifiIsAvailable = availability;
}

- (BOOL)getWifiAvailability
{
	// Always check for the latest status
	wifiIsAvailable = [iSDRAppDelegate wifiIsEnabled];
	return  wifiIsAvailable;
}


///////////////////////////////////////////////////////////////////////////////
// External Utility Methods - provided for user convenience
///////////////////////////////////////////////////////////////////////////////
// Retrieve the IP address of the connected device
- (NSString *)getWifiConnectedIPAddress
{
	NSString *address = @"error";
	struct ifaddrs *interfaces = NULL;
	struct ifaddrs *temp_addr = NULL;
	int success = 0;

	// retrieve the current interfaces - returns 0 on success
	success = getifaddrs(&interfaces);
	if(success == 0)
	{
		// Loop through list of interfaces
		temp_addr = interfaces;
		while(temp_addr != NULL)
		{
			if(temp_addr->ifa_addr->sa_family == AF_INET)
			{
				// Check if interface is en0 which is the wifi connection on the iPhone
				if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"])
				{
					// Get NSString from C String
					address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
					WIFI_DEBUGPRINT(("IP: %s\n", [address UTF8String]));
				}
			}

			temp_addr = temp_addr->ifa_next;
		}
	}

	// Free memory
	freeifaddrs(interfaces);

	return address;
}

#import <SystemConfiguration/CaptiveNetwork.h>

- (id)fetchSSIDInfo
{
	NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
#ifdef WIFI_DEBUG
	NSLog(@"Supported interfaces: %@", ifs);
#endif
	id info = nil;
	for (NSString *ifnam in ifs) {
		info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
#ifdef WIFI_DEBUG
		NSLog(@"%@ => %@", ifnam, info);
#endif
		if (info && [info count]) { break; }
	}

	return info;
}

- (NSString*)connectedSSID
{
	NSDictionary *networkDict = [self fetchSSIDInfo];
	// Select the SSID from the network information
	NSString* ssid = [networkDict objectForKey:@"SSID"];

#ifdef WIFI_DEBUG
	printf("Network Dictionary:\n");
	[networkDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		NSString* s = [NSString stringWithFormat:@"%@ %@", key, obj];
		printf(" %s\n", [s UTF8String]);
	}];
#endif

	return ssid;
}

///////////////////////////////////////////////////////////////////////////////
// Internal Setter Methods for ReadOnly variables
///////////////////////////////////////////////////////////////////////////////
- (void)setState:(WifiState)newState
{
	if(state == newState) return; // prevent notifications when no change occurred

	if(newState == Uninitialized)
	{
		state = Disconnected;
	}
	else
	{
		state = newState;
	}

	if(state == Disconnected)
	{
		// Close all connections
		[listenSocket disconnect];
		[gcdSocket disconnect];

		// Stop any client connections
//		@synchronized(connectedSockets)
//		{
//			NSUInteger i;
//			for (i = 0; i < [connectedSockets count]; i++)
//			{
//				// Call disconnect on the socket,
//				// which will invoke the socketDidDisconnect: method,
//				// which will remove the socket from the list.
//				[[connectedSockets objectAtIndex:i] disconnect];
//			}
//		}
	}

	SDR_DEBUGPRINT(("WifiInterface setting state to: %d\n", newState));

	if(_wifiStateListenersCount)
	{
		__block WifiState theState = state;

		[self performBlockOnMainThread:^{
            @synchronized(self->_wifiStateListenerList)
			{
                for(id listener in self->_wifiStateListenerList)
				{
					[listener newWifiState:theState];
				}
			}
		}];
	}

	return;
}

///////////////////////////////////////////////////////////////////////////////
// ReadOnly Getter Methods
///////////////////////////////////////////////////////////////////////////////
- (WifiState)getState
{
	WIFI_DEBUGPRINT(("WifiInterface returning state: %d\n", state));
	return state;
}


///////////////////////////////////////////////////////////////////////////////
// Broadcast/Listener support methods
///////////////////////////////////////////////////////////////////////////////
- (void)applyRadioConnection:(id)sender
{
	// Only allow radio listeners to apply this state
	if(state != SocketEstablished) return;

	if(_wifiRadioInfoListenersCount)
	{
		if([_wifiRadioInfoListenerList containsObject:sender])
		{
			self.state = ConnectedWithRadio;
		}
	}
}

// Call this method when something happens that listeners need to be notified about
- (void)doNotifyWifiResultListeners:(WifiResult)result
{
	__block WifiResult theResult = result;

	[self performBlockOnMainThread:^{
        @synchronized(self->_wifiResultlistenerList)
		{
            for(id listener in self->_wifiResultlistenerList)
			{
				[listener receiveWifiInterfaceResult:theResult];
			}
		}
	}];

	return;
}


- (void)addWifiResultListener:(id)listener
{
	if(listener == nil) return;

	if(_wifiResultlistenerList == nil)
	{
		_wifiResultlistenerList = [NSMutableArray new];
	}
	else if([_wifiResultlistenerList containsObject:listener]) return;

	if((_wifiResultlistenerList != nil) && [listener respondsToSelector:@selector(receiveWifiInterfaceResult:)])
	{
		@synchronized(_wifiResultlistenerList)
		{
			[_wifiResultlistenerList addObject:listener];
			_wifiResultlistenersCount = [_wifiResultlistenerList count];
		}
	}
}


- (void)removeWifiResultListener:(id)listener
{
	if(listener == nil) return;
	if(_wifiResultlistenerList == nil) return;

	@synchronized(_wifiResultlistenerList)
	{
		[_wifiResultlistenerList removeObject:listener];
		_wifiResultlistenersCount = [_wifiResultlistenerList count];
	}
}


- (void)addWifiStateListener:(id)listener
{
	if(listener == nil) return;

	if(_wifiStateListenerList == nil)
	{
		_wifiStateListenerList = [NSMutableArray new];
	}
	else if([_wifiStateListenerList containsObject:listener]) return;

	if((_wifiStateListenerList != nil) && [listener respondsToSelector:@selector(newWifiState:)])
	{
		@synchronized(_wifiStateListenerList)
		{
			[_wifiStateListenerList addObject:listener];
			_wifiStateListenersCount = [_wifiStateListenerList count];
		}
	}
}


- (void)removeWifiStateListener:(id)listener
{
	if(listener == nil) return;
	if(_wifiStateListenerList == nil) return;

	@synchronized(_wifiStateListenerList)
	{
		[_wifiStateListenerList removeObject:listener];
		_wifiStateListenersCount = [_wifiStateListenerList count];
	}
}


- (void)addCenterFrequencyListener:(id)listener
{
	if(listener == nil) return;

	if(_centerFrequencyChangeListenerList == nil)
	{
		_centerFrequencyChangeListenerList = [NSMutableArray new];
	}
	else if([_centerFrequencyChangeListenerList containsObject:listener]) return;

	if((_centerFrequencyChangeListenerList != nil) && [listener respondsToSelector:@selector(centerFrequencyChanged: spectrumShifted: stepped: radioInitiated:)])
	{
		@synchronized(_centerFrequencyChangeListenerList)
		{
			[_centerFrequencyChangeListenerList addObject:listener];
			_wifiCenterFreqListenersCount = [_centerFrequencyChangeListenerList count];
		}
	}
}


- (void)addRadioInfoListener:(id)listener
{
	if(listener == nil) return;

	if(_wifiRadioInfoListenerList == nil)
	{
		_wifiRadioInfoListenerList = [NSMutableArray new];
	}
	else if([_wifiRadioInfoListenerList containsObject:listener]) return;

	if((_wifiRadioInfoListenerList != nil) && [listener respondsToSelector:@selector(radioDataReceived: payload:)])
	{
		@synchronized(_wifiRadioInfoListenerList)
		{
			[_wifiRadioInfoListenerList addObject:listener];
			_wifiRadioInfoListenersCount = [_wifiRadioInfoListenerList count];
		}
	}
}


- (void)removeCenterFrequencyListener:(id)listener
{
	if(listener == nil) return;
	if(_centerFrequencyChangeListenerList == nil) return;

	@synchronized(_centerFrequencyChangeListenerList)
	{
		[_centerFrequencyChangeListenerList removeObject:listener];
		_wifiCenterFreqListenersCount = [_centerFrequencyChangeListenerList count];
	}
}


- (void)removeRadioInfoListener:(id)listener
{
	if(listener == nil) return;
	if(_wifiRadioInfoListenerList == nil) return;

	@synchronized(_wifiRadioInfoListenerList)
	{
		[_wifiRadioInfoListenerList removeObject:listener];
		_wifiRadioInfoListenersCount = [_wifiRadioInfoListenerList count];
	}
}


- (void)removeAllListeners
{
	if(_wifiResultlistenerList)
	{
		@synchronized(_wifiResultlistenerList)
		{
			[_wifiResultlistenerList removeAllObjects];
			_wifiResultlistenerList = nil;
			_wifiResultlistenersCount = 0;
		}
	}

	if(_wifiStateListenerList)
	{
		@synchronized(_wifiStateListenerList)
		{
			[_wifiStateListenerList removeAllObjects];
			_wifiStateListenerList = nil;
			_wifiStateListenersCount = 0;
		}
	}

	if(_centerFrequencyChangeListenerList)
	{
		@synchronized(_centerFrequencyChangeListenerList)
		{
			[_centerFrequencyChangeListenerList removeAllObjects];
			_centerFrequencyChangeListenerList = nil;
			_wifiCenterFreqListenersCount = 0;
		}
	}

	if(_wifiRadioInfoListenerList)
	{
		@synchronized(_wifiRadioInfoListenerList)
		{
			[_wifiRadioInfoListenerList removeAllObjects];
			_wifiRadioInfoListenerList = nil;
			_wifiRadioInfoListenersCount = 0;
		}
	}

	return;
}


+ (NSData *)Semicolon
{
	return [NSData dataWithBytes:"\x3B" length:1];
}


/////////////////////////////////////////////////////////////////////////////////////////////////////
// Threading Support Methods
/////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)performBlockOnMainThread:(BasicBlock)bblock
{
	[self performSelectorOnMainThread:@selector(callBlock:) withObject:[bblock copy] waitUntilDone:[NSThread isMainThread]];
}

- (void)callBlock:(BasicBlock)bblock
{
	bblock();
}



- (id <WifiInterfaceDelegate>)delegate { return delegate; }

- (void)setDelegate:(id <WifiInterfaceDelegate>)v
{
	delegate = v;
}

@end

// Define the message class
@implementation Message

@synthesize messageType;
@synthesize messageString;
@synthesize freqData;
@synthesize stepping;

- (id)init
{
	self = [super init];

	return self;
}

- (id)initWithMessage:(NSString*)string
{
	self = [super init];

	if(self)
	{
		self.messageString = string;
	}

	return self;
}

@end
