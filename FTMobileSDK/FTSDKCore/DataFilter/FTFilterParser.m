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

@interface FTFilterRegexLiteral : NSObject
@property (nonatomic, copy) NSString *pattern;
@end

@implementation FTFilterRegexLiteral
@end

@interface FTFilterCondition : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) FTFilterOperator op;
@property (nonatomic, strong) id value;
@property (nonatomic, copy) NSArray<NSRegularExpression *> *regexes;
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
    if (self.regexes.count == 0 || value.length == 0) {
        return NO;
    }
    NSRange range = NSMakeRange(0, value.length);
    for (NSRegularExpression *regex in self.regexes) {
        if ([regex firstMatchInString:value options:0 range:range] != nil) {
            return YES;
        }
    }
    return NO;
}

@end

@implementation FTFilterParser

+ (nullable FTDataFilterRuleBlock)predicateWithRule:(NSString *)rule {
    NSString *body = [self ruleBody:rule];
    if (body.length == 0) {
        return nil;
    }
    return [self predicateWithExpression:body];
}

+ (NSString *)ruleBody:(NSString *)rule {
    if (![rule isKindOfClass:NSString.class] || rule.length == 0) {
        return @"";
    }
    NSString *body = [self trimmed:rule];
    if ([body hasPrefix:@"{"] && [body hasSuffix:@"}"] && body.length >= 2) {
        body = [body substringWithRange:NSMakeRange(1, body.length - 2)];
    }
    return [self trimmed:body];
}

+ (nullable FTDataFilterRuleBlock)predicateWithExpression:(NSString *)expression {
    NSString *body = [self stripEnclosingParentheses:[self trimmed:expression]];
    if (body.length == 0) {
        return nil;
    }
    
    NSArray<NSString *> *orParts = [self splitString:body byLogicalOperator:@"or"];
    if (orParts.count > 1) {
        NSMutableArray *predicates = [NSMutableArray arrayWithCapacity:orParts.count];
        for (NSString *part in orParts) {
            FTDataFilterRuleBlock predicate = [self predicateWithExpression:part];
            if (!predicate) {
                return nil;
            }
            [predicates addObject:[predicate copy]];
        }
        return ^BOOL(NSDictionary<NSString *, id> *values) {
            for (FTDataFilterRuleBlock predicate in predicates) {
                if (predicate(values)) {
                    return YES;
                }
            }
            return NO;
        };
    }
    
    NSArray<NSString *> *andParts = [self splitString:body byLogicalOperator:@"and"];
    if (andParts.count > 1) {
        NSMutableArray *predicates = [NSMutableArray arrayWithCapacity:andParts.count];
        for (NSString *part in andParts) {
            FTDataFilterRuleBlock predicate = [self predicateWithExpression:part];
            if (!predicate) {
                return nil;
            }
            [predicates addObject:[predicate copy]];
        }
        return ^BOOL(NSDictionary<NSString *, id> *values) {
            for (FTDataFilterRuleBlock predicate in predicates) {
                if (!predicate(values)) {
                    return NO;
                }
            }
            return YES;
        };
    }
    
    FTFilterCondition *condition = [self parseCondition:body];
    if (!condition) {
        return nil;
    }
    return ^BOOL(NSDictionary<NSString *, id> *values) {
        return [condition evaluate:values];
    };
}

