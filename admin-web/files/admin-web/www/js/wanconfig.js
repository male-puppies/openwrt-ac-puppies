var g_lanarr = [];
var g_getvalue = {
	"dhcp": {
		"metric": "",
		"macaddr": "",
		"mtu": ""
	},
	"pppoe": {
		"username": "",
		"password": "",
		"metric": "",
		"macaddr": "",
		"mtu": ""
	},
	"static": {
		"ipaddr": "",
		"netmask": "",
		"gateway": "",
		"dns": "",
		"metric": "",
		"macaddr": "",
		"mtu": ""
	}
}
$(function() {
	createInitModal();
	verifyEventsInit();
	initEvents();
	initData();
	setInitMac("11:22:33:11:22:ff")
});

function createInitModal() {
	$("#modal_tips, #modal_spin").modal({
		"backdrop": "static",
		"show": false
	});
}

function initData() {
	ucicall("GetWanconfig", function(d) {
		if (d.status == 0 && typeof d.data == "object") {
			var data = d.data;
			g_lanarr = data.lan ? dtObjToArray(data.lan) : [];
			// var length = ObjCountLength(data);
			setRadios(data);
			$("input.empty").val("");
			for (var k in data) {
				if (typeof data[k] == "object" && "dns" in data[k]) {
					data[k]["dns"] = data[k]["dns"].replace(/\ /g, ",");
				}
			}
			jsonTraversal(data, jsTravSet);
			OnWan();
			setInitMac(data.initmac);
		} else {
			createModalTips("初始化失败！请尝试重新加载！");
		}
	});
}

function setInitMac(mac) {
	var reg = /^([0-9a-fA-F]{2}(:)){5}[0-9a-fA-F]{2}$/;
	if (!reg.test(mac)) return;

	var arr = mac.split(":");
	if (typeof arr[5] == "undefined") return;
	var qmac = arr[0] + ":" + arr[1] + ":" + arr[2] + ":" + arr[3] + ":" + arr[4] + ":";

	if ($("#wan0__macaddr").val() == "") {
		$("#wan0__macaddr").val(qmac + madd(arr[5], 4));
	}
	if ($("#wan1__macaddr").val() == "") {
		$("#wan1__macaddr").val(qmac + madd(arr[5], 3));
	}
	if ($("#wan2__macaddr").val() == "") {
		$("#wan2__macaddr").val(qmac + madd(arr[5], 2));
	}
	if ($("#wan3__macaddr").val() == "") {
		$("#wan3__macaddr").val(qmac + madd(arr[5], 1));
	}
	
	function madd(a, b) {
		var num = parseInt(a, 16) + parseInt(b);
		var str = num.toString(16);
		if (str.length == 1) {
			return "0" + str;
		} else if (str.length == 2) {
			return str;
		} else if (str.length == 3) {
			return str.substring(1);
		} else {
			return "00";
		}
	}
}

function initEvents() {
	$("input[name='radio_wan']").on("click", OnWan);
	$("input[name=wan0__proto], input[name=wan1__proto], input[name=wan2__proto], input[name=wan3__proto]").on("change", OnProtocol);
	$(".submit").on("click", OnSubmit);
	$(".showlock").on("click", OnShowlock);
	OnWan();
	$('[data-toggle="tooltip"]').tooltip();
}

function OnWan() {
	var value = $("input[name='radio_wan']:checked").val();
	for (var i = 0; i < 4; i++) {
		if (i < parseInt(value)) {
			$(".wan" + i).show().find("input").prop("disabled", false);
		} else {
			$(".wan" + i).hide().find("input").prop("disabled", true);
		}
	}
	
	OnProtocol();
}

function OnProtocol() {
	for (var i = 0; i < 4; i++) {
		var value = $("input[name='wan" + i + "__proto']:checked").val();
		if (value === "dhcp") {
			$(".wan" + i + "-pppoe, .wan" + i + "-static").hide().find("input").prop("disabled", true);
		} else if (value === "pppoe") {
			$(".wan" + i + "-pppoe").show();
			if ($(".wan" + i + "-pppoe input").is(":visible")) {
				$(".wan" + i + "-pppoe input").prop("disabled", false);
			}
			// $(".wan" + i + "-pppoe").show().find("input").prop("disabled", false);
			$(".wan" + i + "-static").hide().find("input").prop("disabled", true);
		} else if (value === "static") {
			$(".wan" + i + "-static").show();
			if ($(".wan" + i + "-static input").is(":visible")) {
				$(".wan" + i + "-static input").prop("disabled", false);
			}
			
			$(".wan" + i + "-pppoe").hide().find("input").prop("disabled", true);
			// $(".wan" + i + "-static").show().find("input").prop("disabled", false);
		}
	}
}

