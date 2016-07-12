//
//  NCMCBluetoothLEManager.m
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-21.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "NCMCBluetoothLEManager.h"
#import "NCMCMessageData.h"
#import "NCMCPeripheralInfo.h"
#import "NCMCPeerID+Core.h"

#define TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID    @"B7020F32-5170-4F62-B078-E5C231B71B3F"
#define TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_WITH_RESPONSE_UUID    @"0E182478-7DC7-43D2-9B52-06FE34B325CE"
#define TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_WITHOUT_RESPONSE_UUID    @"541300E2-99C2-4319-A5B9-98E96053D2C9"

@interface NCMCBluetoothLEManager()
{
    NSMutableArray<NCMCMessageData*> *recMsgArray;
    NSMutableArray<NCMCMessageData*> *dataToSend;
    
    Boolean isBrowsingOrAdvertising;
}

@property (nonatomic, strong) dispatch_queue_t concurrentBluetoothLEDelegateQueue;
@property (nonatomic, strong) dispatch_queue_t serialDataSendingQueue;

// central properties
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) NSMutableDictionary<NSString*, NCMCPeripheralInfo*> *discoveredPeripherals; // key:UUIDString value:NCMCPeripheralInfo

// peripheral properties
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *sendCharacteristic;
@property (strong, nonatomic) CBMutableCharacteristic *receiveWithResponseCharacteristic;
@property (strong, nonatomic) CBMutableCharacteristic *receiveWithoutResponseCharacteristic;
@property (strong, nonatomic) NSMutableDictionary<NSString*, CBCentral*> *connectedCentrals; // key:UUIDString value:CBCentral


@end

@implementation NCMCBluetoothLEManager

@synthesize isCentral, session, concurrentBluetoothLEDelegateQueue, serialDataSendingQueue, centralManager, peripheralManager, sendCharacteristic, receiveWithResponseCharacteristic, receiveWithoutResponseCharacteristic, isDeviceReady;

static NCMCBluetoothLEManager *_sharedNCMCBluetoothLEManager = nil;

+ (NCMCBluetoothLEManager *)instance {
    
    @synchronized(self) {
        
        if (_sharedNCMCBluetoothLEManager == nil) {
            _sharedNCMCBluetoothLEManager = [[NCMCBluetoothLEManager alloc] init];
        }
    }
    
    return _sharedNCMCBluetoothLEManager;
}

-(void)clear
{
    // destroy all connections and reset variables
    [self disconnect];
    
    if (self.discoveredPeripherals != nil) {
        [self.discoveredPeripherals removeAllObjects];
    }
    
    if (self.connectedCentrals != nil) {
        [self.connectedCentrals removeAllObjects];
    }
    
    if (dataToSend != nil) {
        [dataToSend removeAllObjects];
    }
    
    self.centralService = nil;
    self.peripheralService = nil;
    self.session = nil;
    
    if (self.centralManager != nil) {
        [self.centralManager setDelegate:nil];
    }
    
    self.centralManager = nil;
    if (self.peripheralManager != nil) {
        [self.peripheralManager setDelegate:nil];
        [self.peripheralManager removeAllServices];
    }
    self.peripheralManager = nil;
    self.isDeviceReady = NO;
    
    self.concurrentBluetoothLEDelegateQueue = nil;
    self.serialDataSendingQueue = nil;
    
    isBrowsingOrAdvertising = NO;
}

-(void)setupDispatchQueue
{
    self.concurrentBluetoothLEDelegateQueue = dispatch_queue_create("com.nc.ncmultipeerconnectivity",DISPATCH_QUEUE_CONCURRENT);
    self.serialDataSendingQueue = dispatch_queue_create("com.nc.ncmultipeerconnectivity.data",DISPATCH_QUEUE_SERIAL);
}

