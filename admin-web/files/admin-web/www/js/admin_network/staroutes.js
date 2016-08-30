var oTabStaroutes,
	clearInitData,
	nodeEdit = [],
	modify_flag = "add",
	editName,
	g_getvalue = {
		"iface": "",
		"target": "",
		"netmask": "",
		"gateway": "",
		"metric": "",
		"mtu": ""
	};

$(function() {
	oTabStaroutes = createDtStaroutes();
	createInitModal();
	verifyEventsInit();
	initEvents();
});

function createDtStaroutes() {
	var cgiobj = {
		page: 1,
		count: 10000
		}
	return $("#table_staroutes").dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": "../../js/lib/dataTables.chinese.json"},
		"ajax": {
			"url": cgiDtUrl("route_get",cgiobj),
//			"url": "http://localhost/route_get",
			"type": "GET",
			"dataSrc": dtDataCallback
		},
		"columns": [
			{
				"data": null,
				"width": 60
			},
			{
				"data": "iface",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d
					}
				}
			},
			{
				"data": "target",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d
					}
				}
			},
			{
				"data": "netmask",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d
					}
				}
			},
			{
				"data": "gateway",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d
					}
				}
			},
			{
				"data": "metric",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d
					}
				}
			},
			{
				"data": "mtu",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d
					}
				}
			},
			{
				"data": "status",
				"render": function(d,t,f){
					if (d == 0) {
						return "<span class='text-success'>有效</span>"
					} if (d == 1) {
						return "<span class='text-danger'>无效</span>"
					} else {
						return "<span class='text-success'>自动</span>"
					}
				}
			},
			{
				"data": "status",
				"width": 80,
				"orderable": false,
				"render": function(d, t, f) {
					if (d == 255) {
						return '<div class="btn-group btn-group-xs"><a class="btn btn-primary disabled" onclick="" data-toggle="tooltip" data-container="body" title="禁止编辑默认组"><i class="icon-pencil"></i></a><a class="btn btn-danger disabled" onclick="" data-toggle="tooltip" data-container="body" title="禁止删除默认组"><i class="icon-trash"></i></a></div>';
					} else {
						return '<div class="btn-group btn-group-xs"><a class="btn btn-zx" onclick="edit(this)" data-toggle="tooltip" data-container="body" title="编辑"><i class="icon-pencil"></i></a><a class="btn btn-danger" onclick="OnDelete(this)" data-toggle="tooltip" data-container="body" title="删除"><i class="icon-trash"></i></a></div>';
					}
				}
			},
			{
				"data": "status",
				"width": 60,
				"orderable": false,
				"searchable": false,
				"render": function(d, t, f) {
					if (d == 255) {
						return '<input type="checkbox" value="1 0" disabled />';
					} else {
						return '<input type="checkbox" value="1 0" />';
					}
				}
			}
		],
		"rowCallback": function(nTd, sData, oData, iRow, iCol) {
			dtBindRowSelectEvents(nTd);
			$(nTd).find("td:first").html(iRow + 1);
		},
		"drawCallback": function() {
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
	if (!verification()) return;
	var data = jsonTraversal(g_getvalue, jsTravGet);
	if (modify_flag == "add") {
		cgicall.post("route_add", data, function(d) {
			cgicallBack(d, initData, function() {
				createModalTips("添加失败！" + (d.data ? d.data : ""));
			});
		})
	} else {
		data.rid = nodeEdit[0].rid;
		cgicall.post("route_set", data, function(d) {
			cgicallBack(d, initData, function() {
				createModalTips("修改失败！" + (d.data ? d.data : ""));
			});
		})
	}
}

function DoDelete() {
	var idarr = [];
	for (var i = 0; i < nodeEdit.length; i++) {
		idarr.push(nodeEdit[i].rid)
	}
	var cgiobj = {
		rids: idarr
	}
	cgicall.post("route_del", cgiobj, function(d) {
		cgicallBack(d, initData, function() {
				createModalTips("删除失败！" + (d.data ? d.data : ""));
			});
	});
}

function initData() {
	dtReloadData(oTabStaroutes, false);
}

function edit(that) {
	cgicall.get("iface_list", function(d) {
		if (d.status == 0 && typeof d.data == "object" && ObjCountLength(d.data) > 0) {
			var str = "";
			 for (var i = 0; i < d.data.length; i++) {
				 str += "<option value='" + d.data[i] + "'>" + d.data[i] + "</option>";
			 }
			$("#iface").html(str);
			if (typeof that == "undefined") {
				//add
				modify_flag = "add";
				var obj = {
					"target": "",
					"netmask": "",
					"gateway": "",
					"metric": "",
					"mtu": ""
				}
				jsonTraversal(obj, jsTravSet);
			} else {
				//edit
				modify_flag = "edit";
				getSelected(that);
				jsonTraversal(nodeEdit[0], jsTravSet);
			}
			$('#modal_edit').modal("show");
		} else {
			createModalTips("获取接口失败！请尝试重新加载！");
		}
	});
}

function OnDelete(that) {
	getSelected(that);
	if (nodeEdit.length == 0) {
		createModalTips("请选择要删除的列表！");
		return;
	}
	createModalTips("删除后不可恢复。</br>是否确认删除该路由？", "DoDelete");
}

function initEvents() {
	$(".add").on("click", function() { edit(); });
	$(".delete").on("click", function() { OnDelete(); });
	$('.checkall').on('click', OnSelectAll);
	$('[data-toggle="tooltip"]').tooltip();
}

function OnSelectAll() {
	dtSelectAll(this, oTabStaroutes);
}

function getSelected(that) {
	nodeEdit = [];
	if (that) {
		var node = $(that).closest("tr");
		var data = oTabStaroutes.api().row(node).data();
		nodeEdit.push(data);
	} else {
		nodeEdit = dtGetSelected(oTabStaroutes);
	}
}