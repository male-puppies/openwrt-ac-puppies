var g_getvalue = {
	"interface": {
		"enabled": "1",
		"reliability": "1",
		"count": "1",
		"timeout": "2",
		"interval": "5",
		"down": "3",
		"up": "3"
	},
	"member": {
		"interface": "",
		"metric": "",
		"weight": "",
	},
	"policy": {
		"use_member": "",
		"last_resort": "default",
	},
	"rule": {
		"proto": "all",
		"sticky": "0",
		"use_policy": "",
	}
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
	ucicall("GetWanconfig", function(d) {
		if (d.status == 0) {
			for (var i = 0; i < 4; i++) {
				var wan = "wan" + i;
				if (wan in d.data) {
					$("." + wan).show().find("input");
				} else {
					$("." + wan).hide().find("input").prop("disabled", true);
				}
			}
			
			ucicall("GetMwan", function(data) {
				if (data.status == 0 && typeof data.data == "object") {
					setMwan(data.data);
					OnEnable();
					OnRadios();
				} else {
					createModalTips("初始化失败！请尝试重新加载！");
				}
			});
		} else {
			createModalTips("初始化失败！请尝试重新加载！");
		}
	});
}

function setMwan(d) {
	if (typeof d["rule"] == "undefined" || typeof d["policy"] == "undefined" || typeof d["member"] == "undefined" || typeof d["interface"] == "undefined") return;
	
	var rule; //获取规则里的应用策略名，默认用rule_default，否则随机
	for (var key in d["rule"]) {
		if (key == "rule_default") {
			rule = d["rule"][key].use_policy;
			break;
		} else {
			rule = d["rule"][key].use_policy;
		}
	}
	
	var use_member = d["policy"][rule]["use_member"] || []; //获取策略名中应用的成员
	if (use_member.length == 0) {
		console.log("use_member 为空");
		return;
	}
	
	var metric = true; //用于判断策略配置
	$(".enable").prop("checked", false);
	for (var i = 0; i < use_member.length; i++) {
		var m = use_member[i];
		if (typeof d["member"][m] == "undefined") continue;
		
		var mem = d["member"][m];
		var enable = $("." + mem["interface"] + " .enable");

		if (!(enable.is(":disabled"))) {
			enable.prop("checked", true);
			$("#" + mem["interface"]).val(mem["weight"]);
		} else {
			enable.prop("checked", false);
		}
		
		
		if (mem["metric"] != 1) {
			metric = false;
		}
	}
	
	if (metric == true) {
		$("input[name='rule'][value='average']").prop("checked", true);
	} else {
		$("input[name='rule'][value='backup']").prop("checked", true);
		for (var i = 0; i < use_member.length; i++) {
			var m = use_member[i];
			if (typeof d["member"][m] == "undefined") continue;
			
			var mem = d["member"][m];
			if (mem["metric"] == 1) {
				$("input[name='wan" + i + "'][value='1']").prop("checked", true);
			} else {
				$("input[name='wan" + i + "'][value='2']").prop("checked", true);
			}
		}
	}
}

function initEvents() {
	$(".enable").on("click", function() { OnEnable(this) });
	$("input[name='rule']").on("click", OnRadios);
	$(".submit").on("click", OnSubmit);
	OnEnable();
	$('[data-toggle="tooltip"]').tooltip();
}

function OnSubmit() {
	if (!verification()) return;

	var obj = {};
	var policy = {
		"policy_default": {
			"last_resort": "default",
			"use_member": []
		}
	}
	var rule = {
		"rule_default": {
			"proto": "all",
			"sticky": "0",
			"use_policy": "policy_default"
		}
	}
		
	for (var i = 0; i < 4; i++) {
		var wan = "wan" + i;
		
		var face = obj["interface"] || {};
		var member = obj["member"] || {};

		if ($("." + wan + " .enable").is(":checked") && !($("." + wan + " .enable").is(":disabled"))) {
			face[wan] = ObjClone(g_getvalue["interface"]);

			member[wan + "_default"] = {};
			member[wan + "_default"]["interface"] = wan;
			if ($("input[name='rule']:checked").val() == "average") {
				member[wan + "_default"]["metric"] = "1";
			} else {
				member[wan + "_default"]["metric"] = $("input[name='" + wan + "']:checked").val() + "";
			}
			member[wan + "_default"]["weight"] = $("#" + wan).val();

			policy["policy_default"]["use_member"].push(wan + "_default");

			obj["interface"] = face;
			obj["member"] = member;
		}
	}
	obj["policy"] = policy;
	obj["rule"] = rule;

	if (typeof obj["interface"] == "undefined" || typeof obj["member"] == "undefined") {
		obj = {
			"delete": "all"
		}
	}
	
	$("#modal_spin").modal("show");
	ucicall("SetMwan", obj, function(d) {
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
	})
}

function OnEnable(that) {
	var mark = true;
	$(".enable").each(function(index, element) {
		if ($(element).is(":checked") && !($(element).is(":disabled"))) {
			mark = false;
		}
	});
	if (mark) {
		$(".radio").find("input").prop("disabled", true);
	} else {
		$(".radio").find("input").prop("disabled", false);
		OnRadios();
	}
	
	if (typeof that != "undefined") {
		checked(that)
	} else {
		$(".enable").each(function(index, element) {
			checked(element);
		});
	}

	function checked(_that) {
		if ($(_that).is(":checked") && !($(_that).is(":disabled"))) {
			$(_that).closest(".input-group").children("input").prop("disabled", false);
		} else {
			$(_that).closest(".input-group").children("input").prop("disabled", true);
		}
	}
}

function OnRadios() {
	var value = $("input[name='rule']:checked").val();
	if (value == "average") {
		$(".onradio").find("input").prop("disabled", true);
	} else {
		$(".onradio").find("input").prop("disabled", false);
	}
}
