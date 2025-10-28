const formatTime = (totalSeconds) => {
  const hours = String(Math.floor(totalSeconds / 3600)).padStart(2, "0");
  const minutes = String(Math.floor((totalSeconds % 3600) / 60)).padStart(2, "0");
  const seconds = String(totalSeconds % 60).padStart(2, "0");

  return `${hours}:${minutes}:${seconds}`;
};

const initializeAdventCountdown = (root) => {
  if (!root || root.dataset.countdownBound === "true") return;
  root.dataset.countdownBound = "true";

  const label = root.querySelector("[data-countdown-label]");
  if (!label) return;

  const rawRemaining = root.dataset.remainingSeconds ?? root.dataset['remaining_seconds'];
  let remainingSeconds = Number(rawRemaining);
  if (Number.isNaN(remainingSeconds)) return;
  remainingSeconds = Math.max(remainingSeconds, 0);

  let intervalId = null;

  const update = () => {
    label.textContent = `${formatTime(remainingSeconds)} left until next check-in`;

    if (remainingSeconds === 0) {
      if (intervalId) clearInterval(intervalId);
      return;
    }

    remainingSeconds = Math.max(remainingSeconds - 1, 0);
  };

  update();
  intervalId = window.setInterval(update, 1000);
};

function initializeTabs(consoleEl) {
  if (!consoleEl) return;

  const tabs = Array.from(consoleEl.querySelectorAll("[data-advent-tab]"));
  const panels = Array.from(consoleEl.querySelectorAll("[data-advent-panel]"));

  if (tabs.length === 0 || panels.length === 0) {
    return;
  }

  let currentId =
    tabs.find((tab) => tab.classList.contains("is-active"))?.dataset.adventTab ||
    tabs[0].dataset.adventTab;

  const activate = (targetId) => {
    if (!targetId) {
      return;
    }

    currentId = targetId;

    panels.forEach((panel) => {
      const isMatch = panel.dataset.adventPanel === targetId;
      panel.classList.toggle("is-hidden", !isMatch);
    });

    tabs.forEach((tab) => {
      const isMatch = tab.dataset.adventTab === targetId;
      tab.classList.toggle("is-active", isMatch);
    });
  };

  tabs.forEach((tab) => {
    tab.addEventListener("click", (event) => {
      event.preventDefault();
      const targetId = tab.dataset.adventTab;

      if (!targetId || targetId === currentId) {
        return;
      }

      activate(targetId);
    });
  });

  activate(currentId);
}

function initializeHeadline(consoleEl) {
  if (!consoleEl) return;

  const title = consoleEl.querySelector(".advent-title");
  if (!title) return;

  const lines = Array.from(title.querySelectorAll(".advent-title__line"));
  if (lines.length === 0) {
    return;
  }

  const clearTimers = (line) => {
    if (line._typingTimeouts) {
      line._typingTimeouts.forEach((timeoutId) => window.clearTimeout(timeoutId));
    }
    line._typingTimeouts = [];
  };

  lines.forEach((line) => {
    clearTimers(line);
    const text = line.dataset.text || line.textContent || "";
    line.dataset.text = text;
    line.textContent = "";
    line.classList.remove("is-complete");
  });

  const typeLine = (index) => {
    if (index >= lines.length) return;

    const line = lines[index];
    const text = line.dataset.text || "";
    const baseDelay = Number(line.dataset.speed || 65);
    let charIndex = 0;

    const schedule = (callback, delay) => {
      const timeoutId = window.setTimeout(callback, delay);
      line._typingTimeouts.push(timeoutId);
      return timeoutId;
    };

    const step = () => {
      line.textContent = text.slice(0, charIndex);
      charIndex += 1;

      if (charIndex <= text.length) {
        schedule(step, baseDelay);
      } else {
        line.classList.add("is-complete");
        schedule(() => typeLine(index + 1), 500);
      }
    };

    schedule(step, 0);
  };

  typeLine(0);
}

const bootstrapAdvent = () => {
  const root = document.querySelector(".advent-console");
  initializeAdventCountdown(root?.querySelector(".advent-countdown"));
  initializeTabs(root);
  initializeHeadline(root);
};

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", bootstrapAdvent);
} else {
  bootstrapAdvent();
}

document.addEventListener("turbo:load", bootstrapAdvent, { once: false });
