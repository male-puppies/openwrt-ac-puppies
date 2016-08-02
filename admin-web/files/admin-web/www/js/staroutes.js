var oTabStaroutes,
	clearInitData,
	opr = "add",
	editName,
	g_getvalue = {
		"interface": "",
		"target": "",
		"netmask": "",
		"gateway": "",
		"metric": "",
		"mtu": ""
	};

$(function() {
	createInitModal();
	verifyEventsInit();
	initEvents();
	oTabStaroutes = createDtStaroutes();
});

function createDtStaroutes() {
	var cmd = {"key": "GetStaroutes"}
	return $("#table_staroutes").dataTable({
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
				"data": "interface",
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

	var objs = jsonTraversal(g_getvalue, jsTravGet);
	var obj = {};
	for (var k in objs) {
		if (objs[k] != "") {
			obj[k] = objs[k];
		}
	}

	$("#modal_edit").modal("hide");
	$("#modal_edit").one("hidden.bs.modal", function() {
		$("#modal_spin").modal("show");
		if (opr == "add") {
			ucicall("AddRoutes", obj, function(d) {
				var func = {
					"sfunc": function() {
						initData();
					},
					"ffunc": function() {
						createModalTips("添加失败！" + (d.data ? d.data : ""));
					}
				}
				cgicallBack(d, "#modal_spin", func);
			});
		} else {
			if (typeof editName != "undefined" && editName != "") {
				obj[".name"] = editName;
			} else {
				alert("参数错误！请尝试重新加载！");
				return;
			}
			ucicall("UpdateRoutes", obj, function(d) {
				var func = {
					"sfunc": function() {
						initData();
					},
					"ffunc": function() {
						createModalTips("修改失败！" + (d.data ? d.data : ""));
					}
				}
				cgicallBack(d, "#modal_spin", func);
			});
		}
	});
}

function DoDelete() {
	var obj = {};
	if (typeof editName != "undefined" && editName != "") {
		obj[".name"] = editName;
	} else {
		alert("参数错误！请尝试重新加载！");
		return;
	}
	
	$("#modal_tips").modal("hide");
	$("#modal_tips").one("hidden.bs.modal", function() {
		$("#modal_spin").modal("show");
		ucicall("DeleteRoutes", obj, function(d) {
			var func = {
				"sfunc": function() {
					initData();
				},
				"ffunc": function() {
					createModalTips("删除失败！" + (d.data ? d.data : ""));
				}
			}
			cgicallBack(d, "#modal_spin", func);
		});
	});
}

function initData() {
	dtReloadData(oTabStaroutes, false);
}

function edit(that) {
	ucicall("GetInterface", function(d) {
		if (d.status == 0 && typeof d.data == "object" && ObjCountLength(d.data) > 0) {
			var data = d.data;
			var str = "";
			// for (var i in data) {
				// str += "<option value='" + data[i] + "'>" + data[i] + "</option>";
			// }
			for (var i = 1; i < 6; i++) {
				var eth = "eth0." + i;
				if (eth in data) {
					str += "<option value='" + data[eth] + "'>" + data[eth] + "</option>";
				}
			}
			$("#interface").html(str);
			if (typeof that == "undefined") {
				//add
				opr = "add";
			} else {
				//edit
				opr = "edit";
				var node = $(that).closest("tr");
				var objs = oTabStaroutes.api().row(node).data();
				editName = objs[".name"];
				var obj = {};
				for (var k in objs) {
					if (k.substring(0, 1) != ".") {
						obj[k] = objs[k];
					}
				}

				jsonTraversal(obj, jsTravSet);
			}
			$('#modal_edit').modal("show");
		} else {
			createModalTips("获取接口失败！请尝试重新加载！");
		}
	});
}

function OnDelete(that) {
	var node = $(that).closest("tr");
	var objs = oTabStaroutes.api().row(node).data();
	editName = objs[".name"];
	
	createModalTips("删除后不可恢复。</br>是否确认删除该路由？", "DoDelete");
}

function initEvents() {
	$(".add").on("click", function() { edit(); });
	$('[data-toggle="tooltip"]').tooltip();
}
