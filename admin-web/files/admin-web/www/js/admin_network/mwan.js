
$(function() {
	createInitModal();
	verifyEventsInit();
	initEvents();
	initData();
});

function createInitModal() {
	$("#modal_edit, #modal_tips").modal({
		"backdrop": "static",
		"show": false
	});
}

function initData() {
	cgicall.get("mwan_get", function(d) {
		if (d.status == 0 && typeof d.data == "object") {
			var obj = d.data,
				enable = obj.enable == 1 ? true : false,
				ifaces = dtObjToArray(obj.ifaces);

			$("#enable").prop("checked", enable);
			$("input[type=radio][name=policy][value=" + obj.policy + "]").prop("checked", true);

			$(".ifaces, .mline, .bline").empty();
			for (var i = 0, ien = ifaces.length; i < ien; i++) {
				var enable = ifaces[i].enable == 1 ? true : false,
					name = ifaces[i].name,
					// bandwidth = enable ? ifaces[i].bandwidth : "",
					bandwidth = ifaces[i].bandwidth,
					main_iface = dtObjToArray(obj.main_iface),
					check = $.inArray(name, main_iface) > -1 ? true : false,
					policy = obj.policy == "balanced" ? true : false,
					wan_node = consWanNode(name, bandwidth, enable),
					mline_node = consLineNode(name, policy, check, "main"),
					bline_node = consLineNode(name, policy, !check, "backup");

				$("input.wan-check", wan_node).on("click", function() {
					if ($(this).is(":checked")) {
						$(this).parent().siblings("input.wan-text").prop("enable", false);
					} else {
						$(this).parent().siblings("input.wan-text").prop("enable", true);
					}
				});
				$('[data-toggle="tooltip"]', wan_node).tooltip();
				$(".ifaces").append(wan_node);
				$("span.mline").append(mline_node);
				$("span.bline").append(bline_node);
			}
		} else {
			createModalTips("初始化失败！请尝试重新加载！");
		}
	});
}

function consWanNode(name, bandwidth, enable) {
	return $("<div>", {
					"class": "form-group clearfix"
				}
			)
			.append($("<label>", {
					"class": "col-md-2 col-sm-3 col-xs-4 control-label"
				})
				.html("启用" + name.toUpperCase())
			)
			.append($("<div>", {
					"class": "col-md-3 col-sm-4 col-xs-5"
				})
				.append($("<div>", {
						"class": "input-group"
					})
					.append($("<span>", {
							"class": "input-group-addon"
						})
						.append($("<input>", {
								"type": "checkbox",
								"id": name + "_check",
								"class": "wan-check",
								"checked": enable,
								"value": "1 0"
							})
						)
					)
					.append($("<input>", {
							"type": "text",
							"id": name,
							"class": "form-control wan-text",
							"value": bandwidth,
							"enable": !enable,
							"verify": "num 0 1000"
						})
					)
				)
			)
			.append($("<div>", {
					"class": "col-md-7 col-sm-5 col-xs-3 tip-icons"
				})
				.append($("<span>", {
						"class": "units"
					})
					.html("Mbps")
				)
				.append($("<span>", {
						"class": "icon-tip",
						"data-toggle": "tooltip",
						"data-placement": "bottom",
						"title": "输入数字0~1000。请填写网络带宽。"
					})
					.append($("<i>", {
							"class": "icon-question-sign"
						})
					)
				)
			);
}

function consLineNode(name, policy, check, val) {
	return $("<label>", {
				"class": "label-wan " + name
			})
			.append($("<input>", {
					"type": "radio",
					"name": name,
					"value": val,
					"enable": policy,
					"checked": check
				})
			)
			.append(name.toUpperCase());
}

function initEvents() {
	$(".submit").on("click", OnSubmit);
	$("input:radio[name='policy']").on("click", OnPolicy);
	$('[data-toggle="tooltip"]').tooltip();
}

function OnSubmit() {
	if(!verification()) return;

	var ifaces = [],
		main_iface = [],
		obj = {
			"policy": $("input[name='policy']:checked").val(),
			"enable": $("#enable").is(":checked") ? 1 : 0
		};

	$(".wan-text").each(function(index, element) {
		var o = {},
			id = $(element).attr("id");

		o.enable = $("#" + id + "_check").is(":checked") ? 1 : 0;
		o.name = id;
		o.bandwidth = $(element).val();
		ifaces.push(o);

		if ($("input:radio[name='" + id + "']:checked").val() == "main") {
			main_iface.push(id);
		}
	});

	obj.ifaces = ifaces;
	obj.main_iface = main_iface;

	var sobj = {
		"arg": JSON.stringify(obj)
	}

	cgicall.post("mwan_set", sobj, function(d) {
		cgicallBack(d, function() {
			createModalTips("保存成功！");
			initData();
		}, function() {
			createModalTips("保存失败！" + (d.data ? d.data : ""));
		});
	});
}

function OnPolicy() {
	if ($(this).val() == "balanced") {
		$(".onradio").find("input").prop("enable", true);
	} else {
		$(".onradio").find("input").prop("enable", false);
	}
}
