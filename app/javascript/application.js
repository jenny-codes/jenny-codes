import $ from "jquery";

window.$ = $;
window.jQuery = $;

import "bootstrap/dist/js/bootstrap.bundle";
import "jquery-lazy";

import { initializeCleanBlog } from "./clean_blog";
import "./vendor/prism";

const initializeLazyImages = () => {
  $(".lazy").Lazy({
    effect: "fadeIn",
    effectTime: 1000,
    threshold: 50,
    delay: 1,
  });
};

export const bootstrapApplication = () => {
  initializeCleanBlog();
  initializeLazyImages();
};

$(bootstrapApplication);

document.addEventListener("turbo:load", bootstrapApplication, { once: false });

window.lazyLoadInit = initializeLazyImages;
