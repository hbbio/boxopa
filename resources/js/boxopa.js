$("*[rel=popover]")
	.popover({
		placement: 'bottom',
		live: true,
    html: true
	})
	.click(function(e) {
    e.preventDefault()
  });