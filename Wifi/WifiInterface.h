//
//  WifiInterface.h
//  iSDR
//
//  Created by Charles Scharlau on 10/21/10.
//  Copyright (c) 2011-2026 OpenARDF. Licensed under the MIT License.
//

/****************************************************************************
Description:

 This is a skeleton example of a singleton that runs continuously on its own run loop. It also incorporates a data listener model, where other ojects can register as listeners to the singleton and will be notified whenever some event occurs. It also incorporates Apple's delegate model, so that a single object can register as the delegate for the singleton and therefore receive all the delegate messages from the singleton.

 Care has been taken to ensure that communications with the delegate and listeners occur on the main thread (which assumes that listeners and the main thread are in fact running on the main thread). Ensuring that messages are send on the receiver's thread is important to avoid some very strange and difficult to diagnose crashes.

 This method is a little complex, but extremely powerful, and should allow for robust threaded interface behavior with little effort. The delegate can launch the singleton and configure it as necessary. The delegate, and other entities, can register to be informed when wifi messages arrive - or perhaps just for specific wifi messages that they are interested in. The delegate or other entities can access the singleton to send wifi messages or change the wifi interface configuration.


Typical usage:

 Access or create the singleton instance:

   WifiInterface* wifi = [WifiInterface sharedInstance:val1 param2:val2]; // creates a unique instance if it does not already exist
   wifi.delegate = self; // set the delegate
   [wifi addListener:self]; // register to receive notifications from the singleton
   [wifi startWifiInterface]; // start the singleton running its own run loop

 Send a command to the singleton:

    [wifi example_DoSomethingThatInterruptsThread]; // like configure the wifi interface
    [wifi example_DoSomething]; // like tell the singleton to send a message
    [wifi stopWifiInterface]; // stop the singleton's thread

 Confirm that the singleton has been created:
    if([WifiInterface exists]) { do something } // but usually you will just access it as shown above, which will create it if it does not already exist

 You should never need to kill or delete the singleton. It will exist until iOS shuts down the app

 */

#import "product.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>
#import <CoreFoundation/CoreFoundation.h>


#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <fcntl.h>

#include "GCDAsyncSocket.h"

#include "iSDRAppDelegate.h"

#define READ_TIMEOUT	10.
#define READ_TIMEOUT_EXTENSION	0.
#define WRITE_TIMEOUT	15.
#define WRITE_TIMEOUT_EXTENSION 0.

typedef void (^BasicBlock)(void);


typedef enum wifiStates
{
	Disconnected = 0,
	Searching = 1,
	SocketEstablished = 2,
	ConnectedWithRadio = 3,
	NumberOfWifiStates,
	Uninitialized
} WifiState;

typedef enum wifiMessageTypes
{
	SetCenterFrequencyCommand,
	SetAutoInformation,
	RetrieveOMInformation, // Option Module Query
	RetrieveModeInformation, // Operating Mode
	RetrieveK3Information,
	RetrieveIFOffsetInformation, // IF Offset
	NumberOfMessageTypes,
	UndefinedMessageType
} WifiMessage;

typedef enum wifiResults
{
	WifiStubResultForTesting,
	WifiNoResults, // use this to initialize a return value

	WifiSuccessEstablishedConnection,
	WifiErrorConnectionFailed,
	WifiErrorTCPConnectionFailed,

	WifiErrorInGetAddrInfoCall,
	WifiErrorCommandPortNotSet,

	WifiSendCommandSucceeded,
	WifiErrorSendCommandFailedDueToNoConnection,
	WifiErrorSendCommandFailedDueToDisabled,

	WifiErrorWifiDisablbedOnDevice,
	WifiErrorTCPSendCommandFailed,

	WifiInterfaceNotInConnectedState
//	WifiInterfaceNotInSearchingState,
//	WifiInterfaceNotInDisabledState
} WifiResult;

typedef enum radioMessageResults
{
	RadioMessageSent,
	RadioMessageDupe,
	RadioMessageNotReady,
	RadioMessageError,
	RadioMessageDelayed
} RadioMessageResult;

typedef enum catMessageTypes
{
	CAT_AI, // auto-info
	CAT_MD, // radio mode
	CAT_K3, // recognized by Elecraft K3 and KX3
	CAT_OM, // used to distinguish KX3
	CAT_IS, // IF offset value
	CAT_IGNORED_DATA
} CatMessageType;


@protocol WifiInterfaceDelegate
@required
@optional
@end

@protocol WifiInterfaceListener
@required
- (void)receiveWifiInterfaceResult:(WifiResult)data;
@optional
@end

@protocol WifiStateListener
@required
- (void)newWifiState:(WifiState)aState;
@optional
@end

