//
//  TTXMPPController.h
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
#import "XMPPFramework.h"

#warning 这里需要根据实际情况配置
#define XMPP_DOMAIN      @"xmpp.xxx.com"    //domain
#define XMPP_PORT        8333               //服务器端口
#define XMPP_HOST        @"192.168.0.11"    //服务器地址

@interface TTXMPPController : NSObject<XMPPStreamDelegate, XMPPReconnectDelegate, XMPPPingDelegate, XMPPAutoPingDelegate>
{
    NSString * _username;
    NSString * _password;
}

@property (nonatomic, retain) NSString * username;
@property (nonatomic, retain) NSString * password;

@property (nonatomic, assign) int packageCount;     //开始sm后收到服务器发送数据包数量

+ (id)shareInstance;

//设置当前连接XMPP的用户名和密码，会断开连接再从新连接XMPP服务器
+ (void)setupSharedUsername:(NSString *)username andPassword:(NSString *)password;

//发送消息
- (void)sendMessage:(NSString *)message userId:(NSString *)userId;

//卸载，将保存的用户密码清空，并且断开连接
+ (void)uninstallShared;

- (BOOL)connect;   //连接服务器
- (void)connectAfterDelay:(NSTimeInterval)delay;
- (void)disconnect;//断开连接
- (BOOL)isConnecting;//是否连接着

- (void)goOnline;  //上线
- (void)goOffline; //下线

@end
