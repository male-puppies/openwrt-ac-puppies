var oTab,
	g_protogroup,
	g_timegroup,
	g_ipgroup,
	modify_flag = "add",
	nodeEdit = [];

$(function() {
	oTab = createDt();
	createInitModal();
	verifyEventsInit();
	initEvents();
	initData2();
	initData3();
});

function createDt() {
	var cgiobj = {
		"page": 1,
		"count": 10000
	}
	return $('#table_acrule').dataTable({
		"pagingType": "full_numbers",
		"ordering": false,
		"language": {"url": '../../js/lib/dataTables.chinese.json'},
		"ajax": {
			"url": cgiDtUrl("acrule_get", cgiobj),
			"type": "GET",
			"dataSrc": dtDataCallback
		},
		"columns": [
			{
				"data": null,
				"width": 60,
			},
			{
				"data": "rulename",
				"render": function(d, t, f) {
					if (d.length == 0) {
						return "--";
					} else {
						return d;
					}
				}
			},
			{
				"data": "ruledesc",
				"render": function(d, t, f) {
					if (d.length == 0) {
						return "--";
					} else {
						return d;
					}
				}
			},
			{
				"data": "proto_ids",
				"render": function(d, t, f) {
					return "协议";
				}
			},
			{
				"data": "actions",
				"render": function(d, t, f) {
					var data = dtObjToArray(d);
					if ($.inArray("ACCEPT", data) > -1) {
						return "允许";
					} else if ($.inArray("REJECT", data) > -1) {
						return "阻断";
					} else {
						return "其它";
					}
				}
			},
			{
				"data": "tmgrp_ids",
				"render": function(d, t, f) {
					var data = dtObjToArray(d);
					if (data.length == 0) return "--";
					return '<span value="' + data[0].tmgrpid + '">' + data[0].tmgrpname + '</span>';
				}
			},
			{
				"data": "src_ipgids",
				"render": function(d, t, f) {
					var data = dtObjToArray(d);
					if (data.length == 0) return "--";
					return '<span value="' + data[0].ipgid + '">' + data[0].ipgrpname + '</span>';
				}
			},
			{
				"data": "dest_ipgids",
				"render": function(d, t, f) {
					var data = dtObjToArray(d);
					if (data.length == 0) return "--";
					return '<span value="' + data[0].ipgid + '">' + data[0].ipgrpname + '</span>';
				}
			},
			{
				"data": "ruleid",
				"render": function(d, t, f) {
					return '<div class="btn-group btn-group-xs"><a class="btn btn-success mark1" onclick="rowMove(\'up\', \'' + d + '\')"><i class="icon-chevron-up"></i></a><a class="btn btn-success mark2" onclick="rowMove(\'down\', \'' + d + '\')"><i class="icon-chevron-down"></i></a></div>';
				}
			},
			{
				"data": "enable",
				"render": function(d, t, f) {
					if (typeof d != "undefined" && d.toString() != "1") {
						return '<a class="btn btn-danger btn-xs" onclick="set_enable(this)" data-toggle="tooltip" data-container="body" title="点击启用"><i class="icon-remove"></i> 已禁用 </a>';
					} else {
						return '<a class="btn btn-success btn-xs" onclick="set_enable(this)" data-toggle="tooltip" data-container="body" title="点击禁用"><i class="icon-ok"></i> 已启用 </a>';
					}
				}
			},
			{
				"data": "ruleid",
				"width": 90,
				"orderable": false,
				"render": function(d, t, f) {
					return '<div class="btn-group btn-group-xs"><a class="btn btn-primary" onclick="edit(this)" data-toggle="tooltip" data-container="body" title="编辑"><i class="icon-pencil"></i></a><a class="btn btn-danger" onclick="OnDelete(this)" data-toggle="tooltip" data-container="body" title="删除"><i class="icon-trash"></i></a></div>';
				}
			},
			{
				"data": null,
				"width": 60,
				"orderable": false,
				"searchable": false,
				"defaultContent": '<input type="checkbox" value="1 0" />'
			}
		],
		"rowCallback": function(nTd, sData, oData, iRow, iCol) {
			dtBindRowSelectEvents(nTd);
			$(nTd).find("td:first").html(iRow + 1);
		},
		"drawCallback": function() {
			var rows = this.api().rows().nodes();
			if (rows.length > 0) {
				var firstRow = rows[0];
				var pre_lastRow = this.api().row(rows.length - 1).node();
				$(firstRow).find(".btn-group .mark1").addClass("disabled");
				$(pre_lastRow).find(".btn-group .mark2").addClass("disabled");
			}

			$("body > div.tooltip").remove();
			$('[data-toggle="tooltip"]').tooltip();
		}
	});
}

