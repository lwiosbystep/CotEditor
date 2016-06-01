/*
 
 CETextViewDelegate.m
 
 CotEditor
 http://coteditor.com
 
 Created by 1024jp on 2016-05-31.
 
 ------------------------------------------------------------------------------
 
 © 2004-2007 nakamuxu
 © 2014-2016 1024jp
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 
 */

#import "CETextViewDelegate.h"
#import "CETextView.h"

#import "CEDefaults.h"

#import "NSString+CENewLine.h"


@interface CETextViewDelegate ()

@property (nonatomic) NSUInteger lastCursorLocation;

@property (nonatomic, nullable) IBOutlet CETextView *textView;

@end




#pragma mark -

@implementation CETextViewDelegate

#pragma mark Object Methods

// ------------------------------------------------------
/// initialize instance
- (nonnull instancetype)init
// ------------------------------------------------------
{
    self = [super init];
    if (self) {
        // observe change of defaults
        [[NSUserDefaults standardUserDefaults] addObserver:self
                                                forKeyPath:CEDefaultHighlightCurrentLineKey
                                                   options:NSKeyValueObservingOptionNew
                                                   context:NULL];
        
        // update current line highlight on changing frame size
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(invalidateCurrentLineRect)
                                                     name:NSViewFrameDidChangeNotification
                                                   object:[self textView]];
    }
    return self;
}


// ------------------------------------------------------
/// clean up
- (void)dealloc
// ------------------------------------------------------
{
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:CEDefaultHighlightCurrentLineKey];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    _textView = nil;
    
}


// ------------------------------------------------------
/// apply change of user setting
- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSString *, id> *)change context:(nullable void *)context
// ------------------------------------------------------
{
    id newValue = change[NSKeyValueChangeNewKey];
    
    if ([keyPath isEqualToString:CEDefaultHighlightCurrentLineKey]) {
        CETextView *textView = object;
        
        if ([newValue boolValue]) {
            [self invalidateCurrentLineRect];
        } else {
            NSRect rect = [textView highlightLineRect];
            [textView setHighlightLineRect:NSZeroRect];
            [textView setNeedsDisplayInRect:rect avoidAdditionalLayout:YES];
        }
    }
}



#pragma mark Delegate

//=======================================================
// NSTextViewDelegate  < textView
//=======================================================

