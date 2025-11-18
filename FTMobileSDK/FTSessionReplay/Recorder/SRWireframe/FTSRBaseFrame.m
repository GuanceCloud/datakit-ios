//
//  FTSRBaseFrame.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/7.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTSRBaseFrame.h"
#import <objc/runtime.h>
#import "FTLog+Private.h"
#import <math.h>
static const char * kClassPropertiesKey;
static const char * kMapperObjectKey;
BOOL isNull(id value)
{
    if (!value) return YES;
    if ([value isKindOfClass:[NSNull class]]) return YES;

    return NO;
}
BOOL isNAN(id value) {
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *num = (NSNumber *)value;
        return num.doubleValue != num.doubleValue;
    }
    
    if ([value isKindOfClass:[NSValue class]]) {
        const char *type = [value objCType];
        if (strcmp(type, @encode(double)) == 0) {
            return isnan([value doubleValue]);
        } else if (strcmp(type, @encode(float)) == 0) {
            return isnan([value floatValue]);
        }
    }
    return NO;
}
@implementation FTSRBaseFrame
-(NSDictionary *)toDictionary{
    NSArray* properties = [self __properties__];
    NSMutableDictionary* tempDictionary = [NSMutableDictionary dictionaryWithCapacity:properties.count];
    id value;

    for (FTSRBaseFrameProperty* p in properties) {
        NSString* keyPath = (self.__keyMapper) ? [self __mapString:p.name withKeyMapper:self.__keyMapper] : p.name;
        value = [self valueForKey: p.name];
        
        if ([keyPath rangeOfString:@"."].location != NSNotFound) {
            [self __createDictionariesForKeyPath:keyPath inDictionary:&tempDictionary];
        }
        if (isNull(value)){
            if (value == nil)
            {
                [tempDictionary removeObjectForKey:p.name];
            }
            else
            {
                [tempDictionary setValue:[NSNull null] forKeyPath:p.name];
            }
            continue;
        }
        if (isNAN(value)) {
            continue;
        }
        if ([value isKindOfClass:FTSRBaseFrame.class]) {
            value = [(FTSRBaseFrame*)value toDictionary];
            [tempDictionary setValue:value forKeyPath: keyPath];
            continue;
        }else{
            if (p.protocol) {
                value = [self __reverseTransform:value forProperty:p];
            }
            [tempDictionary setValue:value forKeyPath: keyPath];
        }
    }
    return [tempDictionary copy];
}
-(NSData *)toJSONData{
    NSData* jsonData = nil;
    NSError* jsonError = nil;
    @try {
        NSDictionary* dict = [self toDictionary];
        jsonData = [NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:&jsonError];
    }
    @catch (NSException *exception) {
        FTInnerLogError(@"EXCEPTION: %@", exception.description);
        return nil;
    }

    return jsonData;
}
-(NSString *)toJSONString{
    return [[NSString alloc] initWithData: [self toJSONData]
                                 encoding: NSUTF8StringEncoding];
}
- (NSArray *)__properties__{
    NSDictionary* classProperties = objc_getAssociatedObject(self.class, &kClassPropertiesKey);
    if (classProperties) return [classProperties allValues];
    [self __setup__];
    classProperties = objc_getAssociatedObject(self.class, &kClassPropertiesKey);
    return [classProperties allValues];
}
- (void)__setup__{
    NSMutableDictionary* propertyIndex = [NSMutableDictionary dictionary];
    Class class = [self class];
    NSScanner* scanner = nil;
    NSString* propertyType = nil;
    while (class != [FTSRBaseFrame class]) {
        unsigned int  count = 0;
        objc_property_t *properties = class_copyPropertyList(class, &count);
        for (unsigned int i = 0; i < count; i++) {
            FTSRBaseFrameProperty *p = [[FTSRBaseFrameProperty alloc]init];
            objc_property_t property = properties[i];
            const char *propertyName = property_getName(property);
            p.name = @(propertyName);
            
            const char *attrs = property_getAttributes(property);
            NSString* propertyAttributes = @(attrs);
            NSArray* attributeItems = [propertyAttributes componentsSeparatedByString:@","];
            
            if ([attributeItems containsObject:@"R"]) {
                continue; //to next property
            }
            scanner = [NSScanner scannerWithString: propertyAttributes];

            [scanner scanUpToString:@"T" intoString: nil];
            [scanner scanString:@"T" intoString:nil];
            if ([scanner scanString:@"@\"" intoString: &propertyType]) {
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"]
                                        intoString:&propertyType];
                p.type = NSClassFromString(propertyType);
                //read through the property protocols
                while ([scanner scanString:@"<" intoString:NULL]) {

                    NSString* protocolName = nil;
                    [scanner scanUpToString:@">" intoString: &protocolName];
                    if ([protocolName isEqualToString:@"Optional"]) {
                    } else if([protocolName isEqualToString:@"Index"]) {
                    } else if([protocolName isEqualToString:@"Ignore"]) {
                        p = nil;
                    } else {
                        p.protocol = protocolName;
                    }
                    [scanner scanString:@">" intoString:NULL];
                }

            }
            if (p && ![propertyIndex objectForKey:p.name]) {
                [propertyIndex setValue:p forKey:p.name];
            }
        }
        free(properties);
        class = [class superclass];
    }
    objc_setAssociatedObject(
                             self.class,
                             &kClassPropertiesKey,
                             [propertyIndex copy],
                             OBJC_ASSOCIATION_RETAIN // This is atomic
                             );
    id mapper = [[self class] keyMapper];
    if ( mapper && !objc_getAssociatedObject(self.class, &kMapperObjectKey) ) {
        objc_setAssociatedObject(
                                 self.class,
                                 &kMapperObjectKey,
                                 mapper,
                                 OBJC_ASSOCIATION_RETAIN // This is atomic
                                 );
    }
}
-(FTJSONKeyMapper*)__keyMapper
{
    //get the model key mapper
    return objc_getAssociatedObject(self.class, &kMapperObjectKey);
}
-(NSString*)__mapString:(NSString*)string withKeyMapper:(FTJSONKeyMapper*)keyMapper
{
    if (keyMapper) {
        string = [keyMapper convertValue:string];
    }
    return string;
}
-(void)__createDictionariesForKeyPath:(NSString*)keyPath inDictionary:(NSMutableDictionary**)dict
{
    //find if there's a dot left in the keyPath
    NSUInteger dotLocation = [keyPath rangeOfString:@"."].location;
    if (dotLocation==NSNotFound) return;

    //inspect next level
    NSString* nextHierarchyLevelKeyName = [keyPath substringToIndex: dotLocation];
    NSDictionary* nextLevelDictionary = (*dict)[nextHierarchyLevelKeyName];

    if (nextLevelDictionary==nil) {
        //create non-existing next level here
        nextLevelDictionary = [NSMutableDictionary dictionary];
    }

    //recurse levels
    [self __createDictionariesForKeyPath:[keyPath substringFromIndex: dotLocation+1]
                            inDictionary:&nextLevelDictionary ];

    //create the hierarchy level
    [*dict setValue:nextLevelDictionary  forKeyPath: nextHierarchyLevelKeyName];
}
-(id)__reverseTransform:(id)value forProperty:(FTSRBaseFrameProperty*)property
{
    Class protocolClass = NSClassFromString(property.protocol);
    if (!protocolClass) return value;

    if ([self __isJSONModelSubClass:protocolClass]) {

        if (property.type == [NSArray class] || property.type == [NSMutableArray class]) {
            NSMutableArray* tempArray = [NSMutableArray arrayWithCapacity: [(NSArray*)value count] ];
            for (NSObject<FTAbstractJSONModelProtocol>* model in (NSArray*)value) {
                if ([model respondsToSelector:@selector(toDictionary)]) {
                    [tempArray addObject: [model toDictionary]];
                } else
                    [tempArray addObject: model];
            }
            return [tempArray copy];
        }

        //check if should export dictionary of dictionaries
        if (property.type == [NSDictionary class] || property.type == [NSMutableDictionary class]) {
            NSMutableDictionary* res = [NSMutableDictionary dictionary];
            for (NSString* key in [(NSDictionary*)value allKeys]) {
                id<FTAbstractJSONModelProtocol> model = value[key];
                [res setValue: [model toDictionary] forKey: key];
            }
            return [NSDictionary dictionaryWithDictionary:res];
        }
    }

    return value;
}
-(BOOL)__isJSONModelSubClass:(Class)class{
    return [class isSubclassOfClass:FTSRBaseFrame.class];
}
#pragma mark ========== NSCoding\NSSecureCoding ==========
- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    //Get all properties
    NSArray * propertyArray = [self getAllProperties];
    for (NSString * name in propertyArray) {
        //Remove underscore prefix from property name
        NSString * key = [name substringFromIndex:1];

        [coder encodeObject:[self valueForKey:key] forKey:[NSString stringWithFormat:@"%@",key]];
    }
}
- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    self = [super init];
    if(self){
        NSArray *propertyArray = [self getAllProperties];
        for (NSString *name in propertyArray) {
            //Remove underscore prefix from property name
            NSString * key = [name substringFromIndex:1];
            [self setValue:[coder decodeObjectForKey:[NSString stringWithFormat:@"%@",key]] forKey:key];
        }
    }
    return self;
}
-(NSArray *)getAllProperties{
    NSMutableArray * array = [[NSMutableArray alloc]init];
    Class this_class = object_getClass(self);

    NSArray *objectArray = [self getProperties:this_class];
    if(objectArray){
        [array addObjectsFromArray:objectArray];
    }
    while (class_getSuperclass(this_class) != NSObject.class) {
        this_class = class_getSuperclass(this_class);
        NSArray *nArray = [self getProperties:this_class];
        if(nArray){
            [array addObjectsFromArray:nArray];
        }
    }
    return array;
}
- (NSArray *)getProperties:(Class)class{
    NSMutableArray * array = [[NSMutableArray alloc]init];
    
    unsigned int  count = 0;
    //Call runtime method
    //Ivar: The object content object returned by the method, here will return an Ivar type pointer
    //class_copyIvarList method can capture all variables of the class, store the variable count in an unsigned int pointer
    Ivar * ivars = class_copyIvarList(class, &count);
    //Traverse
    for (int i=0; i< count ; i++) {
        //Traverse by moving pointer
        Ivar var = ivars[i];
        //Get variable name
        const char * name = ivar_getName(var);
        NSString * str = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
        [array addObject:str];
    }
    //Free memory
    free(ivars);
    return array;
}
+ (FTJSONKeyMapper *)keyMapper{
    return nil;
}
+(BOOL)supportsSecureCoding{
    return YES;
}
- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[self class]]) return NO;
    return [self isEqualToBaseFrame:(FTSRBaseFrame *)object];
}
// Subclasses must override.
- (BOOL)isEqualToBaseFrame:(FTSRBaseFrame *)baseFrame {
    return NO;
}
@end

@implementation FTSRBaseFrameProperty


@end

