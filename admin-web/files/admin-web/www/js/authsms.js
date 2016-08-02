
var g_post = {
	"sms": "",
	"type": "",
	"sno": "",
	"pwd": "",
	"sign": "",
	"msg": ""
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
	cgicall('SmsList', function(d) {
		if (d.status == 0) {
			jsonTraversal(d.data, jsTravSet);
			setExpire(d.data);
			if (typeof d.data.switch != "undefined" && d.data.switch == "1") {
				$(".account-tips").show();
				$(".form-group input, .form-group select, .form-group textarea").prop("disabled", true);
			} else {
				$(".account-tips").hide();
				$(".form-group input:not('#counter__success,#counter__fail'), .form-group select, .form-group textarea").prop("disabled", false);
			}
		}
	})
}

function setExpire(d) {
	var num = parseInt(d.expire);
	$("#expire1").val(parseInt(num/1440));
	$("#expire2").val(parseInt((num%1440)/60));
	$("#expire3").val(parseInt(num%60));
}

function initEvents() {
	$('.submit').on('click', saveConf);
	$(".showlock").on("click", OnShowlock);
	$(".smsreset").on("click", OnSmsreset)
	$('[data-toggle="tooltip"]').tooltip();
}

function saveConf() {
	if (!verification()) return false;
	
	var obj = jsonTraversal(g_post, jsTravGet);
	obj.expire = parseInt($("#expire1").val())*1440 + parseInt($("#expire2").val())*60 + parseInt($("#expire3").val());
	cgicall('SmsSet', obj, function(d) {
		if (d.status == 0) {
			initData();
			createModalTips("保存成功！");
		} else {
			createModalTips("保存失败！");
		}
	});
}

function OnSmsreset() {
	cgicall('SmsResetCounter', function(d) {
		if (d.status == 0) {
			initData();
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