function createInitModal() {
	$("#modal_edit, #modal_tips").modal({
		"backdrop": "static",
		"show": false
	});
}

function initData() {
	dtReloadData(oTab, false);
	initData2();
}

function initData2() {
	cgicall.get("acproto_get", {
		"page": 1,
		"count": 10000
	}, function(d) {
		if (d.status == 0) {
			g_protogroup = dtObjToArray(d.data);
		}
	});
	cgicall.get("timegroup_get", {
		"page": 1,
		"count": 10000,
		"order": "tmgrpname",
		"desc": 1,
		"search": "tmgrpname",
		"link": "all"
	}, function(d) {
		if (d.status == 0) {
			g_timegroup = dtObjToArray(d.data);
		}
	});
	cgicall.get("ipgroup_get", {
		"page": 1,
		"count": 10000,
		"order": "ipgrpname",
		"desc": 1,
		"search": "ipgrpname",
		"link": "all"
	}, function(d) {
		if (d.status == 0) {
			g_ipgroup = dtObjToArray(d.data);
		}
	});
}

function initData3() {
	cgicall.get("acset_get", function(d) {
		if (d.status == 0) {
			var bypass = d.data.bypass;
			var check = d.data.check;

			if (bypass.enable == 1) {
				$("#bypass__enable").prop("checked", true);
				$("#bypass").prop("disabled", false);
			} else {
				$("#bypass__enable").prop("checked", false);
				$("#bypass").prop("disabled", true);
			}

			if (check.enable == 1) {
				$("#check__enable").prop("checked", true);
				$("#check").prop("disabled", false);
			} else {
				$("#check__enable").prop("checked", false);
				$("#check").prop("disabled", true);
			}

			var bypass_str = dtObjToArray(bypass.mac).join("\n") != "" ? dtObjToArray(bypass.mac).join("\n") + "\n" : "" + dtObjToArray(bypass.ip).join("\n");
			$("#bypass").val(bypass_str);

			var check_str = dtObjToArray(check.mac).join("\n") != "" ? dtObjToArray(check.mac).join("\n") + "\n" : "" + dtObjToArray(check.ip).join("\n");
			$("#check").val(check_str);
		}
	});
}

