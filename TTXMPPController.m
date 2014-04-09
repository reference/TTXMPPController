//
//  TTXMPPController.m
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
#import "TTXMPPController.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

#define XMPP_PING_INTERVAL 60

@implementation TTXMPPController
{
    XMPPStream    * _xmppStream;
    XMPPReconnect * _xmppReconnect;
    XMPPPing      * _xmppPing;
    XMPPAutoPing  * _xmppAutoPing;
}

+ (id)shareInstance
{
    static dispatch_once_t once;
    static TTXMPPController * _self;
    dispatch_once( &once, ^{ _self = [[TTXMPPController alloc] init]; } );
    return _self;
}

+ (void)setupSharedUsername:(NSString *)username andPassword:(NSString *)password
{
    TTXMPPController * xmppCtrl = [TTXMPPController shareInstance];

    [xmppCtrl disconnect];

    xmppCtrl.username = username;
    xmppCtrl.password = password;

    [xmppCtrl connectAfterDelay:1]; //延时启动连接
}

+ (void)uninstallShared
{
    TTXMPPController * xmppCtrl = [TTXMPPController shareInstance];

    [xmppCtrl disconnect];

    xmppCtrl.username = nil;
    xmppCtrl.password = nil;
}


- (id)init
{
    self = [super init];
    
    if (self) {
#if DEBUG
        [DDLog addLogger:[DDTTYLogger sharedInstance]];
#endif
        //初始化XMPP流对象
        _xmppStream = [XMPPStream new];
        [_xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
        
        //接入断线检测重连模块
        _xmppReconnect = [XMPPReconnect new];
        [_xmppReconnect activate:_xmppStream];
        [_xmppReconnect addDelegate:self delegateQueue:dispatch_get_main_queue()];
        
        //接入Ping 响应模块
        _xmppPing = [XMPPPing new];
        [_xmppPing activate:_xmppStream];
        [_xmppPing addDelegate:self delegateQueue:dispatch_get_main_queue()];//接入Ping 响应模块
        
        //接入自动 Ping 模块，(心跳；用于检测和服务器的连接是否出现问题)
        _xmppAutoPing = [XMPPAutoPing new];
        _xmppAutoPing.pingInterval = XMPP_PING_INTERVAL; //每隔几秒来一次
        _xmppAutoPing.pingTimeout = 10; //超时时间，秒
        [_xmppAutoPing activate:_xmppStream];
        [_xmppAutoPing addDelegate:self delegateQueue:dispatch_get_main_queue()];
    }
    return self;
}

#pragma mark - utils

+ (NSString*)stringWithNewUUID {
    // Create a new UUID
    CFUUIDRef uuidObj = CFUUIDCreate(nil);
    
    CFStringRef uuidString = CFUUIDCreateString(nil, uuidObj);
    NSString *result = (NSString *)CFBridgingRelease(CFStringCreateCopy( NULL, uuidString));
    CFRelease(uuidObj);
    CFRelease(uuidString);
    
    return result;
}

+ (NSString *)messageUUID {
    return [TTXMPPController stringWithNewUUID];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connect/disconnect
////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)connect
{
    if (!self.username || self.username.length == 0 || !self.password || self.password.length == 0)
    {
        [self disconnect];
        return NO;
    }

    //如果已经连接则不重复连接
    if (![_xmppStream isDisconnected])
    {
        return YES;
    }
    
    //组装 JID
    NSString * deviceModel = [[UIDevice currentDevice].model stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString * deviceUUID = [[UIDevice currentDevice].identifierForVendor UUIDString];
    NSString * appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString * resource = [NSString stringWithFormat:@"%@#%@#%@", deviceModel, deviceUUID, appVersion];
    
    //配置连接信息
    _xmppStream.hostName = XMPP_HOST;
    _xmppStream.myJID = [XMPPJID jidWithUser:self.username domain:XMPP_DOMAIN resource:resource];
    _xmppStream.hostPort = XMPP_PORT;
    
    NSError * error = nil;
    NSLog(@"XMPP > 使用JID %@ 连接服务器 %@", _xmppStream.myJID, _xmppStream.hostName);
    if ( ![_xmppStream connectWithTimeout:30 error:&error] )
    {
        NSLog(@"XMPP > 连接错误: %@", error);
        return NO;
    }
    
    return YES;
}

- (void)connectAfterDelay:(NSTimeInterval)delay
{
    [self performSelector:@selector(connect) withObject:nil afterDelay:delay];
}

- (void)disconnect
{
    [self goOffline];
    [_xmppStream disconnect];
}

- (BOOL)isConnecting
{
    return [_xmppStream isConnected];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark 发送消息|好友请求等
////////////////////////////////////////////////////////////////////////////////////////////////////

//发xmpp消息
- (void)sendMessage:(NSString *)message userId:(NSString *)userId
{
    //需要具体协议实现
    
    //例如
    /*
    NSString *jid = [NSString stringWithFormat:@"%@@%@", userId,XMPP_DOMAIN];
    
	if([message length] > 0 && jid) {
		NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
		[body setStringValue:message];
		
		NSXMLElement *msg = [NSXMLElement elementWithName:@"message"];
        [msg addAttributeWithName:@"id" stringValue:[TJXMPPController messageUUID]];
		[msg addAttributeWithName:@"type" stringValue:@"chat"];
		[msg addAttributeWithName:@"to" stringValue:jid];
        //[msg addAttributeWithName:@"from" stringValue:@"20081220.ds@gmail.com"];
		[msg addChild:body];
		
		[_xmppStream sendElement:msg];
    }
     */
}

////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark goOnline/goOffline
////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)goOnline
{
    XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
    [_xmppStream sendElement:presence];
}

- (void)goOffline
{
    XMPPPresence *presence = [XMPPPresence presenceWithType:@"unavailable"];
    [_xmppStream sendElement:presence];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStreamDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamWillConnect:(XMPPStream *)sender {
    NSLog(@"%s", sel_getName(_cmd));
}

- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket {
    NSLog(@"%s Socket: %@", sel_getName(_cmd), socket);
}

- (void)xmppStreamDidStartNegotiation:(XMPPStream *)sender {
    NSLog(@"%s StartNegotiation", sel_getName(_cmd));
}

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings {
    NSLog(@"%s Settings: %@", sel_getName(_cmd), settings);
    if (YES /*allowSelfSignedCertificates*/)
    {
        [settings setObject:[NSNumber numberWithBool:YES] forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];
    }

    if (YES /*allowSSLHostNameMismatch*/)
    {
        [settings setObject:[NSNull null] forKey:(NSString *)kCFStreamSSLPeerName];
    }

}

- (void)xmppStreamDidSecure:(XMPPStream *)sender {
    NSLog(@"%s", sel_getName(_cmd));
}

//已经建立连接
- (void)xmppStreamDidConnect:(XMPPStream *)sender{
    NSLog(@"%s", sel_getName(_cmd));
    NSLog(@"XMPP > 已和服务器建立好连接");

    //使用密码验证用户
    NSError *error = nil;
    NSLog(@"XMPP > 使用密码 %@ 验证用户", self.password);
    if (![sender authenticateWithPassword:self.password error:&error])
    {
        NSLog(@"XMPP Error authenticating: %@",error);
    }
}

- (void)xmppStreamDidRegister:(XMPPStream *)sender {
    NSLog(@"%s", sel_getName(_cmd));
}

- (void)xmppStream:(XMPPStream *)sender didNotRegister:(DDXMLElement *)error {
    NSLog(@"%s Error: %@", sel_getName(_cmd), error);
}

//验证成功
- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
    NSLog(@"%s", sel_getName(_cmd));

    NSLog(@"XMPP > 用户验证成功");

    //设置为在线状态
    [self goOnline];
}

//验证失败
- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(DDXMLElement *)error {
    NSLog(@"%s Error: %@", sel_getName(_cmd), error);

    NSLog(@"XMPP > 用户验证失败 %@",error);
}

- (NSString *)xmppStream:(XMPPStream *)sender alternativeResourceForConflictingResource:(NSString *)conflictingResource {
    NSLog(@"%s ConflictingResource: %@", sel_getName(_cmd), conflictingResource);
    return conflictingResource;
}

//将要收到 IQ 的处理方法
- (XMPPIQ *)xmppStream:(XMPPStream *)sender willReceiveIQ:(XMPPIQ *)iq {
    NSLog(@"willReceiveIQ %s IQ: %@", sel_getName(_cmd), iq);
    return iq;
}

//将要收到 Message 的处理方法
- (XMPPMessage *)xmppStream:(XMPPStream *)sender willReceiveMessage:(XMPPMessage *)message {
    NSLog(@"%s Message: %@", sel_getName(_cmd), message);
    return message;
}

//将要收到 Presence 的处理方法
- (XMPPPresence *)xmppStream:(XMPPStream *)sender willReceivePresence:(XMPPPresence *)presence {
    NSLog(@"%s Presence: %@", sel_getName(_cmd), presence);
    return presence;
}

//已经成功收到 IQ 的处理方法
- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
    NSLog(@"%s IQ: %@", sel_getName(_cmd), iq);

    return YES;
}

//已经成功收到 Message 后的处理方式
- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
    NSLog(@"receive xmpp message : %@",message);
}

//已经成功收到 Presence 的处理方法
- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence {

}

//当管道流出现错误的时候会调用该方法
- (void)xmppStream:(XMPPStream *)sender didReceiveError:(DDXMLElement *)error {
    NSLog(@"%s Error: %@", sel_getName(_cmd), error);
}

- (XMPPIQ *)xmppStream:(XMPPStream *)sender willSendIQ:(XMPPIQ *)iq {
    NSLog(@"%s IQ: %@", sel_getName(_cmd), iq);
    return iq;
}

- (XMPPMessage *)xmppStream:(XMPPStream *)sender willSendMessage:(XMPPMessage *)message {
    NSLog(@"%s Message: %@", sel_getName(_cmd), message);
    return message;
}

- (XMPPPresence *)xmppStream:(XMPPStream *)sender willSendPresence:(XMPPPresence *)presence {
    NSLog(@"%s Presence: %@", sel_getName(_cmd), presence);
    return presence;
}

- (void)xmppStream:(XMPPStream *)sender didSendIQ:(XMPPIQ *)iq {
    NSLog(@"didSendIQ %s IQ: %@", sel_getName(_cmd), iq);
}

//消息发送成功，要处理发送成功后的业务在此
- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message {
    NSLog(@"%s Message: %@", sel_getName(_cmd), message);
}

- (void)xmppStream:(XMPPStream *)sender didSendPresence:(XMPPPresence *)presence {
    NSLog(@"%s Presence: %@", sel_getName(_cmd), presence);
}

- (void)xmppStreamWasToldToDisconnect:(XMPPStream *)sender {
    NSLog(@"%s", sel_getName(_cmd));
}

//当管道连接出现问题的时候被调用
- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error {
    NSLog(@"%s Error: %@", sel_getName(_cmd), error);
}

- (void)xmppStream:(XMPPStream *)sender didReceiveP2PFeatures:(DDXMLElement *)streamFeatures {
    NSLog(@"%s StreamFeatures: %@", sel_getName(_cmd), streamFeatures);
}

- (void)xmppStream:(XMPPStream *)sender willSendP2PFeatures:(DDXMLElement *)streamFeatures {
    NSLog(@"%s StreamFeatures: %@", sel_getName(_cmd), streamFeatures);
}

- (void)xmppStream:(XMPPStream *)sender didRegisterModule:(id)module {
    NSLog(@"%s Module: %@", sel_getName(_cmd), module);
}

- (void)xmppStream:(XMPPStream *)sender willUnregisterModule:(id)module {
    NSLog(@"%s Module: %@", sel_getName(_cmd), module);
}

/*
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPRosterDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////

//当接收到好友请求的时候会调用该方法
- (void)xmppRoster:(XMPPRoster *)sender didReceivePresenceSubscriptionRequest:(XMPPPresence *)presence {
    NSLog(@"%s\nSender: %@\nXMPPPresence: %@", _cmd, sender, presence);
}
*/

////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPAutoPingDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppAutoPingDidSendPing:(XMPPAutoPing *)sender
{
    NSLog(@"XMPP > 已发送心跳包!!!!");
}

- (void)xmppAutoPingDidReceivePong:(XMPPAutoPing *)sender
{
    NSLog(@"XMPP > 收到心跳包回复!!!!");
}

- (void)xmppAutoPingDidTimeout:(XMPPAutoPing *)sender
{
    NSLog(@"XMPP > !!检测到有心跳包超时的情况!!");
}

////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPReconnectDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)xmppReconnect:(XMPPReconnect *)sender didDetectAccidentalDisconnect:(SCNetworkReachabilityFlags)connectionFlags {
    NSLog(@"XMPP > !!检测到意外断开连接!! > SCNetworkReachabilityFlags: %d",connectionFlags);
}

//是否尝试自动重新连接，返回YES 则开始自动连接
- (BOOL)xmppReconnect:(XMPPReconnect *)sender shouldAttemptAutoReconnect:(SCNetworkReachabilityFlags)connectionFlags {
    NSLog(@"XMPP > !!开始自动重新连接!! > SCNetworkReachabilityFlags: %d",connectionFlags);
    return YES;
}

@end
