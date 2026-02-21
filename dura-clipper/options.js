// DURA Clipper — Options Page Script

(async function () {
  "use strict";

  const subfolderInput = document.getElementById("subfolder");
  const defaultNotebookSelect = document.getElementById("default-notebook");
  const defaultModeSelect = document.getElementById("default-mode");
  const notebookListEl = document.getElementById("notebook-list");
  const newNotebookInput = document.getElementById("new-notebook");
  const addNotebookBtn = document.getElementById("add-notebook-btn");
  const autoCloseCheckbox = document.getElementById("auto-close");
  const includeImageCheckbox = document.getElementById("include-image");
  const saveBtn = document.getElementById("save-btn");
  const statusEl = document.getElementById("status");

  let notebooks = [];

  // Load current settings
  const settings = await chrome.storage.sync.get([
    "downloadSubfolder",
    "defaultNotebook",
    "defaultClipMode",
    "notebooks",
    "autoClose",
    "includeFeaturedImage",
  ]);

  subfolderInput.value = settings.downloadSubfolder || "DURA-Clips";
  defaultModeSelect.value = settings.defaultClipMode || "full";
  autoCloseCheckbox.checked = settings.autoClose !== false;
  includeImageCheckbox.checked = settings.includeFeaturedImage || false;

  notebooks = settings.notebooks || ["Inbox", "Research", "Reading List"];
  renderNotebooks();
  populateNotebookSelect(settings.defaultNotebook || "Inbox");

  // Render notebook list
  function renderNotebooks() {
    notebookListEl.innerHTML = "";
    notebooks.forEach((nb, index) => {
      const item = document.createElement("div");
      item.className = "notebook-item";

      const span = document.createElement("span");
      span.textContent = nb;

      const removeBtn = document.createElement("button");
      removeBtn.textContent = "\u00d7";
      removeBtn.title = "Remove";
      removeBtn.addEventListener("click", () => {
        notebooks.splice(index, 1);
        renderNotebooks();
        populateNotebookSelect(defaultNotebookSelect.value);
      });

      item.appendChild(span);
      item.appendChild(removeBtn);
      notebookListEl.appendChild(item);
    });
  }

  function populateNotebookSelect(selectedValue) {
    defaultNotebookSelect.innerHTML = "";
    notebooks.forEach((nb) => {
      const opt = document.createElement("option");
      opt.value = nb;
      opt.textContent = nb;
      if (nb === selectedValue) opt.selected = true;
      defaultNotebookSelect.appendChild(opt);
    });
  }

  // Add notebook
  addNotebookBtn.addEventListener("click", () => {
    const name = newNotebookInput.value.trim();
    if (!name) return;
    if (notebooks.includes(name)) {
      newNotebookInput.value = "";
      return;
    }
    notebooks.push(name);
    newNotebookInput.value = "";
    renderNotebooks();
    populateNotebookSelect(defaultNotebookSelect.value);
  });

  newNotebookInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      addNotebookBtn.click();
    }
  });

  // Save settings
  saveBtn.addEventListener("click", async () => {
    await chrome.storage.sync.set({
      downloadSubfolder: subfolderInput.value.trim() || "DURA-Clips",
      defaultNotebook: defaultNotebookSelect.value,
      defaultClipMode: defaultModeSelect.value,
      notebooks: notebooks,
      autoClose: autoCloseCheckbox.checked,
      includeFeaturedImage: includeImageCheckbox.checked,
    });

    statusEl.classList.remove("hidden");
    setTimeout(() => statusEl.classList.add("hidden"), 2000);
  });
})();
