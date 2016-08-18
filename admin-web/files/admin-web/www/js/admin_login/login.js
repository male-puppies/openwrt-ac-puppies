
$(function() {
	getCookies();
	createInitModal;
});

function createInitModal() {
	$("#modal_tips").modal({
		"backdrop": "static",
		"show": false
	});
}

function getCookies() {
	var user = $.cookie("login_user");
	var pwd = $.cookie("login_pwd");
	
	if (typeof user != "undefined") {
		$("#username").val(user);
	}
	if (typeof pwd != "undefined") {
		$(".remember").prop("checked", true);
		$("#password").val(pwd);
	} else if (typeof user != "undefined"){
		$(".remember").prop("checked", false);
	}
}

function OnSubmit() {
	var username = $("#username").val(),
		password = $("#password").val(),
		obj = {
			username: username,
			password: password
		};
		
	cgicall.get("login", obj, function(d) {
		if (d.status == 0 && typeof d.data == "object" && typeof d.data.token != "undefined" && typeof d.data.refresh != "undefined") {
			$.cookie('token', d.data.token, {path: "/"});
			$.cookie('refresh', d.data.refresh, {path: "/"});
			if ($(".remember").is(":checked")) {
				$.cookie('login_user', username, {expires: 7, path: "/"});
				$.cookie('login_pwd', password, {expires: 7, path: "/"});
			} else {
				$.cookie('login_user', username, {expires: 7, path: "/"});
				$.cookie('login_pwd', '', {expires: -1, path: "/"});
			}
			window.location.href = "/view/admin_status/index.html";
		} else {
			createModalTips("登录失败！" + (d.data ? d.data : ""));
		}
	});
}
