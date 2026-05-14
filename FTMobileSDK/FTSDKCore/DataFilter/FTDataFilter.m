//
//  FTDataFilter.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/5/14.
//

#import "FTDataFilter.h"
#import "FTFilterParser.h"
#import "FTInnerLog.h"

@interface FTDataFilter()
@property (nonatomic, copy) NSDictionary<NSString *, NSArray<FTDataFilterRuleBlock> *> *compiledFilters;
@end

@implementation FTDataFilter

- (instancetype)initWithFilters:(NSDictionary<NSString *, NSArray<NSString *> *> *)filters {
    self = [super init];
    if (self) {
        _compiledFilters = [self compileFilters:filters];
    }
    return self;
}

- (NSDictionary<NSString *, NSArray<FTDataFilterRuleBlock> *> *)compileFilters:(NSDictionary<NSString *, NSArray<NSString *> *> *)filters {
    NSMutableDictionary *compiled = [NSMutableDictionary dictionary];
    [filters enumerateKeysAndObjectsUsingBlock:^(NSString *category, NSArray<NSString *> *rules, BOOL *stop) {
        if (![category isKindOfClass:NSString.class] || ![rules isKindOfClass:NSArray.class]) {
            return;
        }
        NSMutableArray *predicates = [NSMutableArray array];
        for (NSString *rule in rules) {
            FTDataFilterRuleBlock predicate = [FTFilterParser predicateWithRule:rule];
            if (predicate) {
                [predicates addObject:[predicate copy]];
            } else {
                FTInnerLogWarning(@"[data-filter] Invalid filter rule: %@", rule);
            }
        }
        if (predicates.count > 0) {
            compiled[category] = [predicates copy];
        }
    }];
    return [compiled copy];
}

- (BOOL)isMatchedWithCategory:(NSString *)category
                       source:(NSString *)source
                         tags:(NSDictionary *)tags
                       fields:(NSDictionary *)fields {
    if (category.length == 0 || source.length == 0) {
        return NO;
    }
    NSArray<FTDataFilterRuleBlock> *rules = self.compiledFilters[category];
    if (rules.count == 0) {
        return NO;
    }
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    if ([tags isKindOfClass:NSDictionary.class]) {
        [values addEntriesFromDictionary:tags];
    }
    if ([fields isKindOfClass:NSDictionary.class]) {
        [values addEntriesFromDictionary:fields];
    }
    values[@"source"] = source;
    values[@"measurement"] = source;
    for (FTDataFilterRuleBlock rule in rules) {
        if (rule(values)) {
            return YES;
        }
    }
    return NO;
}

@end
