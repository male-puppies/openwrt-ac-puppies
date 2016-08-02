var g_getvalue = {
	"ipaddr": "",
	"netmask": ""
}
var g_getdhcp = {
	"start": "",
	"limit": "",
	"leasetime": "",
	"dhcp_option": "",
}

$(function() {
	createInitModal();
	verifyEventsInit();
	initEvents();
	initData();
});

function createInitModal() {
	$("#modal_tips, #modal_spin").modal({
		"backdrop": "static",
		"show": false
	});
}

function initData() {
	ucicall("GetLanconfig", function(d) {
		if (d.status == 0 && typeof d.data == "object" && typeof d.data.dhcp == "object") {
			var data = d.data;
			setLan(data);
			jsonTraversal(data, jsTravSet);
			OnChangeMask();
		} else {
			createModalTips("初始化失败！请尝试重新加载！");
		}
	})
}

function setLan(data) {
	if (typeof data == "object") {
		for (var i = 0; i < 4; i++) {
			var lan = "lan" + i;
			//dhcp
			if (lan in data.dhcp) {
				$("." + lan + " .denable").prop("checked", true);

				var dhcp_option = data.dhcp[lan]["dhcp_option"];
				if (typeof dhcp_option != "undefined" && dhcp_option.substring(0, 2) == "6,") {
					data.dhcp[lan]["dhcp_option"] = dhcp_option.substring(2, dhcp_option.length);
				}
				
				var leasetime = data.dhcp[lan]["leasetime"];
				if (typeof leasetime != "undefined" && leasetime.substring(leasetime.length-1, leasetime.length) == "h") {
					data.dhcp[lan]["leasetime"] = leasetime.substring(0, leasetime.length - 1);
				}
				
				if (typeof data.dhcp[lan]["ignore"] != "undefined" && data.dhcp[lan]["ignore"] == "1") {
					$("." + lan + " .denable").prop("checked", false);
				} else {
					$("." + lan + " .denable").prop("checked", true);
				}
				
				
			} else {
				$("." + lan + " .denable").prop("checked", false);
			}
			//lan
			if (lan in data) {
				$("." + lan + " .enable").prop("checked", true);
				OnEnable();
			} else {
				$("." + lan + " .enable").prop("checked", false);
				OnEnable();
			}
		}

		var num = parseInt(data.wan.length) || 1
		if (num > 1 && num < 5) {
			$(".enable").prop("disabled", false);
			for (var k = 5 - num; k < 4; k++) {
				$(".lan" + k + " .title b").html("该口已被WAN占用");
				$(".lan" + k + " .enable").prop("disabled", true);
				$(".lan" + k).find("input").prop("disabled", true);
			}
		}
	}
}

function initEvents() {
	$(".submit").on("click", OnSubmit)
	$(".wrapper-oth").hide();
	$(".main-wrapper.other > .main-top").on("click", OnSHide);
	$("#lan1__enable, #lan2__enable, #lan3__enable").on("click", function() { OnEnable(this); });
	$("#lan0__dhcp_enable, #lan1__dhcp_enable, #lan2__dhcp_enable, #lan3__dhcp_enable").on("click", function() { OnDhcpEnable(this); });
	$("#lan0__netmask, #lan1__netmask, #lan2__netmask, #lan3__netmask").on("blur keyup", function() { OnChangeMask(this); })
	OnEnable();
	
	$('[data-toggle="tooltip"]').tooltip();
}

