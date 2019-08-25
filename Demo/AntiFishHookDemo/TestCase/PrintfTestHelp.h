//
//  Test.h
//  FishHookProtect
//
//  Created by jintao on 2019/3/25.
//  Copyright © 2019 jintao. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PrintfTestHelp : NSObject

+ (void)printf: (NSString *)str;

+ (void)antiFishhook;

@end

NS_ASSUME_NONNULL_END
