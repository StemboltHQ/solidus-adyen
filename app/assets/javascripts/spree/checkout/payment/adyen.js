jQuery(function($) {
  $('#adyen-hpp-details').each(function() {
    node = this;
    url = this.dataset.url;

    $.get(url, function(data) {
      $(node).html(data);
    });
  });
});
