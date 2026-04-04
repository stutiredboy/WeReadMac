(function() {
    'use strict';

    if (window.__wereadNotesInterceptorInstalled) return;
    window.__wereadNotesInterceptorInstalled = true;

    var WEREAD_DOMAINS = ['i.weread.qq.com', 'weread.qq.com'];

    function isWeReadURL(url) {
        // Handle relative URLs — if the page is weread.qq.com, relative URLs are WeRead requests
        if (!url || url.length === 0) return false;
        if (url.startsWith('/')) return true;
        try {
            var parsed = new URL(url);
            return WEREAD_DOMAINS.some(function(d) { return parsed.hostname === d || parsed.hostname.endsWith('.' + d); });
        } catch (e) {
            // If URL parsing fails, it's likely a relative URL
            return true;
        }
    }

    function classifyMessage(url, method, body) {
        var lowerUrl = url.toLowerCase();

        // Highlight/bookmark related
        if (lowerUrl.indexOf('bookmark') !== -1 || lowerUrl.indexOf('markbook') !== -1) {
            if (method === 'DELETE' || lowerUrl.indexOf('delete') !== -1 || lowerUrl.indexOf('remove') !== -1) {
                return 'deleteHighlight';
            }
            return 'highlight';
        }

        // Thought/review related
        if (lowerUrl.indexOf('review') !== -1 || lowerUrl.indexOf('thought') !== -1) {
            if (method === 'DELETE' || lowerUrl.indexOf('delete') !== -1 || lowerUrl.indexOf('remove') !== -1) {
                return 'deleteThought';
            }
            if (lowerUrl.indexOf('update') !== -1) {
                return 'updateThought';
            }
            return 'thought';
        }

        // Also check body for bookmarkId or markText to catch highlights sent to generic endpoints
        if (body && typeof body === 'object') {
            if (body.bookmarkId && !body.markText) {
                return 'deleteHighlight';
            }
            if (body.markText || body.bookmarkId) {
                if (method === 'DELETE' || lowerUrl.indexOf('delete') !== -1 || lowerUrl.indexOf('remove') !== -1) return 'deleteHighlight';
                return 'highlight';
            }
            if (body.reviewId && body.content) {
                return 'thought';
            }
        }

        return null;
    }

    function sendToNative(type, url, method, body) {
        try {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.notesCapture) {
                window.webkit.messageHandlers.notesCapture.postMessage({
                    type: type,
                    url: url,
                    method: method,
                    timestamp: Date.now(),
                    body: body
                });
                console.log('[WeReadMac] Captured ' + type + ': ' + url);
            }
        } catch (e) {
            // Silently ignore errors to avoid disrupting the reading experience
        }
    }

    function tryParseJSON(str) {
        if (!str) return null;
        if (typeof str === 'object') return str;
        try { return JSON.parse(str); } catch (e) { return null; }
    }

    function tryDecodeBase64(str) {
        if (!str || typeof str !== 'string') return str;
        // Check if the string looks like base64 (only contains base64 chars and is long enough)
        if (!/^[A-Za-z0-9+/]+=*$/.test(str) || str.length < 8) return str;
        try {
            var decoded = decodeURIComponent(escape(atob(str)));
            // If decoded result contains mostly printable characters, it's likely valid
            if (decoded && decoded.length > 0) return decoded;
        } catch (e) {
            // Not valid base64 or not valid UTF-8, return original
        }
        return str;
    }

    function decodePayloadFields(body) {
        if (!body || typeof body !== 'object') return body;
        var decoded = {};
        var base64Fields = ['markText', 'content', 'abstract', 'chapterTitle', 'bookTitle', 'bookAuthor'];
        for (var key in body) {
            if (body.hasOwnProperty(key)) {
                if (base64Fields.indexOf(key) !== -1 && typeof body[key] === 'string') {
                    decoded[key] = tryDecodeBase64(body[key]);
                } else {
                    decoded[key] = body[key];
                }
            }
        }
        return decoded;
    }

    // Caches to avoid repeated API calls
    var bookInfoCache = {};
    var chapterCache = {}; // bookId → { chapterUid → title }

    function fetchBookInfo(bookId) {
        if (!bookId || bookInfoCache[bookId]) return;
        bookInfoCache[bookId] = true;

        var infoUrl = '/web/book/info?bookId=' + encodeURIComponent(bookId);
        origFetch.call(window, infoUrl, { method: 'GET', credentials: 'include' })
            .then(function(resp) { return resp.json(); })
            .then(function(info) {
                if (info && (info.title || info.author || info.cover)) {
                    sendToNative('bookInfo', infoUrl, 'GET', {
                        bookId: bookId,
                        title: info.title || '',
                        author: info.author || '',
                        cover: info.cover || '',
                        publisher: info.publisher || '',
                        isbn: info.isbn || ''
                    });
                    console.log('[WeReadMac] Fetched book info for: ' + bookId + ' → ' + (info.title || ''));
                }
            })
            .catch(function(e) {
                bookInfoCache[bookId] = false;
                console.log('[WeReadMac] Failed to fetch book info for: ' + bookId, e);
            });
    }

    function fetchChapterInfos(bookId) {
        if (!bookId || chapterCache[bookId]) return;
        chapterCache[bookId] = true; // Mark as in-flight

        var chapterUrl = '/web/book/chapterInfos';
        origFetch.call(window, chapterUrl, {
            method: 'POST',
            credentials: 'include',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ bookIds: [bookId], sinces: { }, bookVersions: {} })
        })
            .then(function(resp) { return resp.json(); })
            .then(function(result) {
                if (!result || !result.data || !result.data.length) return;
                var chapters = {};
                var bookData = result.data[0];
                if (bookData && bookData.updated) {
                    bookData.updated.forEach(function(ch) {
                        if (ch.chapterUid && ch.title) {
                            chapters[String(ch.chapterUid)] = ch.title;
                        }
                    });
                }
                chapterCache[bookId] = chapters;
                // Send all chapter mappings to native
                sendToNative('chapterInfos', chapterUrl, 'POST', {
                    bookId: bookId,
                    chapters: chapters
                });
                console.log('[WeReadMac] Fetched ' + Object.keys(chapters).length + ' chapters for: ' + bookId);
            })
            .catch(function(e) {
                chapterCache[bookId] = false;
                console.log('[WeReadMac] Failed to fetch chapter infos for: ' + bookId, e);
            });
    }

    // Track in-flight bookmark list syncs per bookId to skip duplicate requests
    var bookmarkListSyncing = {};

    function processReviewAddResponse(url, responseBody, requestBody) {
        var data = tryParseJSON(responseBody);
        if (!data || !data.reviewId) return;

        // Merge request fields with response reviewId for matching on native side
        var reqBody = tryParseJSON(requestBody) || {};
        var merged = {
            reviewId: String(data.reviewId),
            bookId: reqBody.bookId,
            content: reqBody.content,
            abstract: reqBody.abstract,
            chapterUid: reqBody.chapterUid,
            range: reqBody.range
        };
        sendToNative('thoughtReviewId', url, 'POST', decodePayloadFields(merged));
        console.log('[WeReadMac] Captured reviewId from /web/review/add: ' + data.reviewId);
    }

    function processResponse(url, responseBody) {
        if (!url || url.toLowerCase().indexOf('bookmarklist') === -1) return;
        var data = tryParseJSON(responseBody);
        if (!data || !data.updated) return;

        // Extract bookId from URL or first entry
        var bookId = null;
        try {
            var match = url.match(/bookId=([^&]+)/);
            if (match) bookId = decodeURIComponent(match[1]);
        } catch (e) {}
        if (!bookId && data.updated.length > 0) bookId = data.updated[0].bookId;

        // Skip if a sync is already in progress for this bookId
        if (bookId && bookmarkListSyncing[bookId]) {
            console.log('[WeReadMac] Skipping bookmarkList sync (already in progress): ' + bookId);
            return;
        }

        // Mark as syncing, auto-clear after 10 seconds
        if (bookId) {
            bookmarkListSyncing[bookId] = true;
            setTimeout(function() { delete bookmarkListSyncing[bookId]; }, 10000);
        }

        sendToNative('bookmarkList', url, 'GET', data);
        console.log('[WeReadMac] Captured bookmarkList: ' + url + ' (' + data.updated.length + ' bookmarks)');
        // Trigger book info enrichment for bookmarks
        if (data.updated.length > 0 && data.updated[0].bookId) {
            fetchBookInfo(data.updated[0].bookId);
        }
    }

    function processRequest(url, method, rawBody) {
        if (!isWeReadURL(url)) return;
        method = (method || 'GET').toUpperCase();
        if (method === 'GET') return;

        var body = tryParseJSON(rawBody);
        if (!body) return;

        var type = classifyMessage(url, method, body);
        if (type) {
            sendToNative(type, url, method, decodePayloadFields(body));
            // Fetch book & chapter info for new captures
            if (body.bookId && (type === 'highlight' || type === 'thought')) {
                fetchBookInfo(body.bookId);
                fetchChapterInfos(body.bookId);
            }
        } else {
            // Log unclassified non-GET requests for debugging
            console.log('[WeReadMac] Unclassified ' + method + ' request: ' + url, body);
        }
    }

    // Patch XMLHttpRequest
    var origOpen = XMLHttpRequest.prototype.open;
    var origSend = XMLHttpRequest.prototype.send;

    XMLHttpRequest.prototype.open = function(method, url) {
        this.__wr_method = method;
        this.__wr_url = url;
        return origOpen.apply(this, arguments);
    };

    XMLHttpRequest.prototype.send = function(data) {
        processRequest(this.__wr_url || '', this.__wr_method, data);
        var wrUrl = this.__wr_url || '';
        var lowerUrl = wrUrl.toLowerCase();
        // Intercept response for bookmarklist URLs
        if (lowerUrl.indexOf('bookmarklist') !== -1) {
            this.addEventListener('load', function() {
                processResponse(wrUrl, this.responseText);
            });
        }
        // Intercept response for /web/review/add
        if (lowerUrl.indexOf('/web/review/add') !== -1 || (lowerUrl.indexOf('review') !== -1 && lowerUrl.indexOf('add') !== -1)) {
            var reqData = data;
            this.addEventListener('load', function() {
                processReviewAddResponse(wrUrl, this.responseText, reqData);
            });
        }
        return origSend.apply(this, arguments);
    };

    // Patch fetch — expose original for use by NotesDeleteService
    var origFetch = window.fetch;
    window.__origFetch = origFetch;
    window.fetch = function(input, init) {
        var url = typeof input === 'string' ? input : (input && input.url ? input.url : '');
        var method = (init && init.method) || 'GET';
        var rawBody = init && init.body;
        processRequest(url, method, rawBody);
        var result = origFetch.apply(this, arguments);
        var lowerFetchUrl = url ? url.toLowerCase() : '';
        // Intercept response for bookmarklist URLs
        if (lowerFetchUrl.indexOf('bookmarklist') !== -1) {
            result = result.then(function(response) {
                var cloned = response.clone();
                cloned.json().then(function(data) {
                    processResponse(url, data);
                }).catch(function() {});
                return response;
            });
        }
        // Intercept response for /web/review/add
        if (lowerFetchUrl.indexOf('/web/review/add') !== -1 || (lowerFetchUrl.indexOf('review') !== -1 && lowerFetchUrl.indexOf('add') !== -1)) {
            result = result.then(function(response) {
                var cloned = response.clone();
                cloned.json().then(function(data) {
                    processReviewAddResponse(url, data, rawBody);
                }).catch(function() {});
                return response;
            });
        }
        return result;
    };

    console.log('[WeReadMac] Notes interceptor installed');
})();
