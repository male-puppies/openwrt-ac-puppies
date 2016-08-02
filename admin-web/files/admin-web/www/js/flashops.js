
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

function upFunc(d) {
	$("#modal_spin").modal("hide");
	$("#modal_spin").one("hidden.bs.modal", function() {
		if (d.status == 0) {
			createModalTips("上传成功！恢复配置将会重启设备。</br>是否确认恢复配置？", "DoUpload");
		} else {
			createModalTips("上传失败！" + (d.data ? d.data : ""));
		}
	});
}

function brushFunc(d) {
	$("#modal_spin").modal("hide");
	$("#modal_spin").one("hidden.bs.modal", function() {
		if (d.status == 0) {
			createModalTips("上传成功！升级刷写新的固件将会重启设备。</br>是否确认进行升级？", "DoBrush");
		} else {
			createModalTips("上传失败！" + (d.data ? d.data : ""));
		}
	});
}

function funcall() {
	setInterval(function() {
		var cmd = {
			"key": "Login",
			"data": {
				"username": "",
				"password": ""
			}
		}
		$.post(
			"/logincall",
			{
				"cmd": JSON.stringify(cmd)
			},
			function(d) {
				if (typeof d == "object" && typeof d.data != "undefined") {
					if (d.data.indexOf("failed") >= 0 || d.data.indexOf("error") >= 0 || d.data.indexOf("timeout") >= 0) {
						console.log("continue...");
					} else {
						setTimeout(function() {
							window.location.href = "/login/admin_login/login.html";
						}, 6000);
					}
				}
			},
			"json"
		);
	}, 5000);
}

function DoUpload() {
	$("#modal_tips").modal("hide");
	$("#modal_tips").one("hidden.bs.modal", function() {
		$("#modal_spin .modal-body p").html("正在恢复配置！<br>请稍候...");
		$("#modal_spin").modal("show");
	});
	ucicall("UploadBackup", function(d) {
		$.cookie('md5psw', '', {expires: -1, path: "/"});
		setTimeout(funcall, 12000);
	});
	
}

function DoBrush() {
	var keep = $("#keep").is(":checked") ? "1" : "0";
	$("#modal_tips").modal("hide");
	$("#modal_tips").one("hidden.bs.modal", function() {
		$("#modal_spin .modal-body p").html("Loading...");
		$("#modal_spin").modal("show");
		
		ucicall("UploadBrush", {"keep": keep}, function(d) {
			if (d.status == 1 && d.data == "badupload") {
				$("#modal_spin").modal("hide");
				$("#modal_spin").one("hidden.bs.modal", function() {
					createModalTips("升级失败！不支持所上传的文件，请确认选择的文件无误！");
				});
				return false;
			} else {
				$("#modal_spin .modal-body p").html("正在进行升级！<br>请稍候...");
				$("#modal_spin").modal("show");
				$.cookie('md5psw', '', {expires: -1, path: "/"});
				setTimeout(funcall, 12000);
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

	ucicall("ConfReset", function(d) {
		$.cookie('md5psw', '', {expires: -1, path: "/"});
		setTimeout(funcall, 12000);
	});
}

function DoOnlineup() {
	$("#modal_tips").modal("hide");
	$("#modal_tips").one("hidden.bs.modal", function() {
		cgicall("ACUpgrade", function(d) {
			if (d.status == 0) {
				$("#modal_spin .modal-body p").html("正在下载最新固件，成功后将会自动升级！<br>请稍候...");
				$("#modal_spin").modal("show");
			} else {
				createModalTips("在线升级失败！");
			}
		});
	});
}

function initEvents() {
	$(".download").on("click", OnDownload);
	$(".upload").on("click", OnUpload);
	$(".reset").on("click", OnReset);
	$(".brush").on("click", OnBrush);
	$(".checkver").on("click", OnCheckver);
	$(".onlineup").on("click", OnOnlineup);
	
	$('[data-toggle="tooltip"]').tooltip();
}

function OnDownload() {
	ucicall("DownloadBackup", function(d) {
		if (d.status == 0 && typeof d.data != "undefined") {
			var str = d.data;
			window.location.href = "/tmp/" + str;
		}
	})
}

function OnUpload() {
	if (!verification("#backup")) return false;
	
	var options = {
		url: "/call/upload",				//form提交数据的地址
		type: "post",						//form提交的方式(method:post/get)
		dataType: "json",					//服务器返回数据类型
		clearForm: false,					//提交成功后是否清空表单中的字段值
		restForm: false,					//提交成功后是否重置表单中的字段值，即恢复到页面加载时的状态
		timeout: 30000,						//设置请求时间，超过该时间后，自动退出请求，单位(毫秒)。　
		beforeSubmit: function(d) {},		//提交前执行的回调函数
		success: function(d) {upFunc(d)}	//提交成功后执行的回调函数
	};
	
	$("#modal_spin .modal-body p").html("正在上传！<br>请稍候...");
	$("#modal_spin").modal("show");
	$("#backup").ajaxSubmit(options);
	return false;
}

function OnReset() {
	createModalTips("恢复出厂将会还原所有配置并重启设备。</br>是否确认恢复出厂配置？", "DoReset");
}

function OnBrush() {
	if (!verification("#brush")) return false;
	
	var options = {
		url: "/call/upload",
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

function OnCheckver() {
	$("#modal_spin .modal-body p").html("检测中...");
	$("#modal_spin").modal("show");

	cgicall("ACChkNew", function(d) {
		if (d.status == 0 && d.data != "") {
			$("#modal_spin").modal("hide");
			$("#modal_spin").one("hidden.bs.modal", function() {
				$(".ospan").html(d.data);
				$(".ononline").show();
			});
		} else {
			$("#modal_spin").modal("hide");
			$("#modal_spin").one("hidden.bs.modal", function() {
				createModalTips("已是最新版本！");
				$(".ononline").hide();
			});
		}
	})
}

function OnOnlineup() {
	createModalTips("在线升级会在后台下载固件文件，成功后会自动进行升级并重启设备。</br>是否确认进行在线升级？", "DoOnlineup");
}
