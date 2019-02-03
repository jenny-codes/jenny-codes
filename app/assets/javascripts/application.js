// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require rails-ujs
//= require popper 
//= require bootstrap
//= require activestorage
//= require jquery-lazy
// require turbolinks
//= require clean-blog

// $(document).on('turbolinks:load', function() {
$(document).on('ready', function() {
  window.lazyLoadInit();
});


window.lazyLoadInit = function(){
  $('.lazy').Lazy({
    effect: "fadeIn",
    effectTime: 1000,
    threshold: 50,
    delay: 1
  });
};