function consProto() {
	if (!g_protogroup) return false;

	var data = g_protogroup;
	var obj = {};
	for (var i = 0, ien = data.length; i < ien; i++) {
		var pid = data[i].pid;
		var tmp = obj["ul__" + pid] || [];
		tmp.push(data[i]);
		obj["ul__" + pid] = tmp;
	}

	if (typeof obj["ul__-1"] == "undefined") return false;

	var pp_node = $("<div>");
	consNode("ul__-1", pp_node, 0);

	function consNode(key, p_node, num) {
		$("#proto_edit .left .inner").empty();
		$("#proto_sel").empty();
		var angle = "icon-angle-right",
			folder = "icon-folder-close",
			ul_node = $("<ul>", {
				"class": key,
				"style": "display:block;"
			});

		if (num > 1) {
			ul_node.attr("style", "display:none;");
		}

		for (var i = 0, ien = obj[key].length; i < ien; i++) {
			if (obj[key][i]["node_type"] == "leaf") {
				folder = "icon-file-alt"
				angle = "icon-angle-none"
			} else {
				if (num == 0) {
					angle = "icon-angle-down";
					folder = "icon-folder-open";
				} else {
					angle = "icon-angle-right";
					folder = "icon-folder-close";
				}
			}

			var li_node = $("<li>", {
							"id": "li__" + obj[key][i]["proto_id"]
						})
						.append(
							$("<i>", {
								"class": angle + " aleft"
							})
						)
						.append(
							$("<i>", {
								"class": folder + " aright"
							})
						)
						.append(
							$("<span>").html(obj[key][i]["proto_desc"])
						);

			li_node.find("span").on("click", function() {
				var sib = $(this).siblings("ul");
				if ($(this).hasClass("active")) {
					$(this).removeClass("active");
				} else {
					$(this).addClass("active");
					$(this).parents("ul").siblings("span").removeClass("active");
					sib.parent().children("i.aleft").removeClass("icon-angle-down").addClass("icon-angle-right");
					sib.parent().children("i.aright").removeClass("icon-folder-open").addClass("icon-folder-close")
					sib.slideUp(200).find("span").removeClass("active");
				}
			})
			li_node.find("i.icon-folder-close, i.icon-folder-open, i.icon-angle-down, i.icon-angle-right").on("click", function() {
				var sib = $(this).siblings("ul");
				var par = $(this).parent();
				if (sib.is(":hidden")) {
					par.children("i.aleft").removeClass("icon-angle-right").addClass("icon-angle-down");
					par.children("i.aright").removeClass("icon-folder-close").addClass("icon-folder-open");
					sib.slideDown(200);
				} else {
					par.children("i.aleft").removeClass("icon-angle-down").addClass("icon-angle-right");
					par.children("i.aright").removeClass("icon-folder-open").addClass("icon-folder-close");
					sib.slideUp(200);
				}
			});
			ul_node.append(li_node);

			var proto_id = "ul__" + obj[key][i]["proto_id"];
			if (proto_id in obj) {
				consNode(proto_id, li_node, num + 1);
			}
		}

		p_node.append(ul_node);
		if (num == 0) $("#proto_edit .left .inner").append(p_node);
	}

	return true;
}

function consIpgroup() {
	if (!g_ipgroup) return false;

	var data = g_ipgroup;
	var str = "";
	for (var i = 0, ien = data.length; i < ien; i++) {
		str += '<option value="' + data[i]["ipgid"] + '">' + data[i]["ipgrpname"] + '</option>'
	}
	$("#src_ipgids, #dest_ipgids").html(str);

	return true;
}

function consTimegroup() {
	if (!g_timegroup) return false;

	var data = g_timegroup;
	var str = "";
	for (var i = 0, ien = data.length; i < ien; i++) {
		str += '<option value="' + data[i]["tmgid"] + '">' + data[i]["tmgrpname"] + '</option>'
	}
	$("#tmgrp_ids").html(str);
	return true;
}

function edit(that) {
	var obj,
		proto,
		str;

	modify_flag = "mod";
	getSelected(that);
	obj = ObjClone(nodeEdit[0]);

	if (!consProto() || !consIpgroup() || !consTimegroup()) {
		createModalTips("初始化失败！请尝试重新加载！");
		return false;
	}

	obj.actions = (obj.actions && obj.actions[0]) && obj.actions[0] || "ACCEPT";
	obj.tmgrp_ids = (obj.tmgrp_ids && obj.tmgrp_ids[0] && obj.tmgrp_ids[0].tmgid) && obj.tmgrp_ids[0].tmgid || 255;
	obj.src_ipgids = (obj.src_ipgids && obj.src_ipgids[0] && obj.src_ipgids[0].ipgid) && obj.src_ipgids[0].ipgid || 63;
	obj.dest_ipgids = (obj.dest_ipgids && obj.dest_ipgids[0] && obj.dest_ipgids[0].ipgid) && obj.dest_ipgids[0].ipgid || 63;

	jsonTraversal(obj, jsTravSet);

	proto = obj.proto_ids;
	str = "";
	for (var i = 0, ien = proto.length; i < ien; i++) {
		var p_id = "li__" + proto[i].proto_id;
		var p_desc = proto[i].proto_desc;
		if (typeof p_desc != "undefined") {
			str += '<li value="' + p_id + '">' + proto[i].proto_desc + '</li>';
			$("#proto_edit .left li#" + p_id).hide();
		}
	}
	$("#proto_sel").html(str);

	$('#modal_edit').modal("show");
}

