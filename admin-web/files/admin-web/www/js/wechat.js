
var g_post = {
	"wx": "",
	"shop_name": "",
	"ssid": "",
	"shop_id": "",
	"appid": "",
	"secretkey": ""
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
	cgicall('WxShopList', function(d) {
		if (d.status == 0) {
			jsonTraversal(d.data, jsTravSet);
			if (typeof d.data.switch != "undefined" && d.data.switch == "1") {
				$(".account-tips").show();
				$(".form-group input").prop("disabled", true);
			} else {
				$(".account-tips").hide();
				$(".form-group input").prop("disabled", false);
			}
			OnWx();
		}
	})
}

function initEvents() {
	$('.submit').on('click', saveConf);
	$('#wx').on('click', OnWx);
	$('[data-toggle="tooltip"]').tooltip();
}

function saveConf() {
	if (!verification()) return false;
	
	var obj = jsonTraversal(g_post, jsTravGet);
	cgicall('WxShopSet', obj, function(d) {
		if (d.status == 0) {
			initData();
			createModalTips("保存成功！");
		} else {
			createModalTips("保存失败！");
		}
	});
}

function OnWx() {
	var that = $("#wx");
	if (that.is(":checked") && !that.is(":disabled")) {
		that.closest(".form-group").siblings().find("input").prop("disabled", false);
	} else {
		that.closest(".form-group").siblings().find("input").prop("disabled", true);
	}
}
