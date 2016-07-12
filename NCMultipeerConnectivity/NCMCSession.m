//
//  NCMCSession.m
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-20.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "Core/NCMCBluetoothLEManager.h"
#import "Core/NCMCSession+Core.h"
#import "Core/NCMCPeerID+Core.h"

typedef enum NCMCSystemMessageType {
    PERIPHERAL_CENTRAL_REFUSE_INVITATION = 0,
    PERIPHERAL_CENTRAL_ACCEPT_INVITATION = 1,
    CENTRAL_PERIPHERAL_CONNECTION_REQUEST = 2,
    CENTRAL_PERIPHERAL_ASSIGN_IDENTIFIER = 3,
    CENTRAL_PERIPHERAL_DEVICE_CONNECTED = 4,
    CENTRAL_PERIPHERAL_DEVICE_DISCONNECTED = 5,
} NCMCSystemMessageType;

@implementation NCMCSession

@synthesize serviceID, myPeerID;

-(instancetype)initWithPeer:(NCMCPeerID*)peerID  andServiceID:(NSString*)sid
{
    self = [super init];
    
    if (self) {
        self.serviceID = sid;
        self.myPeerID = peerID;
        self.connectedDevices = [[NSMutableArray alloc]init];
        [self configBluetoothManger];
    }
    
    return self;
}

-(void)disconnect
{
    [[NCMCBluetoothLEManager instance] disconnect];
    [self.connectedDevices removeAllObjects];
}

-(void)sendData:(NSData *)data toPeers:(NSArray<NCMCPeerID *> *)peerIDs  withMode:(NCMCSessionSendDataMode)mode
{
    for (NCMCPeerID* peerID in peerIDs) {
        NSData* msg = [self packUserMessage:data withTargetPeerID:peerID];
        if ([[NCMCBluetoothLEManager instance]isCentral]) {
            [[NCMCBluetoothLEManager instance] sendCentralData:msg toPeripheral:peerID.identifier withMode:mode];
        } else {
            [[NCMCBluetoothLEManager instance] sendPeripheralData:msg toCentral: [self getCentralDeviceInfo].identifier];
        }
    }
}

-(NSArray<NCMCPeerID*>*)getConnectedPeers
{
    NSMutableArray* peers = [[NSMutableArray alloc]init];
    NSEnumerator *enmuerator = [self.connectedDevices objectEnumerator];
    
    for (NCMCDeviceInfo *info in enmuerator) {
        NCMCPeerID *peerID= [[NCMCPeerID alloc]initWithDisplayName:info.name andIdentifier:info.identifier andUniqueID:info.uniqueID];
        [peers addObject:peerID];
    }
    
    return peers;
}

-(void)notifyPeerStateChanged:(NCMCPeerID *)peerID newState:(NCMCSessionState)state
{
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(session:peer:didChangeState:)]) {
        [self.delegate session:self peer:peerID didChangeState:state];
    }
}

-(void)notifyDidReceiveData:(NSData *)data fromPeer:(NCMCPeerID *)peerID
{
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(session:didReceiveData:fromPeer:)]) {
        [self.delegate session:self didReceiveData:data fromPeer:peerID];
    }
}

-(void)onPeripheralDisconnected:(NSString *)identifier
{
    NCMCDeviceInfo *info = [self getDeviceInfoByIdentifier:identifier];
    if (info != nil) {
        // notify this device
        NCMCPeerID *peerID= [[NCMCPeerID alloc]initWithDisplayName:info.name andIdentifier:identifier andUniqueID:info.uniqueID];
        [self notifyPeerStateChanged:peerID newState:NCMCSessionStateNotConnected];
        
        // if central notify all peripherals
        if ([[NCMCBluetoothLEManager instance] isCentral]) {
            NSData* deviceData = [self encodeDeviceInfo:info];
            NSData* sysData = [self packSystemMessageWithType:CENTRAL_PERIPHERAL_DEVICE_DISCONNECTED andMessage:deviceData];
            
            NSEnumerator *enmuerator = [self.connectedDevices objectEnumerator];
            
            for (NCMCDeviceInfo *peripheralInfo in enmuerator) {
                if (peripheralInfo.uniqueID != 0) {
                    [[NCMCBluetoothLEManager instance] sendCentralData:sysData toPeripheral:peripheralInfo.identifier  withMode:NCMCSessionSendDataReliable];
                }
            }
        }
        
        [self.connectedDevices removeObject:info];
    }
}

