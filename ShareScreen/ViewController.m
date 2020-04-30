//
//  ViewController.m
//  ShareScreen
//
//  Created by AmpleSky on 2020/4/8.
//  Copyright © 2020年 ampleskyTeam. All rights reserved.
//

#import "ViewController.h"
#import <ReplayKit/ReplayKit.h>
#import "GCDAsyncSocket.h"
#import "NTESTPCircularBuffer.h"
#import "NTESSocketPacket.h"
#import "NTESI420Frame.h"
#import "NTESYUVConverter.h"
@interface ViewController ()<GCDAsyncSocketDelegate>
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSMutableArray *sockets;
@property (nonatomic, assign) NTESTPCircularBuffer *recvBuffer;
@property (nonatomic, assign)NSInteger        rotation;
@property (nonatomic,strong)RPSystemBroadcastPickerView     *broadPickerView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupSocket];
    [self.view addSubview:self.broadPickerView];
    //切换分支了,查看是否有x影响
}
//getMedia

- (RPSystemBroadcastPickerView *)broadPickerView{
    if(!_broadPickerView){
        _broadPickerView = [[RPSystemBroadcastPickerView alloc] initWithFrame:CGRectMake(100, 100, 50, 50)];
        //    _broadPickerView.showsMicrophoneButton = NO;
        _broadPickerView.preferredExtension = @"com.amplesky.client.claireye.upLoadPro";
    }
    return _broadPickerView;
}


- (void)setupSocket
{
    
    self.sockets = [NSMutableArray array];
    self.recvBuffer = (NTESTPCircularBuffer *)malloc(sizeof(NTESTPCircularBuffer)); // 需要释放
    NTESTPCircularBufferInit(self.recvBuffer, kRecvBufferMaxSize);
    //    self.queue = dispatch_queue_create("com.netease.edu.rp.server", DISPATCH_QUEUE_SERIAL);
    self.queue = dispatch_get_main_queue();
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.queue];
    self.socket.IPv6Enabled = NO;
    NSError *error;
    //    [self.socket acceptOnUrl:[NSURL fileURLWithPath:serverURL] error:&error];
    [self.socket acceptOnPort:8999 error:&error];
    [self.socket readDataWithTimeout:-1 tag:0];
    if (error == nil)
    {
        NSLog(@"开启成功");
    }
    else
    {
        NSLog(@"开启失败");
        [self setupSocket];
    }
    NSNotificationCenter *center =[NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(defaultsChanged:)
                   name:NSUserDefaultsDidChangeNotification
                 object:nil];
}

- (void)defaultsChanged:(NSNotification *)notification
{
    GCDAsyncSocket *socket = self.sockets.count ? self.sockets[0] : nil;
    
    NSUserDefaults *defaults = (NSUserDefaults*)[notification object];
    id setting = nil;
    // 分辨率
    static NSInteger quality;
    setting = [defaults objectForKey:@"videochat_preferred_video_quality"];
    if (quality != [setting integerValue] && setting)
    {
        quality = [setting integerValue];
        NTESPacketHead head;
        head.service_id = 0;
        head.command_id = 1; // 1：分辨率 2：裁剪比例 3：视频方向
        head.data_len = 0;
        head.version = 0;
        NSString *str = [NSString stringWithFormat:@"%d", [setting intValue]];
        [socket writeData:[NTESSocketPacket packetWithBuffer:[str dataUsingEncoding:NSUTF8StringEncoding] head:&head] withTimeout:-1 tag:0];
    }
    
    // 视频方向
    static NSInteger orientation;
    setting = [defaults objectForKey:@"videochat_preferred_video_orientation"];
    if (orientation != [setting integerValue] && setting)
    {
        orientation = [setting integerValue];
        self.rotation = orientation;
        NTESPacketHead head;
        head.service_id = 0;
        head.command_id = 3; // 1：分辨率 2：裁剪比例 3：视频方向
        head.data_len = 0;
        head.version = 0;
        head.serial_id = 0;
        NSString *str = [NSString stringWithFormat:@"%@", setting];
        [socket writeData:[NTESSocketPacket packetWithBuffer:[str dataUsingEncoding:NSUTF8StringEncoding] head:&head] withTimeout:-1 tag:0];
        
    }
}