function set_enable(that) {
	var node = $(that).closest("tr");
	var obj = oTab.api().row(node).data();
	var sobj = ObjClone(obj);
	if (obj.enable == "1") {
		sobj.enable = "0"
	} else {
		sobj.enable = "1"
	}

	sobj.tmgrp_ids = [(obj.tmgrp_ids && obj.tmgrp_ids[0] && obj.tmgrp_ids[0].tmgid) && obj.tmgrp_ids[0].tmgid || 255];
	sobj.src_ipgids = [(obj.src_ipgids && obj.src_ipgids[0] && obj.src_ipgids[0].ipgid) && obj.src_ipgids[0].ipgid || 63];
	sobj.dest_ipgids = [(obj.dest_ipgids && obj.dest_ipgids[0] && obj.dest_ipgids[0].ipgid) && obj.dest_ipgids[0].ipgid || 63];
	sobj.proto_ids = (function(){
		var arr = [];
		var ids = obj.proto_ids;
		for (var i = 0, ien = ids.length; i < ien; i++) {
			arr.push(ids[i].proto_id);
		}
		return arr;
	}());

	cgicall.post("acrule_set", sobj, function(d) {
		cgicallBack(d, initData, function() {
			createModalTips("修改失败！" + (d.data ? d.data : ""));
		});
	})
}

function DoSave() {
	if(!verification("#modal_edit")) return;

	var acrule = {
		enable: 1,
		rulename: "",
		ruledesc: "",
		actions: "",
		tmgrp_ids: "",
		src_ipgids: "",
		dest_ipgids: "",
		src_zids: [1],
		dest_zids: [0]
	}

	var obj = jsonTraversal(acrule, jsTravGet);
	obj.actions = [obj.actions || "", "ADUIT"];
	obj.tmgrp_ids = [parseInt(obj.tmgrp_ids) || 255];
	obj.src_ipgids = [parseInt(obj.src_ipgids) || 63];
	obj.dest_ipgids = [parseInt(obj.dest_ipgids) || 63];
	obj.proto_ids = [];

	$("#proto_sel li").each(function(index, element) {
		var id = $(element).attr("value");
		var reg = new RegExp("li__([0-9a-zA-Z]*)", "g");
		if (reg.test(id)) {
			obj.proto_ids.push(RegExp.$1);
		}
	});

	if (modify_flag == "add") {
		cgicall.post("acrule_add", obj, function(d) {
			cgicallBack(d, initData, function() {
				createModalTips("添加失败！" + (d.data ? d.data : ""));
			});
		});
	} else {
		obj.ruleid = nodeEdit[0].ruleid;
		obj.priority = nodeEdit[0].priority;
		cgicall.post("acrule_set", obj, function(d) {
			cgicallBack(d, initData, function() {
				createModalTips("修改失败！" + (d.data ? d.data : ""));
			});
		});
	}
}

function rowMove(set, id) {
	var data,
		num,
		arr = [],
		sarr = [];

	data = oTab.api().rows().data();
	for (var i = 0; i < data.length; i++) {
		if (data[i].ruleid == id) {
			num = i;
		}
		arr.push(data[i].ruleid);
	}

	if (set == "up") {
		if (num == 0) {
			createModalTips("第一条，不能移动！");
			return;
		}
		id2 = arr[num - 1];
		sarr = [id2, id];
	} else if (set == "down") {
		if (num == data.length - 1) {
			createModalTips("最后一条，不能移动！");
			return;
		}
		id2 = arr[num + 1];
		sarr = [id, id2];
	}

	cgicall.post("acrule_adjust", {ruleids: sarr}, function(d) {
		cgicallBack(d, initData, function() {
			createModalTips("移动失败！" + (d.data ? d.data : ""));
		});
	});
}

function DoDelete(){
	var idarr = [];
	for (var i = 0, ien = nodeEdit.length; i < ien; i++) {
		idarr.push(nodeEdit[i].ruleid);
	}
	cgicall.post("acrule_del", {"ruleids": idarr}, function(d) {
		cgicallBack(d, initData, function() {
			createModalTips("删除失败！" + (d.data ? d.data : ""));
		});
	});
}

