$.ajax("../ajax/sidebar.html", {
	type: "GET",
	dataType: "html",
	async: false,
	cache: false,
	error: function() {
		console.log("error ajax header.html!")
	},
	success: function(data, textStatus, jqXHR) {
		$("#header_ajax").html(data);
	},
	complete: function(jqXHR, textStatus) {}
});