// misc
-(void) disconnect
{
    if (self.isCentral) {
        [self stopBrowsing];
        NSEnumerator *enmuerator = [self.discoveredPeripherals objectEnumerator];
        
        for (NCMCPeripheralInfo *info in enmuerator) {
            [self disconnectToPeripheralByInfo:info];
        }
    } else {
        [self stopAdvertising];
        [self.peripheralManager removeAllServices];
    }
}

- (NSError *)errnoErrorWithReason:(NSString *)reason
{
    NSString *errMsg = [NSString stringWithUTF8String:strerror(errno)];
    NSDictionary *userInfo;
    
    if (reason)
        userInfo = [NSDictionary dictionaryWithObjectsAndKeys:errMsg, NSLocalizedDescriptionKey,
                    reason, NSLocalizedFailureReasonErrorKey, nil];
    else
        userInfo = [NSDictionary dictionaryWithObjectsAndKeys:errMsg, NSLocalizedDescriptionKey, nil];
    
    return [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:userInfo];
}

/***********************************************************************/
/*                          MESSAGE   FUNCTIONS                        */
/***********************************************************************/
-(NSArray*)makeMsg:(NSData*)msg byCapability:(NSUInteger)capacity {
    NSLog(@"makeMsg msg length = %lu, capacity = %lu", (unsigned long)msg.length, (unsigned long)capacity);
    NSMutableArray *messageArray = [[NSMutableArray alloc]init];
    
    NSInteger limitation = capacity -  2;
    
    if ([msg length] < limitation) {
        [messageArray addObject:[self packMsg:msg andIsNew:YES andIsCompleted:YES]];
    } else {
        NSInteger index = 0;
        
        BOOL isComplete = NO;
        
        while (!isComplete) {
            NSInteger amountToSend = [msg length] - index;
            
            if (amountToSend > limitation) {
                amountToSend = limitation;
                isComplete = NO;
            } else {
                isComplete = YES;
            }
            
            NSData *chunk = [NSData dataWithBytes:msg.bytes + index length:amountToSend];
            
            [messageArray addObject:[self packMsg:chunk andIsNew:(index == 0) andIsCompleted:isComplete]];
            
            index += amountToSend;
        }
    }
    
    return messageArray;
}

-(void)processMsg:(NSData*)msg from:(NSString*)uuid
{
    char* msgPointer = (char*)[msg bytes];
    NSUInteger msgLength = [msg length];
    BOOL isNewMsg = (BOOL)msgPointer[0];
    BOOL isCompleted = (BOOL)msgPointer[1];
    msgPointer++;
    msgPointer++;
    
    NSData* msgData;
    msgData = [NSData dataWithBytes:msgPointer length:msgLength-2];
    
    if (isNewMsg) {
        if (isCompleted) {
            if (self.session != nil) {
                [self.session onDataReceived:msgData from:uuid];
            }
        } else {
            NCMCMessageData* data = [self getMessageData:uuid];
            if (data != nil) {
                [data clearData];
            } else {
                data = [[NCMCMessageData alloc]initWithDeviceUUID:uuid andIsReliable:YES];
            }
            [data addData:msgData];
            
            if (recMsgArray == nil) {
                recMsgArray = [[NSMutableArray alloc]init];
            }
            [recMsgArray addObject:data];
        }
    } else {
        NCMCMessageData* data = [self getMessageData:uuid];
        if (data != nil) {
            [data addData:msgData];
            if (isCompleted) {
                
                if (self.session != nil) {
                    [self.session onDataReceived:msgData from:uuid];
                }
                
                [data clearData];
                [recMsgArray removeObject:data];
            }
        }
        
    }
}

-(NCMCMessageData*)getMessageData:(NSString*)uuid
{
    NCMCMessageData* data = nil;
    if (recMsgArray != nil) {
        for (NCMCMessageData* d in recMsgArray) {
            if ([[d deviceUUID] isEqualToString:uuid]) {
                data = d;
                break;
            }
        }
    }
    
    return data;
}

