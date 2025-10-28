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

  let remainingSeconds = Number(root.dataset.remainingSeconds);
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

const bootstrapAdvent = () => {
  initializeAdventCountdown(document.querySelector(".advent-countdown"));
};

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", bootstrapAdvent);
} else {
  bootstrapAdvent();
}

document.addEventListener("turbo:load", bootstrapAdvent, { once: false });
