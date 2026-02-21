// DURA Clipper — Popup Script

(async function () {
  "use strict";

  const pageTitleEl = document.getElementById("page-title");
  const pageDomainEl = document.getElementById("page-domain");
  const errorBanner = document.getElementById("error-banner");
  const errorText = document.getElementById("error-text");
  const modeSelection = document.getElementById("mode-selection");
  const notebookSelect = document.getElementById("notebook-select");
  const tagsInput = document.getElementById("tags-input");
  const tagSuggestions = document.getElementById("tag-suggestions");
  const saveBtn = document.getElementById("save-btn");
  const successOverlay = document.getElementById("success-overlay");

  let currentTab = null;

  // Ensure content script is injected, then send a message.
  // If the content script isn't loaded yet, inject it programmatically.
  async function ensureContentScript(tabId) {
    try {
      // Ping the content script to see if it's alive
      await chrome.tabs.sendMessage(tabId, { action: "checkSelection" });
    } catch {
      // Content script not loaded — inject it now
      await chrome.scripting.executeScript({
        target: { tabId: tabId },
        files: ["lib/readability.js", "content.js"],
      });
      // Brief delay for scripts to initialize
      await new Promise((r) => setTimeout(r, 100));
    }
  }

  // Initialize
  try {
    const [tab] = await chrome.tabs.query({
      active: true,
      currentWindow: true,
    });
    currentTab = tab;

    if (!tab || !tab.url || tab.url.startsWith("chrome://") || tab.url.startsWith("chrome-extension://")) {
      showError("Cannot clip this type of page.");
      saveBtn.disabled = true;
      return;
    }

    if (tab.url.endsWith(".pdf")) {
      showError("Download this PDF and import directly into DURA.");
      saveBtn.disabled = true;
      return;
    }

    pageTitleEl.textContent = tab.title || "Untitled";
    pageDomainEl.textContent = extractDomain(tab.url);

    // Inject content script if needed, then check selection
    try {
      await ensureContentScript(tab.id);
      const selResponse = await chrome.tabs.sendMessage(tab.id, {
        action: "checkSelection",
      });
      if (selResponse && selResponse.hasSelection) {
        modeSelection.disabled = false;
      }
    } catch {
      // Still can't reach content script — will try again on save
    }
  } catch (e) {
    showError("Could not access current tab.");
    saveBtn.disabled = true;
    return;
  }

  // Load settings
  const settings = await chrome.storage.sync.get([
    "notebooks",
    "defaultNotebook",
    "defaultClipMode",
    "autoClose",
    "downloadSubfolder",
    "includeFeaturedImage",
    "tagHistory",
  ]);

  const notebooks = settings.notebooks || ["Inbox", "Research", "Reading List"];
  const defaultNotebook = settings.defaultNotebook || "Inbox";
  const defaultMode = settings.defaultClipMode || "full";
  const autoClose = settings.autoClose !== false;
  const subfolder = settings.downloadSubfolder || "DURA-Clips";
  const includeFeaturedImage = settings.includeFeaturedImage || false;
  const tagHistory = settings.tagHistory || [];

  // Populate notebook dropdown
  notebooks.forEach((nb) => {
    const opt = document.createElement("option");
    opt.value = nb;
    opt.textContent = nb;
    if (nb === defaultNotebook) opt.selected = true;
    notebookSelect.appendChild(opt);
  });

  // Set default clip mode
  const defaultRadio = document.querySelector(
    `input[name="mode"][value="${defaultMode}"]`
  );
  if (defaultRadio && !defaultRadio.disabled) {
    defaultRadio.checked = true;
  }

  // Tag autocomplete
  tagsInput.addEventListener("input", () => {
    const value = tagsInput.value;
    const parts = value.split(",");
    const current = parts[parts.length - 1].trim().toLowerCase();

    if (!current || tagHistory.length === 0) {
      tagSuggestions.classList.add("hidden");
      return;
    }

    const matches = tagHistory.filter(
      (t) =>
        t.toLowerCase().startsWith(current) &&
        !parts
          .slice(0, -1)
          .map((p) => p.trim().toLowerCase())
          .includes(t.toLowerCase())
    );

    if (matches.length === 0) {
      tagSuggestions.classList.add("hidden");
      return;
    }

    tagSuggestions.innerHTML = "";
    matches.slice(0, 5).forEach((match) => {
      const div = document.createElement("div");
      div.className = "suggestion";
      div.textContent = match;
      div.addEventListener("click", () => {
        parts[parts.length - 1] = " " + match;
        tagsInput.value = parts.join(",") + ", ";
        tagSuggestions.classList.add("hidden");
        tagsInput.focus();
      });
      tagSuggestions.appendChild(div);
    });
    tagSuggestions.classList.remove("hidden");
  });

  tagsInput.addEventListener("blur", () => {
    setTimeout(() => tagSuggestions.classList.add("hidden"), 150);
  });

  // Save button
  saveBtn.addEventListener("click", async () => {
    saveBtn.disabled = true;
    saveBtn.textContent = "Clipping...";
    hideError();

    const mode = document.querySelector('input[name="mode"]:checked').value;
    const notebook = notebookSelect.value;
    const tags = tagsInput.value
      .split(",")
      .map((t) => t.trim())
      .filter(Boolean);

    try {
      // Ensure content script is injected before extracting
      await ensureContentScript(currentTab.id);

      // Extract page content
      const extracted = await chrome.tabs.sendMessage(currentTab.id, {
        action: "extract",
        mode: mode,
      });

      if (!extracted || !extracted.success) {
        showError(extracted?.error || "Extraction failed.");
        saveBtn.disabled = false;
        saveBtn.textContent = "Save Clip";
        return;
      }

      // Convert HTML to Markdown using Turndown
      let bodyMarkdown = "";
      if (extracted.bodyHTML && mode !== "bookmark") {
        bodyMarkdown = htmlToMarkdown(extracted.bodyHTML, extracted.url);
      }

      // Build the full markdown file
      const content = buildMarkdownFile(
        extracted,
        bodyMarkdown,
        notebook,
        tags,
        includeFeaturedImage
      );
      const filename = buildFilename(extracted.title);

      // Download via background
      await chrome.runtime.sendMessage({
        action: "download",
        content: content,
        filename: filename,
        subfolder: subfolder,
      });

      // Update tag history
      if (tags.length > 0) {
        const updatedHistory = [...new Set([...tags, ...tagHistory])].slice(
          0,
          50
        );
        await chrome.storage.sync.set({ tagHistory: updatedHistory });
      }

      // Show success
      successOverlay.classList.remove("hidden");

      if (autoClose) {
        setTimeout(() => window.close(), 1500);
      }
    } catch (e) {
      showError("Failed to clip: " + e.message);
      saveBtn.disabled = false;
      saveBtn.textContent = "Save Clip";
    }
  });

  // Turndown conversion
  function htmlToMarkdown(html, pageUrl) {
    const turndownService = new TurndownService({
      headingStyle: "atx",
      codeBlockStyle: "fenced",
      bulletListMarker: "-",
    });

    // Use GFM plugin for tables
    if (typeof turndownPluginGfm !== "undefined") {
      turndownService.use(turndownPluginGfm.gfm);
    }

    // Demote H1 → H2 (title is already the # heading)
    turndownService.addRule("demoteH1", {
      filter: ["h1"],
      replacement: function (content) {
        return "\n\n## " + content.trim() + "\n\n";
      },
    });

    // Strip scripts, styles, iframes (except YouTube/Vimeo)
    turndownService.addRule("stripScripts", {
      filter: ["script", "style", "noscript"],
      replacement: function () {
        return "";
      },
    });

    turndownService.addRule("iframes", {
      filter: function (node) {
        return node.nodeName === "IFRAME";
      },
      replacement: function (_content, node) {
        const src = node.getAttribute("src") || "";
        if (
          src.includes("youtube.com") ||
          src.includes("youtu.be") ||
          src.includes("vimeo.com")
        ) {
          return "\n\n" + src + "\n\n";
        }
        return "";
      },
    });

    // Resolve relative URLs
    turndownService.addRule("absoluteLinks", {
      filter: function (node) {
        return (
          node.nodeName === "A" &&
          node.getAttribute("href") &&
          !node.getAttribute("href").startsWith("http") &&
          !node.getAttribute("href").startsWith("#") &&
          !node.getAttribute("href").startsWith("mailto:")
        );
      },
      replacement: function (content, node) {
        const href = node.getAttribute("href");
        try {
          const absoluteUrl = new URL(href, pageUrl).href;
          return "[" + content + "](" + absoluteUrl + ")";
        } catch {
          return content;
        }
      },
    });

    turndownService.addRule("absoluteImages", {
      filter: function (node) {
        return (
          node.nodeName === "IMG" &&
          node.getAttribute("src") &&
          !node.getAttribute("src").startsWith("http") &&
          !node.getAttribute("src").startsWith("data:")
        );
      },
      replacement: function (_content, node) {
        const src = node.getAttribute("src");
        const alt = node.getAttribute("alt") || "";
        try {
          const absoluteUrl = new URL(src, pageUrl).href;
          return "![" + alt + "](" + absoluteUrl + ")";
        } catch {
          return "";
        }
      },
    });

    let md = turndownService.turndown(html);

    // Collapse excessive blank lines (max 2)
    md = md.replace(/\n{3,}/g, "\n\n");

    return md.trim();
  }

  function buildMarkdownFile(
    extracted,
    bodyMarkdown,
    notebook,
    tags,
    includeFeaturedImage
  ) {
    const now = new Date().toISOString();
    const title = extracted.title || "Untitled";
    const url = extracted.url || "";
    const author = extracted.author || "";
    const excerpt =
      extracted.excerpt || bodyMarkdown.substring(0, 160).trim();
    const type = extracted.mode === "bookmark" ? "bookmark" : "article";
    const featuredImage = extracted.featuredImage || "";

    const lines = [
      "---",
      `title: "${escapeYaml(title)}"`,
      `url: "${escapeYaml(url)}"`,
      `author: "${escapeYaml(author)}"`,
      `clipped_at: "${now}"`,
      `source: "web"`,
      `type: "${type}"`,
      `tags: [${tags.map((t) => `"${escapeYaml(t)}"`).join(", ")}]`,
      `notebook: "${escapeYaml(notebook)}"`,
      `excerpt: "${escapeYaml(excerpt.substring(0, 160))}"`,
      `featured_image: "${escapeYaml(featuredImage)}"`,
    ];

    if (extracted.readabilityFailed) {
      lines.push(`readability_failed: true`);
    }

    lines.push("---");
    lines.push("");
    lines.push(`# ${title}`);
    lines.push("");

    if (url) {
      const domain = extractDomain(url);
      const dateStr = new Date().toLocaleDateString("en-US", {
        year: "numeric",
        month: "long",
        day: "numeric",
      });
      lines.push(`> Clipped from [${domain}](${url}) on ${dateStr}`);
      lines.push("");
    }

    if (
      includeFeaturedImage &&
      featuredImage &&
      type !== "bookmark"
    ) {
      lines.push(`![Featured Image](${featuredImage})`);
      lines.push("");
    }

    if (type !== "bookmark" && bodyMarkdown) {
      lines.push(bodyMarkdown);
    }

    return lines.join("\n") + "\n";
  }

  function buildFilename(title) {
    const date = new Date().toISOString().split("T")[0];
    const slug = slugify(title || "untitled").substring(0, 60);
    return `${date}-${slug}.md`;
  }

  function slugify(text) {
    return text
      .toLowerCase()
      .replace(/[^\w\s-]/g, "")
      .replace(/[\s_]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .replace(/-{2,}/g, "-");
  }

  function extractDomain(url) {
    try {
      return new URL(url).hostname.replace(/^www\./, "");
    } catch {
      return url;
    }
  }

  function escapeYaml(str) {
    return (str || "").replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  }

  function showError(msg) {
    errorText.textContent = msg;
    errorBanner.classList.remove("hidden");
  }

  function hideError() {
    errorBanner.classList.add("hidden");
  }
})();
