
$(function() {
	createInitModal();
});

function createInitModal() {
	$("#modal_spin").modal({
		"backdrop": "static",
		"show": false
	});
}

function OnDiag(that) {
	$("#result").hide();
	var _that = $(that).closest(".diag").find("input.ping");
	var obj = {
		tool: _that.attr("id"),
		host: _that.val()
	}
	$("#modal_spin").modal("show");
	cgicall.get("nettool_get", obj, function(d) {
		$("#modal_spin").modal("hide");
		if (d.status == 0) {
			$("#result span").html(d.data);
			$("#result").show();
		} else {
			$("#result span").html("获取失败！");
			$("#result").show();
		}
	});
}