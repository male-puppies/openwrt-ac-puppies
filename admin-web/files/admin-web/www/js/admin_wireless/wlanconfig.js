var oTabWlan,
	nodeEdit = [],
	opr = 'add';
$(function() {
	oTabWlan = createDtWlan();
	createInitModal();
	verifyEventsInit();
	initEvents();
});

function createDtWlan() {
	var cgiobj = {
		"page": 1,
		"count": 10000,
		"order": "ssid",
		"desc": 1,
		"search": "ssid",
		"link": "all"
	}
	return $("#table_wlanconfig").dataTable({
		"pagingType": "full_numbers",
		"order": [
			[1, 'asc']
		],
		"language": {
			"url": "../../js/lib/dataTables.chinese.json"
		},
		"ajax": {
			"url": cgiDtUrl("wlan_get", cgiobj),
			"type": "GET",
			"dataSrc": dtDataCallback
		},
		"columns": [{
			"data": null,
			"width": 60
		}, {
			"data": "ssid"
		}, {
			"data": "encrypt"
		}, {
			"data": "band",
			"render": function(d, t, f) {
				if(d === "2g") {
					return "2G";
				} else if(d === "5g") {
					return "5G";
				} else {
					return "双频";
				}
			}
		}, {
			"data": "enable",
			"render": function(d, t, f) {
				if(d == 0) {
					return '<a class="btn btn-danger btn-xs" onclick="set_enable(this)" data-toggle="tooltip" data-container="body" title="点击启用"><i class="icon-remove"></i> 已禁用 </a>';
				} else {
					return '<a class="btn btn-success btn-xs" onclick="set_enable(this)" data-toggle="tooltip" data-container="body" title="点击禁用"><i class="icon-ok"></i> 已启用 </a>';
				}
			}
		}, {
			"data": null,
			"width": 90,
			"orderable": false,
			"render": function(d, t, f) {
				return '<div class="btn-group btn-group-xs"><a class="btn btn-zx"  onclick="edit(this);" data-toggle="tooltip" data-container="body" title="编辑"><i class="icon-pencil"></i></a><a class="btn btn-danger" onclick="OnDelete(this);" data-toggle="tooltip" data-container="body" title="删除"><i class="icon-trash"></i></a></div>';
			}
		}, {
			"data": null,
			"width": 60,
			"orderable": false,
			"searchable": false,
			"defaultContent": '<input type="checkbox" value="1 0" />'
		}],
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
	$("#modal_edit, #modal_tips").modal({
		"backdrop": "static",
		"show": false
	});
}

function initEvents() {
	$(".add").on("click", OnAdd);
	$(".delete").on("click", function() { OnDelete(); });
	$(".checkall").on("click", OnSelectAll);
	$("#encrypt").on("change", OnEncrypt);
	$(".showlock").on("click", OnShowlock);
	$('[data-toggle="tooltip"]').tooltip();
}

function initData() {
	dtReloadData(oTabWlan, false)
}

function OnAdd() {
	opr = 'add';
	var oSSID = {
		'enable': '1',
		'band': 'all',
		'ssid': '',
		'encrypt': 'none',
		'password': '',
		'hide': "0",
	};
	jsonTraversal(oSSID, jsTravSet);
	OnEncrypt();
	$('#modal_edit').modal("show");
}

function edit(that) {
	opr = 'edit';
	getSelected(that);
	jsonTraversal(nodeEdit[0], jsTravSet);
	OnEncrypt();
	$('#modal_edit').modal("show");
}

function set_enable(that) {
	getSelected(that);
	var obj = ObjClone(nodeEdit[0]);
	if(obj.enable == "1") {
		obj.enable = "0";
	} else {
		obj.enable = "1";
	}

	cgicall.post('wlan_set', obj, function(d) {
		cgicallBack(d, initData, function() {
			createModalTips("修改失败！" + (d.data ? d.data : ""));
		});
	});
}

function DoSave() {
	if(!verification()) return;
	var oSSID = {
		'enable': '1',
		'band': 'all',
		'ssid': '',
		'encrypt': 'none',
		'password': 'none',
		'hide': "0",
		'wlanid':"0"
	}
	var obj = jsonTraversal(oSSID,jsTravGet);
	if(opr == 'add') {
		cgicall.post('wlan_add', obj, function(d) {
			cgicallBack(d, initData, function() {
				createModalTips("添加失败！" + (d.data ? d.data : ""));
			});
		});
	} else {
		obj.wlanid = nodeEdit[0].wlanid;
		cgicall.post('wlan_set', obj, function(d) {
			cgicallBack(d, initData, function() {
				createModalTips("添加失败！" + (d.data ? d.data : ""));
			});
		});
	}
}

function OnDelete(that) {
	getSelected(that);
	if(nodeEdit.length < 1) {
		createModalTips("选择要删除的SSID！");
		return;
	}
	createModalTips("删除后不可恢复。</br>确定要删除？", "DoDelete");
}

function DoDelete() {

	var arr = [];
	for(var i = nodeEdit.length - 1; i >= 0; i--) {
		arr.push({
			"ssid": nodeEdit[i].ssid,
			"wlanid": nodeEdit[i].wlanid
		});
	}
	var obj = {wlanids:arr}
	cgicall.post('wlan_del', obj, function(d) {
		cgicallBack(d, initData, function() {
			createModalTips("删除失败！" + (d.data ? d.data : ""));
		});
	})
}

function OnEncrypt() {
	var ent = $('#encrypt').val();
	if(ent == 'none') {
		$('#password').prop('disabled', true);
		$('#password').val('');
	} else {
		$('#password').prop('disabled', false);
	};
}

function OnShowlock(that) {
	var tt = $(this).closest(".form-group").find("input.form-control")
	if(tt.length > 0 && (tt.attr("type") == "text" || tt.attr("type") == "password")) {
		if(tt.attr("type") == "password") {
			$(this).find("i").removeClass("icon-lock").addClass("icon-unlock");
			tt.attr("type", "text");
		} else {
			$(this).find("i").removeClass("icon-unlock").addClass("icon-lock");
			tt.attr("type", "password")
		}
	}
}

function OnSelectAll() {
	dtSelectAll(this, $("#table_wlanconfig"));
}

function getSelected(that) {
	nodeEdit = [];
	if(that) {
		var node = $(that).closest("tr");
		var data = oTabWlan.api().row(node).data();
		nodeEdit.push(data);
	} else {
		nodeEdit = dtGetSelected(oTabWlan);
	}
}