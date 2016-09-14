$(function() {
	initEvents();
});

function initEvents() {
	$("#web_user, #web_pwd, #sms_user, #sms_pwd").on("focus blur keyup", rm_tips);
	$(".cancle").on("click", function() {
		$(".alertbox,.mengban").hide();
	});
}

// weixin auth
function call_weixin() {
	var params = window.location.search;
	if (params && params != "") {
		if (typeof g_redirect != "undefined" && g_redirect != "") {
			window.location.href = "wx-auth.html" + params + "&g_redirect=" + g_redirect;
		} else {
			window.location.href = "wx-auth.html" + params;
		}
	} else {
		if (typeof g_redirect != "undefined" && g_redirect != "") {
			window.location.href = "wx-auth.html" + "?g_redirect=" + g_redirect;
		} else {
			window.location.href = "wx-auth.html";
		}
	}
}

// web auth
function call_web() {
	rm_tips("all");
	$(".web-confirm,.mengban").show();
}

// sms auth
function call_sms() {
	rm_tips("all");
	$(".sms-confirm,.mengban").show();
}

// auto auth
function call_auto() {
	var params = window.location.search || "";
	var obj = {};
	obj.now = new Date().getTime();
	$.post(
		"/wxlogin2info" + params,
		obj,
		auto_action,
		"json"
	);
}

function web_action() {
	if (warn_web_user() == true) return;
	if (warn_web_pwd() == true) return;

	var params = window.location.search,
		username = $("#web_user").val(),
		password = $("#web_pwd").val();

	// var sarr = params.substring(1).split("&");
	// var obj = {}
	// for (var i = 0; i < sarr.length; i++) {
		// var tokens = sarr[i].split("=");
		// if (tokens.length == 2) {
			// obj[tokens[0]] = tokens[1];
		// }
	// }

	// if (!(obj.hasOwnProperty("mac") && obj.hasOwnProperty("ip"))) {
		// alert("非法参数！尝试重新加载！");
		// return;
	// }

	// var mac = obj.mac;
	// var ip = obj.ip;

	// var mac_reg = /^[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}$/;
	// var mac_reg2 = /^[0-9a-f]{2}-[0-9a-f]{2}-[0-9a-f]{2}-[0-9a-f]{2}-[0-9a-f]{2}-[0-9a-f]{2}$/;
	// var ip_reg = /^[1-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/
	// if (!((mac_reg.test(mac) || mac_reg2.test(mac)) && ip_reg.test(ip))) {
		// alert("非法参数！尝试重新加载！");
		// return;
	// }

	$.post(
		"/cloudlogin" + params,
		{
			username: username,
			password: password
			// mac: mac,
			// ip: ip
		},
		function(d) {
			if (d.status == 0) {
				$(".web-confirm .tips").html("<span style='color:green;'>登录成功！</span>");
				if (typeof d.data != "undefined" && d.data.substring(0, 4) == "http") {
					window.location.href = d.data;
				} else {
					window.location.href = "http://www.baidu.com";
				}
			} else {
				$(".web-confirm .tips").html("登录失败！" + (d.data ? d.data : ""));
			}
		},
		"json"
	);
}

function sms_action() {
	if (warn_sms_user() == true) return;
	if (warn_sms_pwd() == true) return;

	$.post(
		"/phonelogin",
		{
			"UserName": $("#sms_user").val(),
			"Password": $("#sms_pwd").val()
		},
		function (d) {
			if (d.status == 0) {
				$(".sms-confirm .tips").html("<span style='color:green;'>登录成功！</span>");
				if (typeof d.data != "undefined" && d.data.substring(0, 4) == "http") {
					window.location.href = d.data;
				} else {
					window.location.href = "http://www.baidu.com";
				}
			} else {
				$(".sms-confirm .tips").html("登录失败！");
			}
		},
		"json"
	);
}

function auto_action(data) {
	if (typeof data.Mac == "undefined" && typeof data.Extend == "undefined") {
		alert("登录失败！");
		return;
	}
	$.post(
		"/weixin2_login",
		{
			openId: "auto-" + data.Mac,
			extend: data.Extend
		},
		function(d) {
			if (d.status == 0) {
				if (typeof d.data != "undefined" && d.data.substring(0, 4) == "http") {
					window.location.href = d.data;
				} else {
					window.location.href = "http://www.baidu.com";
				}
			} else {
				alert("登录失败！");
			}
		},
		"json"
	);
}

function time_wait(wait) {
	if (wait == 0) {
		$("#sms_code").attr("disabled", false);
		$("#sms_code").html("获取验证码").removeClass("code-warn");
		wait = 60;
	} else {
		$("#sms_code").attr("disabled", true);
		$("#sms_code").html('重新发送' + wait).addClass("code-warn");
		wait--;
		setTimeout(function() {
			time_wait(wait)
		},
		1000)
	}
}

function sms_code() {
	if (warn_sms_user() == true) return;

	$.post(
		"/PhoneNo",
		{
			"UserName" : $("#sms_user").val()
		},
		function (d) {
			if (d.status == 0) {
				time_wait(60);
				$(".sms-confirm .tips").html("<span style='color:green;'>获取验证码成功</span>");
			} else {
				if (typeof d.data != "undefined") {
					$(".sms-confirm .tips").html("获取验证码失败！" + d.data);
				} else {
					$(".sms-confirm .tips").html("获取验证码失败！");
				}
			}
		},
		"json"
	)
}

function warn_web_user() {
	var val = $("#web_user").val();
	if ($.trim(val) == '') {
		$("#web_user").addClass("warn");
		$(".web-confirm .tips").html("请输入帐号");
		return true;
	}
	$("#web_user").removeClass("warn");
	$(".web-confirm .tips").html("");
	return false;
}

function warn_web_pwd() {
	var val = $("#web_pwd").val();
	if ($.trim(val) == '') {
		$("#web_pwd").addClass("warn");
		$(".web-confirm .tips").html("请输入密码");
		return true;
	}
	$("#web_pwd").removeClass("warn");
	$(".web-confirm .tips").html("");
	return false;
}

function warn_sms_user() {
	var val = $("#sms_user").val();
	var reg = /^1[3-8][0-9]\d{8}$/;

	if ($.trim(val) == '') {
		$("#sms_user").addClass("warn");
		$(".sms-confirm .tips").html("请输入手机号码");
		return true;
	} else if (!reg.test(val)) {
		$("#sms_user").addClass("warn");
		$(".sms-confirm .tips").html("手机号码格式不正确");
		return true;
	}
	$("#sms_user").removeClass("warn");
	$(".sms-confirm .tips").html("");
	return false;
}

function warn_sms_pwd() {
	var val = $("#sms_pwd").val();
	if ($.trim(val) == '') {
		$("#sms_pwd").addClass("warn");
		$(".sms-confirm .tips").html("请输入验证码");
		return true;
	}
	$("#sms_pwd").removeClass("warn");
	$(".sms-confirm .tips").html("");
	return false
}

function rm_tips(s) {
	if (s == "all") {
		$("#web_user, #web_pwd, #sms_user, #sms_pwd").removeClass("warn");
	} else {
		$(this).removeClass("warn");
	}
	$(".tips").html("");
}