@protocol WifiCenterFrequencyListener
@required
- (void)centerFrequencyChanged:(frequencyType)newFrequencyKHz spectrumShifted:(BOOL)spectrumShift stepped:(BOOL)stepping radioInitiated:(BOOL)radioInitiated;
@optional
@end

@protocol WifiRadioInfoListener
@required
- (void)radioDataReceived:(CatMessageType)messageType payload:(NSString*)msg;
@optional
@end

@interface WifiInterface : NSObject <GCDAsyncSocketDelegate>
{

    int			status;
    int			sendResults;
	BOOL		menuCenterFrequencyChange;
	NSString*	commandPort;
	NSString*	dataPort;
	float		frequencyShift;
	WifiState	state;

@private
	id <WifiInterfaceDelegate>		delegate;
	BOOL							wifiIsAvailable;
	NSMutableArray*					_wifiResultlistenerList;
	NSMutableArray*					_wifiStateListenerList;
	NSMutableArray*					_centerFrequencyChangeListenerList;
	NSMutableArray*					_wifiRadioInfoListenerList;

	NSInteger						_wifiResultlistenersCount;
	NSInteger						_wifiStateListenersCount;
	NSInteger						_wifiCenterFreqListenersCount;
	NSInteger						_wifiRadioInfoListenersCount;

	NSMutableString*				lastIPAddressReceived;
	NSMutableString*				lastFrequencyCommand;

	GCDAsyncSocket*					gcdSocket;
}

@property (nonatomic, assign) id <WifiInterfaceDelegate>	delegate;
@property (nonatomic, retain) NSMutableArray*			_wifiResultlistenerList;
@property (nonatomic, retain) NSMutableArray*			_wifiStateListenerList;
@property (nonatomic, retain) NSMutableArray*			_centerFrequencyChangeListenerList;
@property (nonatomic, retain) NSMutableArray*			_wifiRadioInfoListenerList;
@property (nonatomic, readwrite) BOOL					menuCenterFrequencyChange;
@property (nonatomic, retain, setter = setCommandPort:) NSString*					commandPort;
@property (nonatomic, retain, setter = setDataPort:)	NSString*					dataPort;
@property (nonatomic, readwrite) float					frequencyShift;
@property (nonatomic, readonly, getter = getState)	WifiState	state;
@property (nonatomic, readwrite, setter = setWifiAvailability:, getter = getWifiAvailability) BOOL	wifiIsAvailable;
@property (nonatomic, readonly, getter = getWifiConnectedIPAddress) NSString*				connectedIPAddress;
@property (nonatomic, readonly, getter = connectedSSID) NSString*							connectedSSID;
@property (nonatomic, retain) NSMutableString* lastFrequencyCommand;
@property (nonatomic, retain) NSMutableString* lastIPAddressReceived;

@property (nonatomic, retain) GCDAsyncSocket*			gcdSocket;

// Wifi API methods
// These are the methods that get called by "outside parties" requesting actions from the WifiInterface singleton
- (BOOL)establishWifiConnection:(NSString*)ipAddress;
- (RadioMessageResult)sendCommand_FA:(frequencyType)frequencyKHZ stepmode:(BOOL)isStep;
- (RadioMessageResult)sendCommand_AI:(NSInteger)parameter;
- (RadioMessageResult)sendCommand_OM;
- (RadioMessageResult)sendCommand_MD;

- (void)prepInterface:(BOOL)reinit;  // Doesn't need to be called after first init, but should be called after app returns from background
- (void)startWifiInterface;
- (void)stopWifiInterface;
- (void)disableWifiInterface:(BOOL)force; // generally this should get called only as the result of some user action
- (RadioMessageResult)sendCommand_IS;

// Misc. utility and info methods
- (NSString *)getWifiConnectedIPAddress;
- (NSString*)connectedSSID;

// Listener Support
- (void)addWifiResultListener:(id)listener;
- (void)addWifiStateListener:(id)listener;
- (void)addCenterFrequencyListener:(id)listener;
- (void)addRadioInfoListener:(id)listener;
- (void)removeWifiResultListener:(id)listener;
- (void)removeWifiStateListener:(id)listener;
- (void)removeCenterFrequencyListener:(id)listener;
- (void)removeAllListeners;

- (void)applyRadioConnection:(id)sender;

// Singleton Support
+ (WifiInterface *)sharedInstance;

+ (NSData *)Semicolon;

@end

@interface Message : NSString
{
	NSString*		messageString;
	WifiMessage		messageType;
	frequencyType	freqData;
	BOOL			stepping;
}

@property (nonatomic, retain) NSString* messageString;
@property (nonatomic) WifiMessage messageType;
@property (nonatomic) frequencyType freqData;
@property (nonatomic) BOOL stepping;

- (id)init;
- (id)initWithMessage:(NSString*)string;

@end
