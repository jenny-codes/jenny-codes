import $ from "jquery";

const setupFloatingLabels = () => {
  $("body")
    .on("input propertychange", ".floating-label-form-group", (event) => {
      const hasValue = Boolean($(event.target).val());
      $(event.currentTarget).toggleClass("floating-label-form-group-with-value", hasValue);
    })
    .on("focus", ".floating-label-form-group", (event) => {
      $(event.currentTarget).addClass("floating-label-form-group-with-focus");
    })
    .on("blur", ".floating-label-form-group", (event) => {
      $(event.currentTarget).removeClass("floating-label-form-group-with-focus");
    });
};

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

export const initializeCleanBlog = () => {
  setupFloatingLabels();
  setupNavbarScrollBehavior();
};
