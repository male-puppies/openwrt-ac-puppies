var oTab,
	modify_flag = "add",
	nodeEdit = [];

$(function() {
	oTab = createDt();
	createInitModal();
	verifyEventsInit();
	initEvents();
});

function createDt() {
	var cgiobj = {
		"page": 1,
		"count": 10000,
		"order": "ipgrpname",
		"desc": 1,
		"search": "ipgrpname",
		"link": "all"
	}
	return $('#table_ipgroup').dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": '../../js/lib/dataTables.chinese.json'},
		"ajax": {
			"url": cgiTdUrl("ipgroup_get", cgiobj),
			"type": "GET",
			"dataSrc": function(json) {
				if (json.status == 0) {
					return dtObjToArray(json.data);
				} else if (json.data.indexOf("timeout") > -1) {
					window.location.href = "/login/admin_login/login.html";
				} else {
					return [];
				}
			}
		},
		"columns": [
			{
				"data": null,
				"width": 60,
			},
			{
				"data": "ipgrpname"
			},
			{
				"data": "ipgrpdesc",
				"render": function(d, t, f) {
					if (d.length == 0) {
						return "--";
					} else {
						return d;
					}
				}
			},
			{
				"data": "ranges",
				"render": function(d, t, f) {
					var json = JSON.parse(d);
					if (Object.prototype.toString.call(json) === '[object Array]') {
						var list ='<ul style="line-height:18px;list-style-type:none;margin:0;margin-top:6px;">';
						for (var i = 0, ien = json.length; i < ien; i++) {
							list += '<li>' + json[i] + '</li>';
						}
						list += '</ul>';
						return list;
					} else {
						return d;
					}
				}
			},
			{
				"data": null,
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
				"defaultContent": '<input type="checkbox" value="1 0" />',
			}
		],
		"rowCallback": function(nTd, sData, oData, iRow, iCol) {
			dtBindRowSelectEvents(nTd);
			$(nTd).find("td:first").html(iRow + 1);
		},
		"drawCallback": function() {
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
	dtReloadData(oTab, false)
}

function edit(that) {
	modify_flag = "mod";
	getSelected(that);
	var obj = ObjClone(nodeEdit[0]);
	obj.ranges = JSON.parse(obj.ranges).join("\n");
	jsonTraversal(obj, jsTravSet)
	$('#modal_edit').modal("show");
}

function DoSave() {
	if(!verification()) return;
	var ipInfo={
        "ipgrpname": "",
        "ranges": "",
        "ipgrpdesc": ""
	}
	var obj = jsonTraversal(ipInfo, jsTravGet);
	obj.ranges = JSON.stringify(obj.ranges.split("\n"));
	if (modify_flag == "add") {
		cgicall.post("ipgroup_add", obj, function(d) {
			cgicallBack(d, initData, function() {
				createModalTips("添加失败！" + (d.data ? d.data : ""));
			});
		});
	} else {
		obj.ipgid = nodeEdit[0].ipgid;
		cgicall.post("ipgroup_set", obj, function(d) {
			cgicallBack(d, initData, function() {
				createModalTips("修改失败！" + (d.data ? d.data : ""));
			});
		});
	}
}

function DoDelete(){
	var idarr = [];
	for (var i = 0, ien = nodeEdit.length; i < ien; i++) {
		idarr.push(nodeEdit[i].ipgid);
	}
	cgicall.post("ipgroup_del", {"ipgids": idarr}, function(d) {
		cgicallBack(d, initData, function() {
			createModalTips("删除失败！" + (d.data ? d.data : ""));
		});
	});
}

function initEvents() {
	$(".add").on("click", OnAdd);
	$('.delete').on('click', function() {OnDelete()});
	$(".checkall").on("click", OnSelectAll);
	$('[data-toggle="tooltip"]').tooltip();
}

function OnAdd() {
	$("#ipgrpname").val('');
	$("#ranges").val('');
	$("#ipgrpdesc").val('');
	modify_flag = "add";
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

function OnSelectAll() {
	dtSelectAll(this, $("#table_ipgroup"));
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