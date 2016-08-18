var oTabWlan,
	oTabAps,
	nodeEdit = [],
	opr = 'add',
	modify_wlanid = "00001",
	oSSID = {
		'enable': "1",
		'band': 'all',
		'SSID': 'SSID',
		'encrypt': 'none',
		'password':'',
		'hide': "0",
		'vlanEnable': '0',
		'vlanID': ''
	};

$(function() {
	oTabWlan = createDtWlan();
	oTabAps = createDtAps();
	createInitModal();
	verifyEventsInit();
	initEvents();
});

function createDtWlan() {
	var cmd = {"key": "WLANList"}
	return $("#table_wlanconfig").dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": "../../js/black/dataTables.chinese.json"},
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
				"data": "SSID"
			},
			{
				"data": "band",
				"visible": false,
				"render": function(d, t, f) {
					if (d === "2g") {
						return "2G";
					} else if (d === "5g") {
						return "5G";
					} else {
						return "双频";
					}
				}
			},
			{
				"data": "encrypt"
			},
			{
				"data": "checkAps",
				"render": function(d, t, f) {
					return '<a href="javascript:;" onclick="OpenCheckaps(this);" data-toggle="tooltip" data-container="body" title="查看"><span class="badge">' + d + '</span></a>';
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
				"width": 90,
				"orderable": false,
				"render": function(d, t, f) {
					return '<div class="btn-group btn-group-xs"><a class="btn btn-zx"  onclick="edit(this);" data-toggle="tooltip" data-container="body" title="编辑"><i class="icon-pencil"></i></a><a class="btn btn-danger" onclick="OnDelete(this);" data-toggle="tooltip" data-container="body" title="删除"><i class="icon-trash"></i></a></div>';
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
			//提示
			$("body > div.tooltip").remove();
			$('[data-toggle="tooltip"]').tooltip();
		}
	});
}

function createDtAps() {
	return $('#table_effectaps').dataTable({
		// "pagingType": "full_numbers",
		"order": [[0, 'asc']],
		"language": {"url": "../../js/black/dataTables.chinese.json"},
		"columns": [
			{
				"data": "apid",
				"render" : function(d, t, f) {
					return '<span value="' + d + '">' + d + (f.ap_des ? ' (' + f.ap_des + ')' : '') + '</span>';
				}
			},
			{ 
				"data": "check",
				"orderable": false,
				"render": function(d, t, f) {
					if (d == "1") {
						return '<input type="checkbox" checked="checked" value="1 0" />';
					} else {
						return '<input type="checkbox" value="1 0" />';
					}
				}
			}
		],
		"rowCallback": dtBindRowSelectEvents,
		"drawCallback": function() {
			// $('.efaps_all input').prop("checked", true);
			// $('.efaps_oth input').prop("checked", false);
			this.$('td:eq(1)', {}).each(function(index, element) {
				if ($(element).find('input').is(":checked")) {
					$(element).parent("tr").addClass("row_selected");
				} else {
					$(element).parent("tr").removeClass("row_selected");
					if (opr != 'add') {
						$('.efaps_all input').prop("checked", false);
						$('.efaps_oth input').prop("checked", true);
					}
				}
			});
		}
	})
}

function createInitModal() {
	$("#modal_edit, #modal_tips, #modal_checkaps").modal({
		"backdrop": "static",
		"show": false
	});
}

function initData() {
	dtReloadData(oTabWlan, false)
}

function edit(that) {
	opr = 'edit',
	getSelected(that);
	jsonTraversal(nodeEdit[0], jsTravSet);
	OnEncrypt();
	OnVlanChanged();
	set_wlanListAps(nodeEdit[0]);
}

function set_wlanListAps(wlan){
	var obj = {
			"SSID": "",
			"ext_wlanid": ""
		}

	if (wlan && typeof wlan == "object") {
		obj.SSID = wlan["SSID"];
		obj.ext_wlanid = wlan["ext_wlanid"];
		modify_wlanid = wlan["ext_wlanid"];
	} else {
		$(".efaps_all input").prop("checked", true);
		$(".efaps_oth input").prop("checked", false);
		$(".checkall2").prop("checked", false)
	}

	cgicall('WLANListAps', obj, function(d) {
		if (d.status == 0) {
			dtRrawData(oTabAps, dtObjToArray(d.data));
			OnEfaps("true");
			$("#modal_edit").modal("show");
		} else {
			createModalTips("获取AP列表失败！请尝试重新加载！");
		}
	})
}

function set_enable(that) {	
	var node = $(that).closest("tr");
	var obj = oTabWlan.api().row(node).data();
	
	if (obj.enable == "1") {
		obj.enable = "0";
	} else {
		obj.enable = "1";
	}

	var sobj = {
		"cmd": "setwlan",
		"data": {
			"SSID": obj.SSID,
			"enable": obj.enable,
			"ext_wlanid": obj.ext_wlanid
		}
	}

	cgicall('WLANModify', sobj, function(d) {
		if (d.status == 0) {
			initData();
		} else {
			createModalTips("修改失败！" + (d.data ? d.data : ""));
		}
	});
}

