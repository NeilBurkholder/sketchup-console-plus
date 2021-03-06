define(['ace/ace'], function (ace) {

    var TokenIterator = ace.require('ace/token_iterator').TokenIterator;

    var space = /^\s+$/,
        comma = /^,\s*$/,
        semicolon = /^;\s*$/,
        assignment = /^=$/,
        endOfLineComment = /^#/,
        isString = /^\"(?:\\"|[^"])*\"$|^\'(?:\\'|[^'])*\'$/,
        bracketOpen = /^[\(\[\{]$/,
        bracketClose = /^[\)\]\}]$/,
        bracketMatching = {'(': ')', ')': '(',  '[': ']', ']': '[', '{': '}', '}': '{'},
        indexAccessor = /^[\[\]]$/;

    /**
     * Get the current token from token iterator and correct it if necessary.
     * Ace's Ruby tokenizer incorrectly splits some tokens, for example methods ending with question marks or exclamation marks. 
     */
    function getCorrectedCurrentToken (tokenIterator) {
        // Check the next token to make sure we have the complete current token.
        // Detecting setter methods however is ambiguous to distinguish from local variable assignments.
        var currentToken = tokenIterator.getCurrentToken(); // An object {type: string, value: string, index: number, start: number}
        if (currentToken == null) return null;
        var tokenString = currentToken.value;
        var nextToken = tokenIterator.stepForward();
        if (nextToken != null) {
            switch (nextToken.value) {
                case '?':  tokenString += '?'; break;
                case '?.': tokenString += '?'; break;
                case '!':  tokenString += '!'; break;
                case '!.': tokenString += '!'; break;
                default: break; // null or non-matching
            }
        }
        tokenIterator.stepBackward(); // again the old currentToken
        return tokenString;
    }

    /**
     * Get a list of continuous tokens preceding the given position in the editor.
     * The token list includes – if possible – all tokens needed for a valid object/class/module or chained methods.
     * @returns {Array<string>} - An array of string.
     */
    function getCurrentTokens (aceEditor) {
        var position = aceEditor.getCursorPosition();
        var tokenIterator = new TokenIterator(aceEditor.getSession(), position.row, position.column);
        var tokens = [];
        var bracketStack = [];
        var token = getCorrectedCurrentToken(tokenIterator);
        if (token == null) return tokens;
        // Abort if the token is not autocompletable.
        if (endOfLineComment.test(token) || isString.test(token)) {
            return tokens;
        }
        tokens.unshift(token);
        if (bracketClose.test(token)) {
            bracketStack.push(token);
        }
        // Walk from the caret position backwards and collect tokens. Skip everything within brackets.
        var currentToken; // An object {type: string, value: string, index: number, start: number}
        while (true) {
            currentToken = tokenIterator.stepBackward();
            if (currentToken == null) break;
            var token = currentToken.value;
            // TODO: How to handle line breaks? If there is not a dot or double colon before or after, we should break.
            // Since we walk backwards, closing brackets are added to the stack.
            if (bracketClose.test(token)) {
                bracketStack.push(token);
                // And opening brackets that match the top stack element, remove it from the stack.
            } else if (bracketOpen.test(token)) {
                var last = bracketStack[bracketStack.length - 1];
                if (last == bracketMatching[token]) {
                    bracketStack.pop();
                    if (indexAccessor.test(token) && bracketStack.length == 0) {
                        if (tokens[0] == ']') {
                            if (tokens[1] == '=') {
                                tokens.shift();
                                tokens[0] = '[]=';
                            } else {
                                tokens[0] = '[]';
                            }
                        }
                    }
                } else {
                    break;
                }
            } else if (space.test(token) || 
                       comma.test(token) || 
                       semicolon.test(token) ||
                       assignment.test(token) ||
                       endOfLineComment.test(token)) {
                break;
            } else if (bracketStack.length == 0) {
                // TODO: add [] methods? Does it handle []=, \w= ?
                switch (tokens[0]) {
                    case '?.':
                        tokens[0] = '.';
                        tokens.unshift(token + '?');
                        break;
                    case '?':
                        tokens[0] = token + '?';
                        break;
                    case '!.':
                        tokens[0] = '.';
                        tokens.unshift(token + '!');
                        break;
                    case '!':
                        tokens[0] = token + '!';
                        break;
                    case '=':
                        tokens[0] = token + '=';
                        break;
                    default:
                        // Words outside of brackets. We want to collect those.
                        tokens.unshift(token);
                }
            }
        }
        return tokens;
    }

    return getCurrentTokens;
});