// ------------------------------------------------------
/// text will be edited
- (BOOL)textView:(nonnull NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(nullable NSString *)replacementString
// ------------------------------------------------------
{
    // standardize line endings to LF (Key Typing, Script, Paste, Drop or Replace via Find Panel)
    // (Line endings replacemement by other text modifications are processed in the following methods.)
    //
    // # Methods Standardizing Line Endings on Text Editing
    //   - File Open:
    //       - CEDocument > readFromURL:ofType:error:
    //   - Key Typing, Script, Paste, Drop or Replace via Find Panel:
    //       - CETextViewDelegate > textView:shouldChangeTextInRange:replacementString:
    
    if (!replacementString ||  // = only attributes changed
        ([replacementString length] == 0) ||  // = text deleted
        [[textView undoManager] isUndoing] ||  // = undo
        [replacementString isEqualToString:@"\n"])
    {
        return YES;
    }
    
    // replace all line endings with LF
    CENewLineType replacementLineEndingType = [replacementString detectNewLineType];
    if ((replacementLineEndingType != CENewLineNone) && (replacementLineEndingType != CENewLineLF)) {
        NSString *newString = [replacementString stringByReplacingNewLineCharacersWith:CENewLineLF];
        
        [textView replaceWithString:newString
                              range:affectedCharRange
                      selectedRange:NSMakeRange(affectedCharRange.location + [newString length], 0)
                         actionName:nil];  // Action name will be set automatically.
        
        return NO;
    }
    
    return YES;
}


// ------------------------------------------------------
/// build completion list
- (nonnull NSArray<NSString *> *)textView:(nonnull NSTextView *)textView completions:(nonnull NSArray<NSString *> *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(nullable NSInteger *)index
// ------------------------------------------------------
{
    // do nothing if completion is not suggested from the typed characters
    if (charRange.length == 0) { return @[]; }
    
    NSMutableOrderedSet<NSString *> *candidateWords = [NSMutableOrderedSet orderedSet];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *partialWord = [[textView string] substringWithRange:charRange];
    
    // extract words in document and set to candidateWords
    if ([defaults boolForKey:CEDefaultCompletesDocumentWordsKey]) {
        if (charRange.length == 1 && ![[NSCharacterSet alphanumericCharacterSet] characterIsMember:[partialWord characterAtIndex:0]]) {
            // do nothing if the particle word is an symbol
            
        } else {
            NSString *documentString = [textView string];
            NSString *pattern = [NSString stringWithFormat:@"(?:^|\\b|(?<=\\W))%@\\w+?(?:$|\\b)",
                                 [NSRegularExpression escapedPatternForString:partialWord]];
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
            [regex enumerateMatchesInString:documentString options:0
                                      range:NSMakeRange(0, [documentString length])
                                 usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
             {
                 [candidateWords addObject:[documentString substringWithRange:[result range]]];
             }];
        }
    }
    
    // copy words defined in syntax style
    if ([defaults boolForKey:CEDefaultCompletesSyntaxWordsKey]) {
        NSArray<NSString *> *syntaxWords = [(CETextView *)textView syntaxCompletionWords];
        for (NSString *word in syntaxWords) {
            if ([word rangeOfString:partialWord options:NSCaseInsensitiveSearch|NSAnchoredSearch].location != NSNotFound) {
                [candidateWords addObject:word];
            }
        }
    }
    
    // copy the standard words from default completion words
    if ([defaults boolForKey:CEDefaultCompletesStandartWordsKey]) {
        [candidateWords addObjectsFromArray:words];
    }
    
    // provide nothing if there is only a candidate which is same as input word
    if ([candidateWords count] == 1 && [[candidateWords firstObject] caseInsensitiveCompare:partialWord] == NSOrderedSame) {
        return @[];
    }
    
    return [candidateWords array];
}


// ------------------------------------------------------
/// text did edit.
- (void)textDidChange:(nonnull NSNotification *)aNotification
// ------------------------------------------------------
{
    CETextView *textView = [aNotification object];
    
    // retry completion if needed
    //   -> Flag is set in CETextView > `insertCompletion:forPartialWordRange:movement:isFinal:`
    if ([textView needsRecompletion]) {
        [textView setNeedsRecompletion:NO];
        [textView completeAfterDelay:0.05];
    }
}


// ------------------------------------------------------
/// the selection of main textView was changed.
- (void)textViewDidChangeSelection:(nonnull NSNotification *)aNotification
// ------------------------------------------------------
{
    NSTextView *textView = [aNotification object];
    if (![textView isKindOfClass:[NSTextView class]]) { return; }
    
    // highlight the current line
    [self invalidateCurrentLineRect];
    
    // highlight matching brace
    [self highlightMatchingBraceInTextView:textView];
}


// ------------------------------------------------------
/// font is changed
- (void)textViewDidChangeTypingAttributes:(nonnull NSNotification *)notification
// ------------------------------------------------------
{
    [self invalidateCurrentLineRect];
}



#pragma mark Private Methods

// ------------------------------------------------------
/// find the matching open brace and highlight it
- (void)highlightMatchingBraceInTextView:(nonnull NSTextView *)textView
// ------------------------------------------------------
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:CEDefaultHighlightBracesKey]) { return; }
    
    // The following part is based on Smultron's SMLTextView.m by Peter Borg. (2006-09-09)
    // Smultron 2 was distributed on <http://smultron.sourceforge.net> under the terms of the BSD license.
    // Copyright (c) 2004-2006 Peter Borg
    
    NSString *completeString = [textView string];
    if ([completeString length] == 0) { return; }
    
    NSInteger location = [textView selectedRange].location;
    NSInteger difference = location - [self lastCursorLocation];
    [self setLastCursorLocation:location];
    
    // The brace will be highlighted only when the cursor moves forward, just like on Xcode. (2006-09-10)
    // If the difference is more than one, they've moved the cursor with the mouse or it has been moved by resetSelectedRange below and we shouldn't check for matching braces then.
    if (difference != 1) { return; }
    
    // check the caracter just before the cursor
    location--;
    
    unichar beginBrace, endBrace;
    switch ([completeString characterAtIndex:location]) {
        case ')':
            beginBrace = '(';
            endBrace = ')';
            break;
            
        case '}':
            beginBrace = '{';
            endBrace = '}';
            break;
            
        case ']':
            beginBrace = '[';
            endBrace = ']';
            break;
            
        case '>':
            if (![[NSUserDefaults standardUserDefaults] boolForKey:CEDefaultHighlightLtGtKey]) { return; }
            beginBrace = '<';
            endBrace = '>';
            break;
            
        default:
            return;
    }
    
    NSUInteger skippedBraceCount = 0;
    
    while (location--) {
        unichar character = [completeString characterAtIndex:location];
        if (character == beginBrace) {
            if (skippedBraceCount == 0) {
                // highlight the matching brace
                [textView showFindIndicatorForRange:NSMakeRange(location, 1)];
                return;
            }
            skippedBraceCount--;
            
        } else if (character == endBrace) {
            skippedBraceCount++;
        }
    }
    
    // do not beep when the typed brace is `>`
    //  -> Since `>` (and `<`) can often be used alone unlike other braces.
    if (endBrace != '>') {
        NSBeep();
    }
}


// ------------------------------------------------------
/// update current line highlight area
- (void)invalidateCurrentLineRect
// ------------------------------------------------------
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:CEDefaultHighlightCurrentLineKey]) { return; }
    
    CETextView *textView = [self textView];
    
    // avoid useless calcuration before textView is initialized.  (2014-07 by 1024jp)
    if (![[textView window] isVisible]) { return; }
    
    NSLayoutManager *layoutManager = [textView layoutManager];
    
    // calcurate current line rect
    NSRange lineRange = [[textView string] lineRangeForRange:[textView selectedRange]];
    lineRange.length -= (lineRange.length > 0) ? 1 : 0;  // remove line ending
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:lineRange actualCharacterRange:NULL];
    NSRect rect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:[textView textContainer]];
    rect.size.width = [[textView textContainer] containerSize].width - 2 * [[textView textContainer] lineFragmentPadding];
    rect = NSOffsetRect(rect, [textView textContainerOrigin].x, [textView textContainerOrigin].y);
    
    // let textView draw the rect to highlight
    if (!NSEqualRects([textView highlightLineRect], rect)) {
        // clear previous highlihght
        [textView setNeedsDisplayInRect:[textView highlightLineRect] avoidAdditionalLayout:YES];
        
        // draw highlight
        [textView setHighlightLineRect:rect];
        [textView setNeedsDisplayInRect:rect avoidAdditionalLayout:YES];
    }
}

@end