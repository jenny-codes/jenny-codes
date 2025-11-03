const formatTime = (totalSeconds) => {
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  const parts = [];
  if (hours > 0) parts.push(`${hours} hour${hours === 1 ? '' : 's'}`);
  if (minutes > 0) parts.push(`${minutes} minute${minutes === 1 ? '' : 's'}`);
  parts.push(`${seconds} second${seconds === 1 ? '' : 's'}`);

  return parts.join(' ');
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

function initializeHeadline(consoleEl, options = {}) {
  const { skipAnimation = false, onComplete } = options;
  if (!consoleEl) return;

  const title = consoleEl.querySelector(".advent-title");
  if (!title) return;

  const lines = Array.from(title.querySelectorAll(".advent-title__line"));
  if (lines.length === 0) {
    if (typeof onComplete === "function") {
      onComplete();
    }
    return;
  }

  const clearTimers = (line) => {
    if (line._typingTimeouts) {
      line._typingTimeouts.forEach((timeoutId) => window.clearTimeout(timeoutId));
    }
    line._typingTimeouts = [];
  };

  if (skipAnimation) {
    lines.forEach((line) => {
      clearTimers(line);
      const text = line.dataset.text || line.textContent || "";
      line.dataset.text = text;
      line.textContent = text;
      line.classList.add("is-complete");
    });
    if (typeof onComplete === "function") {
      requestAnimationFrame(() => onComplete());
    }
    return;
  }

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
        if (index + 1 < lines.length) {
          schedule(() => typeLine(index + 1), 500);
        } else if (typeof onComplete === "function") {
          schedule(() => onComplete(), 120);
        }
      }
    };

    schedule(step, 0);
  };

  typeLine(0);
}

const prefersReducedMotion = () => {
  const query = typeof window !== "undefined" && typeof window.matchMedia === "function"
    ? window.matchMedia("(prefers-reduced-motion: reduce)")
    : null;

  return query ? query.matches : false;
};

const triggerFireworks = () => {
  if (prefersReducedMotion()) return;

  const container = document.createElement("div");
  container.className = "advent-starfield";

  const symbols = ["✦", "✧", "✹", "✶", "★", "✺", "✷", "✵", "✱", "✻", "✫", "✯"];
  const emissionDuration = 3000;
  const removalDelay = 3700;
  const waveInterval = 180;

  const spawnBurst = () => {
    const burstCenterX = 8 + Math.random() * 84;
    const burstCenterY = 12 + Math.random() * 76;
    const starCount = 26 + Math.floor(Math.random() * 18);

    for (let index = 0; index < starCount; index += 1) {
      const star = document.createElement("span");
      star.className = "advent-starfield__star";

      const angle = Math.random() * Math.PI * 2;
      const distance = 160 + Math.random() * 320;
      const dx = Math.cos(angle) * distance;
      const dy = Math.sin(angle) * distance;

      star.textContent = symbols[Math.floor(Math.random() * symbols.length)];
      star.style.setProperty("--origin-x", `${burstCenterX}%`);
      star.style.setProperty("--origin-y", `${burstCenterY}%`);
      star.style.setProperty("--dx", `${dx}px`);
      star.style.setProperty("--dy", `${dy}px`);
      star.style.setProperty("--delay", `${Math.random() * 200}ms`);
      star.style.setProperty("--duration", `${2400 + Math.random() * 1600}ms`);
      star.style.setProperty("--rotate", `${Math.floor(Math.random() * 1440)}deg`);
      star.style.setProperty("--scale", `${1 + Math.random() * 1.4}`);
      star.style.setProperty("--size", `${28 + Math.random() * 28}px`);

      container.appendChild(star);
    }
  };

  spawnBurst();

  const emissionStart = performance.now();
  const emissionTimer = window.setInterval(() => {
    if (performance.now() - emissionStart >= emissionDuration) {
      window.clearInterval(emissionTimer);
      return;
    }
    spawnBurst();
  }, waveInterval);

  document.body.appendChild(container);

  window.setTimeout(() => {
    container.classList.add("is-fading");
  }, removalDelay - 350);

  window.setTimeout(() => {
    container.remove();
  }, removalDelay);
};

const swapConsoleContent = (currentConsole, nextMarkup, options = {}) => {
  const { skipHeadlineAnimation = false } = options;
  if (!currentConsole) return;

  const initialHeight = currentConsole.offsetHeight;
  currentConsole.style.height = `${initialHeight}px`;

  let hasSwapped = false;

  const completeSwap = () => {
    if (hasSwapped) return;
    hasSwapped = true;

    currentConsole.innerHTML = nextMarkup;
    const nextHeight = currentConsole.scrollHeight;

    requestAnimationFrame(() => {
      currentConsole.style.height = `${nextHeight}px`;
    });

    currentConsole.classList.remove('is-transitioning-out');
    currentConsole.classList.add('is-entering');

    requestAnimationFrame(() => {
      currentConsole.classList.add('is-visible');
      bootstrapAdvent(currentConsole, { skipHeadlineAnimation });

      let fadeInFallback;
      const handleFadeInEnd = (event) => {
        if (event.target !== currentConsole || (event.propertyName !== 'opacity' && event.propertyName !== 'height')) return;
        currentConsole.classList.remove('is-entering', 'is-visible');
        currentConsole.style.height = '';
        currentConsole.removeEventListener('transitionend', handleFadeInEnd);
        window.clearTimeout(fadeInFallback);
      };

      currentConsole.addEventListener('transitionend', handleFadeInEnd);

      fadeInFallback = window.setTimeout(() => {
        currentConsole.classList.remove('is-entering', 'is-visible');
        currentConsole.style.height = '';
        currentConsole.removeEventListener('transitionend', handleFadeInEnd);
      }, 700);
    });
  };

  const handleFadeOutEnd = (event) => {
    if (event && (event.target !== currentConsole || event.propertyName !== 'opacity')) return;
    currentConsole.removeEventListener('transitionend', handleFadeOutEnd);
    completeSwap();
  };

  currentConsole.addEventListener('transitionend', handleFadeOutEnd);
  currentConsole.classList.add('is-transitioning-out');

  window.setTimeout(() => {
    handleFadeOutEnd();
  }, 380);
};

