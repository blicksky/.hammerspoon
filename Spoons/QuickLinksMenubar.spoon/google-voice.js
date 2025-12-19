const CODE_PATTERN = /\bcode\s+(\d+)/gi;
const MARKER_ATTR = "data-code-highlighted";

function highlightCodesInText(textNode) {
  const text = textNode.textContent;
  if (!CODE_PATTERN.test(text)) {
    return;
  }
  CODE_PATTERN.lastIndex = 0;

  const fragment = document.createDocumentFragment();
  let lastIndex = 0;
  let match;

  while ((match = CODE_PATTERN.exec(text)) !== null) {
    const numbersStart = match.index + match[0].indexOf(match[1]);

    if (numbersStart > lastIndex) {
      fragment.appendChild(
        document.createTextNode(text.slice(lastIndex, numbersStart))
      );
    }

    const span = document.createElement("span");
    span.setAttribute(MARKER_ATTR, "true");
    span.style.display = "inline-block";
    span.style.border = "2px dotted #f59e0b";
    span.style.borderRadius = "4px";
    span.style.padding = "1px 4px";
    span.style.backgroundColor = "#fef3c7";
    span.style.cursor = "pointer";
    span.textContent = match[1];
    const code = match[1];
    span.addEventListener(
      "click",
      (e) => {
        e.stopPropagation();
        e.stopImmediatePropagation();
        e.preventDefault();
        navigator.clipboard.writeText(code);
      },
      true
    );
    fragment.appendChild(span);

    lastIndex = CODE_PATTERN.lastIndex;
  }

  if (lastIndex < text.length) {
    fragment.appendChild(document.createTextNode(text.slice(lastIndex)));
  }

  textNode.parentNode.replaceChild(fragment, textNode);
}

function scanForCodes() {
  document
    .querySelectorAll("gv-annotation:not([" + MARKER_ATTR + "])")
    .forEach((el) => {
      if (CODE_PATTERN.test(el.textContent)) {
        CODE_PATTERN.lastIndex = 0;
        el.childNodes.forEach((child) => {
          if (child.nodeType === Node.TEXT_NODE) {
            highlightCodesInText(child);
          }
        });
        el.setAttribute(MARKER_ATTR, "true");
      }
    });
}

function debounce(fn, delay) {
  let timeout;
  return () => {
    clearTimeout(timeout);
    timeout = setTimeout(fn, delay);
  };
}

const debouncedScan = debounce(scanForCodes, 200);

const messagesContainer = document.querySelector("div.messages-container");
if (messagesContainer) {
  new MutationObserver(debouncedScan).observe(messagesContainer, {
    childList: true,
    subtree: true,
    characterData: true,
  });
}

scanForCodes();
