/*
 *  CPLayoutManager.j
 *  AppKit
 *
 *  <!> FIXME only insert into DOM when actually visible (as done in CPTableView)
 *
 *
 *  Created by Daniel Boehringer on 27/12/2013.
 *  All modifications copyright Daniel Boehringer 2013.
 *  Based on original work by
 *  Emmanuel Maillard on 27/02/2010.
 *  Copyright Emmanuel Maillard 2010.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

@import "CPTextStorage.j"
@import "CPTextContainer.j"
@import "CPTypesetter.j"

function _RectEqualToRectHorizontally(lhsRect, rhsRect)
{
    return (lhsRect.origin.x == rhsRect.origin.x &&
            lhsRect.size.width == rhsRect.size.width &&
            lhsRect.size.height == rhsRect.size.height);
}


@implementation CPArray(SortedSearching)

- (unsigned)indexOfObject:(id)anObject sortedByFunction:(Function)aFunction context:(id)aContext
{
    var result = [self _indexOfObject:anObject sortedByFunction:aFunction context:aContext];

    return (result >= 0) ? result : CPNotFound;
}

- (unsigned)_indexOfObject:(id)anObject sortedByFunction:(Function)aFunction context:(id)aContext
{
    var length= [self count];

    if (!aFunction)
        return CPNotFound;

    if (length === 0)
        return -1;

    var mid,
        c,
        first = 0,
        last = length - 1;

    while (first <= last)
    {
        mid = FLOOR((first + last) / 2);
          c = aFunction(anObject, self[mid], aContext);

        if (c > 0)
            first = mid + 1;
        else if (c < 0)
            last = mid - 1;
        else
        {
            while (mid < length - 1 && aFunction(anObject, self[mid + 1], aContext) == CPOrderedSame)
                mid++;

            return mid;
        }
    }

    return -first - 1;
}

@end

var _sortRange = function(location, anObject)
{
    if (CPLocationInRange(location, anObject._range))
        return CPOrderedSame;
    else if (CPMaxRange(anObject._range) <= location)
        return CPOrderedDescending;
    else
        return CPOrderedAscending;
}

var _objectWithLocationInRange = function(aList, aLocation)
{
    var index = [aList indexOfObject: aLocation sortedByFunction:_sortRange context:nil];

    if (index != CPNotFound)
        return aList[index];

    return nil;
}

var _objectsInRange = function(aList, aRange)
{
    var list = [],
        c = aList.length,
        location = aRange.location;

    for (var i = 0; i < c; i++)
    {
        if (CPLocationInRange(location, aList[i]._range))
        {
            list.push(aList[i]);
            if (CPMaxRange(aList[i]._range) <= CPMaxRange(aRange))
                location = CPMaxRange(aList[i]._range);
            else
                break;
        }
        else if (CPLocationInRange(CPMaxRange(aRange), aList[i]._range))
        {
            list.push(aList[i]);
            break;
        }
        else if (CPRangeInRange(aRange, aList[i]._range))
        {
            list.push(aList[i]);
        }
    }

    return list;
}

@implementation _CPLineFragment : CPObject
{
    CPRect _fragmentRect;
    CPRect _usedRect;
    CPPoint _location;
    CPRange _range;
    CPTextContainer _textContainer;
    BOOL _isInvalid;
    CPMutableArray _runs;

    /* 'Glyphs' frames */
    CPArray _glyphsFrames;
}

- (id)createDOMElementWithText:aString andFont:aFont andColor:aColor
{
    var style,
        span = document.createElement("span");

    style = span.style;
    style.position = "absolute";
    style.visibility = "visible";
    style.padding = "0px";
    style.margin = "0px";
    style.whiteSpace = "pre";
    style.backgroundColor = "transparent";
    style.font = [aFont cssString];

    if (aColor)
        style.color = [aColor cssString];

    // FIXME <!> quote HTML entities
    if (CPFeatureIsCompatible(CPJavaScriptInnerTextFeature))
        span.innerText = aString;
    else if (CPFeatureIsCompatible(CPJavaScriptTextContentFeature))
        span.textContent = aString;

    return span;
}

- (id)initWithRange:(CPRange)aRange textContainer:(CPTextContainer)aContainer textStorage:(CPTextStorage)textStorage
{
    self = [super init];

    if (self)
    {
        _fragmentRect = CGRectMakeZero();
        _usedRect = CGRectMakeZero();
        _location = CPPointMakeZero();
        _range = CPMakeRangeCopy(aRange);
        _textContainer = aContainer;
        _isInvalid = NO;

        _runs = [[CPMutableArray alloc] init];
        var effectiveRange = CPMakeRange(0,0),
            location = aRange.location;

        do {
            var attributes = [textStorage attributesAtIndex:location effectiveRange:effectiveRange];
            effectiveRange = attributes ? CPIntersectionRange(aRange, effectiveRange) : aRange;

            var string = [textStorage._string substringWithRange:effectiveRange],
                font = [textStorage font] || [CPFont systemFontOfSize:12.0];

            if ([attributes containsKey:CPFontAttributeName])
                 font = [attributes objectForKey:CPFontAttributeName];

            var color = [attributes objectForKey:CPForegroundColorAttributeName],
                elem = [self createDOMElementWithText:string andFont:font andColor:color],
                run = {_range:CPMakeRangeCopy(effectiveRange), elem:elem, string:string};

            _runs.push(run);

            location = CPMaxRange(effectiveRange);
        } while (location < CPMaxRange(aRange));
    }

    return self;
}

