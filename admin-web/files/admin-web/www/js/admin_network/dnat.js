var oTabFirewall,
	modify_flag = "add",
	nodeEdit,
	g_getvalue = {
		"fwname": "",
		"fwdesc": "",
		"enable": "",
		"proto": "tcp udp",
		"from_szid": "1",
		"from_dport": "",
		"to_dzid": "0",
		"to_dip": "",
		"to_dport": "",
		"reflection": "0"
	};

$(function() {
	createInitModal();
	verifyEventsInit();
	initEvents();
	oTabFirewall = createDtFirewall();
});

function createDtFirewall() {
	var cgiobj = {
		"page": 1,
		"count": 10000
	}
	return $("#table_dnat").dataTable({
		"pagingType": "full_numbers",
		"ordering": false,
		"language": {"url": "../../js/lib/dataTables.chinese.json"},
		"ajax": {
			"url": cgiDtUrl("dnat_get", cgiobj),
			"type": "GET",
			"dataSrc": dtDataCallback
		},
		"columns": [
			{
				"data": null,
				"width": 60
			},
			{
				"data": "fwname",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d
					}
				}
			},
			{
				"data": "fwdesc",
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
				"data": "from_dport",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d
					}
				}
			},
			{
				"data": "to_dip",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d
					}
				}
			},
			{
				"data": "to_dport",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d
					}
				}
			},
			{
				"data": "fwid",
				"render": function(d, t, f) {
					return '<div class="btn-group btn-group-xs"><a class="btn btn-success mark1" onclick="rowMove(\'up\', \'' + d + '\')"><i class="icon-chevron-up"></i></a><a class="btn btn-success mark2" onclick="rowMove(\'down\', \'' + d + '\')"><i class="icon-chevron-down"></i></a></div>';
				}
			},
			{
				"data": "enable",
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
	$("#modal_edit, #modal_tips, #modal_spin").modal({
		"backdrop": "static",
		"show": false
	});
}

function DoSave() {
	if (!verification(".form-horizontal")) return;

	var obj = jsonTraversal(g_getvalue, jsTravGet);
	if (modify_flag == "add") {
		cgicall.post("dnat_add", obj, function(d) {
			cgicallBack(d, initData, function() {
				createModalTips("添加失败！" + (d.data ? d.data : ""));
			});
		});
	} else {
		obj.fwid = nodeEdit[0].fwid;
		cgicall.post("dnat_set", obj, function(d) {
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

	data = oTabFirewall.api().rows().data();
	for (var i = 0; i < data.length; i++) {
		if (data[i].fwid == id) {
			num = i;
		}
		arr.push(data[i].fwid);
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

	cgicall.post("dnat_adjust", {fwids: sarr}, function(d) {
		cgicallBack(d, initData, function() {
			createModalTips("移动失败！" + (d.data ? d.data : ""));
		});
	});
}

function DoDelete() {
	var idarr = [];
	for (var i = 0, ien = nodeEdit.length; i < ien; i++) {
		idarr.push(nodeEdit[i].fwid);
	}

	cgicall.post("dnat_del", {"fwids": idarr}, function(d) {
		cgicallBack(d, initData, function() {
			createModalTips("删除失败！" + (d.data ? d.data : ""));
		});
	});
}

function initData() {
	dtReloadData(oTabFirewall, false);
}

function edit(that) {
	modify_flag = "edit";
	getSelected(that);
	var obj = ObjClone(nodeEdit[0]);
	jsonTraversal(obj, jsTravSet);
	$('#modal_edit').modal("show");
}

function set_enable(that) {
	var node = $(that).closest("tr");
	var obj = oTabFirewall.api().row(node).data();
	if (obj.enable == "1") {
		obj.enable = "0"
	} else {
		obj.enable = "1"
	}

	cgicall.post("dnat_set", obj, function(d) {
		cgicallBack(d, initData, function() {
			createModalTips("修改失败！" + (d.data ? d.data : ""));
		});
	})
}

function initEvents() {
	$(".add").on("click", OnAdd);
	$(".delete").on("click", function() { OnDelete(); });
	$(".checkall").on("click", OnSelectAll);
	$('[data-toggle="tooltip"]').tooltip();
}

function OnAdd() {
	modify_flag = "add";
	jsonTraversal(g_getvalue, jsTravSet);
	$("#enable").prop("checked", true);
	$('#modal_edit').modal("show");
}

function OnDelete(that) {
	getSelected(that);
	if (nodeEdit.length == 0) {
		createModalTips("请选择要删除的列表！");
		return;
	}
	createModalTips("删除后不可恢复。</br>确定要删除？", "DoDelete");
}

function OnSelectAll() {
	dtSelectAll(this, $("#table_dnat"));
}

function getSelected(that) {
	nodeEdit = [];
	if (that) {
		var node = $(that).closest("tr");
		var data = oTabFirewall.api().row(node).data();
		nodeEdit.push(data);
	} else {
		nodeEdit = dtGetSelected(oTabFirewall);
	}
}