-(void)onCentralDisconnected
{
    NSEnumerator *enmuerator = [self.connectedDevices objectEnumerator];
    
    for (NCMCDeviceInfo *info in enmuerator) {
        NCMCPeerID *peerID= [[NCMCPeerID alloc]initWithDisplayName:info.name andIdentifier:info.identifier andUniqueID:info.uniqueID];
        [self notifyPeerStateChanged:peerID newState:NCMCSessionStateNotConnected];
    }
    
    [self.connectedDevices removeAllObjects];
}

-(void)configBluetoothManger
{
    // clear manager first
    [[NCMCBluetoothLEManager instance] clear];

    // set current session
    [NCMCBluetoothLEManager instance].session = self;
}

-(void)setSelfAsCentral
{
    if (self.connectedDevices != nil) {
        [self.connectedDevices removeAllObjects];
    } else {
        self.connectedDevices = [[NSMutableArray alloc]init];
    }
    
    self.myPeerID.uniqueID = 0;
}

-(NSData*)packSystemMessageWithType:(char)msgType andMessage:(NSData*)msg
{
    NSUInteger len = [msg length];
    char msgBuffer[len+3];
    char* target = msgBuffer;
    msgBuffer[0] = 1; // system message
    msgBuffer[1] = msgType; // system message type
    msgBuffer[2] = 0; // nothing, system reserved
    target++;
    target++;
    target++;
    
    if(msg == nil) {
        // this message has no content
        return [NSData dataWithBytes:msgBuffer length:3];
    }
    
    memcpy(target, [msg bytes], len);
    
    return [NSData dataWithBytes:msgBuffer length:len+3];
}

-(NSData*)packUserMessage:(NSData*)msg withTargetPeerID:(NCMCPeerID*)peerID
{
    NSUInteger len = [msg length];
    char msgBuffer[len+3];
    char* target = msgBuffer;
    msgBuffer[0] = 0; // user message
    msgBuffer[1] = peerID.uniqueID; // message to
    msgBuffer[2] = self.myPeerID.uniqueID; // message from
    target++;
    target++;
    target++;
    
    if(msg == nil) {
        // this message has no content
        return [NSData dataWithBytes:msgBuffer length:3];
    }
    
    memcpy(target, [msg bytes], len);
    
    return [NSData dataWithBytes:msgBuffer length:len+3];
}

-(NCMCDeviceInfo *)decodeDeviceInfo:(NSData*)data fromPeer:(NSString*)identifier
{
    NCMCDeviceInfo* deviceInfo = [[NCMCDeviceInfo alloc]init];
    
    char* dataPointer = (char*)[data bytes];
    NSUInteger dataLength = [data length];

    deviceInfo.identifier = identifier;
    
    deviceInfo.uniqueID = (char)dataPointer[0];
    
    dataPointer++;
    NSData* nameData = [NSData dataWithBytes:dataPointer length:dataLength-1];;
    deviceInfo.name = [[NSString alloc]initWithData:nameData encoding:NSUTF8StringEncoding];
    
    return deviceInfo;
}

-(NSData*)encodeDeviceInfo:(NCMCDeviceInfo *)info
{
    NSUInteger len = [info.name length] + 1;
    char targetBuffer[len];
    char* target = targetBuffer;

    target[0] = info.uniqueID;
    target++;
    
    memcpy(target, [info.name UTF8String], [info.name length]);
    
    return [NSData dataWithBytes:targetBuffer length:len];
}

