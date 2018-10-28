//
//  MGSAttributeOverlayTextStorage.m
//  Fragaria
//
//  Created by Daniele Cattaneo on 28/10/2018.
//

#import "MGSAttributeOverlayTextStorage.h"


static NSString * const MGSAttributeOverlayPrefixBase = @"__MGSAttributeOverlay_";


@interface MGSAttributeOverlayTextStorage ()

@property (readonly) NSString *overlayAttributePrefix;

@end


@implementation MGSAttributeOverlayTextStorage
{
    BOOL editInProgress;
    BOOL parentEditInProgress;
}


- (instancetype)initWithParentTextStorage:(NSTextStorage *)ts
{
    self = [super init];
    
    _parentTextStorage = ts;
    _overlayAttributePrefix = [NSString stringWithFormat:@"%@%p_", MGSAttributeOverlayPrefixBase, self];
    
    editInProgress = NO;
    parentEditInProgress = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(parentTextStorageDidProcessEdit:) name:NSTextStorageDidProcessEditingNotification object:ts];
    
    return self;
}


- (instancetype)init
{
    NSTextStorage *backingStore = [[NSTextStorage alloc] init];
    return [self initWithParentTextStorage:backingStore];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (NSString *)string
{
    return self.parentTextStorage.string;
}


- (void)parentTextStorageDidProcessEdit:(NSNotification *)notif
{
    if (editInProgress)
        return;
    
    parentEditInProgress = YES;
    
    NSRange range = self.parentTextStorage.editedRange;
    range.length -= self.parentTextStorage.changeInLength;
    [self edited:self.parentTextStorage.editedMask range:range changeInLength:self.parentTextStorage.changeInLength];
    
    parentEditInProgress = NO;
}


- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{
    NSDictionary *attrib = [self.parentTextStorage attributesAtIndex:location effectiveRange:range];
    NSMutableDictionary *base = [NSMutableDictionary dictionary];
    NSMutableDictionary *ovl = [NSMutableDictionary dictionary];
    NSMutableArray *remove = [NSMutableArray array];
    
    [attrib enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (![key hasPrefix:MGSAttributeOverlayPrefixBase]) {
            [base setObject:obj forKey:key];
        } else if ([key hasPrefix:self.overlayAttributePrefix]) {
            NSString *realKey = [key substringFromIndex:self.overlayAttributePrefix.length];
            if (![obj isKindOfClass:[NSNull class]])
                [ovl setObject:obj forKey:realKey];
            else
                [remove addObject:realKey];
        }
    }];
    
    [base removeObjectsForKeys:remove];
    [base addEntriesFromDictionary:ovl];
    return base;
}


- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str
{
    editInProgress = YES;
    
    [self.parentTextStorage replaceCharactersInRange:range withString:str];
    [self edited:NSTextStorageEditedCharacters range:range changeInLength:str.length-range.length];
    
    editInProgress = NO;
}


- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range
{
    editInProgress = YES;
    
    NSMutableDictionary *fixeddict = [NSMutableDictionary dictionary];
    [attrs enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *newkey = [self.overlayAttributePrefix stringByAppendingString:key];
        [fixeddict setObject:obj forKey:newkey];
    }];
    
    [self.parentTextStorage
        enumerateAttributesInRange:range
        options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
        usingBlock:^(NSDictionary<NSAttributedStringKey, id> * _Nonnull attrs, NSRange subrange, BOOL * _Nonnull stop)
    {
        NSMutableDictionary *newAttributes = [NSMutableDictionary dictionary];
        for (NSString *key in attrs) {
            if ([key hasPrefix:MGSAttributeOverlayPrefixBase]) {
                if (![key hasPrefix:self.overlayAttributePrefix]) {
                    [newAttributes setObject:attrs[key] forKey:key];
                }
            } else {
                NSString *myid = [self.overlayAttributePrefix stringByAppendingString:key];
                [newAttributes setObject:[NSNull null] forKey:myid];
            }
        }
        [newAttributes addEntriesFromDictionary:fixeddict];
        
        NSRange realrange = NSIntersectionRange(range, subrange);
        [self.parentTextStorage setAttributes:newAttributes range:realrange];
    }];
    
    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
    
    editInProgress = NO;
}


@end
