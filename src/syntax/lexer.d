/*
Copyright (c) 2016-2023 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

/**
 * General-purpose non-allocating lexical analyzer.
 *
 * Description:
 * Breaks the input string to a stream of lexemes according to a given delimiter dictionary.
 * Delimiters are symbols that separate sequences of characters (e.g. operators).
 * Lexemes are slices of the input string.
 * Assumes UTF-8 input.
 * Treats \r\n as a single \n.
 *
 * Copyright: Timur Gafarov 2016-2023.
 * License: $(LINK2 boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: Timur Gafarov, Eugene Wissner, Roman Chistokhodov, ijet
 */
module syntax.lexer;

import std.ascii;

struct Token
{
    dstring lexeme;
    size_t startPos;
    size_t endPos;
}

/**
 * Lexical analyzer class
 */
class Lexer
{
    protected:
    dstring input;
    string[] delims;

    uint index;
    uint nextIndex;
    dchar current;

    public:

    this(dstring input, string[] delims)
    {
        this.input = input;
        this.delims = delims;
        this.index = 0;
        this.nextIndex = 0;
    }
    
    void reset(dstring input)
    {
        this.input = input;
        this.index = 0;
        this.nextIndex = 0;
        this.current = dchar.init;
    }
    
    uint position() @property
    {
        return index;
    }

    Token getToken()
    {
        Token res = Token(""d, 0, 0);
        int tStart = -1;
        while(nextIndex < input.length)
        {
            advance();
            dchar c = current;
            
            if (isNewline(c))
            {
                if (tStart > -1)
                {
                    res = Token(input[tStart..index], tStart, index);
                    tStart = -1;
                    break;
                }
                else
                {
                    if (c == '\r')
                    {
                        advance();
                    }
                }
            }
            else if (isWhitespace(c))
            {
                if (tStart > -1)
                {
                    res = Token(input[tStart..index], tStart, index);
                    tStart = -1;
                    break;
                }
            }
            else
            {
                size_t bestLen = 0;
                dstring bestStr = ""d;
                foreach(d; delims)
                {
                    if (forwardCompare(d))
                    {
                        if (d.length > bestLen)
                        {
                            bestLen = d.length;
                            bestStr = input[index..index+d.length];
                        }
                    }
                }
                
                if (bestStr.length)
                {
                    if (tStart > -1)
                    {
                        res = Token(input[tStart..index], tStart, index);
                        tStart = -1;
                        ret();
                        break;
                    }
                    else
                    {
                        res = Token(bestStr, index, index + bestStr.length);
                        forwardJump(bestStr.length);
                        ret();
                        break;
                    }
                }
                else
                {
                    if (tStart == -1)
                    {
                        tStart = index;
                    }
                }
            }
        }
        
        if (nextIndex == input.length)
        {
            if (tStart > -1)
            {
                res = Token(input[tStart..nextIndex], tStart, nextIndex);
                tStart = -1;
            }
        }

        return res;
    }

    protected:

    void advance()
    {
        index = nextIndex;
        current = input[nextIndex];
        nextIndex++;
    }
    
    void ret()
    {
        nextIndex = index;
    }

    void forwardJump(size_t numChars)
    {
        for(size_t i = 0; i < numChars; i++)
        {
            advance();
        }
    }

    bool forwardCompare(string str)
    {
        bool res = true;
        
        for(size_t i = 0; i < str.length; i++)
        {
            if (index + i < input.length)
            {
                int c1 = input[index + i];
                int c2 = str[i];
                if (c1 != c2)
                {
                    res = false;
                    break;
                }
            }
            else {
                res = false;
                break;
            }
        }
        
        return res;
    }

    bool isWhitespace(dchar c)
    {
        foreach(w; std.ascii.whitespace)
        {
            if (c == w)
            {
                return true;
            }
        }
        return false;
    }

    bool isNewline(dchar c)
    {
        return (c == '\n' || c == '\r');
    }

    dstring consumeDelimiter()
    {
        size_t bestLen = 0;
        dstring bestStr = ""d;
        foreach(d; delims)
        {
            if (forwardCompare(d))
            {
                if (d.length > bestLen)
                {
                    bestLen = d.length;
                    bestStr = input[index..index+d.length];
                }
            }
        }
        return bestStr;
    }
}