- (void)setAdvancements:someAdvancements
{
    _glyphsFrames = [];

    var count = someAdvancements.length,
        origin = CPPointMake(_fragmentRect.origin.x + _location.x, _fragmentRect.origin.y); // FIXME _location.y

    for (var i = 0; i < count; i++)
    {
        _glyphsFrames.push(CPRectMake(origin.x, origin.y, someAdvancements[i], _usedRect.size.height));
        origin.x += someAdvancements[i];
    }
}

- (CPString)description
{
    return [super description] +
        "\n\t_fragmentRect="+CPStringFromRect(_fragmentRect) +
        "\n\t_usedRect="+CPStringFromRect(_usedRect) +
        "\n\t_location="+CPStringFromPoint(_location) +
        "\n\t_range="+CPStringFromRange(_range);
}

- (CPArray)glyphFrames
{
    return _glyphsFrames;
}

- (void)drawUnderlineForGlyphRange:(CPRange)glyphRange
                     underlineType:(int)underlineVal
                    baselineOffset:(float)baselineOffset
                   containerOrigin:(CPPoint)containerOrigin
{
// <!> FIXME
}

- (void)invalidate
{
    _isInvalid = YES;
}

- (void)_deinvalidate
{
    _isInvalid = NO;
}

- (void)_removeFromDOM
{
    var i,
        l = _runs.length;

    for (var i = 0; i < l; i++)
    {
        if (_runs[i].elem && _runs[i].DOMactive)
            _textContainer._textView._DOMElement.removeChild(_runs[i].elem);

        _runs[i].elem = nil;
        _runs[i].DOMactive = NO;
    }
}

- (void)drawInContext:(CGContext)context atPoint:(CPPoint)aPoint forRange:(CPRange)aRange
{
    var runs = _objectsInRange(_runs, aRange),
        c = runs.length,
        orig = CPPointMake(_location.x, _location.y + _fragmentRect.origin.y);

    orig.y += aPoint.y;

    for (var i = 0; i < c; i++)
    {
        var run = runs[i];
        orig.x = (_glyphsFrames[run._range.location - runs[0]._range.location] ? _glyphsFrames[run._range.location - runs[0]._range.location].origin.x : 0) +
                    aPoint.x;
        run.elem.style.left = (orig.x) + "px";
        run.elem.style.top = (orig.y - _usedRect.size.height + 4) + "px";

        if (!run.DOMactive)
            _textContainer._textView._DOMElement.appendChild(run.elem);

        run.DOMactive = YES;

        if (run.underline)
        {
            // <!> FIXME
        }
    }
}

- (void)backgroundColorForGlyphAtIndex:(unsigned)index
{
    var run = _objectWithLocationInRange(_runs, index);

    if (run)
        return run.backgroundColor;

    return [CPColor clearColor];
}

- (BOOL)isVisuallyIdenticalToFragment:(_CPLineFragment)newLineFragment
{
    var newFragmentRuns= newLineFragment._runs,
        oldFragmentRuns= _runs;

    if (!oldFragmentRuns || !newFragmentRuns || oldFragmentRuns.length !== newFragmentRuns.length)
        return NO;

    for (var i = 0; i < oldFragmentRuns.length; i++)
    {
        if (newFragmentRuns[i].string !== oldFragmentRuns[i].string ||
            !_RectEqualToRectHorizontally(newLineFragment._fragmentRect, _fragmentRect))
        // FIXME <!>  newFragmentRuns[i].elem.style.left !== oldFragmentRuns[i].elem.style.left && compare CSS-strings
        {
            return NO;
        }
    }

    return YES;
}

- (void)_relocateVerticallyByY:(double) verticalOffset rangeOffset:(unsigned) rangeOffset
{
    _range.location += rangeOffset;
    var l = _runs.length;

    for (var i = 0; i < l; i++)
    {
        _runs[i]._range.location += rangeOffset;

        if (verticalOffset)
            _runs[i].elem.top = (_runs[i].elem.top + verticalOffset) + 'px';
    }

    if (!verticalOffset)
        return NO;

    _fragmentRect.origin.y += verticalOffset;
    _usedRect.origin.y += verticalOffset;
    _location.y += verticalOffset;

    var l = _glyphsFrames.length;

    for (var i = 0; i < l ; i++)
    {
        _glyphsFrames[i].origin.y += verticalOffset;
    }

}

@end

@implementation _CPTemporaryAttributes : CPObject
{
    CPDictionary _attributes;
    CPRange      _range;
}

- (id)initWithRange:(CPRange)aRange attributes:(CPDictionary)attributes
{
    self = [super init];

    if (self)
    {
        _attributes = attributes;
        _range = CPMakeRangeCopy(aRange);
    }

    return self;
}

- (CPString)description
{
    return [super description] +
        "\n\t_range="+CPStringFromRange(_range) +
        "\n\t_attributes="+[_attributes description];
}

@end

/*!
    @ingroup appkit
    @class CPLayoutManager
*/
@implementation CPLayoutManager : CPObject
{
    CPTextStorage   _textStorage;
    id              _delegate;
    CPMutableArray  _textContainers;
    CPTypesetter    _typesetter;

    CPMutableArray  _lineFragments;
    CPMutableArray  _lineFragmentsForRescue;
    id              _extraLineFragment;
    Class           _lineFragmentFactory;

    CPMutableArray  _temporaryAttributes;

    BOOL            _isValidatingLayoutAndGlyphs;
    var             _removeInvalidLineFragmentsRange;
}

