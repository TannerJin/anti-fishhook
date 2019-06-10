//
//  Test.h
//  FishHookProtect
//
//  Created by jintao on 2019/3/25.
//  Copyright © 2019 jintao. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TestHelp : NSObject

+ (void)printWithStr: (NSString *)str;

+ (void *)getNewPrintMehod;
+ (void *)getNewDladdrMethod;
+ (void *)getNewDlopenMethod;
+ (void *)getNewSwiftFoundationNSLog;

@end

NS_ASSUME_NONNULL_END
