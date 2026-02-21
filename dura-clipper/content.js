// DURA Clipper — Content Script
// Injected alongside lib/readability.js on all pages.

(function () {
  "use strict";

  // Listen for messages from popup or background
  chrome.runtime.onMessage.addListener((request, _sender, sendResponse) => {
    if (request.action === "extract") {
      const result = extractPage(request.mode || "full");
      sendResponse(result);
    } else if (request.action === "checkSelection") {
      sendResponse({ hasSelection: !!window.getSelection().toString().trim() });
    }
    return true; // keep channel open for async
  });

  function extractPage(mode) {
    const meta = extractMetadata();

    if (mode === "bookmark") {
      return {
        success: true,
        mode: "bookmark",
        title: meta.title,
        url: meta.url,
        author: meta.author,
        excerpt: meta.excerpt,
        featuredImage: meta.featuredImage,
        bodyHTML: "",
      };
    }

    if (mode === "selection") {
      const sel = window.getSelection();
      if (!sel || !sel.toString().trim()) {
        return { success: false, error: "No text selected." };
      }
      const range = sel.getRangeAt(0);
      const container = document.createElement("div");
      container.appendChild(range.cloneContents());
      return {
        success: true,
        mode: "selection",
        title: meta.title,
        url: meta.url,
        author: meta.author,
        excerpt: meta.excerpt,
        featuredImage: meta.featuredImage,
        bodyHTML: container.innerHTML,
      };
    }

    // Full article (default)
    let bodyHTML = "";
    let readabilityFailed = false;

    try {
      const docClone = document.cloneNode(true);
      const reader = new Readability(docClone);
      const article = reader.parse();
      if (article && article.content) {
        bodyHTML = article.content;
        // Override with Readability's extracted metadata if available
        if (article.title) meta.title = article.title;
        if (article.byline) meta.author = article.byline;
        if (article.excerpt) meta.excerpt = article.excerpt;
      } else {
        bodyHTML = document.body.innerHTML;
        readabilityFailed = true;
      }
    } catch (e) {
      bodyHTML = document.body.innerHTML;
      readabilityFailed = true;
    }

    return {
      success: true,
      mode: "full",
      title: meta.title,
      url: meta.url,
      author: meta.author,
      excerpt: meta.excerpt,
      featuredImage: meta.featuredImage,
      bodyHTML: bodyHTML,
      readabilityFailed: readabilityFailed,
    };
  }

  function extractMetadata() {
    const title =
      getMetaContent("og:title") ||
      getMetaContent("twitter:title") ||
      document.title ||
      "";

    const url =
      document.querySelector('link[rel="canonical"]')?.href ||
      window.location.href;

    const author =
      getMetaContent("author") ||
      getMetaContent("article:author") ||
      getMetaContent("twitter:creator") ||
      "";

    const excerpt =
      getMetaContent("og:description") ||
      getMetaContent("description") ||
      getMetaContent("twitter:description") ||
      "";

    const featuredImage =
      getMetaContent("og:image") ||
      getMetaContent("twitter:image") ||
      "";

    return { title, url, author, excerpt, featuredImage };
  }

  function getMetaContent(nameOrProperty) {
    const el =
      document.querySelector(`meta[property="${nameOrProperty}"]`) ||
      document.querySelector(`meta[name="${nameOrProperty}"]`);
    return el ? el.getAttribute("content") || "" : "";
  }
})();
