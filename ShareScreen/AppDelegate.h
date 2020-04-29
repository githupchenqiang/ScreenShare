//
//  AppDelegate.h
//  ShareScreen
//
//  Created by AmpleSky on 2020/4/8.
//  Copyright © 2020年 ampleskyTeam. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
@interface AppDelegate : UIResponder <UIApplicationDelegate,AVAudioPlayerDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic, strong)NSURLSessionDataTask *dataTask;
@property (nonatomic, strong)NSTimer*        timer;
@property (nonatomic, unsafe_unretained) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, strong)AVAudioPlayer  *audioPlayer;

@end

