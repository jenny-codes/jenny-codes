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

const setSessionFlag = (key) => {
  if (typeof window === 'undefined' || !window.sessionStorage) return;
  try {
    window.sessionStorage.setItem(key, '1');
  } catch (error) {
    console.warn('[advent] unable to persist session flag', key, error);
  }
};

const consumeSessionFlag = (key) => {
  if (typeof window === 'undefined' || !window.sessionStorage) return false;
  try {
    if (window.sessionStorage.getItem(key) === '1') {
      window.sessionStorage.removeItem(key);
      return true;
    }
  } catch (error) {
    console.warn('[advent] unable to consume session flag', key, error);
  }
  return false;
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

  const updateTabQuery = (targetId) => {
    if (!targetId || typeof window === 'undefined' || typeof window.history === 'undefined') {
      return;
    }

    try {
      const url = new URL(window.location.href);
      url.searchParams.set('tab', targetId);
      url.searchParams.delete('puzzle_answer');
      url.searchParams.delete('commit');

      const nextSearch = url.searchParams.toString();
      const nextUrl = nextSearch ? `${url.pathname}?${nextSearch}` : url.pathname;
      window.history.replaceState({}, '', nextUrl);
    } catch (error) {
      console.warn('[advent] unable to update tab query', error);
    }
  };

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

    updateTabQuery(targetId);
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

const triggerFireworksAsync = async () => {
  triggerFireworks();
  if (!prefersReducedMotion()) {
    await sleep(3100);
  }
};

const triggerVoucherConfetti = () => {
  triggerFireworks();
};

const sleep = (ms) => new Promise((resolve) => {
  window.setTimeout(resolve, ms);
});

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

const refreshAdventConsole = async (targetUrl, options = {}) => {
  const { skipHeadlineAnimation = false } = options;
  const currentConsole = document.querySelector('.advent-console');
  if (!currentConsole) return;

  const response = await fetch(targetUrl, {
    method: 'GET',
    credentials: 'same-origin',
    headers: {
      Accept: 'text/html',
      'X-Requested-With': 'XMLHttpRequest',
    },
  });

  if (!response.ok) {
    throw new Error(`Refresh failed with status ${response.status}`);
  }

  const html = await response.text();
  const parser = new DOMParser();
  const doc = parser.parseFromString(html, 'text/html');
  const nextConsole = doc.querySelector('.advent-console');
  if (!nextConsole) {
    throw new Error('Unable to locate updated console content');
  }

  swapConsoleContent(currentConsole, nextConsole.innerHTML, { skipHeadlineAnimation });
};

const clearPuzzleFeedback = (form) => {
  if (!form) return;
  const input = form.querySelector('.advent-input');
  if (input instanceof HTMLInputElement) {
    input.classList.remove('is-error');
    input.removeAttribute('aria-invalid');
  }
  const field = form.querySelector('.advent-puzzle-form__field');
  const hint = field?.querySelector('.advent-puzzle-hint');
  hint?.remove();
};

const showPuzzleHint = (form, message) => {
  if (!form) return;

  const input = form.querySelector('.advent-input');
  if (input instanceof HTMLInputElement) {
    input.classList.add('is-error');
    input.setAttribute('aria-invalid', 'true');
    input.focus();
  }

  const field = form.querySelector('.advent-puzzle-form__field');
  let hint = field?.querySelector('.advent-puzzle-hint');
  if (!hint) {
    hint = document.createElement('span');
    hint.className = 'advent-puzzle-hint';
    hint.setAttribute('role', 'status');
    field?.appendChild(hint);
  }

  if (hint) {
    hint.textContent = message;
  }

  form.classList.add('is-shaking');
  const handleAnimationEnd = () => {
    form.classList.remove('is-shaking');
    form.removeEventListener('animationend', handleAnimationEnd);
  };
  form.addEventListener('animationend', handleAnimationEnd);
};

const clearMessageStatus = (form) => {
  const status = form?.querySelector('[data-advent-message-status]');
  if (!status) return;
  status.textContent = '';
  status.classList.remove('is-visible', 'is-success', 'is-error');
};

const showMessageStatus = (form, message, variant) => {
  const status = form?.querySelector('[data-advent-message-status]');
  if (!status) return;
  status.textContent = message;
  status.classList.add('is-visible');
  status.classList.toggle('is-success', variant === 'success');
  status.classList.toggle('is-error', variant === 'error');
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

const initializePuzzleForm = (root) => {
  if (!root) return;

  const form = root.querySelector('.advent-puzzle-form');
  if (!form || form.dataset.puzzleBound === 'true') return;

  form.dataset.puzzleBound = 'true';

  const inputField = form.querySelector('.advent-input');
  if (inputField instanceof HTMLInputElement) {
    inputField.addEventListener('input', () => {
      if (inputField.value.trim().length > 0) {
        clearPuzzleFeedback(form);
      }
    });
  }

  form.addEventListener('submit', async (event) => {
    event.preventDefault();

    if (form.dataset.puzzlePending === 'true') return;

    const input = form.querySelector('.advent-input');
    if (input instanceof HTMLInputElement) {
      const value = input.value.trim();
      if (value.length <= 66) {
        showPuzzleHint(form, 'say more? 😗');
        return;
      }

      if (/(.)\1{5,}/.test(value)) {
        showPuzzleHint(form, 'not you trying to fill with characters');
        return;
      }
    }

    clearPuzzleFeedback(form);
    form.dataset.puzzlePending = 'true';

    const submitButton = form.querySelector('[type="submit"]');
    submitButton?.setAttribute('disabled', 'true');

    const formData = new FormData(form);

    try {
      const response = await fetch(form.action, {
        method: (form.method || 'POST').toUpperCase(),
        body: formData,
        credentials: 'same-origin',
        headers: {
          Accept: 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      });

      let payload = null;
      try {
        payload = await response.json();
      } catch (error) {
        console.error('[advent] puzzle submission response parse error', error);
      }

      if (payload?.status === 'ok') {
        const redirectUrl = payload.redirect_to || `${window.location.pathname}?tab=main`;
        clearPuzzleFeedback(form);

        try {
          const url = new URL(redirectUrl, window.location.origin);
          url.searchParams.set('tab', 'main');
          window.history.replaceState({}, '', `${url.pathname}?${url.searchParams.toString()}`);

          triggerFireworks();
          if (!prefersReducedMotion()) {
            await sleep(3100);
          }
          await refreshAdventConsole(url.toString(), { skipHeadlineAnimation: true });
        } catch (error) {
          console.error('[advent] puzzle refresh fallback', error);
          triggerFireworks();
          if (!prefersReducedMotion()) {
            await sleep(3100);
          }
          window.location.assign(redirectUrl);
        }
        return;
      } else if (payload?.status === 'error') {
        showPuzzleHint(form, payload.message || 'That is not correct. Try again?');
        const input = form.querySelector('.advent-input');
        if (input instanceof HTMLInputElement) {
          input.value = '';
          input.focus();
        }
      } else if (!response.ok) {
        throw new Error(`Unexpected response status ${response.status}`);
      } else {
        showPuzzleHint(form, 'Something went wrong. Please try again.');
      }
    } catch (error) {
      console.error('[advent] puzzle submission fallback', error);
      form.submit();
    } finally {
      submitButton?.removeAttribute('disabled');
      form.dataset.puzzlePending = 'false';
    }
  });
};

const initializeVoucherCarousel = (root) => {
  if (!root) return;

  const carousels = Array.from(root.querySelectorAll('[data-advent-carousel]'));
  if (carousels.length === 0) return;

  carousels.forEach((carousel) => {
    if (carousel.dataset.carouselBound === 'true') return;
    carousel.dataset.carouselBound = 'true';

    const track = carousel.querySelector('[data-advent-carousel-track]');
    if (!track) return;

    const slides = Array.from(track.querySelectorAll('[data-advent-carousel-slide]'));
    if (slides.length === 0) return;

    const viewport = carousel.querySelector('[data-advent-carousel-viewport]');
    const prevButton = carousel.querySelector('[data-advent-carousel-prev]');
    const nextButton = carousel.querySelector('[data-advent-carousel-next]');

    const totalSlides = slides.length;
    let currentIndex = slides.findIndex((slide) => slide.classList.contains('is-active'));
    if (currentIndex < 0) currentIndex = 0;

    const clampIndex = (index) => Math.max(0, Math.min(index, totalSlides - 1));

    const applyTransform = (index) => {
      if (!track) return;
      track.style.transform = `translateX(-${index * 100}%)`;
    };

    const updateNavState = () => {
      const atStart = currentIndex === 0;
      const atEnd = currentIndex === totalSlides - 1;

      if (prevButton) {
        prevButton.disabled = atStart;
      }
      if (nextButton) {
        nextButton.disabled = atEnd;
      }
    };

    const setActiveSlide = (index) => {
      slides.forEach((slide, slideIndex) => {
        slide.classList.toggle('is-active', slideIndex === index);
      });
      if (viewport) {
        viewport.dataset.carouselIndex = String(index);
      }
      applyTransform(index);
      updateNavState();
    };

    const goTo = (index) => {
      const targetIndex = clampIndex(index);
      currentIndex = targetIndex;
      setActiveSlide(currentIndex);
    };

    if (track) {
      track.style.transition = 'none';
      applyTransform(currentIndex);
    }

    setActiveSlide(currentIndex);

    if (track) {
      requestAnimationFrame(() => {
        track.style.removeProperty('transition');
      });
    }

    if (totalSlides === 1) {
      carousel.dataset.hasSingle = 'true';
    } else {
      delete carousel.dataset.hasSingle;
    }

    prevButton?.addEventListener('click', (event) => {
      event.preventDefault();
      goTo(currentIndex - 1);
    });

    nextButton?.addEventListener('click', (event) => {
      event.preventDefault();
      goTo(currentIndex + 1);
    });

    if (totalSlides > 1 && viewport) {
      let startX = null;
      let isPointerDown = false;
      const swipeThreshold = 40;

      const getClientX = (event) => {
        if (typeof event.clientX === 'number') return event.clientX;
        if (event.touches && event.touches[0]) return event.touches[0].clientX;
        if (event.changedTouches && event.changedTouches[0]) return event.changedTouches[0].clientX;
        return null;
      };

      const handlePointerDown = (event) => {
        if (event.pointerType === 'mouse' && event.button !== 0) return;
        const clientX = getClientX(event);
        if (clientX === null) return;
        startX = clientX;
        isPointerDown = true;
        if (track) {
          track.style.transition = 'none';
        }
      };

      const handlePointerMove = (event) => {
        if (!isPointerDown || !track) return;
        const clientX = getClientX(event);
        if (clientX === null) return;
        const deltaX = clientX - startX;
        const viewportWidth = viewport.clientWidth || 1;
        const offsetPercentage = (deltaX / viewportWidth) * 100;
        track.style.transform = `translateX(calc(-${currentIndex * 100}% + ${offsetPercentage}%))`;
      };

      const handlePointerEnd = (event) => {
        if (!isPointerDown) return;
        isPointerDown = false;

        const clientX = getClientX(event);
        const deltaX = clientX !== null && startX !== null ? clientX - startX : 0;

        if (track) {
          track.style.removeProperty('transition');
        }

        applyTransform(currentIndex);

        if (Math.abs(deltaX) >= swipeThreshold) {
          if (deltaX < 0) {
            goTo(currentIndex + 1);
          } else if (deltaX > 0) {
            goTo(currentIndex - 1);
          }
        }

        startX = null;
      };

      viewport.addEventListener('pointerdown', handlePointerDown);
      viewport.addEventListener('pointermove', handlePointerMove);
      viewport.addEventListener('pointerup', handlePointerEnd);
      viewport.addEventListener('pointercancel', handlePointerEnd);
      viewport.addEventListener('pointerleave', handlePointerEnd);

      viewport.addEventListener('touchstart', handlePointerDown, { passive: true });
      viewport.addEventListener('touchmove', handlePointerMove, { passive: true });
      viewport.addEventListener('touchend', handlePointerEnd);
      viewport.addEventListener('touchcancel', handlePointerEnd);
    }
  });
};

const initializeVoucherActions = (root) => {
  if (!root) return;

  const bindVoucherActionForm = (form) => {
    if (!form || form.dataset.voucherActionBound === 'true') return;

    form.dataset.voucherActionBound = 'true';

    const submitButton = form.querySelector('button[type="submit"], input[type="submit"]');

    const handleSubmit = async (event) => {
      const action = form.dataset.adventVoucherAction || 'draw';

      if (action === 'redeem') {
        setSessionFlag('adventSkipHeadlineAnimation');
        setSessionFlag('adventRedeemConfetti');
        return;
      }

      if (form.dataset.voucherPending === 'true') {
        event.preventDefault();
        return;
      }

      form.dataset.voucherPending = 'true';
      if (submitButton) {
        submitButton.disabled = true;
      }

      event.preventDefault();

      try {
        await submitAdventForm(form, { skipHeadlineAnimation: true });
      } catch (error) {
        console.error('[advent] voucher action fallback submission', error);
        form.removeEventListener('submit', handleSubmit);
        form.submit();
        return;
      } finally {
        form.dataset.voucherPending = 'false';
        submitButton?.removeAttribute('disabled');
      }
    };

    form.addEventListener('submit', handleSubmit);
  };

  root
    .querySelectorAll('form[data-advent-voucher-action]')
    .forEach((form) => bindVoucherActionForm(form));
};

const initializeMessageForm = (root) => {
  if (!root) return;

  const forms = Array.from(root.querySelectorAll('[data-advent-message-form]'));
  forms.forEach((form) => {
    if (form.dataset.adventMessageBound === 'true') return;
    form.dataset.adventMessageBound = 'true';

    const input = form.querySelector('textarea');
    const submitButton = form.querySelector('button[type="submit"], input[type="submit"]');

    if (input instanceof HTMLTextAreaElement) {
      input.addEventListener('input', () => {
        clearMessageStatus(form);
      });
    }

    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      if (form.dataset.adventMessagePending === 'true') return;

      clearMessageStatus(form);

      const value = input instanceof HTMLTextAreaElement ? input.value.trim() : '';
      if (value.length === 0) {
        showMessageStatus(form, 'say more? 😗', 'error');
        return;
      }

      form.dataset.adventMessagePending = 'true';
      submitButton?.setAttribute('disabled', 'disabled');

      try {
        const response = await fetch(form.action, {
          method: (form.method || 'POST').toUpperCase(),
          body: new FormData(form),
          headers: {
            Accept: 'application/json',
            'X-Requested-With': 'XMLHttpRequest',
          },
          credentials: 'same-origin',
        });

        if (!response.ok) {
          throw new Error(`Request failed with status ${response.status}`);
        }

        const payload = await response.json();

        if (payload?.status === 'ok') {
          showMessageStatus(form, 'received!', 'success');
          if (input instanceof HTMLTextAreaElement) {
            input.value = '';
          }
        } else {
          const message = payload?.message || 'Something went wrong. Please try again.';
          showMessageStatus(form, message, 'error');
        }
      } catch (error) {
        console.error('[advent] message submission failed', error);
        showMessageStatus(form, 'Something went wrong. Please try again.', 'error');
      } finally {
        form.dataset.adventMessagePending = 'false';
        submitButton?.removeAttribute('disabled');
      }
    });
  });
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
  const voucherRedeemedFlag = root.querySelector('[data-voucher-redeemed-flash="true"]');
  if (voucherRedeemedFlag) {
    root.dataset.adventRedeemed = 'true';
    voucherRedeemedFlag.remove();
  }

  const redeemedFromFlash = root.dataset.adventRedeemed === 'true';
  const skipHeadline = options.skipHeadlineAnimation || redeemedFromFlash || consumeSessionFlag('adventSkipHeadlineAnimation');

  initializeHeadline(root, {
    skipAnimation: skipHeadline,
    onComplete: () => {
      if (body) {
        root.classList.add('is-ready');
      }
    },
  });
  initializeCheckInButton(root);
  initializePuzzleForm(root);
  initializeMessageForm(root);
  initializeVoucherCarousel(root);
  initializeVoucherActions(root);

  if (redeemedFromFlash || consumeSessionFlag('adventRedeemConfetti')) {
    triggerVoucherConfetti();
    if (root.dataset) {
      root.dataset.adventRedeemed = 'false';
    }
  }
};

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", bootstrapAdvent);
} else {
  bootstrapAdvent();
}

document.addEventListener("turbo:load", bootstrapAdvent, { once: false });