- (id)init
{
    self = [super init];

    if (self)
    {
        _textContainers = [[CPMutableArray alloc] init];
        _lineFragments = [[CPMutableArray alloc] init];
        _typesetter = [CPTypesetter sharedSystemTypesetter];
        _isValidatingLayoutAndGlyphs = NO;
        _lineFragmentFactory = [_CPLineFragment class];
    }

    return self;
}

- (void)setTextStorage:(CPTextStorage)textStorage
{
    if (_textStorage === textStorage)
        return;

    _textStorage = textStorage;
}

- (CPTextStorage)textStorage
{
    return _textStorage;
}

- (void)insertTextContainer:(CPTextContainer)aContainer atIndex:(int)index
{
    [_textContainers insertObject:aContainer atIndex:index];
    [aContainer setLayoutManager:self];
}

- (void)addTextContainer:(CPTextContainer)aContainer
{
    [_textContainers addObject:aContainer];
    [aContainer setLayoutManager:self];
}

- (void)removeTextContainerAtIndex:(int)index
{
    var container = [_textContainers objectAtIndex:index];
    [container setLayoutManager:nil];
    [_textContainers removeObjectAtIndex:index];
}

- (CPArray)textContainers
{
    return _textContainers;
}

// <!> fixme
- (int)numberOfGlyphs
{
    return [_textStorage length];
}
- (int)numberOfCharacters
{
    return [_textStorage length];
}

- (CPTextView)firstTextView
{
    return [_textContainers[0] textView];
}

// from cocoa (?)
- (CPTextView)textViewForBeginningOfSelection
{
   return [[_textContainers objectAtIndex:0] textView];
}

- (BOOL)layoutManagerOwnsFirstResponderInWindow:(CPWindow)aWindow
{
    var firstResponder = [aWindow firstResponder],
        c = [_textContainers count];

    for (var i = 0; i < c; i++)
    {
        if ([_textContainers[i] textView] === firstResponder)
            return YES;
    }

    return NO;
}

- (CPRect)boundingRectForGlyphRange:(CPRange)aRange inTextContainer:(CPTextContainer)container
{
    if (![self numberOfGlyphs])
        return CPRectMake(0, 0, 1, 12);    // crude hack to give a cursor in an empty doc.

    if (CPMaxRange(aRange) >= [self numberOfGlyphs])
        aRange = CPMakeRange([self numberOfGlyphs] - 1, 1);

    var fragments = _objectsInRange(_lineFragments, aRange),
        rect = nil,
        c = [fragments count];

    for (var i = 0; i < c; i++)
    {
        var fragment = fragments[i];
        if (fragment._textContainer === container)
        {
            var frames = [fragment glyphFrames],
                l = frames.length;

            for (var j = 0; j < l; j++)
            {
                if (CPLocationInRange(fragment._range.location + j, aRange))
                {
                    if (!rect)
                        rect = CPRectCreateCopy(frames[j]);
                    else
                        rect = CPRectUnion(rect, frames[j]);
                }
            }
        }
    }
    return (rect) ? rect : CGRectMakeZero();
}

- (CPRange)glyphRangeForTextContainer:(CPTextContainer)aTextContainer
{
    var range = nil,
        c = [_lineFragments count];
    for (var i = 0; i < c; i++)
    {
        var fragment = _lineFragments[i];
        if (fragment._textContainer === aTextContainer)
        {
           if (!range)
                range = CPMakeRangeCopy(fragment._range);
            else
                range = CPUnionRange(range, fragment._range);
        }
    }
    return (range)?range:CPMakeRange(CPNotFound, 0);
}

- (void)_removeInvalidLineFragments
{
    _lineFragmentsForRescue = [_lineFragments copy];
    [_lineFragmentsForRescue makeObjectsPerformSelector:@selector(_deinvalidate)];

    if (_removeInvalidLineFragmentsRange && _removeInvalidLineFragmentsRange.length && _lineFragments.length)
    {
        [[_lineFragments subarrayWithRange:_removeInvalidLineFragmentsRange] makeObjectsPerformSelector:@selector(invalidate)];
        [_lineFragments removeObjectsInRange:_removeInvalidLineFragmentsRange];
        [[_lineFragmentsForRescue subarrayWithRange:_removeInvalidLineFragmentsRange] makeObjectsPerformSelector:@selector(invalidate)];
    }

}

- (void)_cleanUpDOM
{
    var l = _lineFragmentsForRescue.length;

    for (var i = 0; i < l; i++)
    {
        if (_lineFragmentsForRescue[i]._isInvalid)
            [_lineFragmentsForRescue[i] _removeFromDOM];
    }
}

- (void)_validateLayoutAndGlyphs
{
    if (_isValidatingLayoutAndGlyphs)
        return;

    _isValidatingLayoutAndGlyphs = YES;

    var startIndex = CPNotFound,
        removeRange = CPMakeRange(0,0);

    var l = _lineFragments.length;
    if (l)
    {
        for (var i = 0; i < l; i++)
        {
            if (_lineFragments[i]._isInvalid)
            {
                startIndex = _lineFragments[i]._range.location;
                removeRange.location = i;
                removeRange.length = l - i;
                break;
            }
        }

        if (startIndex == CPNotFound && CPMaxRange (_lineFragments[l - 1]._range) < [_textStorage length])
            startIndex =  CPMaxRange(_lineFragments[l - 1]._range);  // start one line above current line to make sure that a word can jump up
    }
    else
        startIndex = 0;

    /* nothing to validate and layout */
    if (startIndex == CPNotFound)
    {
        _isValidatingLayoutAndGlyphs = NO;
        return;
    }

    if (removeRange.length)
        _removeInvalidLineFragmentsRange = CPMakeRangeCopy(removeRange);

    if (!startIndex)  // We erased all lines
        [self setExtraLineFragmentRect:CPRectMake(0,0) usedRect:CPRectMake(0,0) textContainer:nil];

    //    document.title=startIndex;
    [_typesetter layoutGlyphsInLayoutManager:self startingAtGlyphIndex:startIndex maxNumberOfLineFragments:-1 nextGlyphIndex:nil];
    [self _cleanUpDOM];
    _isValidatingLayoutAndGlyphs = NO;
}