-(NSData*)packMsg:(NSData*)msg andIsNew:(BOOL)isNewMsg andIsCompleted:(BOOL)isCompleted{
    NSUInteger len = [msg length];
    char targetBuffer[len+2];
    char* target = targetBuffer;
    targetBuffer[0] = isNewMsg;
    target++;
    targetBuffer[1] = isCompleted;
    target++;
    
    if(msg == nil) {
        // this message has no content
        return [NSData dataWithBytes:targetBuffer length:2];
    }
    
    memcpy(target, [msg bytes], len);
    
    return [NSData dataWithBytes:targetBuffer length:len+2];
}
/***********************************************************************/
/*                          CENTRAL FUNCTIONS                          */
/***********************************************************************/

-(void)setupCentralEnv:(NCMCCentralService*)service
{
    [self setupDispatchQueue];
    if (self.discoveredPeripherals != nil) {
        [self.discoveredPeripherals removeAllObjects];
    } else {
        self.discoveredPeripherals = [[NSMutableDictionary alloc]init];
    }
    if (dataToSend != nil) {
        [dataToSend removeAllObjects];
    }
    self.centralService = service;
    self.isCentral = YES;
    self.isDeviceReady = NO;
    isBrowsingOrAdvertising = NO;
    [self.session setSelfAsCentral];
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:self.concurrentBluetoothLEDelegateQueue];
}

-(Boolean)startBrowsing
{
    if (self.isDeviceReady) {
        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:self.session.serviceID]]  options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO}] ;
        NSLog(@"BluetoothLE central scanning started");
    } else {
        NSLog(@"Device is not ready, scheduled for start later");
    }
    
    isBrowsingOrAdvertising = YES;
    
    return self.isDeviceReady;
}

-(void)stopBrowsing
{
    //self.centralService = nil;
    [self.centralManager stopScan];
    isBrowsingOrAdvertising = NO;
}

-(void)invitePeer:(NCMCPeerID *)peerID
{
    NCMCPeripheralInfo *info =  self.discoveredPeripherals[peerID.identifier];
    NSLog(@"Connecting to peripheral name = %@ id = %@", info.name, peerID.identifier);
    [self.centralManager connectPeripheral:info.peripheral options:nil];
}

-(void)disconnectToPeripheral:(NSString *)identifier
{
    NCMCPeripheralInfo* info =  self.discoveredPeripherals[identifier];
    [self disconnectToPeripheralByInfo:info];
}

-(void)disconnectToPeripheralByInfo:(NCMCPeripheralInfo *)info
{
    if (info != nil) {
        if (info.peripheral !=nil)
        {
            for (CBService *service in info.peripheral.services)
            {
                if (service.characteristics != nil)
                {
                    for (CBCharacteristic *characteristic in service.characteristics) {
                        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID]])
                        {
                            if (characteristic.isNotifying) {
                                [info.peripheral setNotifyValue:NO forCharacteristic:characteristic];
                            }
                        }
                    }
                }
            }
            
            [info.peripheral setDelegate:nil];
            [self.centralManager cancelPeripheralConnection:info.peripheral];
        }
    }
}

-(void)sendCentralData : (NSData*)data toPeripheral:(NSString*)identifier  withMode:(NCMCSessionSendDataMode)mode
{
    NCMCPeripheralInfo *info = self.discoveredPeripherals[(NSString*)identifier];
    if (info) {
        if (dataToSend == nil) {
            dataToSend = [[NSMutableArray alloc]init];
        }
        Boolean isReliable = ((mode == NCMCSessionSendDataReliable) ? YES : NO);

        CBCharacteristicWriteType capabilityType = isReliable ? CBCharacteristicWriteWithResponse : CBCharacteristicWriteWithoutResponse;
        NSArray *msgs = [self makeMsg:data byCapability:[info.peripheral maximumWriteValueLengthForType: capabilityType]];
        
        dispatch_async(self.serialDataSendingQueue, ^{
            for (NSData *msg in msgs) {
                NCMCMessageData *msgData = [[NCMCMessageData alloc]initWithDeviceUUID:info.peripheral.identifier.UUIDString andIsReliable:isReliable];
                [msgData addData:msg];
                [dataToSend addObject:msgData];
            }
        });
        
        [self executeSendCentralData];
    }
}