-(void)sendCentralConnectionRequestToPeer:(NCMCPeerID *)peerID
{
    NCMCDeviceInfo* centralDevice = [[NCMCDeviceInfo alloc]init];
    centralDevice.identifier = self.myPeerID.identifier; //useless, will reset with real identifier got in peripheral
    centralDevice.uniqueID = 0;
    centralDevice.name = [self.myPeerID displayName];
    
    NSData* centralDeviceData = [self encodeDeviceInfo:centralDevice];
    
    NSData* sysData = [self packSystemMessageWithType:CENTRAL_PERIPHERAL_CONNECTION_REQUEST andMessage:centralDeviceData];
    
    [[NCMCBluetoothLEManager instance] sendCentralData:sysData toPeripheral:peerID.identifier withMode:NCMCSessionSendDataReliable];
}

void(^myInvitationHandler)(BOOL, NCMCSession*, NCMCPeerID*) = ^(BOOL accept, NCMCSession* session, NCMCPeerID *peerID) {
    if(accept){
        // send accept to central and wait for assign unique id
        NCMCDeviceInfo* device = [[NCMCDeviceInfo alloc]init];
        device.identifier = session.myPeerID.identifier;
        device.uniqueID = -1;
        device.name = session.myPeerID.displayName;
        
        NSData* deviceData = [session encodeDeviceInfo:device];
        
        NSData* sysData = [session packSystemMessageWithType:PERIPHERAL_CENTRAL_ACCEPT_INVITATION andMessage:deviceData];
        
        [[NCMCBluetoothLEManager instance] sendPeripheralData:sysData toCentral:peerID.identifier];
        
        // clear and init local connected information
        NCMCDeviceInfo* centralDevice = [[NCMCDeviceInfo alloc]init];
        centralDevice.identifier = peerID.identifier;
        centralDevice.uniqueID = 0;
        centralDevice.name = peerID.displayName;
        
        if ([session connectedDevices] != nil) {
            [[session connectedDevices]removeAllObjects];
            [[session connectedDevices] addObject:centralDevice];
        }
        
    } else {
        // send refuse to central
        NSData* sysData = [session packSystemMessageWithType:PERIPHERAL_CENTRAL_REFUSE_INVITATION andMessage:nil];
        
        [[NCMCBluetoothLEManager instance] sendPeripheralData:sysData toCentral:peerID.identifier];
        
        // remove central device from local
        if ([session connectedDevices] != nil) {
            [[session connectedDevices]removeAllObjects];
        }
    }
};