- (BOOL)_rescuingInvalidFragmentsWasPossibleForGlyphRange:(CPRange)aRange
{
    var l = _lineFragments.length,
        location = aRange.location,
        found = NO;

    for (var i = 0; i < l; i++)
    {
        if (CPLocationInRange(location, _lineFragments[i]._range))
        {    found = YES;
            break;
        }
    }

    if (!found)
        return NO;

    if (!_lineFragmentsForRescue[i])
        return NO;

    var startLineForDOMRemoval = i,
        l = _lineFragments.length,
        isIdentical = YES,
        newLineFragment= _lineFragments[i],
        oldLineFragment = _lineFragmentsForRescue[i];

    if (![oldLineFragment isVisuallyIdenticalToFragment: newLineFragment])
    {
        isIdentical = NO;
    }

    if (isIdentical)    // patch and, if applicable, patch the linefragments
    {
        var rangeOffset = CPMaxRange(_lineFragments[startLineForDOMRemoval]._range) - CPMaxRange(_lineFragmentsForRescue[startLineForDOMRemoval]._range);

        if (!rangeOffset) // <!> fixme-> patch vertically instead of redrawing
            return NO;

        var verticalOffset = _lineFragments[startLineForDOMRemoval]._usedRect.origin.y - _lineFragmentsForRescue[startLineForDOMRemoval]._usedRect.origin.y,
            l = _lineFragmentsForRescue.length;

        for (var i = startLineForDOMRemoval + 1; i < l; i++)
        {
            _lineFragmentsForRescue[i]._isInvalid = NO;    // protect them from final removal
            //if()
            [_lineFragmentsForRescue[i] _relocateVerticallyByY:verticalOffset rangeOffset:rangeOffset];
            _lineFragments.push(_lineFragmentsForRescue[i]);
        }
    }

    return isIdentical;
}

- (void)invalidateDisplayForGlyphRange:(CPRange)range
{
    var lineFragments = _objectsInRange(_lineFragments, range);

    for (var i = 0; i < lineFragments.length; i++)
        [[lineFragments[i]._textContainer textView] setNeedsDisplayInRect: lineFragments[i]._fragmentRect];
}

- (void)invalidateLayoutForCharacterRange:(CPRange)aRange isSoft:(BOOL)flag actualCharacterRange:(CPRangePointer)actualCharRange
{
    var firstFragmentIndex = _lineFragments.length? [_lineFragments indexOfObject: aRange.location sortedByFunction:_sortRange context:nil]:CPNotFound;

    if (firstFragmentIndex == CPNotFound)
    {
        if (_lineFragments.length)
            firstFragmentIndex = _lineFragments.length - 1;
        else
        {
            if (actualCharRange)
            {
                actualCharRange.length = aRange.length;
                actualCharRange.location = 0;
            }

            return;
        }
    }
    else
        firstFragmentIndex = firstFragmentIndex + (firstFragmentIndex ? - 1 : 0);

    var fragment = _lineFragments[firstFragmentIndex],
        range = CPMakeRangeCopy(fragment._range);

    fragment._isInvalid = YES;

    /* invalidated all fragments that follow */
    for (var i = firstFragmentIndex + 1; i < _lineFragments.length; i++)
    {
        _lineFragments[i]._isInvalid = YES;
        range = CPUnionRange(range, _lineFragments[i]._range);
    }

    if (CPMaxRange(range) < CPMaxRange(aRange))
        range = CPUnionRange(range, aRange);

    if (actualCharRange)
    {    actualCharRange.length = range.length;
        actualCharRange.location = range.location;
    }
}

- (void)textStorage:(CPTextStorage)textStorage edited:(unsigned)mask range:(CPRange)charRange changeInLength:(int)delta invalidatedRange:(CPRange)invalidatedRange
{
    var actualRange = CPMakeRange(CPNotFound,0);
    [self invalidateLayoutForCharacterRange: invalidatedRange isSoft:NO actualCharacterRange:actualRange];
    [self invalidateDisplayForGlyphRange: actualRange];
}

- (CPRange)glyphRangeForBoundingRect:(CPRect)aRect inTextContainer:(CPTextContainer)container
{
    var range = nil,
        i,
        c = [_lineFragments count];

    for (i = 0; i < c; i++)
    {
        var fragment = _lineFragments[i];

        if (fragment._textContainer === container)
        {
            if (CPRectContainsRect(aRect, fragment._usedRect))
            {
                if (!range)
                    range = CPMakeRangeCopy(fragment._range);
                else
                    range = CPUnionRange(range, fragment._range);
            }
            else
            {
                var glyphRange = CPMakeRange(CPNotFound, 0),
                    frames = [fragment glyphFrames];

                for (var j = 0; j < frames.length; j++)
                {
                    if (CPRectIntersectsRect(aRect, frames[j]))
                    {
                        if (glyphRange.location == CPNotFound)
                            glyphRange.location = fragment._range.location + j;
                        else
                            glyphRange.length++;
                    }
                }
                if (glyphRange.location != CPNotFound)
                {
                    if (!range)
                        range = CPMakeRangeCopy(glyphRange);
                    else
                        range = CPUnionRange(range, glyphRange);
                }
            }
        }
    }
    return (range)?range:CPMakeRange(0,0);
}