-(void)executeSendCentralData
{
    dispatch_async(self.serialDataSendingQueue, ^{
        if (dataToSend == nil || dataToSend.count == 0) {
            return;
        }
        
        for (NCMCMessageData *data in dataToSend){
            NCMCPeripheralInfo *info = self.discoveredPeripherals[[data deviceUUID]];
            if (info != nil) {
                if ([data isReliable]) {
                    [info.peripheral writeValue:[data data] forCharacteristic:info.writeWithResponseCharacteristic type:CBCharacteristicWriteWithResponse];
                    NSLog(@"sendDataToClients reliable dataSize = %lu", (unsigned long)[data data].length);
                } else {
                    [info.peripheral writeValue:[data data] forCharacteristic:info.writeWithoutResponseCharacteristic type:CBCharacteristicWriteWithoutResponse];
                    NSLog(@"sendDataToClients unreliable dataSize = %lu", (unsigned long)[data data].length);
                }
                
            }
        }
        
        [dataToSend removeAllObjects];
    });
}

// begin CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state != CBCentralManagerStatePoweredOn) {
        NSLog(@"Bluetooth is OFF !!!");

        if (self.centralService != nil) {
            NSError* error = [self errnoErrorWithReason:@"Bluetooth Off"];
            
            [self.centralService notifyDidNotStartBrowsingForPeers:error];
        }
        
        self.isDeviceReady = NO;
        
        return;
    }
    
    if (central.state == CBCentralManagerStatePoweredOn) {
        self.isDeviceReady = YES;
        if (isBrowsingOrAdvertising) {
            [self startBrowsing];
        }
    }
}

- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    if (self.centralService == nil || self.centralService.session == nil) {
        return;
    }
    
    if (![advertisementData[CBAdvertisementDataServiceUUIDsKey] containsObject:[CBUUID UUIDWithString:self.centralService.session.serviceID]] || [advertisementData count] < 3) {
        return;
    }
    
    NSString* name = advertisementData[CBAdvertisementDataLocalNameKey];
    
    if (self.discoveredPeripherals[peripheral.identifier.UUIDString] == nil) {
        NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
        
        NCMCPeripheralInfo *info = [[NCMCPeripheralInfo alloc]init];
        info.peripheral = peripheral;
        info.readCharacteristic = nil;
        info.writeWithResponseCharacteristic = nil;
        info.writeWithoutResponseCharacteristic = nil;
        info.name = name;
        self.discoveredPeripherals[peripheral.identifier.UUIDString] = info;
        peripheral.delegate = self;
        
        NCMCPeerID* peerID = [[NCMCPeerID alloc]initWithDisplayName:name andIdentifier:peripheral.identifier.UUIDString andUniqueID:-1];
        [self.centralService notifyFoundPeer:peerID];
    }
}

- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NCMCPeripheralInfo *info = self.discoveredPeripherals[peripheral.identifier.UUIDString];
    if (info) {
        NCMCPeerID* peerID = [[NCMCPeerID alloc]initWithDisplayName:info.name andIdentifier:peripheral.identifier.UUIDString andUniqueID:-1];
        [self.centralService notifyLostPeer:peerID];
        
        [self.discoveredPeripherals removeObjectForKey:peripheral.identifier.UUIDString];
    } else {
        // shouldn't be here
        NSLog(@"error!!!  cannot find peripheral in discoveredPeripherals");
    }
    
    [self.centralManager cancelPeripheralConnection:peripheral];
}

- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NCMCPeripheralInfo *info = self.discoveredPeripherals[peripheral.identifier.UUIDString];
    if (!info) {
        // shouldn't be here
        NSLog(@"error!!!  cannot find peripheral in discoveredPeripherals");
        return;
    }
    
    NSLog(@"Connected to %@", info.name);
    NSLog(@"Trying to find transfer service in %@", info.name);

    [peripheral discoverServices:@[[CBUUID UUIDWithString:self.session.serviceID]]];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"didDisconnectPeripheral %@", peripheral.identifier.UUIDString);
    // TODO session notify stat
    NCMCPeripheralInfo *info = self.discoveredPeripherals[peripheral.identifier.UUIDString];
    if (info) {
        //NCMCPeerID* peerID = [[NCMCPeerID alloc]initWithDisplayName:info.name andIdentifier:peripheral.identifier.UUIDString];
        /*
        if (self.centralService != nil) {
            [self.centralService notifyLostPeer:peerID];
        }*/
        
        if (self.session != nil) {
            [self.session onPeripheralDisconnected:peripheral.identifier.UUIDString];
        }
        
        [self.discoveredPeripherals removeObjectForKey:peripheral.identifier.UUIDString];
    }
}
// end CBCentralManagerDelegate

// begin CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NCMCPeripheralInfo *info = self.discoveredPeripherals[peripheral.identifier.UUIDString];
    if (!info) {
        // shouldn't be here
        NSLog(@"error!!!  cannot find peripheral in discoveredPeripherals");
        return;
    }
    if (error)
    {
        NSLog(@"discovery service failed : %@", error.localizedDescription);
        
        NCMCPeerID* peerID = [[NCMCPeerID alloc]initWithDisplayName:info.name andIdentifier:peripheral.identifier.UUIDString andUniqueID:-1];
        [self.centralService notifyLostPeer:peerID];
        
        [self.discoveredPeripherals removeObjectForKey:peripheral.identifier.UUIDString];
        [self.centralManager cancelPeripheralConnection:peripheral];
        return;
    }
    
    NSLog(@"transfer service found in %@", info.name);
    
    for (CBService *service in peripheral.services)
    {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID], [CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_WITH_RESPONSE_UUID], [CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_WITHOUT_RESPONSE_UUID]] forService:service];
    }
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NCMCPeripheralInfo *info = self.discoveredPeripherals[peripheral.identifier.UUIDString];
    if (!info) {
        // shouldn't be here
        NSLog(@"error!!!  cannot find peripheral in discoveredPeripherals");
        return;
    }
    if (error) {
        NSLog(@"discovery Characteristics failed : %@", error.localizedDescription);
        
        NCMCPeerID* peerID = [[NCMCPeerID alloc]initWithDisplayName:info.name andIdentifier:peripheral.identifier.UUIDString andUniqueID:-1];
        [self.centralService notifyLostPeer:peerID];
        
        [self.discoveredPeripherals removeObjectForKey:peripheral.identifier.UUIDString];
        [self.centralManager cancelPeripheralConnection:peripheral];
        return;
    }
    
    BOOL isReadCharFound = NO;
    BOOL isWriteWithResponseCharFoud = NO;
    BOOL isWriteWithoutResponseCharFoud = NO;
    
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID]])
        {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            info.readCharacteristic = characteristic;
            isReadCharFound = YES;
        }
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_WITH_RESPONSE_UUID]])
        {
            info.writeWithResponseCharacteristic = characteristic;
            isWriteWithResponseCharFoud = YES;
        }
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_WITHOUT_RESPONSE_UUID]])
        {
            info.writeWithoutResponseCharacteristic = characteristic;
            isWriteWithoutResponseCharFoud = YES;
        }
    }
#if __CC_PLATFORM_IOS
    NSLog(@"peripheral maxResponse : %lu , maxNoResponse : %lu", (unsigned long)[peripheral maximumWriteValueLengthForType: CBCharacteristicWriteWithResponse], (unsigned long)[peripheral maximumWriteValueLengthForType: CBCharacteristicWriteWithoutResponse]);
