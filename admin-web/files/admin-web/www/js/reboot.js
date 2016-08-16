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
		ucicall("SysReboot", function(d) {
			$("#modal_spin").modal("show");
			$.cookie('token', '', {expires: -1, path: "/"});
			setTimeout(funcall, 12000);
		});
	});
}

function funcall() {
	setInterval(function() {
		ucicall("GetSystem", function(d) {
			setTimeout(function() {
				window.location.href = "/login/admin_login/login.html";
			}, 3000);
		});
	}, 5000);
}

function initEvents() {
	$(".reboot").on("click", OnReboot);
}

function OnReboot() {
	createModalTips("是否确认进行重启？", "DoReboot");
}
