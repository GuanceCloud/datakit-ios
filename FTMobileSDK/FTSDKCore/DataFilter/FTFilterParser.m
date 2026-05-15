//
//  FTFilterParser.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/5/14.
//

#import "FTFilterParser.h"
#import "FTInnerLog.h"

typedef NS_ENUM(NSUInteger, FTFilterOperator) {
    FTFilterOperatorEqual,
    FTFilterOperatorNotEqual,
    FTFilterOperatorRegex,
    FTFilterOperatorNotRegex,
    FTFilterOperatorGreaterThan,
    FTFilterOperatorGreaterThanOrEqual,
    FTFilterOperatorLessThan,
    FTFilterOperatorLessThanOrEqual,
    FTFilterOperatorIn,
    FTFilterOperatorNotIn,
};

@interface FTFilterCondition : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) FTFilterOperator op;
@property (nonatomic, strong) id value;
@property (nonatomic, strong) NSRegularExpression *regex;
- (BOOL)evaluate:(NSDictionary<NSString *, id> *)values;
@end

@implementation FTFilterCondition

- (BOOL)evaluate:(NSDictionary<NSString *, id> *)values {
    id actual = values[self.key];
    if (!actual || actual == NSNull.null) {
        return NO;
    }
    switch (self.op) {
        case FTFilterOperatorEqual:
            return [[self stringValue:actual] isEqualToString:[self stringValue:self.value]];
        case FTFilterOperatorNotEqual:
            return ![[self stringValue:actual] isEqualToString:[self stringValue:self.value]];
        case FTFilterOperatorRegex:
            return [self regexMatches:[self stringValue:actual]];
        case FTFilterOperatorNotRegex:
            return ![self regexMatches:[self stringValue:actual]];
        case FTFilterOperatorGreaterThan:
            return [self numberValue:actual] > [self numberValue:self.value];
        case FTFilterOperatorGreaterThanOrEqual:
            return [self numberValue:actual] >= [self numberValue:self.value];
        case FTFilterOperatorLessThan:
            return [self numberValue:actual] < [self numberValue:self.value];
        case FTFilterOperatorLessThanOrEqual:
            return [self numberValue:actual] <= [self numberValue:self.value];
        case FTFilterOperatorIn:
            return [self value:actual isIn:self.value];
        case FTFilterOperatorNotIn:
            return ![self value:actual isIn:self.value];
    }
}

- (NSString *)stringValue:(id)value {
    if ([value isKindOfClass:NSString.class]) {
        return value;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [value stringValue];
    }
    return [value description];
}

- (double)numberValue:(id)value {
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return [value doubleValue];
    }
    return 0;
}

