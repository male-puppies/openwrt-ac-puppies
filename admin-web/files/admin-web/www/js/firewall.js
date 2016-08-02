var oTabFirewall,
	clearInitData,
	opr = "add",
	editName,
	g_getvalue = {
		"target": "DNAT",
		"name": "",
		"proto": "",
		"src": "",
		"src_dport": "",
		"dest": "",
		"dest_ip": "",
		"dest_port": ""
	};

$(function() {
	createInitModal();
	verifyEventsInit();
	initEvents();
	oTabFirewall = createDtFirewall();
});

function createDtFirewall() {
	var cmd = {"key": "GetFirewall"}
	return $("#table_firewall").dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": "../../js/black/dataTables.chinese.json"},
		"ajax": {
			"url": "/call/ucicall",
			"type": "POST",
			"data": {
				"cmd": JSON.stringify(cmd)
			},
			"dataSrc": function(json) {
				if (json.status == 0) {
					return dtObjToArray(json.data);
				} else if (json.data == "login") {
					window.location.href = "/login/admin_login/login.html";
				} else {
					console.log("dataTables POST error...");
					return [];
				}
			}
		},
		"columns": [
			{
				"data": null,
				"width": 60
			},
			{
				"data": "name",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d
					}
				}
			},
			{
				"data": "proto",
				"render": function(d, t, f) {
					if (d == "tcp") {
						return "TCP";
					} else if (d == "udp") {
						return "UDP";
					} else if (d == "tcp udp") {
						return "TCP+UDP";
					} else {
						return "--";
					}
				}
			},
			{
				"data": "src_dport",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d
					}
				}
			},
			{
				"data": "dest_ip",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d
					}
				}
			},
			{
				"data": "dest_port",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d
					}
				}
			},
			{ 
				"data": "enabled",
				"render": function(d, t, f){
					if (d == 0) {
						return '<a class="btn btn-danger btn-xs" onclick="set_enable(this)" data-toggle="tooltip" data-container="body" title="点击启用"><i class="icon-remove"></i> 已禁用 </a>';
					} else {
						return '<a class="btn btn-success btn-xs" onclick="set_enable(this)" data-toggle="tooltip" data-container="body" title="点击禁用"><i class="icon-ok"></i> 已启用 </a>';
					}
				}
			},
			{
				"data": null,
				"width": 80,
				"orderable": false,
				"render": function(d, t, f) {
					return '<div class="btn-group btn-group-xs"><a class="btn btn-zx" onclick="edit(this)" data-toggle="tooltip" data-container="body" title="编辑"><i class="icon-pencil"></i></a><a class="btn btn-danger" onclick="OnDelete(this)" data-toggle="tooltip" data-container="body" title="删除"><i class="icon-trash"></i></a></div>';
				}
			}
		],
		"rowCallback": function(nTd, sData, oData, iRow, iCol) {
			$(nTd).find("td:first").html(iRow + 1);
		}
	});
}

function createInitModal() {
	$("#modal_edit, #modal_tips, #modal_spin").modal({
		"backdrop": "static",
		"show": false
	});
}

function DoSave() {	
	if (!verification(".form-horizontal")) return;

	var obj = jsonTraversal(g_getvalue, jsTravGet);
	if (!$("#enabled").is(":checked")) {
		obj.enabled = "0";
	}

	if (opr == "add") {
		ucicall("AddFirewall", obj, function(d) {
			var func = {
				"sfunc": function() {
					initData();
				},
				"ffunc": function() {
					createModalTips("添加失败！" + (d.data ? d.data : ""));
				}
			}
			cgicallBack(d, "#modal_edit", func);
		});
	} else {
		if (typeof editName != "undefined" && editName != "") {
			obj[".name"] = editName;
		} else {
			alert("参数错误！请尝试重新加载！");
			return;
		}
		ucicall("SetFirewall", obj, function(d) {
			var func = {
				"sfunc": function() {
					initData();
				},
				"ffunc": function() {
					alert("xx")
					createModalTips("修改失败！" + (d.data ? d.data : ""));
				}
			}
			cgicallBack(d, "#modal_edit", func);
		});
	}
}

function DoDelete() {
	var obj = {};
	if (typeof editName != "undefined" && editName != "") {
		obj[".name"] = editName;
	} else {
		alert("参数错误！请尝试重新加载！");
		return;
	}
	ucicall("DeleteFirewall", obj, function(d) {
		console.log(d)
		var func = {
			"sfunc": function() {
				initData();
			},
			"ffunc": function() {
				createModalTips("删除失败！" + (d.data ? d.data : ""));
			}
		}
		cgicallBack(d, "#modal_tips", func);
	});
}

function initData() {
	dtReloadData(oTabFirewall, false);
}

function edit(that) {
	var node = $(that).closest("tr"),
		objs = oTabFirewall.api().row(node).data(),
		obj = {};
		
	opr = "edit";
	editName = objs[".name"];
	for (var k in objs) {
		if (k.substring(0, 1) != ".") {
			obj[k] = objs[k];
		}
	}

	jsonTraversal(obj, jsTravSet);
	if (typeof obj.enabled != "undefined" && obj.enabled == "0") {
		$("#enabled").prop("checked", false);
	} else {
		$("#enabled").prop("checked", true);
	}
	$('#modal_edit').modal("show");
}

function set_enable(that) {
	var node = $(that).closest("tr"),
		objs = oTabFirewall.api().row(node).data(),
		obj = {};

	for (var k in objs) {
		if (k == ".name" || k.substring(0, 1) != ".") {
			obj[k] = objs[k];
		}
	}
	if (typeof obj[".name"] == "undefined" || obj[".name"] == "") {
		createModalTips("参数错误！请尝试重新加载！");
		return;
	}
	if (typeof obj.enabled != "undefined" && obj.enabled == "0") {
		obj.enabled = undefined;
	} else {
		obj.enabled = "0";
	}
	ucicall("SetFirewall", obj, function(d) {
		if (d.status == 0) {
			initData();
		} else {
			createModalTips("修改失败！" + (d.data ? d.data : ""));
		}
	});
}

function OnDelete(that) {
	var node = $(that).closest("tr");
	var objs = oTabFirewall.api().row(node).data();
	editName = objs[".name"];
	
	createModalTips("删除后不可恢复。</br>是否确认删除？", "DoDelete");
}

function initEvents() {
	$(".add").on("click", function() { OnAdd(); });
	$('[data-toggle="tooltip"]').tooltip();
}

function OnAdd() {
	opr = "add";
	
	var obj = {
		"target": "DNAT",
		"name": "",
		"proto": "tcp udp",
		"src": "wan",
		"src_dport": "",
		"dest": "lan",
		"dest_ip": "",
		"dest_port": ""
	};
	jsonTraversal(obj, jsTravSet);
	$("#enabled").prop("checked", true);
	
	$('#modal_edit').modal("show");
}
