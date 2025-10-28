import $ from "./jquery_setup";
import "bootstrap/dist/js/bootstrap.bundle";
import "jquery-lazy";

import "./vendor/prism";

const setupNavbarScrollBehavior = () => {
  const breakpoint = 992;

  if ($(window).width() <= breakpoint) {
    return;
  }

  const headerHeight = 66;

  $(window).on(
    "scroll",
    { previousTop: 0 },
    function onScroll() {
      const currentTop = $(window).scrollTop();

      if (currentTop < this.previousTop) {
        if (currentTop > 0 && $("#mainNav").hasClass("is-fixed")) {
          $("#mainNav").addClass("is-visible");
        } else {
          $("#mainNav").removeClass("is-visible is-fixed");
        }
      } else if (currentTop > this.previousTop) {
        $("#mainNav").removeClass("is-visible");

        if (currentTop > headerHeight && !$("#mainNav").hasClass("is-fixed")) {
          $("#mainNav").addClass("is-fixed");
        }
      }

      this.previousTop = currentTop;
    }
  );
};

const initializeLazyImages = () => {
  const activate = () => {
    if (typeof $.fn.Lazy !== "function") {
      return;
    }

    $(".lazy").Lazy({
      effect: "fadeIn",
      effectTime: 1000,
      threshold: 50,
      delay: 1,
    });
  };

  if (typeof $.fn.Lazy === "function") {
    activate();
    return;
  }

  activate();
};

export const bootstrapApplication = () => {
  setupNavbarScrollBehavior();
  initializeLazyImages();
};

$(bootstrapApplication);

document.addEventListener("turbo:load", bootstrapApplication, { once: false });

window.lazyLoadInit = initializeLazyImages;
