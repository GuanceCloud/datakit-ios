//
//  Crasher.m
//
//  Created by Karl Stenerud on 2012-01-28.
//

#import "Crasher.h"
#import <pthread.h>
#import <exception>
class MyException: public std::exception
{
public:
    virtual const char* what() const noexcept;
};

const char* MyException::what() const noexcept
{
    return "Something bad happened...";
}


class MyCPPClass
{
public:
    void throwAnException()
    {
        throw MyException();
    }
};


@interface MyClass: NSObject @end
@implementation MyClass @end

@interface MyProxy: NSProxy @end
@implementation MyProxy @end

@interface RefHolder: NSObject
{
    __unsafe_unretained id _ref;
}
@property(nonatomic, readwrite, assign) id ref;

@end

@implementation RefHolder

- (id) ref
{
    return _ref;
}

- (void) setRef:(id) ref
{
    _ref = ref;
}

@end


@interface Crasher ()

@property(nonatomic, readwrite, retain) NSLock* lock;

@end


@implementation Crasher

@synthesize lock = _lock;

- (id) init
{
    if((self = [super init]))
    {
        self.lock = [[NSLock alloc] init];
    }
    return self;
}

int* g_crasher_null_ptr = NULL;

- (void)throwUncaughtNSException
{
    
    id data = [NSArray arrayWithObject:@"Hello World"];
    [(NSDictionary*)data objectForKey:@""];
    
}

- (void)dereferenceBadPointer{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        char* ptr = (char*)-1;
        *ptr = 1;
    });
    
}

- (void)dereferenceNullPointer
{
    *g_crasher_null_ptr = 1;
}

- (void)useCorruptObject
{
    
    void* pointers[] = {NULL, NULL, NULL};
    void* randomData[] = {
        (void*)"a",
        (void*)"b",
        (void*)pointers,
        (void*)"d",
        (void*)"e",
        (void*)"f"};
    
    // A corrupted/under-retained/re-used piece of memory
    struct {void* isa;} corruptObj = {randomData};
    
    // Message an invalid/corrupt object.
    // This will deadlock if called in a crash handler.
    [(__bridge id)&corruptObj class];
    
    
    // From http://landonf.bikemonkey.org/2011/09/14
    
    // Random data
    
}

- (void)spinRunloop
{
    // From http://landonf.bikemonkey.org/2011/09/14
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^
                       {
            NSLog(@"ERROR: Run loop should be dead but isn't!");
        });
        *g_crasher_null_ptr = 1;
    });
    
}

static volatile int counter = 0; // To prevent recursion optimization

- (void)causeStackOverflow
{
    [self causeStackOverflow];
    counter++;
}

- (void)doAbort
{
    abort();
}
int g_crasher_denominator = 0;
- (void) doDiv0
{
    int value = 10;
    value /= g_crasher_denominator;
    NSLog(@"%d", value);
}

- (void)accessDeallocatedObject
{
    //    NSArray* array = [[NSArray alloc] initWithObjects:@"", nil];
    //    [array release];
    //    void* ptr = array;
    //    memset(ptr, 0xe1, 16);
    //    [array objectAtIndex:10];
    //    return;
    
    RefHolder* ref = [RefHolder new];
    ref.ref = [NSArray arrayWithObjects:@"test1", @"test2", nil];
    
    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       NSLog(@"Object = %@", [ref.ref objectAtIndex:1]);
                   });
    
}

- (void)accessDeallocatedPtrProxy{
    RefHolder* ref = [RefHolder new];
    ref.ref = [MyProxy alloc];
    
    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       NSLog(@"Object = %@", ref.ref);
                   });
}

- (void)zombieNSException
{
    @try
    {
        NSString* value = @"This is a string";
        [NSException raise:@"TurboEncabulatorException"
                    format:@"Spurving bearing failure: Barescent skor motion non-sinusoidal for %p", value];
    }
    @catch (NSException *exception)
    {
        RefHolder* ref = [RefHolder new];
        ref.ref = exception;
        dispatch_async(dispatch_get_main_queue(), ^
                       {
                           NSLog(@"Exception = %@", ref.ref);
                       });
    }
}

- (void)corruptMemory
{
    size_t stringsize = sizeof(uintptr_t) * 2 + 2;
    NSString* string = [NSString stringWithFormat:@"%d", 1];
    NSLog(@"%@", string);
    void* cast = (__bridge void*)string;
    uintptr_t address = (uintptr_t)cast;
    void* ptr = (char*)address + stringsize;
    memset(ptr, 0xa1, 500);
}
// ANR
- (void)anr{
    [self.lock lock];
    [NSThread sleepForTimeInterval:0.2f];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [NSThread sleepForTimeInterval:6];
        [self.lock unlock];
    });
    dispatch_async(dispatch_get_main_queue(), ^
                   {
        [self.lock lock];
    });
    dispatch_async(dispatch_get_main_queue(), ^
                   {
        [self.lock unlock];
    });
}
- (void)deadlock
{
    [self.lock lock];
    [NSThread sleepForTimeInterval:0.2f];
    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       [self.lock lock];
                   });
}

- (void)pthreadAPICrash
{
    // http://landonf.bikemonkey.org/code/crashreporting
    pthread_getname_np(pthread_self(), (char*)0x1, 1);
}


- (void)throwUncaughtCPPException
{
    MyCPPClass instance;
    instance.throwAnException();
}

@end
