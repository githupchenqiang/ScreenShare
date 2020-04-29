//
//  AppDelegate.m
//  ShareScreen
//
//  Created by AmpleSky on 2020/4/8.
//  Copyright © 2020年 ampleskyTeam. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    self.backgroundTaskIdentifier =[application beginBackgroundTaskWithExpirationHandler:^(void) {
        [self endBackgroundTask];
        
    }];
    
    if (!self.audioPlayer) {
        [self setAudio];
        NSLog(@"初始化");
    }else{
        [self.audioPlayer play];
        NSLog(@"播放");
    }
    
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[UIApplication sharedApplication]endBackgroundTask:self.backgroundTaskIdentifier];
    // 销毁后台任务标识符
    self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    [self.audioPlayer pause];
    
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


- (void) endBackgroundTask{
    
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    
    AppDelegate *weakSelf = self;
    
    dispatch_async(mainQueue, ^(void) {
        
        AppDelegate *strongSelf = weakSelf;
        
        if (strongSelf != nil){
            
//            [strongSelf.myTimer invalidate];// 停止定时器
            
            // 每个对 beginBackgroundTaskWithExpirationHandler:方法的调用,必须要相应的调用 endBackgroundTask:方法。这样，来告诉应用程序你已经执行完成了。
            
            // 也就是说,我们向 iOS 要更多时间来完成一个任务,那么我们必须告诉 iOS 你什么时候能完成那个任务。
            
            // 也就是要告诉应用程序：“好借好还”嘛。
            
            // 标记指定的后台任务完成
            
            [[UIApplication sharedApplication]endBackgroundTask:self.backgroundTaskIdentifier];
            
            // 销毁后台任务标识符
            
            strongSelf.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
            
        }
        
    });
    
}

- (void)setAudio{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        NSError *audioSessionError = nil;
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        if ([audioSession setCategory:AVAudioSessionCategoryPlayback error:&audioSessionError]){
            
            NSLog(@"Successfully set the audio session.");
            
        } else {
            NSLog(@"Could not set the audio session");
        }
        [audioSession setActive:YES error:nil];
        [[UIApplication sharedApplication]beginReceivingRemoteControlEvents];
        NSBundle *mainBundle = [NSBundle mainBundle];
        
        NSString *filePath = [mainBundle pathForResource:@"NoAudio"ofType:@"mp3"];
        
        NSData *fileData = [NSData dataWithContentsOfFile:filePath];
        
        NSError *error = nil;
        
        self.audioPlayer = [[AVAudioPlayer alloc] initWithData:fileData error:&error];
        
        if (self.audioPlayer != nil){
            //      [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(AudioPlayerNotice:) name:AVAudioSessionInterruptionNotification object:nil];
            self.audioPlayer.delegate = self;
            
            [self.audioPlayer setNumberOfLoops:-1];
            [self.audioPlayer prepareToPlay];
            [self.audioPlayer play];
            if ([self.audioPlayer prepareToPlay] && [self.audioPlayer play]){
                NSLog(@"Successfully started playing...");
            } else {
                NSLog(@"Failed to play.");
            }
        } else {
            
        }
    });
    
}

@end
