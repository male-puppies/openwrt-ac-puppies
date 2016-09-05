$(function() {
	createInitModal();
	initEvents();
});

function createInitModal() {
	$("#modal_tips, #modal_spin").modal({
		"backdrop": "static",
		"show": false
	});
}

function DoReboot() {
	$("#modal_tips").modal("hide");
	$("#modal_tips").one("hidden.bs.modal", function() {
		cgicall.post("system_set", {"cmd": "reboot"}, function(d) {
			if (d.status == 0) {
				$("#modal_spin").modal("show");
				$.cookie('md5psw', '', {expires: -1, path: "/"});
				setTimeout(funcall, 12000);
			} else {
				createModalTips("重启失败！" + (d.data ? d.data : ""));
			}
		});
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

function initEvents() {
	$(".reboot").on("click", OnReboot);
}

function OnReboot() {
	createModalTips("是否确认进行重启？", "DoReboot");
}
