
var g_post = {
	"switch": 0,
	"account": "",
	"ac_host": "",
	"desc": "",
	"ac_port": ""
};

$(function(){
	createInitModal();
	verifyEventsInit();
	initEvents();
	initData();
});

function createInitModal() {
	$("#modal_tips").modal({
		"backdrop": "static",
		"show": false
	});
}

function initData() {
	cgicall.get('cloud_get', function(d) {
		if (d.status == 0) {
			g_post.ac_port = d.data.ac_port || "";
			jsonTraversal(d.data, jsTravSet);
			if (typeof d.data.state != "undefined" && d.data.state == 1) {
				$(".connet-account").css("color", "#4cae4c").find("p").html("已连接 " + d.data.host);
			} else {
				$(".connet-account").css("color", "#d9534f").find("p").html("未连接");
			}
		}
	})
}

function initEvents() {
	$('.submit').on('click', saveConf);
}

function saveConf() {
	if (!verification()) return false;

	var obj = jsonTraversal(g_post, jsTravGet);
	if (typeof obj.ac_host != "undefined") {
		obj.ac_host = $.trim(obj.ac_host)
	}
	cgicall.post('cloud_set', obj, function(d) {
		if (d.status == 0) {
			initData();
			createModalTips("保存成功！");
		} else {
			createModalTips("保存失败！" + (d.data ? d.data : ""));
		}
	});
}