#endif
   NCMCPeerID* peerID = [[NCMCPeerID alloc]initWithDisplayName:info.name andIdentifier:peripheral.identifier.UUIDString andUniqueID:-1];
    if (isReadCharFound && isWriteWithResponseCharFoud && isWriteWithoutResponseCharFoud) {
        // send central info to peripheral and wait for perpheral confirm the connection
        if (self.session != nil) {
            [self.session sendCentralConnectionRequestToPeer:peerID];
        }
    } else {
        [self.centralService notifyLostPeer:peerID];
        
        [self.discoveredPeripherals removeObjectForKey:peripheral.identifier.UUIDString];
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID]]) {
        return;
    }
    
    if (error != nil) {
        NSLog(@"set notification falied : %@", error);
        [self.discoveredPeripherals removeObjectForKey:peripheral.identifier.UUIDString];
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
    
    // waiting for perpheral confirm the connection
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"peripheral update value failed for characteristic %@ with error : %@", characteristic, error);
        return;
    }
    
    NCMCPeripheralInfo *info = self.discoveredPeripherals[peripheral.identifier.UUIDString];
    
    if (![characteristic isEqual:info.readCharacteristic]) {
        return;
    }
    
    //NSLog(@"centralManager receive data length %u", characteristic.value.length);
    
    [self processMsg:characteristic.value from:peripheral.identifier.UUIDString];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Central write Error : %@", error);
        return;
    }
    
    NCMCPeripheralInfo *info = self.discoveredPeripherals[peripheral.identifier.UUIDString];
    NSLog(@"didWriteValueForCharacteristic to %@", info.name);
}
// end CBPeripheralDelegate

/***********************************************************************/
/*                          PERIPHERAL FUNCTIONS                       */
/***********************************************************************/

-(void)setupPeripheralEnv:(NCMCPeripheralService*)service
{
    [self setupDispatchQueue];
    if (dataToSend != nil) {
        [dataToSend removeAllObjects];
    }
    if (self.connectedCentrals != nil) {
        [self.connectedCentrals removeAllObjects];
    } else {
        self.connectedCentrals = [[NSMutableDictionary alloc]init];
    }
    self.peripheralService = service;
    self.isCentral = NO;
    self.isDeviceReady = NO;
    isBrowsingOrAdvertising = NO;
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:self.concurrentBluetoothLEDelegateQueue];
}

-(Boolean)startAdvertising
{
    if (self.isDeviceReady && self.session != nil) {
        [self.peripheralManager startAdvertising:@{CBAdvertisementDataLocalNameKey:self.session.myPeerID.displayName,CBAdvertisementDataServiceUUIDsKey:@[[CBUUID UUIDWithString:self.session.serviceID]]}];
        NSLog(@"peripheralManager startAdvertising...");
    } else {
        NSLog(@"Device is not ready, scheduled for start later");
    }
    
    isBrowsingOrAdvertising = YES;
    
    return self.isDeviceReady;
}

-(void) stopAdvertising
{
    //self.peripheralService = nil;
    [self.peripheralManager stopAdvertising];
    isBrowsingOrAdvertising = NO;
}

-(void)sendPeripheralData : (NSData*)data toCentral:(NSString*)identifier
{
    if (!self.isCentral && ![identifier isEqualToString:@""]) {
        CBCentral* centralDevice = self.connectedCentrals[identifier];
        if (centralDevice == nil) {
            return;
        }

        if (dataToSend == nil) {
            dataToSend = [[NSMutableArray alloc]init];
        }
        
        NSArray *msgs = [self makeMsg:data byCapability:centralDevice.maximumUpdateValueLength];
        
        dispatch_async(self.serialDataSendingQueue, ^{
            for (NSData *msg in msgs) {
                NCMCMessageData *msgData = [[NCMCMessageData alloc]initWithDeviceUUID:identifier andIsReliable:YES];
                [msgData addData:msg];
                [dataToSend addObject:msgData];
            }
        });
        
        [self executeSendPeripheralData];
    }
}

