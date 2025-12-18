const CODE_PATTERN = /\bcode\s+(\d+)/gi;
const MARKER_ATTR = "data-code-highlighted";

function highlightCodes(node) {
  if (node.nodeType === Node.TEXT_NODE) {
    if (node.parentNode && node.parentNode.hasAttribute && node.parentNode.hasAttribute(MARKER_ATTR)) {
      return;
    }

    const text = node.textContent;
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

    node.parentNode.replaceChild(fragment, node);
  } else if (
    node.nodeType === Node.ELEMENT_NODE &&
    node.tagName !== "SCRIPT" &&
    node.tagName !== "STYLE" &&
    !node.hasAttribute(MARKER_ATTR)
  ) {
    Array.from(node.childNodes).forEach(highlightCodes);
  }
}

function processPage() {
  highlightCodes(document.body);
}

processPage();

const observer = new MutationObserver((mutations) => {
  mutations.forEach((mutation) => {
    mutation.addedNodes.forEach((node) => {
      if (
        node.nodeType === Node.ELEMENT_NODE ||
        node.nodeType === Node.TEXT_NODE
      ) {
        highlightCodes(node);
      }
    });
  });
});

observer.observe(document.body, {
  childList: true,
  subtree: true,
});
