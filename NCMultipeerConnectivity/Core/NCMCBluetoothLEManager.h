//
//  NCMCBluetoothLEManager.h
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-21.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "NCMCSession+Core.h"
#import "NCMCCentralService+Core.h"
#import "NCMCPeripheralService+Core.h"


@interface NCMCBluetoothLEManager : NSObject<CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate>

@property (assign, nonatomic)Boolean isCentral;
@property (strong, nonatomic)NCMCSession* session;
@property (strong, nonatomic)NCMCCentralService* centralService;
@property (strong, nonatomic)NCMCPeripheralService* peripheralService;
@property (assign, nonatomic) Boolean isDeviceReady;

-(void)clear;

+(NCMCBluetoothLEManager *)instance;

-(void)disconnect;

// central
-(void)setupCentralEnv:(NCMCCentralService*)service;
-(Boolean)startBrowsing;
-(void)stopBrowsing;
-(void)invitePeer:(NCMCPeerID*)peerID;
-(void)sendCentralData : (NSData*)data toPeripheral:(NSString*)identifier withMode:(NCMCSessionSendDataMode)mode;
-(void)disconnectToPeripheral:(NSString*) identifier;


// peripheral
-(void)setupPeripheralEnv:(NCMCPeripheralService*)service;
-(Boolean)startAdvertising;
-(void)stopAdvertising;
-(void)sendPeripheralData : (NSData*)data toCentral:(NSString*)identifier;

@end
