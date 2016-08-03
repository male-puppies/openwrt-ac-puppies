
$(function() {
	verifyEventsInit();
	initEvents();
	createInitModal();
});

function createInitModal() {
	$("#modal_tips").modal({
		"backdrop": "static",
		"show": false
	});
}

function initData() {
	$("#opwd, #pwd, #apwd").val("");
}

function initEvents() {
	$(".submit").on("click", OnSubmit);
	$(".showlock").on("click", OnShowlock);
	$('[data-toggle="tooltip"]').tooltip();
}

function OnSubmit() {
	if (!verification()) return;
	var obj,
		opwd = $("#opwd").val(),
		pwd = $("#pwd").val(),
		apwd = $("#apwd").val();

	if (pwd != apwd) {
		createModalTips("新密码输入不一致，请重新输入！");
		return;
	}
	obj = {
		"opwd": opwd,
		"pwd": pwd
	}
	ucicall("SetPassword", obj, function(d) {
		if (typeof d.status != "undefined" && typeof d.data != "undefined" && d.status == 0) {
			createModalTips("保存成功！");
			$.cookie('token', d.data, {path: "/"});
			initData();
		} else {
			createModalTips("保存失败！" + (d.data ? d.data : ""));
		}
	});
}

function OnShowlock(that) {
	var tt = $(this).closest(".form-group").find("input.form-control")
	if (tt.length > 0 && (tt.attr("type") == "text" || tt.attr("type") == "password")) {
		if (tt.attr("type") == "password") {
			$(this).find("i").removeClass("icon-lock").addClass("icon-unlock");
			tt.attr("type", "text");
		} else {
			$(this).find("i").removeClass("icon-unlock").addClass("icon-lock");
			tt.attr("type", "password")
		}
	}
}