- (void)drawBackgroundForGlyphRange:(CPRange)aRange atPoint:(CPPoint)aPoint
{
}

- (void)drawUnderlineForGlyphRange:(CPRange)glyphRange
                    underlineType:(int)underlineVal
                    baselineOffset:(float)baselineOffset
                    lineFragmentRect:(CGRect)lineFragmentRect
                    lineFragmentGlyphRange:(CPRange)lineGlyphRange
                    containerOrigin:(CPPoint)containerOrigin
{
// FIXME
}

- (void)drawGlyphsForGlyphRange:(CPRange)aRange atPoint:(CPPoint)aPoint
{
    var lineFragments = _objectsInRange(_lineFragments, aRange);

    if (!lineFragments.length)
        return;

    var ctx = nil,
        paintedRange = CPMakeRangeCopy(aRange),
        lineFragmentIndex,
        l= lineFragments.length;

    for (lineFragmentIndex = 0; lineFragmentIndex < l; lineFragmentIndex++)
    {
        var currentFragment = lineFragments[lineFragmentIndex];
        [currentFragment drawInContext:ctx atPoint:aPoint forRange:paintedRange];
    }
}

- (unsigned)glyphIndexForPoint:(CPPoint)point inTextContainer:(CPTextContainer)container fractionOfDistanceThroughGlyph:(FloatArray)partialFraction
{
    var c = [_lineFragments count];
    for (var i = 0; i < c; i++)
    {
        var fragment = _lineFragments[i];
        if (fragment._textContainer === container)
        {
            var frames = [fragment glyphFrames];
            for (var j = 0; j < frames.length; j++)
            {
                if (CPRectContainsPoint(frames[j], point))
                {
                    if (partialFraction)
                        partialFraction[0] = (point.x - frames[j].origin.x) / frames[j].size.width;

                    return fragment._range.location + j;
                }
            }
        }
    }
    // not found, maybe a point left to the last character was clicked->search again with broader constraints
    if ([[_textStorage string] length])
    {
        for (var i = 0; i < c; i++)
        {
            var fragment = _lineFragments[i];

            if (fragment._textContainer === container)
            {
                if (fragment._range.length > 0 && point.y > fragment._fragmentRect.origin.y &&
                    point.y <= fragment._fragmentRect.origin.y + fragment._fragmentRect.size.height)
                {
                    var nlLoc = CPMaxRange(fragment._range) - 1,
                        lastFrame = [[fragment glyphFrames] lastObject];

                    if (point.x > CPRectGetMaxX(lastFrame) + 22 &&   // this allows clicking before and after the (invisible) return character
                        [[_textStorage string] characterAtIndex: nlLoc] === '\n' || i === c -1)
                        return nlLoc + 1;
                    else
                        return nlLoc;
                }
            }
        }
    }
    return CPNotFound;
}

- (unsigned)glyphIndexForPoint:(CPPoint)point inTextContainer:(CPTextContainer)container
{
    return [self glyphIndexForPoint:point inTextContainer:container fractionOfDistanceThroughGlyph:nil];
}

- (void)_setAttributes:(CPDictionary)attributes toTemporaryAttributes:(_CPTemporaryAttributes)tempAttributes
{
    tempAttributes._attributes = attributes;
}

- (void)_addAttributes:(CPDictionary)attributes toTemporaryAttributes:(_CPTemporaryAttributes)tempAttributes
{
    [tempAttributes._attributes addEntriesFromDictionary:attributes];
}

