//
//  Test.m
//  FishHookProtect
//
//  Created by jintao on 2019/3/25.
//  Copyright © 2019 jintao. All rights reserved.
//

#import "PrintfTestHelp.h"
#include "dlfcn.h"

@implementation PrintfTestHelp

+ (void)printfWithStr:(NSString *)str {
    const char *str2 = [str UTF8String];
    printf("%s", str2);
}

@end