- (void)stopSocket
{
    if (self.socket)
    {
        [self.socket disconnect];
        self.socket = nil;
        [self.sockets removeAllObjects];
        NTESTPCircularBufferCleanup(self.recvBuffer);
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
    
}

#pragma mark - GCDAsyncSocketDelegate
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err
{
    NSLog(@"===断开连接==");
    NTESTPCircularBufferClear(self.recvBuffer);
    [self.sockets removeObject:sock];
}

- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock
{
    NTESTPCircularBufferClear(self.recvBuffer);
    [self.sockets removeObject:sock];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    NTESTPCircularBufferClear(self.recvBuffer);
    [self.sockets addObject:newSocket];
    [newSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
        static uint64_t currenDataSize = 0;
        static uint64_t targeDataSize = 0;
        
        BOOL isHeader = NO;
        if (data.length == sizeof(NTESPacketHead)) { // 检查是不是帧头
            NTESPacketHead *header = (NTESPacketHead *)data.bytes;
            if (header->version == 1 && header->command_id == 1 && header->service_id == 1) {
                isHeader = YES;
                targeDataSize = header->data_len;
                currenDataSize = 0;
            }
        } else {
            currenDataSize += data.length;
        }
        
        if (isHeader) { // a.接收到新的帧头，需要先把原来的缓存处理或者清空
            [self handleRecvBuffer];
            NTESTPCircularBufferProduceBytes(self.recvBuffer,
                                             data.bytes,
                                             (int32_t)data.length);
        } else if (currenDataSize >= targeDataSize
                   && currenDataSize != -1) { // b.加上新来的数据后缓存中已经满足一帧
            NTESTPCircularBufferProduceBytes(self.recvBuffer,
                                             data.bytes,
                                             (int32_t)data.length);
            currenDataSize = -1;
            [self handleRecvBuffer];
        } else { // c.不够一帧，只添加不处理
            NTESTPCircularBufferProduceBytes(self.recvBuffer,
                                             data.bytes,
                                             (int32_t)data.length);
        }
        [sock readDataWithTimeout:-1 tag:0];
    
}


- (void)handleRecvBuffer {
    if (!self.sockets.count)
    {
        return;
    }
    
    int32_t availableBytes = 0;
    void * buffer = NTESTPCircularBufferTail(self.recvBuffer, &availableBytes);
    int32_t headSize = sizeof(NTESPacketHead);
    
    if(availableBytes <= headSize) {
        //        NSLog(@" > 不够文件头");
        NTESTPCircularBufferClear(self.recvBuffer);
        return;
    }
    
    NTESPacketHead head;
    memset(&head, 0, sizeof(head));
    memcpy(&head, buffer, headSize);
    uint64_t dataLen = head.data_len;
    
    if(dataLen > availableBytes - headSize && dataLen >0) {
        //        NSLog(@" > 不够数据体");
        NTESTPCircularBufferClear(self.recvBuffer);
        return;
    }
    
    void *data = malloc(dataLen);
    memset(data, 0, dataLen);
    memcpy(data, buffer + headSize, dataLen);
    NTESTPCircularBufferClear(self.recvBuffer); // 处理完一帧数据就清空缓存
    
    if([self respondsToSelector:@selector(onRecvData:)]) {
        @autoreleasepool {
            [self onRecvData:[NSData dataWithBytes:data length:dataLen]];
        };
    }
    
    free(data);
}


#pragma mark - NTESSocketDelegate

- (void)onRecvData:(NSData *)data
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NTESI420Frame *frame = [NTESI420Frame initWithData:data];
        CMSampleBufferRef sampleBuffer = [frame convertToSampleBuffer];
        if (sampleBuffer == NULL) {
            return;
        }
            int64_t timeStampNs = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) *
            1000;
            CVPixelBufferRef rtcPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//            RTCVideoFrame *aframe = [[RTCVideoFrame alloc]initWithPixelBuffer:rtcPixelBuffer rotation:self.rotation timeStampNs:timeStampNs];
//            [self.videoCapturer.delegate capturer:self.videoCapturer didCaptureVideoFrame:aframe];
        NSLog(@"%@",sampleBuffer);
        CFRelease(sampleBuffer);
    });
    
}


static NSString * const ScreenHoleNotificationName = @"ScreenHoleNotificationName";
void MyHoleNotificationCallback(CFNotificationCenterRef center,
                                void * observer,
                                CFStringRef name,
                                void const * object,
                                CFDictionaryRef userInfo) {
    NSString *identifier = (__bridge NSString *)name;
    NSObject *sender = (__bridge NSObject *)observer;
    //NSDictionary *info = (__bridge NSDictionary *)userInfo;
    NSDictionary *info = CFBridgingRelease(userInfo);
    
    NSLog(@"userInfo %@  %@",userInfo,info);
    
    NSDictionary *notiUserInfo = @{@"identifier":identifier};
    [[NSNotificationCenter defaultCenter] postNotificationName:ScreenHoleNotificationName
                                                        object:sender
                                                      userInfo:notiUserInfo];
}


- (void)registerForNotificationsWithIdentifier:(nullable NSString *)identifier {
    [self unregisterForNotificationsWithIdentifier:identifier];
    
    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
    CFStringRef str = (__bridge CFStringRef)identifier;
    CFNotificationCenterAddObserver(center,
                                    (__bridge const void *)(self),
                                    MyHoleNotificationCallback,
                                    str,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}
- (void)unregisterForNotificationsWithIdentifier:(nullable NSString *)identifier {
    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
    CFStringRef str = (__bridge CFStringRef)identifier;
    CFNotificationCenterRemoveObserver(center,
                                       (__bridge const void *)(self),
                                       str,
                                       NULL);
}

@end