function OnSubmit() {
	if (!verification()) return;
	var sameip = [];
	for (var i = 0; i < 4; i++) {
		if (!($("#lan" + i + "__ipaddr").is(":disabled"))) {
			sameip.push($("#lan" + i + "__ipaddr").val())
		}
	}

	if (isRepeat(sameip)) {
		createModalTips("IP地址不能相同！");
		return;
	}

	var mark = true;
	$("#lan0__netmask, #lan1__netmask, #lan2__netmask, #lan3__netmask").each(function(index, element) {
		var num = verifys(element);
		var nums = 0;
		$(element).closest("form.form-horizontal").find(".verifymask").each(function(i, e) {
			nums += parseInt($(e).val());
		});
		
		if (nums > num) {
			createModalTips("lan" + index + " 的DHCP因 起始分配基址 和 客户数 而超出IP分配范围，请重新填写！");
			mark = false;
			return false;
		}
	});
	console.log(mark)
	if (!mark) return;
	

	var obj = {};
	obj["dhcp"] = {};
	obj["lan0"] = {
		"ifname": 'eth0.1',
		"proto": "static",
		"ipaddr": $("#lan0__ipaddr").val(),
		"netmask": $("#lan0__netmask").val()
	}
	for (var i = 1; i < 4; i++) {
		var query = $("#lan" + i + "__enable");
		if (!(query.is(":disabled")) && query.is(":checked")) {
			var tmp = obj["lan" + i] || {};
			tmp["ifname"] = "eth0." + (i+1);
			tmp["proto"] = "static";
			for (var k in g_getvalue) {
				tmp[k] = $("#lan" + i + "__" + k).val();
			}
			obj["lan" + i] = tmp;
		}
	}
	
	for (var j = 0; j < 4; j++) {
		var dquery = $("#lan" + j + "__dhcp_enable");
		
		if (!(dquery.is(":disabled"))) {
			var dtmp = obj["dhcp"]["lan" + j] || {};
			dtmp["interface"] = "lan" + j;

			if (dquery.is(":checked")) {
				for (var key in g_getdhcp) {
					var value = $("#dhcp__lan" + j + "__" + key).val();
					if (typeof value != "undefined" && value != "") {
						if (key == "dhcp_option") {
							dtmp[key] = "6," + $("#dhcp__lan" + j + "__" + key).val();
						} else if (key == "leasetime") {
							dtmp[key] = $("#dhcp__lan" + j + "__" + key).val() + "h";
						} else {
							dtmp[key] = $("#dhcp__lan" + j + "__" + key).val();
						}
					}
				}
			} else {
				dtmp["ignore"] = "" + 1;
			}
			
			obj["dhcp"]["lan" + j] = dtmp;
		}
	}

	$("#modal_spin").modal("show");
	ucicall("SetLanconfig", obj, function(d) {
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

function OnSHide() {
	if ($(".wrapper-oth").is(":hidden")) {
		$(".other .icon-double-angle-down").removeClass("icon-double-angle-down").addClass("icon-double-angle-up");
		$(".wrapper-oth").slideDown(500);
	} else {
		$(".other .icon-double-angle-up").removeClass("icon-double-angle-up").addClass("icon-double-angle-down");
		$(".wrapper-oth").slideUp(500);
	}
}

function OnChangeMask(that) {
	if (typeof that != "undefined") {
		nodeChange(that);
	} else {
		$("#lan0__netmask, #lan1__netmask, #lan2__netmask, #lan3__netmask").each(function(index, element) {
			nodeChange(element);
		});
	}
	
	function nodeChange(that) {
		var num = verifys(that);
		$(that).closest(".form-group").nextAll().find(".verifymask").attr("verify", "num 1 " + num);
		verifyEventsInit();
		$(that).closest(".form-group").nextAll().find(".verifymask").closest(".form-group").find(".icon-tip").attr("data-original-title", "输入数字1~" + num + "。");
	}
}

function OnEnable(that) {
	if (typeof that != "undefined") {
		checked(that)
	} else {
		$("#lan1__enable, #lan2__enable, #lan3__enable").each(function(index, element) {
			checked(element);
		});
	}
	
	function checked(_that) {
		if ($(_that).is(":checked") && !($(_that).is(":disabled"))) {
			$(_that).parents(".form-group").nextAll().find("input").prop("disabled", false);
			OnDhcpEnable();
			// $(_that).parents("form.form-horizontal").find("input:not('.enable')").prop("disabled", false);
		} else {
			// $(_that).parents("form.form-horizontal").find("input:not('.enable')").prop("disabled", true);
			$(_that).parents(".form-group").nextAll().find("input").prop("disabled", true);
			OnDhcpEnable();
		}
	}
}

function OnDhcpEnable(that) {
	if (typeof that != "undefined") {
		checked(that)
	} else {
		$("#lan0__dhcp_enable, #lan1__dhcp_enable, #lan2__dhcp_enable, #lan3__dhcp_enable").each(function(index, element) {
			checked(element);
		});
	}
	
	function checked(_that) {
		if ($(_that).is(":checked") && !($(_that).is(":disabled"))) {
			$(_that).parents(".form-group").nextAll().find("input[type='text']").prop("disabled", false);
		} else {
			$(_that).parents(".form-group").nextAll().find("input[type='text']").prop("disabled", true);
		}
	}
}

function ipToint(ip) {
	var num = 0;
    ip = ip.split(".");
    num = Number(ip[0]) * 256 * 256 * 256 + Number(ip[1]) * 256 * 256 + Number(ip[2]) * 256 + Number(ip[3]);
    num = num >>> 0;
    return num;
}

function verifys(that) {
	var val = $(that).val();
	if (!verifyMask(val)) return;
	for (var i = 31; i >= 0; i--) {
		if (((1 << i) & ipToint(val)) == 0) {
			num = Math.pow(2,i + 1) - 2;
			return num;
		}
	}
}

function verifyMask(val) {
	var reg = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
	if (!reg.test(val)) {
		return false;
	}
	var m = [],
		mn = val.split(".");
	
	if(val == "0.0.0.0" || val == "255.255.255.255"){
		return true;
	}
	if (mn.length == 4) {
		for (i = 0; i < 4; i++) {
			m[i] = mn[i];
		}
	} else {
		return false;
	}

	var v = (m[0]<<24)|(m[1]<<16)|(m[2]<<8)|(m[3]);

	var f = 0;	  
	for (k = 0; k < 32; k++) {
		if ((v >> k) & 1) {
			f = 1;
		} else if (f == 1) {
			return false ;
		}
	}
	if (f == 0) { 
		return false;
	}

	for(i = 0; i < 4; i++) {
		var t = /^\d{1,}$/;
		if(!t.test(mn[i])) {
			return false;
		}	
	}
	
	return true;
}

function isRepeat(arr) {
	var hash = {};
	for(var i in arr) {
		if (hash[arr[i]]) return true;
		hash[arr[i]] = true;
	}
	return false;
}