function initEvents() {
	$(".submit").on("click", OnSubmit);
	$(".c-enable").on("click", OnEnable);
	$(".add").on("click", OnAdd);
	$('.delete').on('click', function() {OnDelete()});
	$(".open-proto").on("click", OnOpenProto);
	$(".close-proto").on("click", OnCloseProto);
	$(".add-proto").on("click", OnAddProto);
	$(".del-proto").on("click", OnDelProto);
	$("#proto_edit").on("click", ".right li", OnEditProto);
	$(".checkall").on("click", OnSelectAll);
	$('[data-toggle="tooltip"]').tooltip();
}

function OnSubmit() {
	if(!verification("#main")) return;

	var obj = {
			bypass: {
				enable: $("#bypass__enable").is(":checked") ? 1 : 0,
				mac: [],
				ip: []
			},
			check: {
				enable: $("#check__enable").is(":checked") ? 1 : 0,
				mac: [],
				ip: []
			}
		},
		bypass = $("#bypass").val().split("\n"),
		check = $("#check").val().split("\n");

	regmacip(obj.bypass, bypass);
	regmacip(obj.check, check);

	cgicall.post("acset_set", obj, function(d) {
		cgicallBack(d, initData, function() {
			createModalTips("保存失败！" + (d.data ? d.data : ""));
		});
	});

	function regmacip(obj, arr) {
		var regmac = /^([0-9a-fA-F]{2}(:)){5}[0-9a-fA-F]{2}$/,
			regip = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;

		for (var i = 0, ien = arr.length; i < ien; i++) {
			var val = arr[i];
			if (regmac.test(val)) {
				obj.mac.push(val);
			} else if (regip.test(val)) {
				obj.ip.push(val);
			}
		}
	}
}

function OnEnable() {
	if ($(this).is(":checked")) {
		$(this).closest("div").find("textarea").prop("disabled", false);
	} else {
		$(this).closest("div").find("textarea").prop("disabled", true);
	}
}

function OnAdd() {
	modify_flag = "add";

	$("#enable").prop("checked", true);
	$("#rulename, #ruledesc").val("");
	$("#actions").val("ACCEPT");
	if (!consProto() || !consIpgroup() || !consTimegroup()) {
		createModalTips("初始化失败！请尝试重新加载！");
		return false;
	}
	$('#modal_edit').modal("show");
}

function OnDelete(that) {
	getSelected(that);
	if (nodeEdit.length == 0) {
		createModalTips("请选择要删除的列表！");
		return;
	}
	createModalTips("删除后不可恢复。</br>确定要删除？", "DoDelete");
	$('#modal_tips').modal("show");
}

function OnOpenProto() {
	$("#modal_edit").hide();
	$("#proto_edit").show();
}

function OnCloseProto() {
	$("#proto_edit").hide();
	$("#modal_edit").show();
	verification(".v-proto");
}

function OnAddProto() {
	$("#proto_edit .left span.active").each(function(index, element) {
		var self = $(element);
		if (self.is(":visible")) {
			self.removeClass("active").closest("li").hide();
			var str = '<li value="' + self.closest("li").attr("id") + '">' + self.html() + '</li>';
			$("#proto_sel").append(str);

			self.siblings("ul").find("li").each(function(i, e) {
				OnDelProto(e, $(e).attr("id"));
			});
		}
	});
}

function OnDelProto(e, id) {
	if (id) {
		$("#proto_sel li").each(function(index, element) {
			if ($(element).attr("value") == id) {
				$(element).remove();
				$("#proto_edit #" + id).show();
			}
		})
	} else {
		$("#proto_sel li.active").each(function(index, element) {
			var id = $(element).attr("value");
			$(element).remove();
			$("#proto_edit #" + id).show();
		})
	}
}

function OnEditProto() {
	if ($(this).hasClass("active")) {
		$(this).removeClass("active");
	} else {
		$(this).addClass("active");
	}
}

function OnSelectAll() {
	dtSelectAll(this, $("#table_timegroup"));
}

function getSelected(that) {
	nodeEdit = [];
	if (that) {
		var node = $(that).closest("tr");
		var data = oTab.api().row(node).data();
		nodeEdit.push(data);
	} else {
		nodeEdit = dtGetSelected(oTab);
	}
}