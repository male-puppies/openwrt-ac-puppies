var oTabAuth,
	modify_flag = "add",
	g_delname,
	g_auth = {
		name: '',
		ip1: '',
		ip2: '',
		type: 'auto'
	};

$(function() {
	oTabAuth = createDtAuth();
	createInitModal();
	verifyEventsInit();
	initEvents();
	initData2();
});

function createDtAuth() {
	var cmd = {"key": "PolicyGet"}
	return $("#table_authpolicy").dataTable({
		"pagingType": "full_numbers",
		"ordering": false,
		"language": {"url": '../../js/black/dataTables.chinese.json'},
		"ajax": {
			"url": "/call/cgicall",
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
				"data": "name"
			},
            {
				"data": null,
			  	"render": function (d, t, f) {
					var str = '';
					if (f.ip1 != f.ip2) {
						str = f.ip1 + '-' + f.ip2;
					} else {
						str = f.ip1;
					}
           			return  str;
           		}
            },
            {
				"data": "type",
            	"render": function (d, t, f) {
					if (d  ==  "web") {
						return 'Portal认证';
					} else {
						return '自动认证';
					}
               	}
			},
            {
				"data": "name",
				"render": function(d, t, f) {
					if (d == "default") {
						return '<span style="color: #d9534f;"><i class="icon-minus-sign" style="font-size:15px"></i> 禁止移动</span>';
					}
					
					return '<div class="btn-group btn-group-xs"><a class="btn btn-success mark1" onclick="rowMove(\'up\', \'' + f.name + '\')"><i class="icon-chevron-up"></i></a><a class="btn btn-success mark2" onclick="rowMove(\'down\', \'' + f.name + '\')"><i class="icon-chevron-down"></i></a></div>'; 
				}
			},
			{
				"data": "name",
				"width": 80,
				"orderable": false,
				"render": function(d, t, f) {
					if (d != "default") {
						return '<div class="btn-group btn-group-xs"><a class="btn btn-zx" onclick="edit(this)" data-toggle="tooltip" data-container="body" title="编辑"><i class="icon-pencil"></i></a><a class="btn btn-danger" onclick="OnDelete(\'' + d + '\')" data-toggle="tooltip" data-container="body" title="删除"><i class="icon-trash"></i></a></div>';
					} else {
						return '<div class="btn-group btn-group-xs"><a class="btn btn-zx" onclick="edit(this)" data-toggle="tooltip" data-container="body" title="编辑"><i class="icon-pencil"></i></a><a class="btn btn-danger disabled" data-toggle="tooltip" data-container="body" title="禁止删除默认策略"><i class="icon-trash"></i></a></div>';
					}
				}
			}
        ],
		"rowCallback": function(nTd, sData, oData, iRow, iCol) {
			$(nTd).find("td:first").html(iRow + 1);
		},
		"drawCallback": function() {
			var rows = this.api().rows().nodes();
			if (rows.length > 0) {
				var firstRow = rows[0];
				var pre_lastRow = this.api().row(rows.length - 2).node();
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

function initData2() {
	cgicall("AuthOptList", function(d) {
		if (d.status == 0 && typeof d.data != "undefined" && typeof d.data.redirect != "undefined") {
			$("#AuthUrl").val(d.data.redirect);
		}
	});
}

function initData() {
	dtReloadData(oTabAuth, false)
}

function edit(that) {
	var node,
		obj = {},
		iprange;

	modify_flag = "mod";
	$('#name').prop("disabled", true);
	
	node = $(that).closest("tr");
	obj = oTabAuth.api().row(node).data();
	
	if (obj.name == "default") {
		$('#iprange,input:radio[name="type"]').prop("disabled", true);
	} else {
		$('#iprange,input:radio[name="type"]').prop("disabled", false);
	}

	jsonTraversal(obj, jsTravSet);
	iprange = obj.ip1 + '-' + obj.ip2;
	$("#iprange").val(iprange);
	
	$('#modal_edit').modal("show");
}

function DoSave() {
	if (!verification()) return;
	
	var data = jsonTraversal(g_auth, jsTravGet);
	var iprange = $('#iprange').val().split('-');
	if (iprange.length == 2) {
		data['ip1'] = iprange[0];
		data['ip2'] = iprange[1];
	} else {
		data['ip1'] = iprange[0];
		data['ip2'] = iprange[0];
	}

	if (modify_flag == "add") {
		if ($("#name").val() == "default") {
			verifyModalTip("不能以 default 命名！");
			return;
		}
		cgicall("PolicyAdd", data, function(d) {
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
		if ($("#name").val() == "default") {
			$('#modal_edit').modal("hide");
			return;
		};
		cgicall("PolicySet", data, function(d) {
			var func = {
				"sfunc": function() {
					initData();
				},
				"ffunc": function() {
					createModalTips("修改失败！" + (d.data ? d.data : ""));
				}
			}
			cgicallBack(d, "#modal_edit", func);
		});
	}
}

function rowMove(set, name) {
	var data,
		num,
		forward,
		back,
		arr = [],
		obj = {};
		
	if (name == "default") {
		createModalTips("禁止移动默认策略！");
		return;
	}

	data = oTabAuth.api().rows().data();
	for (var i = 0; i < data.length; i++) {
		if (data[i].name == name) {
			num = i;
		}
		arr.push(data[i].name);
	}

	if (set == "up") {
		if (num == 0) {
			createModalTips("第一条，不能移动！");
			return;
		}
		forward = arr[num];
		back = arr[num - 1];
		arr[num - 1] = forward;
		arr[num] = back;
	} else if (set == "down") {
		if (num == data.length - 2) {
			createModalTips("不能移动到默认策略的位置！");
			return;
		}
		forward = arr[num + 1];
		back = arr[num];
		arr[num] = forward;
		arr[num + 1] = back;
	}

	cgicall("PolicyAdj", arr, function(d) {
		if (d.status == 0) {
			initData();
		} else {
			createModalTips("移动失败！" + (d.data ? d.data : ""));
		}
	})
}

function DoDelete() {
	var arr = [];
	arr.push(g_delname);
	cgicall("PolicyDel", arr, function(d) {
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

function initEvents() {
	$('.add').on('click', OnAddAuth);
	$('.submit').on('click', OnSubmit)
	$('[data-toggle="tooltip"]').tooltip();
}

function OnAddAuth() {
	modify_flag = "add";
	$('#name').prop("disabled", false);
	$('#iprange,input:radio[name="type"]').prop("disabled", false);
	$('#modal_edit').modal("show");
}

function OnSubmit() {
	var val = $.trim($("#AuthUrl").val());
	if (val.substring(0, 7) != "http://" && val.substring(0, 8) != "https://" && val != "") {
		val = "http://" + val;
	}
	var obj = {
		redirect: val
	}
	cgicall("AuthOptSet", obj, function(d) {
		if (d.status == 0) {
			initData2();
			createModalTips("保存成功！");
		} else {
			createModalTips("保存失败！" + (d.data ? d.data : ""));
		}
	})
}

function OnDelete(name){
	if (name  == 'default' ) {
		createModalTips("无法删除默认策略!");
		return;
	}
	g_delname = name;
	createModalTips("删除后不可恢复。</br>确定要删除？", "DoDelete");
}