- (void)executeSendPeripheralData
{
    dispatch_async(self.serialDataSendingQueue, ^{
        if (dataToSend == nil || dataToSend.count == 0) {
            return;
        }
        
        int sendCount = 0;
        
        for (NCMCMessageData *data in dataToSend){
            BOOL didSent = NO;
            
            CBCentral* centralDevice = self.connectedCentrals[data.deviceUUID];
            if (centralDevice != nil) {
                
                NSArray* targets = @[centralDevice];
                didSent = [self.peripheralManager updateValue:[data data] forCharacteristic:self.sendCharacteristic onSubscribedCentrals:targets];
                
                if (!didSent) {
                    NSLog(@"message didn't send, break.");
                    break;
                } else {
                    ++sendCount;
                    NSLog(@"message send, length = %d", (int)[data data].length);
                }
            }
        }
        
        [dataToSend removeObjectsInRange:(NSRange){0, sendCount}];
    });
}

// begin CBPeripheralManagerDelegate
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        NSLog(@"Bluetooth is OFF !!!");
        
        if (self.peripheralService != nil) {
            NSError* error = [self errnoErrorWithReason:@"Bluetooth Off"];
            
            [self.peripheralService notifyDidNotStartAdvertising:error];
        }
        
        self.isDeviceReady = NO;
        
        return;
    }
    
    if (peripheral.state == CBPeripheralManagerStatePoweredOn && self.session != nil) {
        self.sendCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID] properties:CBCharacteristicPropertyNotify | CBCharacteristicPropertyRead value:nil permissions:CBAttributePermissionsReadable];
        
        self.receiveWithResponseCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_WITH_RESPONSE_UUID] properties:CBCharacteristicPropertyWrite value:nil permissions:CBAttributePermissionsWriteable];
        
        self.receiveWithoutResponseCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_WITHOUT_RESPONSE_UUID] properties:CBCharacteristicPropertyWriteWithoutResponse value:nil permissions:CBAttributePermissionsWriteable];
        
        CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:self.session.serviceID] primary:YES];
        
        transferService.characteristics = @[self.sendCharacteristic, self.receiveWithResponseCharacteristic, receiveWithoutResponseCharacteristic];
        
        [self.peripheralManager addService:transferService];
        
        if (self.connectedCentrals != nil) {
            self.connectedCentrals = [[NSMutableDictionary alloc]init];
        } else {
            [self.connectedCentrals removeAllObjects];
        }
        
        self.isDeviceReady = YES;
        
        if (isBrowsingOrAdvertising) {
            [self startAdvertising];
        }
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"didUnsubscribeToCharacteristic central : %@", central.identifier);
    if ([self.sendCharacteristic isEqual:characteristic]) {
        
        [self.connectedCentrals removeObjectForKey:central.identifier.UUIDString];
        
        if (self.session != nil) {
            [self.session onCentralDisconnected];
        }
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"didSubscribeToCharacteristic central.maximumUpdateValueLength = %lu" , (unsigned long)central.maximumUpdateValueLength);
    if (self.connectedCentrals == nil) {
        self.connectedCentrals = [[NSMutableDictionary alloc]init];
    }
    self.connectedCentrals[central.identifier.UUIDString] = central;
    // Do nothing, waiting for central information message
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    [self executeSendPeripheralData];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests
{
    for (CBATTRequest *request in requests) {
        if ([request.characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_WITH_RESPONSE_UUID]]) {
            [peripheral respondToRequest:request    withResult:CBATTErrorSuccess];
            //NSLog(@"peripheralManager receive response data length %u", request.value.length);
        }
        NSMutableString *identifier = [NSMutableString stringWithString:request.central.identifier.UUIDString];
        
        [self processMsg:request.value from:identifier];
    }
}
// end CBPeripheralManagerDelegate

@end