- (void)_handleTemporaryAttributes:(CPDictionary)attributes forCharacterRange:(CPRange)charRange withSelector:(SEL)attributesOperation
{
    if (!_temporaryAttributes)
        _temporaryAttributes = [[CPMutableArray alloc] init];

    var location = charRange.location,
        length = 0,
        dirtyRange = nil;

    do {
        var tempAttributesIndex = [_temporaryAttributes indexOfObject: location sortedByFunction:_sortRange context:nil];

        if (tempAttributesIndex != CPNotFound)
        {
            var tempAttributes = _temporaryAttributes[tempAttributesIndex];

            if (CPRangeInRange(charRange, tempAttributes._range))
            {
                [self performSelector:attributesOperation withObject:attributes withObject:tempAttributes];
                dirtyRange = (dirtyRange)?CPUnionRange(dirtyRange, tempAttributes._range):CPMakeRangeCopy(tempAttributes._range);
                location += tempAttributes._range.length;
                length += tempAttributes._range.length;
            }
            else if (location == tempAttributes._range.location && CPMaxRange(tempAttributes._range) > CPMaxRange(charRange))
            {
                var maxRange = CPMaxRange(charRange),
                    splittedAttribute = [[_CPTemporaryAttributes alloc] initWithRange:CPMakeRange(maxRange, CPMaxRange(tempAttributes._range) - maxRange)
                                     attributes:[tempAttributes._attributes copy]];

                if ([_temporaryAttributes count] == tempAttributesIndex + 1)
                    [_temporaryAttributes addObject:splittedAttribute];
                else
                    [_temporaryAttributes insertObject:splittedAttribute atIndex:tempAttributesIndex + 1];

                tempAttributes._range = CPMakeRange(tempAttributes._range.location, maxRange - tempAttributes._range.location);
                [self performSelector:attributesOperation withObject:attributes withObject:tempAttributes];

                location += tempAttributes._range.length;
                length += tempAttributes._range.length;

                dirtyRange = (dirtyRange)?CPUnionRange(dirtyRange, tempAttributes._range):CPMakeRangeCopy(tempAttributes._range);
                dirtyRange = CPUnionRange(dirtyRange, splittedAttribute._range);
            }
            else
            {
                var splittedAttribute = [[_CPTemporaryAttributes alloc] initWithRange:CPMakeRange(location, CPMaxRange(tempAttributes._range) - location)
                                         attributes:[tempAttributes._attributes copy]];

                if ([_temporaryAttributes count] == tempAttributesIndex + 1)
                    [_temporaryAttributes addObject:splittedAttribute];
                else
                    [_temporaryAttributes insertObject:splittedAttribute atIndex:tempAttributesIndex + 1];

                tempAttributes._range = CPMakeRange(tempAttributes._range.location, location - tempAttributes._range.location);
                dirtyRange = (dirtyRange)?CPUnionRange(dirtyRange, tempAttributes._range):CPMakeRangeCopy(tempAttributes._range);
                dirtyRange = CPUnionRange(dirtyRange, splittedAttribute._range);

                if (splittedAttribute._range.length <= charRange.length)
                {
                    location += splittedAttribute._range.length;
                    length += splittedAttribute._range.length;
                }
                else
                {
                    var nextLocation = location + charRange.length,
                        nextAttribute = [[_CPTemporaryAttributes alloc] initWithRange:CPMakeRange(nextLocation, CPMaxRange(splittedAttribute._range) - nextLocation)
                                         attributes:[tempAttributes._attributes copy]];

                    splittedAttribute._range = CPMakeRange(splittedAttribute._range.location, nextLocation - splittedAttribute._range.location);

                    var insertIndex = [_temporaryAttributes indexOfObject:splittedAttribute];

                    if ([_temporaryAttributes count] == insertIndex + 1)
                        [_temporaryAttributes addObject:nextAttribute];
                    else
                        [_temporaryAttributes insertObject:nextAttribute atIndex:insertIndex + 1];

                    length = charRange.length;
                }
                [self performSelector:attributesOperation withObject:attributes withObject:splittedAttribute];
            }
        }
        else
        {
            [_temporaryAttributes addObject:[[_CPTemporaryAttributes alloc] initWithRange:charRange attributes:attributes]];
            dirtyRange = CPMakeRangeCopy(charRange);
            break;
        }
    } while (length != charRange.length);

    if (dirtyRange)
        [self invalidateDisplayForGlyphRange:dirtyRange];
}

- (void)setTemporaryAttributes:(CPDictionary)attributes forCharacterRange:(CPRange)charRange
{
    [self _handleTemporaryAttributes:attributes forCharacterRange:charRange withSelector:@selector(_setAttributes:toTemporaryAttributes:)];
}

- (void)addTemporaryAttributes:(CPDictionary)attributes forCharacterRange:(CPRange)charRange
{
    [self _handleTemporaryAttributes:attributes forCharacterRange:charRange withSelector:@selector(_addAttributes:toTemporaryAttributes:)];
}