const submitAdventForm = async (form, options = {}) => {
  const { skipHeadlineAnimation = false } = options;
  if (!form) return;

  const currentConsole = document.querySelector('.advent-console');
  if (!currentConsole) {
    form.submit();
    return;
  }

  const response = await fetch(form.action, {
    method: (form.method || 'POST').toUpperCase(),
    body: new FormData(form),
    credentials: 'same-origin',
    headers: {
      Accept: 'text/html',
      'X-Requested-With': 'XMLHttpRequest',
    },
  });

  if (!response.ok) {
    throw new Error(`Request failed with status ${response.status}`);
  }

  const html = await response.text();
  const parser = new DOMParser();
  const doc = parser.parseFromString(html, 'text/html');
  const nextConsole = doc.querySelector('.advent-console');

  if (!nextConsole) {
    throw new Error('Unable to locate updated advent console in response');
  }

  swapConsoleContent(currentConsole, nextConsole.innerHTML, { skipHeadlineAnimation });
};

const initializeCheckInButton = (root) => {
  if (!root) return;

  const button = root.querySelector('[data-advent-check-in]');
  if (!button || button.dataset.checkInBound === 'true') return;

  button.dataset.checkInBound = 'true';

  button.addEventListener('click', (event) => {
    if (button.dataset.checkInPending === 'true') return;

    event.preventDefault();

    button.dataset.checkInPending = 'true';
    button.disabled = true;
    triggerFireworks();

    const form = button.closest('form');
    const delay = prefersReducedMotion() ? 0 : 3100;

    const finalize = () => {
      button.disabled = false;
      button.dataset.checkInPending = 'false';
    };

    const performSubmission = async () => {
      try {
        await submitAdventForm(form, { skipHeadlineAnimation: true });
      } catch (error) {
        console.error('[advent] falling back to classic submission', error);
        form?.submit();
      } finally {
        finalize();
      }
    };

    if (delay === 0) {
      void performSubmission();
    } else {
      window.setTimeout(() => {
        void performSubmission();
      }, delay);
    }
  });
};

const initializeResetButton = (root) => {
  if (!root) return;

  const button = root.querySelector('[data-advent-reset]');
  if (!button || button.dataset.resetBound === 'true') return;

  button.dataset.resetBound = 'true';

  button.addEventListener('click', (event) => {
    if (button.dataset.resetPending === 'true') return;

    event.preventDefault();

    button.dataset.resetPending = 'true';
    button.disabled = true;

    const form = button.closest('form');

    submitAdventForm(form, { skipHeadlineAnimation: true })
      .catch((error) => {
        console.error('[advent] reset fallback submission', error);
        form?.submit();
      })
      .finally(() => {
        button.disabled = false;
        button.dataset.resetPending = 'false';
      });
  });
};

const bindVoucherActionButton = (button) => {
  if (!button || button.dataset.voucherBound === 'true') return;

  button.dataset.voucherBound = 'true';

  button.addEventListener('click', (event) => {
    if (button.dataset.voucherPending === 'true') return;

    event.preventDefault();

    button.dataset.voucherPending = 'true';
    button.disabled = true;

    const form = button.closest('form');

    submitAdventForm(form, { skipHeadlineAnimation: true })
      .catch((error) => {
        console.error('[advent] voucher action fallback submission', error);
        form?.submit();
      })
      .finally(() => {
        button.disabled = false;
        button.dataset.voucherPending = 'false';
      });
  });
};

const initializeVoucherActions = (root) => {
  if (!root) return;

  root.querySelectorAll('[data-advent-voucher-draw]').forEach(bindVoucherActionButton);
  root.querySelectorAll('[data-advent-voucher-redeem]').forEach(bindVoucherActionButton);
};

const bootstrapAdvent = (rootOverride, options = {}) => {
  document.documentElement.classList.add('has-js');

  const root = rootOverride ?? document.querySelector('.advent-console');
  if (!root) return;

  const body = root.querySelector('.advent-console__body');

  if (options.skipHeadlineAnimation) {
    root.classList.add('is-ready');
  } else {
    root.classList.remove('is-ready');
  }

  initializeAdventCountdown(root.querySelector('.advent-countdown'));
  initializeTabs(root);
  initializeHeadline(root, {
    skipAnimation: options.skipHeadlineAnimation,
    onComplete: () => {
      if (body) {
        root.classList.add('is-ready');
      }
    },
  });
  initializeCheckInButton(root);
  initializeResetButton(root);
  initializeVoucherActions(root);
};

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", bootstrapAdvent);
} else {
  bootstrapAdvent();
}

document.addEventListener("turbo:load", bootstrapAdvent, { once: false });