function OpenCheckaps(that) {
	var node,
		obj;

	getSelected(that);
	obj = {
		"SSID": nodeEdit[0]["SSID"],
		"ext_wlanid": nodeEdit[0]["ext_wlanid"]
	}

	cgicall('WLANListAps', obj, function(d) {
		if (d.status == 0) {
			var arr = [],
				data = dtObjToArray(d.data);

			for (var i = 0; i < data.length; i++) {
				if (data[i].check == '1') {
					arr.push('<li>' + data[i].apid + ' (' + (data[i].ap_des ? data[i].ap_des : "") + ')</li>');
				}
			}

			$('#modal_checkaps .ul-checkaps').html(arr.join(""));
			$("#modal_checkaps").modal("show");
		} else {
			createModalTips("获取AP列表失败！请尝试重新加载！");
		}
	});
}

function DoSave() {
	if (!verification()) return;

	var apArr = [],
		obj = jsonTraversal(oSSID, jsTravGet),
		nodes = oTabAps.api().rows().nodes();
	
	if ($('.efaps_all input').is(":checked")) {
		for (var k = nodes.length - 1; k >= 0; k--) {
			apArr.push($(nodes[k]).find("td:eq(0) span").attr("value"));
		};
	} else {
		for (var i = nodes.length - 1; i >= 0; i--) {
			if ($(nodes[i]).hasClass('row_selected')) {
				apArr.push($(nodes[i]).find("td:eq(0) span").attr("value"));
			}
		};
	}

	obj.apList = apArr;
	if ('checkAps' in obj) {
		delete obj.checkAps;
	}
	if (opr == 'add') {
		cgicall('WLANAdd', obj, function(d) {
			var func = {
				"sfunc": function() {
					initData();
				},
				"ffunc": function() {
					createModalTips("保存失败！" + (d.data ? d.data : ""));
				}
			}
			cgicallBack(d, "#modal_edit", func);
		});
	} else {
		obj["ext_wlanid"] = modify_wlanid;
		var sobj = {
			"cmd": "modify",
			"data": obj
		}

		cgicall('WLANModify', sobj, function(d) {
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

function DoDelete() {
	var arr = [];
	for (var i = nodeEdit.length - 1; i >= 0; i--) {
		arr.push({"SSID": nodeEdit[i].SSID, "ext_wlanid": nodeEdit[i].ext_wlanid});
	}

	cgicall('WLANDelete', arr, function(d) {
		var func = {
			"sfunc": function() {
				initData();
			},
			"ffunc": function() {
				createModalTips("删除失败！" + (d.data ? d.data : ""));
			}
		}
		cgicallBack(d, "#modal_tips", func);
	})
}

function initEvents() {
	$(".add").on("click", OnAdd);
	$(".delete").on("click", function() {OnDelete();});
	$(".checkall").on("click", OnSelectAll);
	$(".checkall2").on("click", OnSelectAll2);
	$("#encrypt").on("change", OnEncrypt);
	$('[name="efaps"]').on("change", OnEfaps);
	$(".showlock").on("click", OnShowlock);
	$("#vlanEnable").on("click", OnVlanChanged);
	$('[data-toggle="tooltip"]').tooltip();
}

function OnAdd() {
	opr = 'add';
	var oSSID = {
		'enable': "1",
		'band': 'all',
		'SSID': '',
		'encrypt': 'none',
		'password':'',
		'hide': "0",
		'vlanEnable': '0',
		'vlanID': ''
	}
	jsonTraversal(oSSID, jsTravSet);
	OnEncrypt();
	OnVlanChanged();
	set_wlanListAps();
}

function OnDelete(that) {
	getSelected(that);
	if (nodeEdit.length < 1) {
		createModalTips("选择要删除的SSID！");
		return;
	}
	createModalTips("删除后不可恢复。</br>确定要删除？", "DoDelete");
}

function OnSelectAll() {
	dtSelectAll(this, oTabWlan);
}

function OnSelectAll2() {
	dtSelectAll(this, oTabAps);
}

function OnEncrypt() {
	var ent = $('#encrypt').val();
	if (ent == 'none') {
		$('#password').prop('disabled', true);
		$('#password').val('');
	}else{
		$('#password').prop('disabled', false);
	};
}

function OnEfaps(bol) {
	var checked = $("input[name='efaps']:checked").val();
	if (checked == "all") {
		if (bol == "true") {
			$(".effectaps").css("display", "none");
		} else {
			$(".effectaps").slideUp();
		}
	} else {
		if (bol == "true") {
			$(".effectaps").css("display", "block");
		} else {
			$(".effectaps").slideDown();
		}
	}
}

function OnShowlock(that) {
	var tt = $(this).closest(".form-group").find("input.form-control")
	if (tt.length > 0 && (tt.attr("type") == "text" || tt.attr("type") == "password")) {
		if (tt.attr("type") == "password") {
			$(this).find("i").removeClass("icon-lock").addClass("icon-unlock");
			tt.attr("type", "text");
		} else {
			$(this).find("i").removeClass("icon-unlock").addClass("icon-lock");
			tt.attr("type", "password")
		}
	}
}

function OnVlanChanged() {
	var en = $('#vlanEnable').prop('checked');
	if (en) {
		$('#vlanID').prop('disabled', false);
	}else{
		$('#vlanID').prop('disabled', true);
	};
}

function getSelected(that) {
	nodeEdit = [];
	if (that) {
		var node = $(that).closest("tr");
		var data = oTabWlan.api().row(node).data();
		nodeEdit.push(data);
	} else {
		nodeEdit = dtGetSelected(oTabWlan);
		console.log(nodeEdit)
	}
}