+ (nullable FTFilterCondition *)parseCondition:(NSString *)raw {
    NSString *condition = [self stripEnclosingParentheses:[self trimmed:raw]];
    if (condition.length == 0) {
        return nil;
    }
    NSArray<NSString *> *operators = @[@" notmatch ", @" not match ", @" match ", @" not_in ", @" notin ", @" not in ", @" in ", @">=", @"<=", @"!=", @"==", @"!~", @"=~", @"=", @">", @"<"];
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
    if ([result.value isKindOfClass:FTFilterRegexLiteral.class]) {
        FTFilterRegexLiteral *regexLiteral = result.value;
        result.value = regexLiteral.pattern;
        if (result.op == FTFilterOperatorEqual) {
            result.op = FTFilterOperatorRegex;
        } else if (result.op == FTFilterOperatorNotEqual) {
            result.op = FTFilterOperatorNotRegex;
        }
    }
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
        if ((ch == '\'' || ch == '"' || ch == '`') && (index == 0 || [string characterAtIndex:index - 1] != '\\')) {
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
    NSArray *patterns = [condition.value isKindOfClass:NSArray.class] ? condition.value : @[condition.value ?: @""];
    if (patterns.count == 0) {
        FTInnerLogWarning(@"[data-filter] Invalid regex filter condition: %@", rawCondition);
        return NO;
    }
    NSMutableArray<NSRegularExpression *> *regexes = [NSMutableArray arrayWithCapacity:patterns.count];
    for (id patternValue in patterns) {
        NSString *pattern = [patternValue isKindOfClass:NSString.class] ? patternValue : [patternValue description];
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
        [regexes addObject:regex];
    }
    condition.regexes = [regexes copy];
    return YES;
}

+ (NSRange)rangeOfOperator:(NSString *)op inString:(NSString *)string {
    BOOL inQuote = NO;
    unichar quote = 0;
    NSInteger parenDepth = 0;
    NSInteger bracketDepth = 0;
    NSString *lowerString = string.lowercaseString;
    NSString *lowerOp = op.lowercaseString;
    for (NSUInteger index = 0; index + lowerOp.length <= string.length; index++) {
        unichar ch = [string characterAtIndex:index];
        if ((ch == '\'' || ch == '"' || ch == '`') && (index == 0 || [string characterAtIndex:index - 1] != '\\')) {
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
            parenDepth++;
        } else if (ch == ')') {
            parenDepth = MAX(0, parenDepth - 1);
        } else if (ch == '[') {
            bracketDepth++;
        } else if (ch == ']') {
            bracketDepth = MAX(0, bracketDepth - 1);
        }
        if (parenDepth == 0 && bracketDepth == 0 &&
            [[lowerString substringWithRange:NSMakeRange(index, lowerOp.length)] isEqualToString:lowerOp]) {
            return NSMakeRange(index, lowerOp.length);
        }
    }
    return NSMakeRange(NSNotFound, 0);
}

+ (NSArray<NSString *> *)splitString:(NSString *)string byLogicalOperator:(NSString *)op {
    NSMutableArray *parts = [NSMutableArray array];
    BOOL inQuote = NO;
    unichar quote = 0;
    NSInteger parenDepth = 0;
    NSInteger bracketDepth = 0;
    NSUInteger start = 0;
    NSString *lower = string.lowercaseString;
    for (NSUInteger index = 0; index < string.length; index++) {
        unichar ch = [string characterAtIndex:index];
        if ((ch == '\'' || ch == '"' || ch == '`') && (index == 0 || [string characterAtIndex:index - 1] != '\\')) {
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
            parenDepth++;
            continue;
        }
        if (ch == ')') {
            parenDepth = MAX(0, parenDepth - 1);
            continue;
        }
        if (ch == '[') {
            bracketDepth++;
            continue;
        }
        if (ch == ']') {
            bracketDepth = MAX(0, bracketDepth - 1);
            continue;
        }
        if (parenDepth == 0 && bracketDepth == 0) {
            NSUInteger delimiterLength = [self logicalDelimiterLengthInString:lower
                                                                        index:index
                                                                     operator:op
                                                                    character:ch];
            if (delimiterLength > 0) {
                [parts addObject:[string substringWithRange:NSMakeRange(start, index - start)]];
                index += delimiterLength - 1;
                start = index + 1;
            }
        }
    }
    [parts addObject:[string substringFromIndex:start]];
    return [parts copy];
}

+ (NSUInteger)logicalDelimiterLengthInString:(NSString *)lower
                                       index:(NSUInteger)index
                                    operator:(NSString *)op
                                   character:(unichar)ch {
    BOOL isAnd = [op.lowercaseString isEqualToString:@"and"];
    if (isAnd && ch == ',') {
        return 1;
    }
    NSString *symbol = isAnd ? @"&&" : @"||";
    if (index + symbol.length <= lower.length &&
        [[lower substringWithRange:NSMakeRange(index, symbol.length)] isEqualToString:symbol]) {
        return symbol.length;
    }
    NSString *word = op.lowercaseString;
    if (index + word.length <= lower.length &&
        [[lower substringWithRange:NSMakeRange(index, word.length)] isEqualToString:word] &&
        [self isLogicalWordBoundaryInString:lower index:index length:word.length]) {
        return word.length;
    }
    return 0;
}

+ (BOOL)isLogicalWordBoundaryInString:(NSString *)string index:(NSUInteger)index length:(NSUInteger)length {
    BOOL leftBoundary = index == 0 || ![self isIdentifierCharacter:[string characterAtIndex:index - 1]];
    NSUInteger end = index + length;
    BOOL rightBoundary = end >= string.length || ![self isIdentifierCharacter:[string characterAtIndex:end]];
    return leftBoundary && rightBoundary;
}

+ (BOOL)isIdentifierCharacter:(unichar)ch {
    return [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"] characterIsMember:ch];
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
    if ([value isEqualToString:@"notmatch"]) return FTFilterOperatorNotRegex;
    if ([value isEqualToString:@"match"]) return FTFilterOperatorRegex;
    if ([value isEqualToString:@"not match"]) return FTFilterOperatorNotRegex;
    if ([value isEqualToString:@"not_in"]) return FTFilterOperatorNotIn;
    if ([value isEqualToString:@"notin"]) return FTFilterOperatorNotIn;
    if ([value isEqualToString:@"in"]) return FTFilterOperatorIn;
    if ([value isEqualToString:@"not in"]) return FTFilterOperatorNotIn;
    return FTFilterOperatorEqual;
}

+ (id)parsedValue:(NSString *)raw {
    NSString *value = [self trimmed:raw];
    NSString *lowerValue = value.lowercaseString;
    if ([lowerValue hasPrefix:@"re("] && [value hasSuffix:@")"] && value.length > 3) {
        NSString *inner = [value substringWithRange:NSMakeRange(3, value.length - 4)];
        id patternValue = [self parsedValue:inner];
        FTFilterRegexLiteral *literal = [FTFilterRegexLiteral new];
        literal.pattern = [patternValue isKindOfClass:NSString.class] ? patternValue : [patternValue description];
        return literal;
    }
    if (([value hasPrefix:@"'"] && [value hasSuffix:@"'"]) ||
        ([value hasPrefix:@"\""] && [value hasSuffix:@"\""]) ||
        ([value hasPrefix:@"`"] && [value hasSuffix:@"`"])) {
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
        if ((ch == '\'' || ch == '"' || ch == '`') && (index == 0 || [string characterAtIndex:index - 1] != '\\')) {
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