- (void)removeTemporaryAttribute:(CPString)attributeName forCharacterRange:(CPRange)charRange
{
    if (!_temporaryAttributes)
        return;

    var location = charRange.location,
        length = 0,
        dirtyRange = nil;
    do {
        var tempAttributesIndex = [_temporaryAttributes indexOfObject: location sortedByFunction:_sortRange context:nil];

        if (tempAttributesIndex != CPNotFound)
        {
            var tempAttributes = _temporaryAttributes[tempAttributesIndex];

            if (CPRangeInRange(charRange, tempAttributes._range))
            {
                location += tempAttributes._range.length;
                length += tempAttributes._range.length;
                dirtyRange = (dirtyRange)?CPUnionRange(dirtyRange, tempAttributes._range):CPMakeRangeCopy(tempAttributes._range);

                [tempAttributes._attributes removeObjectForKey:attributeName];

                if ([[tempAttributes._attributes allKeys] count] == 0)
                    [_temporaryAttributes removeObjectAtIndex:tempAttributesIndex];
            }
            else if (location == tempAttributes._range.location && CPMaxRange(tempAttributes._range) > CPMaxRange(charRange))
            {
                var maxRange = CPMaxRange(charRange),
                    splittedAttribute = [[_CPTemporaryAttributes alloc] initWithRange:CPMakeRange(maxRange, CPMaxRange(tempAttributes._range) - maxRange)
                                     attributes:[tempAttributes._attributes copy]];

                if ([_temporaryAttributes count] == tempAttributesIndex + 1)
                    [_temporaryAttributes addObject:splittedAttribute];
                else
                    [_temporaryAttributes insertObject:splittedAttribute atIndex:tempAttributesIndex + 1];

                tempAttributes._range = CPMakeRange(tempAttributes._range.location, maxRange - tempAttributes._range.location);
                location += tempAttributes._range.length;
                length += tempAttributes._range.length;

                [tempAttributes._attributes removeObjectForKey:attributeName];
                if ([[tempAttributes._attributes allKeys] count] == 0)
                    [_temporaryAttributes removeObjectAtIndex:tempAttributesIndex];

                dirtyRange = (dirtyRange)?CPUnionRange(dirtyRange, tempAttributes._range):CPMakeRangeCopy(tempAttributes._range);
                dirtyRange = CPUnionRange(dirtyRange, splittedAttribute._range);
            }
            else
            {
                var splittedAttribute = [[_CPTemporaryAttributes alloc] initWithRange:CPMakeRange(location, CPMaxRange(tempAttributes._range) - location)
                                         attributes:[tempAttributes._attributes copy]];

                if ([_temporaryAttributes count] == tempAttributesIndex + 1)
                    [_temporaryAttributes addObject:splittedAttribute];
                else
                    [_temporaryAttributes insertObject:splittedAttribute atIndex:tempAttributesIndex + 1];

                tempAttributes._range = CPMakeRange(tempAttributes._range.location, location - tempAttributes._range.location);

                dirtyRange = (dirtyRange)?CPUnionRange(dirtyRange, tempAttributes._range):CPMakeRangeCopy(tempAttributes._range);
                dirtyRange = CPUnionRange(dirtyRange, splittedAttribute._range);

                if (splittedAttribute._range.length < charRange.length)
                {
                    location += splittedAttribute._range.length;
                    length += splittedAttribute._range.length;
                }
                else
                {
                    var nextLocation = location + charRange.length,
                        nextAttribute = [[_CPTemporaryAttributes alloc] initWithRange:CPMakeRange(nextLocation, CPMaxRange(splittedAttribute._range) - nextLocation)
                                         attributes:[tempAttributes._attributes copy]];

                    splittedAttribute._range = CPMakeRange(splittedAttribute._range.location, nextLocation - splittedAttribute._range.location);
                    var insertIndex = [_temporaryAttributes indexOfObject:splittedAttribute];

                    if ([_temporaryAttributes count] == insertIndex + 1)
                        [_temporaryAttributes addObject:nextAttribute];
                    else
                        [_temporaryAttributes insertObject:nextAttribute atIndex:insertIndex + 1];

                    length = charRange.length;
                }

                [splittedAttribute._attributes removeObjectForKey:attributeName];
                if ([[splittedAttribute._attributes allKeys] count] == 0)
                    [_temporaryAttributes removeObject:splittedAttribute];
            }
        }
        else
            break;
    } while (length != charRange.length);

    if (dirtyRange)
        [self invalidateDisplayForGlyphRange:dirtyRange];

}

- (CPDictionary)temporaryAttributesAtCharacterIndex:(unsigned)index effectiveRange:(CPRangePointer)effectiveRange
{
    var tempAttribute = _objectWithLocationInRange(_runs, index);  // <!> _runs is wild guess

    if (!tempAttribute)
        return nil;

    if (effectiveRange)
    {
        effectiveRange.location = tempAttribute._range.location;
        effectiveRange.length = tempAttribute._range.length;
    }

    return tempAttribute._attributes;
}

- (void)textContainerChangedTextView:(CPTextContainer)aContainer
{
    /* FIXME: stub */
}

- (CPTypesetter)typesetter
{
    return _typesetter;
}

- (void)setTypesetter:(CPTypesetter)aTypesetter
{
    _typesetter = aTypesetter;
}

- (void)setTextContainer:(CPTextContainer)aTextContainer forGlyphRange:(CPRange)glyphRange
{
    var fragments = _objectsInRange(_lineFragments, glyphRange),
        l = fragments.length;

    for (var i = 0; i < l; i++)
    {
        [fragments[i] invalidate];
    }

    var lineFragment = [[_lineFragmentFactory alloc] initWithRange:glyphRange textContainer:aTextContainer textStorage:_textStorage];
    _lineFragments.push(lineFragment);
}

- (void)setLineFragmentRect:(CPRect)fragmentRect forGlyphRange:(CPRange)glyphRange usedRect:(CPRect)usedRect
{
    var lineFragment = _objectWithLocationInRange(_lineFragments, glyphRange.location);

    if (lineFragment)
    {
        lineFragment._fragmentRect = CPRectCreateCopy(fragmentRect);
        lineFragment._usedRect = CPRectCreateCopy(usedRect);
    }
}

- (void) _setAdvancements:(CPArray)someAdvancements forGlyphRange:(CPRange)glyphRange
{
    var lineFragment = _objectWithLocationInRange(_lineFragments, glyphRange.location);

    if (lineFragment)
        [lineFragment setAdvancements: someAdvancements];
}

- (void)setLocation:(CPPoint)aPoint forStartOfGlyphRange:(CPRange)glyphRange
{
    var lineFragment = _objectWithLocationInRange(_lineFragments, glyphRange.location);
    if (lineFragment)
        lineFragment._location = CPPointCreateCopy(aPoint);
}

- (CPRect)extraLineFragmentRect
{
    if (_extraLineFragment)
        return CPRectCreateCopy(_extraLineFragment._fragmentRect);

    return CGRectMakeZero();
}

- (CPTextContainer)extraLineFragmentTextContainer
{
    if (_extraLineFragment)
        return _extraLineFragment._textContainer;

    return nil;
}

- (CPRect)extraLineFragmentUsedRect
{
    if (_extraLineFragment)
        return CPRectCreateCopy(_extraLineFragment._usedRect);

    return CGRectMakeZero();
}

- (void)setExtraLineFragmentRect:(CPRect)rect usedRect:(CPRect)usedRect textContainer:(CPTextContainer)textContainer
{
    if (textContainer)
    {
        _extraLineFragment = {};
        _extraLineFragment._fragmentRect = CPRectCreateCopy(rect);
        _extraLineFragment._usedRect = CPRectCreateCopy(usedRect);
        _extraLineFragment._textContainer = textContainer;
    }
    else
        _extraLineFragment = nil;
}

