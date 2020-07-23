//
//  FTLogHook.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/15.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTLogHook.h"
#import "FTfishhook.h"
#import "FTMobileAgent+Private.h"
#import "FTConstants.h"
#import "FTBaseInfoHander.h"
#import "NSDate+FTAdd.h"
static FTFishHookCallBack FTHookCallBack;

static ssize_t (*orig_writev)(int a, const struct iovec * v, int v_len);

// swizzle method
ssize_t asl_writev(int a, const struct iovec *v, int v_len) {
    
    NSMutableString *string = [NSMutableString string];
    for (int i = 0; i < v_len; i++) {
        char *c = (char *)v[i].iov_base;
        [string appendString:[NSString stringWithCString:c encoding:NSUTF8StringEncoding]];
    }
    
    ////////// do something  这里可以捕获到日志 string
    if(string.length&&![string containsString:@"[FTLog]"]&&FTHookCallBack){
        FTHookCallBack(string,[[NSDate date] ft_dateTimestamp]);
    }
    // invoke origin mehtod
    ssize_t result = orig_writev(a, v, v_len);
    return result;
}
// origin fprintf IMP
static int     (*origin_fprintf)(FILE * __restrict, const char * __restrict, ...);

// swizzle method
int     asl_fprintf(FILE * __restrict file, const char * __restrict format, ...)
{
    /*
     typedef struct {
     
     unsigned int gp_offset;
     unsigned int fp_offset;
     void *overflow_arg_area;
     void *reg_save_area;
     } va_list[1];
     */
    va_list args;
    
    va_start(args, format);
    
    NSString *formatter = [NSString stringWithUTF8String:format];
    NSString *string = [[NSString alloc] initWithFormat:formatter arguments:args];
    
    ////////// do something  这里可以捕获到日志
    if(string.length&&![string containsString:@"[FTLog]"]&&FTHookCallBack){
        FTHookCallBack(string,[[NSDate date] ft_dateTimestamp]);
    }
    // invoke orign fprintf
    int result = origin_fprintf(file, [string UTF8String]);
    
    va_end(args);
    
    return result;
}
// origin fwrite IMP
static size_t (*orig_fwrite)(const void * __restrict, size_t, size_t, FILE * __restrict);

static char *__messageBuffer = {0};
static int __buffIdx = 0;
void reset_buffer()
{
    __messageBuffer = calloc(1, sizeof(char));
    __messageBuffer[0] = '\0';
    __buffIdx = 0;
}


// swizzle method
size_t asl_fwrite(const void * __restrict ptr, size_t size, size_t nitems, FILE * __restrict stream) {
    
    if (__messageBuffer == NULL) {
        // initial Buffer
        reset_buffer();
    }
    
    char *str = (char *)ptr;
    
    NSString *s = [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
    
    if (__messageBuffer != NULL) {
        
        if (str[0] == '\n' && __messageBuffer[0] != '\0') {
            
            s = [[NSString stringWithCString:__messageBuffer encoding:NSUTF8StringEncoding] stringByAppendingString:s];
            
            // reset buffIdx
            reset_buffer();
            
            ////////// do something  这里可以捕获到日志
            if(s.length>0&&![s containsString:@"[FTLog]"]&&FTHookCallBack){
                FTHookCallBack(s,[[NSDate date] ft_dateTimestamp]);
            }
        }
        else {
            
            // append buffer
            __messageBuffer = realloc(__messageBuffer, sizeof(char) * (__buffIdx + nitems + 1));
            for (size_t i = __buffIdx; i < nitems; i++) {
                __messageBuffer[i] = str[i];
                __buffIdx ++;
            }
            __messageBuffer[__buffIdx + 1] = '\0';
            __buffIdx ++;
        }
    }
    
    return orig_fwrite(ptr, size, nitems, stream);
}
@implementation FTLogHook

+ (void)hookWithBlock:(FTFishHookCallBack)callBack{
    ft_rebind_symbols((struct ft_rebinding[1]){{
        "writev",
        asl_writev,
        (void*)&orig_writev
    }}, 1);
    
    // hook fwrite
    ft_rebind_symbols((struct ft_rebinding[1]){{
        "fwrite",
        asl_fwrite,
        (void *)&orig_fwrite}}, 1);
    
    // hook fprintf
    ft_rebind_symbols((struct ft_rebinding[1]){{
        "fprintf",
        asl_fprintf,
        (void *)&origin_fprintf}}, 1);
    FTHookCallBack = callBack;
}



@end
