(function() {
    if (window._hammerspoonLinkHandlerInjected) return;
    window._hammerspoonLinkHandlerInjected = true;

    function shouldOpenInSelf(url) {
        if (!url) return false;
        
        var currentHost = window.location.hostname;
        var urlHost = '';
        var urlPath = '';
        try {
            var parsedUrl = new URL(url);
            urlHost = parsedUrl.hostname.toLowerCase();
            urlPath = parsedUrl.pathname.toLowerCase();
        } catch (e) {}

        // 1. Same-site navigation stays in the popup
        if (urlHost && currentHost && urlHost === currentHost) {
            return true;
        }

        // 2. Strict Google accounts login domain matching
        // Enforces exact match for accounts.google.com and standard accounts.google.co.* TLD variations
        var isGoogleAuthHost = urlHost === 'accounts.google.com' || 
                               /^accounts\.google\.[a-z]{2,3}(\.[a-z]{2})?$/.test(urlHost);
        
        // Match google.com/accounts/... and www.google.com/accounts/...
        var isGoogleSubpathAuth = (urlHost === 'google.com' || urlHost === 'www.google.com') && 
                                  urlPath.startsWith('/accounts');

        // Match if we are already currently on a Google login page
        var isOnGoogleAuthHost = currentHost && (currentHost === 'accounts.google.com' || 
                                 /^accounts\.google\.[a-z]{2,3}(\.[a-z]{2})?$/.test(currentHost));

        return isGoogleAuthHost || isGoogleSubpathAuth || isOnGoogleAuthHost;
    }

    var originalWindowOpen = window.open;
    window.open = function(url, name, specs) {
        if (!url) return originalWindowOpen ? originalWindowOpen(url, name, specs) : null;
        
        var absoluteUrl;
        try {
            absoluteUrl = new URL(url, window.location.href).href;
        } catch (e) {
            absoluteUrl = url;
        }

        if (absoluteUrl && (absoluteUrl.startsWith('http:') || absoluteUrl.startsWith('https:'))) {
            if (shouldOpenInSelf(absoluteUrl)) {
                window.location.href = absoluteUrl;
                return null;
            }
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.QuickLinksOpenURL) {
                window.webkit.messageHandlers.QuickLinksOpenURL.postMessage(absoluteUrl);
                return null;
            }
        }
        return originalWindowOpen ? originalWindowOpen(url, name, specs) : null;
    };

    document.addEventListener('click', function(e) {
        var anchor = e.target.closest('a');
        if (anchor) {
            var href = anchor.href;
            if (href && (href.startsWith('http:') || href.startsWith('https:'))) {
                if (anchor.target === '_blank') {
                    if (shouldOpenInSelf(href)) {
                        anchor.target = '_self';
                    } else {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.QuickLinksOpenURL) {
                            e.preventDefault();
                            window.webkit.messageHandlers.QuickLinksOpenURL.postMessage(href);
                        }
                    }
                }
            }
        }
    }, true);
})();