/*!
    NOTE: will not validate glyphs and layout
*/
- (CPRect)usedRectForTextContainer:(CPTextContainer)textContainer
{
    var rect = nil;

    for (var i = 0; i < _lineFragments.length; i++)
    {
        if (_lineFragments[i]._textContainer === textContainer)
        {
            if (rect)
                rect = CPRectUnion(rect, _lineFragments[i]._usedRect);
            else
                rect = CPRectCreateCopy(_lineFragments[i]._usedRect);
        }
    }

    return (rect)?rect:CGRectMakeZero();
}

- (CPRect)lineFragmentRectForGlyphAtIndex:(unsigned)glyphIndex effectiveRange:(CPRangePointer)effectiveGlyphRange
{
    var lineFragment = _objectWithLocationInRange(_lineFragments, glyphIndex);

    if (!lineFragment)
        return CGRectMakeZero();

    if (effectiveGlyphRange)
    {
        effectiveGlyphRange.location = lineFragment._range.location;
        effectiveGlyphRange.length = lineFragment._range.length;
    }

    return CPRectCreateCopy(lineFragment._fragmentRect);
}

- (CPRect)lineFragmentUsedRectForGlyphAtIndex:(unsigned)glyphIndex effectiveRange:(CPRangePointer)effectiveGlyphRange
{
    var lineFragment = _objectWithLocationInRange(_lineFragments, glyphIndex);

    if (!lineFragment)
        return CGRectMakeZero();

    if (effectiveGlyphRange)
    {
        effectiveGlyphRange.location = lineFragment._range.location;
        effectiveGlyphRange.length = lineFragment._range.length;
    }

    return CPRectCreateCopy(lineFragment._usedRect);
}

- (CPPoint)locationForGlyphAtIndex:(unsigned)index
{
    if (_lineFragments.length > 0 && index >= [self numberOfGlyphs] - 1)
    {
        var lineFragment= _lineFragments[_lineFragments.length-1],
            glyphFrames = [lineFragment glyphFrames];

        if (glyphFrames.length > 0)
            return CPPointCreateCopy(glyphFrames[glyphFrames.length - 1].origin);
    }

    var lineFragment = _objectWithLocationInRange(_lineFragments, index);

    if (lineFragment)
    {
        if (index == lineFragment._range.location)
            return CPPointCreateCopy(lineFragment._location);

        var glyphFrames = [lineFragment glyphFrames];

        return CPPointCreateCopy(glyphFrames[index - lineFragment._range.location].origin);
    }

    return CPPointMakeZero();
}

- (CPTextContainer)textContainerForGlyphAtIndex:(unsigned)index effectiveRange:(CPRangePointer)effectiveGlyphRange withoutAdditionalLayout:(BOOL)flag
{
/*    if (!flag)
        [self _validateLayoutAndGlyphs];
*/

    var lineFragment = _objectWithLocationInRange(_lineFragments, index);

    if (lineFragment)
    {
        if (effectiveGlyphRange)
        {
            effectiveGlyphRange.location = lineFragment._range.location;
            effectiveGlyphRange.length = lineFragment._range.length;
        }

        return lineFragment._textContainer;
    }

    return nil;
}

- (CPTextContainer)textContainerForGlyphAtIndex:(unsigned)index effectiveRange:(CPRangePointer)effectiveGlyphRange
{
    return [self textContainerForGlyphAtIndex:index effectiveRange:effectiveGlyphRange withoutAdditionalLayout:NO];
}

- (CPRange)characterRangeForGlyphRange:(CPRange)aRange actualGlyphRange:(CPRangePointer)actualRange
{
    /* FIXME: stub */
    return aRange;
}

- (unsigned)characterIndexForGlyphAtIndex:(unsigned)index
{
    /* FIXME: stub */
    return index;
}

- (void)setLineFragmentFactory:(Class)lineFragmentFactory
{
    _lineFragmentFactory = lineFragmentFactory;
}

- (CPArray)rectArrayForCharacterRange:(CPRange)charRange
         withinSelectedCharacterRange:(CPRange)selectedCharRange
                      inTextContainer:(CPTextContainer)container
                            rectCount:(CPRectPointer)rectCount
{

    var rectArray = [],
        lineFragments = _objectsInRange(_lineFragments, selectedCharRange);

    if (!lineFragments.length)
        return rectArray;

    var containerSize = [container containerSize];

    for (var i = 0; i < lineFragments.length; i++)
    {
        var fragment = lineFragments[i];
        if (fragment._textContainer === container)
        {
            var frames = [fragment glyphFrames],
                rect = nil;

            for (var j = 0; j < frames.length; j++)
            {
                if (CPLocationInRange(fragment._range.location + j, selectedCharRange))
                {
                    if (!rect)
                        rect = CPRectCreateCopy(frames[j]);
                    else
                        rect = CPRectUnion(rect, frames[j]);

                    if (CPRectGetMaxX(frames[j]) >=  CPRectGetMaxX(fragment._fragmentRect) &&
                        CPMaxRange(selectedCharRange) > CPMaxRange(fragment._range) ||
                        [[_textStorage string] characterAtIndex:MAX(0, CPMaxRange(selectedCharRange)-1)] === '\n' )
                    {
                         rect.size.width = containerSize.width - rect.origin.x;
                    }
                }
            }

            if (rect)
                rectArray.push(rect);
        }
    }

    return rectArray;
}
@end