function OnSubmit() {
	if (!verification()) return;

	var value = $("input[name='radio_wan']:checked").val();
	if (parseInt(value) > 1) {
		var sameip = [];
		var sameic = [];
		var samemac = [];
		for (var v = 0; v < parseInt(value); v++) {
			if ($("#wan" + v + "__metric").val() == "" && !($("#wan" + v + "__metric").is(":disabled"))) {
				createModalTips("当启用多个WAN口时，跃点数不能为空！请重新输入！");
				return;
			}
			if (!($("#wan" + v + "__ipaddr").is(":disabled"))) {
				sameip.push($("#wan" + v + "__ipaddr").val());
			}
			if (!($("#wan" + v + "__metric").is(":disabled"))) {
				sameic.push($("#wan" + v + "__metric").val());
			}
			if (!($("#wan" + v + "__macaddr").is(":disabled"))) {
				samemac.push($("#wan" + v + "__macaddr").val());
			}
		}
		if (isRepeat(sameip)) {
			createModalTips("IP地址不能相同！");
			return;
		}
		if (isRepeat(sameic)) {
			createModalTips("跃点数不能相同！");
			return;
		}
		if (isRepeat(samemac)) {
			createModalTips("MAC地址不能相同！");
			return;
		}
	}
	
	//根据wan口数量 获取可能会被移除lan的配置
	var delLan = [];
	for (var k = (5 - value); k <= 3; k++) {
		for (var j = 0; j < g_lanarr.length; j++) {
			if ("lan" + k == g_lanarr[j]) {
				delLan.push(g_lanarr[j])
			}
		}
	}
	
	if (delLan.length == 0) {
		DoSubmit(true);
	} else {
		var str = delLan.join(" ");
		createModalTips(str + "已被启用！该操作将会使其禁用！<br>是否确认保存！", "DoSubmit");
	}
}

function DoSubmit(t) {
	var obj = {};
	var value = $("input[name='radio_wan']:checked").val();
	
	for (var i = 0; i < parseInt(value); i++) {
		var proto = $("input[name='wan" + i + "__proto']:checked").val();
		var tmp = obj["wan" + i] || {}
		tmp["proto"] = proto;
		tmp["ifname"] = "eth0." + (5 - i);
		if (proto in g_getvalue) {
			for (var k in g_getvalue[proto]) {
				if (k == "metric" || k == "macaddr" || k == "mtu") {
					var val = $("#wan" + i + "__" + k).val();
					if (typeof val != "undefined" && val != "") {
						tmp[k] = $("#wan" + i + "__" + k).val();
					}
				} else if (k == "dns") {
					tmp[k] = $("#wan" + i + "__" + k).val().replace(/\,/g, " ");
				} else {
					tmp[k] = $("#wan" + i + "__" + k).val();
				}
			}
			obj["wan" + i] = tmp;
		}
	}
	
	if (t == true) {
		submits();
	} else {
		$("#modal_tips").modal("hide");
		$("#modal_tips").one("hidden.bs.modal", function() {
			submits();
		});
	}
	
	function submits() {
		$("#modal_spin").modal("show");
		ucicall("SetWanconfig", obj, function(d) {
			var func = {
				"sfunc": function() {
					initData();
					createModalTips("保存成功！");
				},
				"ffunc": function() {
					createModalTips("保存失败！" + (d.data ? d.data : ""));
				}
			}
			cgicallBack(d, "#modal_spin", func);
		});
	}
}

function setRadios(data) {
	if (typeof data == "object") {
		var j = 0;
		for (var i = 0; i < 4; i++) {
			var wan = "wan" + i;
			if (wan in data) {
				j++;
			}
		}

		$("input[name='radio_wan']").each(function(index, element) {
			if ($(element).attr("value") == j) {
				$(element).prop("checked", true);
			}
		});
	}
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

function isRepeat(arr) {
	var hash = {};
	for(var i in arr) {
		if (hash[arr[i]]) return true;
		hash[arr[i]] = true;
	}
	return false;
}
