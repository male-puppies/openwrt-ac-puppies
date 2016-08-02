
$(function() {
	getCookies();
	createInitModal;
	initEvents();
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

function initEvents() {
	// $(".submit").on("click", OnSubmit);
}

function OnSubmit() {
	var username = $("#username").val(),
		password = $("#password").val();
	$.get(
		"/v1/admin/api/login?username=" + username + "&password=" + password,
		function(d) {
			if (d.status == 0 && typeof d.data == "object" && typeof d.data.token != "undefined" && typeof d.data.refresh != "undefined") {
				$.cookie('md5psw', d.data.token, {path: "/"});
				$.cookie('loginid', d.data.refresh, {path: "/"});
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
		},
		"json"
	)
}
