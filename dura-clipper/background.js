// DURA Clipper — Background Service Worker

chrome.runtime.onInstalled.addListener(() => {
  // Create context menu items
  chrome.contextMenus.create({
    id: "clip-page",
    title: "Clip page to DURA",
    contexts: ["page"],
  });

  chrome.contextMenus.create({
    id: "clip-selection",
    title: "Clip selection to DURA",
    contexts: ["selection"],
  });

  chrome.contextMenus.create({
    id: "save-link",
    title: "Save link to DURA",
    contexts: ["link"],
  });

  chrome.contextMenus.create({
    id: "save-image",
    title: "Save image to DURA",
    contexts: ["image"],
  });

  // Set default options
  chrome.storage.sync.get(null, (items) => {
    const defaults = {
      downloadSubfolder: "DURA-Clips",
      defaultNotebook: "Inbox",
      notebooks: ["Inbox", "Research", "Reading List"],
      defaultClipMode: "full",
      autoClose: true,
      includeFeaturedImage: false,
      tagHistory: [],
    };
    const toSet = {};
    for (const [key, value] of Object.entries(defaults)) {
      if (items[key] === undefined) {
        toSet[key] = value;
      }
    }
    if (Object.keys(toSet).length > 0) {
      chrome.storage.sync.set(toSet);
    }
  });
});

// Handle context menu clicks
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (!tab?.id) return;

  const settings = await chrome.storage.sync.get([
    "downloadSubfolder",
    "defaultNotebook",
  ]);
  const subfolder = settings.downloadSubfolder || "DURA-Clips";
  const notebook = settings.defaultNotebook || "Inbox";

  switch (info.menuItemId) {
    case "clip-page":
      await clipFromContextMenu(tab, "full", subfolder, notebook);
      break;
    case "clip-selection":
      await clipFromContextMenu(tab, "selection", subfolder, notebook);
      break;
    case "save-link":
      await saveBookmarkFromLink(info, subfolder, notebook);
      break;
    case "save-image":
      await saveImageNote(info, tab, subfolder, notebook);
      break;
  }
});

async function clipFromContextMenu(tab, mode, subfolder, notebook) {
  try {
    const [response] = await chrome.tabs.sendMessage(tab.id, {
      action: "extract",
      mode: mode,
    });
    // response comes back directly (not wrapped)
  } catch {
    // Content script not loaded — inject it first
  }

  try {
    const response = await chrome.tabs.sendMessage(tab.id, {
      action: "extract",
      mode: mode,
    });

    if (!response || !response.success) return;

    const markdown = buildMarkdown(response, notebook, []);
    const filename = buildFilename(response.title);
    downloadMarkdown(markdown, filename, subfolder);
  } catch (e) {
    console.error("DURA Clipper: context menu clip failed", e);
  }
}

async function saveBookmarkFromLink(info, subfolder, notebook) {
  const url = info.linkUrl || "";
  const title = info.selectionText || extractDomain(url);
  const markdown = buildMarkdown(
    {
      mode: "bookmark",
      title: title,
      url: url,
      author: "",
      excerpt: "",
      featuredImage: "",
      bodyHTML: "",
    },
    notebook,
    []
  );
  const filename = buildFilename(title);
  downloadMarkdown(markdown, filename, subfolder);
}

async function saveImageNote(info, tab, subfolder, notebook) {
  const imageUrl = info.srcUrl || "";
  const pageUrl = tab.url || "";
  const title = "Image from " + extractDomain(pageUrl);
  const now = new Date().toISOString();

  const frontMatter = [
    "---",
    `title: "${escapeYaml(title)}"`,
    `url: "${escapeYaml(pageUrl)}"`,
    `clipped_at: "${now}"`,
    `source: "web"`,
    `type: "image"`,
    `tags: []`,
    `notebook: "${escapeYaml(notebook)}"`,
    `featured_image: "${escapeYaml(imageUrl)}"`,
    "---",
    "",
    `# ${title}`,
    "",
    `> Clipped from [${extractDomain(pageUrl)}](${pageUrl})`,
    "",
    `![Image](${imageUrl})`,
    "",
  ].join("\n");

  const filename = buildFilename(title);
  downloadMarkdown(frontMatter, filename, subfolder);
}

// Shared Markdown builder used by both popup (via message) and context menus
function buildMarkdown(extracted, notebook, tags) {
  const now = new Date().toISOString();
  const title = extracted.title || "Untitled";
  const url = extracted.url || "";
  const author = extracted.author || "";
  const excerpt =
    extracted.excerpt || (extracted.bodyHTML || "").substring(0, 160).trim();
  const type = extracted.mode === "bookmark" ? "bookmark" : "article";
  const featuredImage = extracted.featuredImage || "";

  const frontMatter = [
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
    frontMatter.push(`readability_failed: true`);
  }

  frontMatter.push("---");
  frontMatter.push("");

  const lines = [...frontMatter];
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

  if (type !== "bookmark" && extracted.bodyHTML) {
    // Convert HTML to Markdown using Turndown (loaded in popup context)
    // For background context menu clips, we pass through HTML and let popup handle it
    // Actually, we'll include a note that body conversion happens in the message handler
    lines.push(extracted.bodyMarkdown || extracted.bodyHTML);
  }

  return lines.join("\n");
}

function buildFilename(title) {
  const date = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
  const slug = slugify(title).substring(0, 60);
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

function downloadMarkdown(content, filename, subfolder) {
  // Manifest V3 service workers don't support Blob/URL.createObjectURL.
  // Use a data URI instead.
  const base64 = btoa(unescape(encodeURIComponent(content)));
  const dataUrl = "data:text/markdown;base64," + base64;

  chrome.downloads.download(
    {
      url: dataUrl,
      filename: `${subfolder}/${filename}`,
      saveAs: false,
    },
    (_downloadId) => {
      if (chrome.runtime.lastError) {
        console.error("DURA Clipper download error:", chrome.runtime.lastError);
      }
    }
  );
}

// Listen for messages from popup to trigger downloads
chrome.runtime.onMessage.addListener((request, _sender, sendResponse) => {
  if (request.action === "download") {
    downloadMarkdown(
      request.content,
      request.filename,
      request.subfolder || "DURA-Clips"
    );
    sendResponse({ success: true });
  }
  return true;
});