- (BOOL)value:(id)actual isIn:(id)expected {
    NSArray *array = [expected isKindOfClass:NSArray.class] ? expected : @[expected ?: @""];
    NSString *actualString = [self stringValue:actual];
    for (id item in array) {
        if ([actualString isEqualToString:[self stringValue:item]]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)regexMatches:(NSString *)value {
    if (!self.regex || value.length == 0) {
        return NO;
    }
    NSRange range = NSMakeRange(0, value.length);
    return [self.regex firstMatchInString:value options:0 range:range] != nil;
}

@end

@implementation FTFilterParser

+ (nullable FTDataFilterRuleBlock)predicateWithRule:(NSString *)rule {
    NSArray<NSArray<FTFilterCondition *> *> *groups = [self parseRule:rule];
    if (groups.count == 0) {
        return nil;
    }
    return ^BOOL(NSDictionary<NSString *,id> *values) {
        for (NSArray<FTFilterCondition *> *andGroup in groups) {
            BOOL groupMatched = YES;
            for (FTFilterCondition *condition in andGroup) {
                if (![condition evaluate:values]) {
                    groupMatched = NO;
                    break;
                }
            }
            if (groupMatched) {
                return YES;
            }
        }
        return NO;
    };
}

+ (NSArray<NSArray<FTFilterCondition *> *> *)parseRule:(NSString *)rule {
    if (![rule isKindOfClass:NSString.class] || rule.length == 0) {
        return @[];
    }
    NSString *body = [self trimmed:rule];
    if ([body hasPrefix:@"{"] && [body hasSuffix:@"}"] && body.length >= 2) {
        body = [body substringWithRange:NSMakeRange(1, body.length - 2)];
    }
    NSMutableArray *groups = [NSMutableArray array];
    for (NSString *orPart in [self splitString:body byLogicalOperator:@"or"]) {
        NSMutableArray *conditions = [NSMutableArray array];
        BOOL groupValid = YES;
        for (NSString *andPart in [self splitString:orPart byLogicalOperator:@"and"]) {
            FTFilterCondition *condition = [self parseCondition:andPart];
            if (!condition) {
                groupValid = NO;
                break;
            }
            [conditions addObject:condition];
        }
        if (groupValid && conditions.count > 0) {
            [groups addObject:[conditions copy]];
        }
    }
    return [groups copy];
}

+ (nullable FTFilterCondition *)parseCondition:(NSString *)raw {
    NSString *condition = [self stripEnclosingParentheses:[self trimmed:raw]];
    if (condition.length == 0) {
        return nil;
    }
    NSArray<NSString *> *operators = @[@" notmatch ", @" not match ", @" match ", @" notin ", @" not in ", @" in ", @">=", @"<=", @"!=", @"==", @"!~", @"=~", @"=", @">", @"<"];
    NSString *matchedOperator = nil;
    NSRange matchedRange = NSMakeRange(NSNotFound, 0);
    for (NSString *op in operators) {
        matchedRange = [self rangeOfOperator:op inString:condition];
        if (matchedRange.location != NSNotFound) {
            matchedOperator = op;
            break;
        }
    }
    if (!matchedOperator) {
        return nil;
    }
    NSString *key = [self trimmed:[condition substringToIndex:matchedRange.location]];
    NSString *value = [self trimmed:[condition substringFromIndex:NSMaxRange(matchedRange)]];
    if (key.length == 0 || value.length == 0) {
        return nil;
    }
    FTFilterCondition *result = [FTFilterCondition new];
    result.key = [self normalizedKey:key];
    result.op = [self filterOperatorWithString:matchedOperator];
    result.value = [self parsedValue:value];
    if (![self compileRegexIfNeededForCondition:result rawValue:value rawCondition:raw]) {
        return nil;
    }
    return result;
}

+ (NSString *)stripEnclosingParentheses:(NSString *)raw {
    NSString *result = [self trimmed:raw];
    while ([result hasPrefix:@"("] && [result hasSuffix:@")"] && [self hasMatchingEnclosingParentheses:result]) {
        result = [self trimmed:[result substringWithRange:NSMakeRange(1, result.length - 2)]];
    }
    return result;
}

+ (BOOL)hasMatchingEnclosingParentheses:(NSString *)string {
    NSInteger depth = 0;
    BOOL inQuote = NO;
    unichar quote = 0;
    for (NSUInteger index = 0; index < string.length; index++) {
        unichar ch = [string characterAtIndex:index];
        if ((ch == '\'' || ch == '"') && (index == 0 || [string characterAtIndex:index - 1] != '\\')) {
            if (!inQuote) {
                inQuote = YES;
                quote = ch;
            } else if (quote == ch) {
                inQuote = NO;
            }
            continue;
        }
        if (inQuote) {
            continue;
        }
        if (ch == '(') {
            depth++;
        } else if (ch == ')') {
            depth--;
            if (depth == 0 && index < string.length - 1) {
                return NO;
            }
            if (depth < 0) {
                return NO;
            }
        }
    }
    return depth == 0;
}

+ (BOOL)compileRegexIfNeededForCondition:(FTFilterCondition *)condition
                                rawValue:(NSString *)rawValue
                            rawCondition:(NSString *)rawCondition {
    if (condition.op != FTFilterOperatorRegex && condition.op != FTFilterOperatorNotRegex) {
        return YES;
    }
    NSString *pattern = [condition.value isKindOfClass:NSString.class] ? condition.value : [condition.value description];
    if (pattern.length == 0) {
        FTInnerLogWarning(@"[data-filter] Invalid regex filter condition: %@", rawCondition);
        return NO;
    }
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    if (error || !regex) {
        FTInnerLogWarning(@"[data-filter] Invalid regex filter condition: %@, error: %@", rawCondition, error.localizedDescription);
        return NO;
    }
    condition.regex = regex;
    return YES;
}

+ (NSRange)rangeOfOperator:(NSString *)op inString:(NSString *)string {
    BOOL inQuote = NO;
    unichar quote = 0;
    NSString *lowerString = string.lowercaseString;
    NSString *lowerOp = op.lowercaseString;
    for (NSUInteger index = 0; index + lowerOp.length <= string.length; index++) {
        unichar ch = [string characterAtIndex:index];
        if ((ch == '\'' || ch == '"') && (index == 0 || [string characterAtIndex:index - 1] != '\\')) {
            if (!inQuote) {
                inQuote = YES;
                quote = ch;
            } else if (quote == ch) {
                inQuote = NO;
            }
        }
        if (!inQuote && [[lowerString substringWithRange:NSMakeRange(index, lowerOp.length)] isEqualToString:lowerOp]) {
            return NSMakeRange(index, lowerOp.length);
        }
    }
    return NSMakeRange(NSNotFound, 0);
}

+ (NSArray<NSString *> *)splitString:(NSString *)string byLogicalOperator:(NSString *)op {
    NSMutableArray *parts = [NSMutableArray array];
    BOOL inQuote = NO;
    unichar quote = 0;
    NSUInteger start = 0;
    NSString *lower = string.lowercaseString;
    NSString *needle = [NSString stringWithFormat:@" %@ ", op.lowercaseString];
    for (NSUInteger index = 0; index < string.length; index++) {
        unichar ch = [string characterAtIndex:index];
        if ((ch == '\'' || ch == '"') && (index == 0 || [string characterAtIndex:index - 1] != '\\')) {
            if (!inQuote) {
                inQuote = YES;
                quote = ch;
            } else if (quote == ch) {
                inQuote = NO;
            }
        }
        if (!inQuote && index + needle.length <= string.length &&
            [[lower substringWithRange:NSMakeRange(index, needle.length)] isEqualToString:needle]) {
            [parts addObject:[string substringWithRange:NSMakeRange(start, index - start)]];
            index += needle.length - 1;
            start = index + 1;
        }
    }
    [parts addObject:[string substringFromIndex:start]];
    return [parts copy];
}

+ (FTFilterOperator)filterOperatorWithString:(NSString *)op {
    NSString *value = [op stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
    if ([value isEqualToString:@"!="]) return FTFilterOperatorNotEqual;
    if ([value isEqualToString:@"=~"]) return FTFilterOperatorRegex;
    if ([value isEqualToString:@"!~"]) return FTFilterOperatorNotRegex;
    if ([value isEqualToString:@">"]) return FTFilterOperatorGreaterThan;
    if ([value isEqualToString:@">="]) return FTFilterOperatorGreaterThanOrEqual;
    if ([value isEqualToString:@"<"]) return FTFilterOperatorLessThan;
    if ([value isEqualToString:@"<="]) return FTFilterOperatorLessThanOrEqual;
    if ([value isEqualToString:@"notmatch"]) return FTFilterOperatorNotIn;
    if ([value isEqualToString:@"match"]) return FTFilterOperatorIn;
    if ([value isEqualToString:@"not match"]) return FTFilterOperatorNotIn;
    if ([value isEqualToString:@"notin"]) return FTFilterOperatorNotIn;
    if ([value isEqualToString:@"in"]) return FTFilterOperatorIn;
    if ([value isEqualToString:@"not in"]) return FTFilterOperatorNotIn;
    return FTFilterOperatorEqual;
}

+ (id)parsedValue:(NSString *)raw {
    NSString *value = [self trimmed:raw];
    if (([value hasPrefix:@"'"] && [value hasSuffix:@"'"]) ||
        ([value hasPrefix:@"\""] && [value hasSuffix:@"\""])) {
        return [value substringWithRange:NSMakeRange(1, value.length - 2)];
    }
    if (([value hasPrefix:@"("] && [value hasSuffix:@")"]) ||
        ([value hasPrefix:@"["] && [value hasSuffix:@"]"])) {
        NSString *items = [value substringWithRange:NSMakeRange(1, value.length - 2)];
        NSMutableArray *array = [NSMutableArray array];
        for (NSString *item in [self splitCommaSeparatedString:items]) {
            [array addObject:[self parsedValue:item]];
        }
        return [array copy];
    }
    NSNumberFormatter *formatter = [NSNumberFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    NSNumber *number = [formatter numberFromString:value];
    return number ?: value;
}

+ (NSArray<NSString *> *)splitCommaSeparatedString:(NSString *)string {
    NSMutableArray *parts = [NSMutableArray array];
    BOOL inQuote = NO;
    unichar quote = 0;
    NSUInteger start = 0;
    for (NSUInteger index = 0; index < string.length; index++) {
        unichar ch = [string characterAtIndex:index];
        if ((ch == '\'' || ch == '"') && (index == 0 || [string characterAtIndex:index - 1] != '\\')) {
            if (!inQuote) {
                inQuote = YES;
                quote = ch;
            } else if (quote == ch) {
                inQuote = NO;
            }
        } else if (!inQuote && ch == ',') {
            [parts addObject:[string substringWithRange:NSMakeRange(start, index - start)]];
            start = index + 1;
        }
    }
    [parts addObject:[string substringFromIndex:start]];
    return [parts copy];
}

+ (NSString *)normalizedKey:(NSString *)key {
    NSString *trimmed = [self trimmed:key];
    if (([trimmed hasPrefix:@"`"] && [trimmed hasSuffix:@"`"]) ||
        ([trimmed hasPrefix:@"'"] && [trimmed hasSuffix:@"'"]) ||
        ([trimmed hasPrefix:@"\""] && [trimmed hasSuffix:@"\""])) {
        return [trimmed substringWithRange:NSMakeRange(1, trimmed.length - 2)];
    }
    return trimmed;
}

+ (NSString *)trimmed:(NSString *)string {
    return [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

@end