-(void)onDataReceived:(NSData *)data from:(NSString *)identifier
{
    char* dataPointer = (char*)[data bytes];
    NSUInteger dataLength = [data length];
    BOOL isSysMsg = (BOOL)dataPointer[0];
    char extraInfo = (char)dataPointer[1]; // sys : sysmsg type; user : msgTo
    char extraInfo2 = (char)dataPointer[2]; // sys : nothing type; user : msgFrom
    dataPointer++;
    dataPointer++;
    dataPointer++;
    
    NSData* dataMsg = [NSData dataWithBytes:dataPointer length:dataLength-3];
    
    if (isSysMsg) {

        switch (extraInfo) {
            case PERIPHERAL_CENTRAL_REFUSE_INVITATION:
            {
                // disconnect to peripheral
                if ([[NCMCBluetoothLEManager instance] isCentral]) {
                    [[NCMCBluetoothLEManager instance] disconnectToPeripheral:identifier];
                }
                break;
            }
            case PERIPHERAL_CENTRAL_ACCEPT_INVITATION:
            {
                // assign peripheral info to peripheral
                NCMCDeviceInfo* newPeripheralDevice = [self decodeDeviceInfo:dataMsg fromPeer:identifier];
                newPeripheralDevice.identifier = identifier;
                newPeripheralDevice.uniqueID = (char)[self.connectedDevices count] + 1; // id 0 is reserved for central
                
                NSData* newDeviceData = [self encodeDeviceInfo:newPeripheralDevice];
                
                NSData* sysData = [self packSystemMessageWithType:CENTRAL_PERIPHERAL_ASSIGN_IDENTIFIER andMessage:newDeviceData];
                
                [[NCMCBluetoothLEManager instance] sendCentralData:sysData toPeripheral:identifier withMode:NCMCSessionSendDataReliable];
                
                // update new connected device info to all connected peripherals
                NSData* sysBroadcastNewDeviceData = [self packSystemMessageWithType:CENTRAL_PERIPHERAL_DEVICE_CONNECTED andMessage:newDeviceData];
                for (NCMCDeviceInfo* connectedPeripheralDeviceInfo in self.connectedDevices) {
                    [[NCMCBluetoothLEManager instance] sendCentralData:sysBroadcastNewDeviceData toPeripheral:connectedPeripheralDeviceInfo.identifier  withMode:NCMCSessionSendDataReliable];
                }
                
                // update all connected peripherals to new connected device
                for (NCMCDeviceInfo* connectedPeripheralDeviceInfo in self.connectedDevices) {
                    NSData* connectedPeripheralDeviceData = [self encodeDeviceInfo:connectedPeripheralDeviceInfo];
                    NSData* sysBroadcastOldPeripheralData = [self packSystemMessageWithType:CENTRAL_PERIPHERAL_DEVICE_CONNECTED andMessage:connectedPeripheralDeviceData];
                    [[NCMCBluetoothLEManager instance] sendCentralData:sysBroadcastOldPeripheralData toPeripheral:identifier  withMode:NCMCSessionSendDataReliable];
                }
                
                [self.connectedDevices addObject:newPeripheralDevice];
                
                // send connection status notification
                NCMCPeerID* peerID = [[NCMCPeerID alloc]initWithDisplayName:newPeripheralDevice.name andIdentifier:newPeripheralDevice.identifier andUniqueID:newPeripheralDevice.uniqueID];
                
                [self notifyPeerStateChanged:peerID newState:NCMCSessionStateConnected];

                break;
            }
            case CENTRAL_PERIPHERAL_CONNECTION_REQUEST:
            {
                if ([self getCentralDeviceInfo] != nil) {
                    // refuse connection directly when another central is being processed
                    NSData* sysData = [self packSystemMessageWithType:PERIPHERAL_CENTRAL_REFUSE_INVITATION andMessage:nil];
                    
                    [[NCMCBluetoothLEManager instance] sendPeripheralData:sysData toCentral:identifier];
                    
                }
                
                NCMCDeviceInfo* centralDevice = [self decodeDeviceInfo:dataMsg fromPeer:identifier];
                
                if (centralDevice.uniqueID == 0) {
                    centralDevice.identifier = identifier; // set with its real identifier
                }
                
                // save central device
                [self.connectedDevices addObject:centralDevice];
                
                NCMCPeerID* peerID = [[NCMCPeerID alloc]initWithDisplayName:centralDevice.name andIdentifier:centralDevice.identifier andUniqueID:centralDevice.uniqueID];
                
                // broadcast invitation
                [[[NCMCBluetoothLEManager instance] peripheralService] notifyDidReceiveInvitationFromPeer:peerID invitationHandler:myInvitationHandler];
                
                break;
            }
            case CENTRAL_PERIPHERAL_ASSIGN_IDENTIFIER:
            {
                NCMCDeviceInfo* device = [self decodeDeviceInfo:dataMsg fromPeer:identifier];
                if ([device.name isEqualToString:self.myPeerID.displayName]) {
                    self.myPeerID.identifier = device.identifier; // useless, because a device never send message to itself
                    self.myPeerID.uniqueID = device.uniqueID;
                    
                    // send central connection status notification
                    NCMCDeviceInfo* centralDevice = [self getCentralDeviceInfo];
                    NCMCPeerID* peerID = [[NCMCPeerID alloc]initWithDisplayName:centralDevice.name andIdentifier:centralDevice.identifier andUniqueID:centralDevice.uniqueID];
                    
                    [self notifyPeerStateChanged:peerID newState:NCMCSessionStateConnected];
                }
                
                break;
            }
            case CENTRAL_PERIPHERAL_DEVICE_CONNECTED:
            {
                NCMCDeviceInfo* device = [self decodeDeviceInfo:dataMsg fromPeer:identifier];
                
                // we've already added central device
                if (device.uniqueID != 0 && (device.uniqueID != self.myPeerID.uniqueID)) {
                    [self.connectedDevices addObject:device];
                    
                    // send connection status notification
                    NCMCPeerID* peerID = [[NCMCPeerID alloc]initWithDisplayName:device.name andIdentifier:device.identifier andUniqueID:device.uniqueID];
                    
                    [self notifyPeerStateChanged:peerID newState:NCMCSessionStateConnected];
                }
                break;
            }
            case CENTRAL_PERIPHERAL_DEVICE_DISCONNECTED:
            {
                NCMCDeviceInfo* device = [self decodeDeviceInfo:dataMsg fromPeer:identifier];
                NCMCDeviceInfo* connectedDevice = [self getDeviceInfoByUniqueID:device.uniqueID];
                if (connectedDevice != nil) {
                    [self.connectedDevices removeObject:connectedDevice];
                    
                    // send connection status notification
                    NCMCPeerID* peerID = [[NCMCPeerID alloc]initWithDisplayName:connectedDevice.name andIdentifier:connectedDevice.identifier andUniqueID:connectedDevice.uniqueID];
                    
                    [self notifyPeerStateChanged:peerID newState:NCMCSessionStateNotConnected];
                }
                break;
            }
        }
    } else {
        if ([[NCMCBluetoothLEManager instance] isCentral]) {
            if (extraInfo == 0) {
                // data from peripheral to central
                NCMCDeviceInfo *deviceInfo = [self getDeviceInfoByIdentifier:identifier];
                if (deviceInfo != nil) {
                    NCMCPeerID *peerID = [[NCMCPeerID alloc]initWithDisplayName:deviceInfo.name andIdentifier:deviceInfo.identifier andUniqueID:deviceInfo.uniqueID];
                    [self notifyDidReceiveData:dataMsg fromPeer:peerID];
                }
            } else {
                // data from peripheral to peripheral
                NCMCDeviceInfo* targetDevice = [self getDeviceInfoByUniqueID:extraInfo];
                if (targetDevice != nil) {
                    [[NCMCBluetoothLEManager instance] sendCentralData:data toPeripheral:targetDevice.identifier  withMode:NCMCSessionSendDataUnreliable];
                }
            }
        } else {
            if (self.myPeerID.uniqueID == extraInfo) {
                NCMCDeviceInfo *deviceInfo = [self getDeviceInfoByUniqueID:extraInfo2];
                if (deviceInfo != nil) {
                    NCMCPeerID *peerID = [[NCMCPeerID alloc]initWithDisplayName:deviceInfo.name andIdentifier:deviceInfo.identifier andUniqueID:deviceInfo.uniqueID];
                    [self notifyDidReceiveData:dataMsg fromPeer:peerID];
                }
            }
        }
    }
}

-(NCMCDeviceInfo*)getDeviceInfoByUniqueID:(char)uniqueID
{
    for (NCMCDeviceInfo* info in self.connectedDevices) {
        if (info.uniqueID == uniqueID) {
            return info;
        }
    }
    
    return nil;
}

-(NCMCDeviceInfo*)getDeviceInfoByIdentifier:(NSString*)identifier
{
    if ([[NCMCBluetoothLEManager instance]isCentral]) {
        for (NCMCDeviceInfo* info in self.connectedDevices) {
            if ([info.identifier isEqualToString:identifier]) {
                return info;
            }
        }
    } // peripherals don't know each other's identifier

    return nil;
}

-(NCMCDeviceInfo*)getCentralDeviceInfo
{
    return [self getDeviceInfoByUniqueID:0];
}

-(char)getDeviceUniqueIDByIdentifier:(NSString*)identifier
{
    NCMCDeviceInfo* device = [self getDeviceInfoByIdentifier:identifier];
    if (device != nil) {
        return device.uniqueID;
    }
    
    return -1;
}

@end
