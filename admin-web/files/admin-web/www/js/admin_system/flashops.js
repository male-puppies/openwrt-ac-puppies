
$(function() {
	createInitModal();
	verifyEventsInit();
	initEvents();
});

function createInitModal() {
	$("#modal_tips, #modal_spin").modal({
		"backdrop": "static",
		"show": false
	});
}

function restoreFunc(d) {
	$("#modal_spin").modal("hide");
	$("#modal_spin").one("hidden.bs.modal", function() {
		if (d.status == 0) {
			createModalTips("上传成功！恢复配置将会重启设备。</br>是否确认恢复配置？", "DoRestore");
		} else {
			createModalTips("上传失败！" + (d.data ? d.data : ""));
		}
	});
}

function brushFunc(d) {
	$("#modal_spin").modal("hide");
	$("#modal_spin").one("hidden.bs.modal", function() {
		if (d.status == 0) {
			var md5 = d.data.md5;
			var size = parseInt(d.data.size);
			if (size < 1000) {
				size = d + "B";
			} else if (size > 1000 && size < 1000000) {
				size = toDecimal(size / 1000) + "KB";
			} else {
				size = toDecimal(size / 1000000) + "MB";
			}

			createModalTips("上传成功！下面是效验值和文件的大小，请与原文件进行比较，以确保数据的完整性。点击“确定”，开始刷写固件。</br><span style='color:#666;font-size:14px'>效验值：" + md5 + "</span></br><span style='color:#666;font-size:14px'>文件大小：" + size + "</span>", "DoBrush");
		} else {
			createModalTips("上传失败！" + (d.data ? d.data : ""));
		}
	});
}

function funcall() {
	setInterval(function() {
		var obj = {
			username: "",
			password: ""
		}

		cgicall.get("login", obj, function(d) {
			setTimeout(function() {
				window.location.href = "/view/admin_login/tologin.html";
			}, 1000);
		});
	}, 5000);
}

function DoRestore() {
	$("#modal_tips").modal("hide");
	$("#modal_tips").one("hidden.bs.modal", function() {
		$("#modal_spin .modal-body p").html("正在恢复配置！<br>请稍候...");
		$("#modal_spin").modal("show");
	});
	cgicall.post("system_restore", function(d) {
		if (d.status == 0) {
			$.cookie('login_pwd', '', {expires: -1, path: "/"});
			setTimeout(funcall, 12000);
		} else {
			createModalTips("恢复配置失败！" + (d.data ? d.data : ""));
		}
	});
}

function DoBrush() {
	var keep = $("#keep").is(":checked") ? "1" : "0";
	$("#modal_tips").modal("hide");
	$("#modal_tips").one("hidden.bs.modal", function() {
		$("#modal_spin .modal-body p").html("Loading...");
		$("#modal_spin").modal("show");

		cgicall.post("system_upgrade", {"keep": keep}, function(d) {
			if (d.status == 0) {
				$("#modal_spin .modal-body p").html("正在进行升级！<br>请稍候...");
				$("#modal_spin").modal("show");
				$.cookie('login_pwd', '', {expires: -1, path: "/"});
				setTimeout(funcall, 12000);
			} else {
				$("#modal_spin").modal("hide");
				$("#modal_spin").one("hidden.bs.modal", function() {
					createModalTips("升级失败！请确认选择的文件无误！");
				});
				return false;
			}
		});
	});
}

function DoReset() {
	$("#modal_tips").modal("hide");
	$("#modal_tips").one("hidden.bs.modal", function() {
		$("#modal_spin .modal-body p").html("正在还原配置并重启设备！<br>请稍候...");
		$("#modal_spin").modal("show");
	});

	cgicall.post("system_set", {cmd: "reset"}, function(d) {
		if (d.status == 0) {
			$.cookie('login_pwd', '', {expires: -1, path: "/"});
			setTimeout(funcall, 12000);
		} else {
			createModalTips("还原配置失败！" + (d.data ? d.data : ""));
		}
	});
}

function initEvents() {
	$(".backup").on("click", OnBackup);
	$(".restore").on("click", OnRestore);
	$(".reset").on("click", OnReset);
	$(".brush").on("click", OnBrush);

	$('[data-toggle="tooltip"]').tooltip();
}

function OnBackup() {
	var version = "/v1/admin/api/",
		token = $.cookie("token") ? "?token=" + $.cookie("token") : "?";

	window.location.href = version + "system_backup" + token + "&_=" + new Date().getTime();
}

function OnRestore() {
	if (!verification("#restore")) return false;

	var options = {
		url: cgiDtUrl("system_backupload"),		//form提交数据的地址
		type: "post",							//form提交的方式(method:post/get)
		dataType: "json",						//服务器返回数据类型
		clearForm: false,						//提交成功后是否清空表单中的字段值
		restForm: false,						//提交成功后是否重置表单中的字段值，即恢复到页面加载时的状态
		timeout: 30000,							//设置请求时间，超过该时间后，自动退出请求，单位(毫秒)。
		beforeSubmit: function(d) {},			//提交前执行的回调函数
		success: function(d) {restoreFunc(d)}	//提交成功后执行的回调函数
	};

	$("#modal_spin .modal-body p").html("正在上传！<br>请稍候...");
	$("#modal_spin").modal("show");
	$("#restore").ajaxSubmit(options);
	return false;
}

function OnReset() {
	createModalTips("恢复出厂将会还原所有配置并重启设备。</br>是否确认恢复出厂配置？", "DoReset");
}

function OnBrush() {
	if (!verification("#brush")) return false;

	var options = {
		url: cgiDtUrl("system_upload"),
		type: "post",
		dataType: "json",
		clearForm: false,
		restForm: false,
		timeout: 30000,
		beforeSubmit: function(d) {},
		success: function(d) {brushFunc(d)}
	};

	$("#modal_spin .modal-body p").html("正在上传！<br>请稍候...");
	$("#modal_spin").modal("show");
	$("#brush").ajaxSubmit(options);
	return false;
}

function toDecimal(x) {
	var f = parseFloat(x);
	if (isNaN(f)) {
		return;
	}
	f = Math.round(x*100)/100;
	return f;
}
