var oTabFlow,
	nodeEdit = [],
	opr = "add";

$(function(){
	oTabFlow = createDtFlow();
	createInitModal();
	verifyEventsInit();
	initEvents();
});

function createDtFlow(){
	var cmd = {"key": "GetFlow"}
	return $("#table_flowctrl").dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": '../../js/black/dataTables.chinese.json'},
		"ajax": {
			"url": "/call/cgicall",
			"type": "POST",
			"data": {
				"cmd": JSON.stringify(cmd)
			},
			"dataSrc": function(json) {
				if (json.status == 0) {
					$("#GlobalSharedDownload").val(parseInt(json.data.GlobalSharedDownload));
					$("#GlobalSharedUpload").val(parseInt(json.data.GlobalSharedUpload));
					return dtObjToArray(json.data.Rules);
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
				"data": "Name"
			},
			{
				"data": "Ip"
			},
			{
				"data": "SharedDownload"
			},
			{
				"data": "SharedUpload"
			},
			{
				"data": "PerIpDownload"	
			},
			{
				"data": "PerIpUpload"
			},
			{
				"data": "Enabled",
				"render": function(d, t, f) {
					if (typeof d != "undefined" && d.toString() != "true") {
						return '<a class="btn btn-danger btn-xs" onclick="set_enable(this)" data-toggle="tooltip" data-container="body" title="点击启用"><i class="icon-remove"></i> 已禁用 </a>';
					} else {
						return '<a class="btn btn-success btn-xs" onclick="set_enable(this)" data-toggle="tooltip" data-container="body" title="点击禁用"><i class="icon-ok"></i> 已启用 </a>';
					}
				}	
			},
			{
				"data": "Name",
				"orderable": false,
				"render": function(d, t, f) {
					return '<div class="btn-group btn-group-xs"><a class="btn btn-zx"  onclick="edit(this);" data-toggle="tooltip" data-container="body" title="编辑"><i class="icon-pencil"></i></a><a class="btn btn-danger" onclick="OnDelete(this);" data-toggle="tooltip" data-container="body" title="删除"><i class="icon-trash"></i></a></div>';
				}
			},
			{
				"data": null,
				"width": 20,
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

function edit(that) {
	getSelected(that)
	jsonTraversal(nodeEdit[0], jsTravSet);
	fixUnit(nodeEdit[0]);
	opr = "mod";
	$("#Name").prop("disabled", true);
	$("#modal_edit").modal("show");	
}

function set_enable(that) {
	getSelected(that);
	var obj = {
		"Name": nodeEdit[0].Name,
		"Enabled": nodeEdit[0].Enabled.toString() == 'true' ? false : true
	}
	cgicall("UpdateRules", obj, function(d) {
		if (d.status == "0") {
			initData();
		} else {
			createModalTips("修改失败！");
		}
	});
}

function DoSave() {	
	if (!verification(".modal")) return;

	var obj = jsonTraversal(nodeEdit[0], jsTravGet);
	var o = combUnit(obj);

	if (opr == "add") {
		var data = oTabFlow.api().rows().data();
		for (var i = data.length - 1; i >= 0; i--) {
			if (data[i].Name == o.Name) {
				verifyModalTip("名称冲突！");
				return;
			}
		}
		cgicall("InsRules", o, function(d) {
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
		cgicall("UpdateRules", o, function(d) {
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
		arr.push(nodeEdit[i].Name);
	}

	cgicall('DeleteRules', arr, function(d) {
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

function initData() {
	dtReloadData(oTabFlow, false);
}

function initEvents(){
	$(".checkall").on("click", OnSelectAll);
	$('.delete').on('click', function() {OnDelete()}); //删除
	$('.add').on('click', onAdd);
	$('.submit').on('click', OnSubmit);
	
	$('[data-toggle="tooltip"]').tooltip();
}

function onAdd() {
	var oRule = {
			"Enabled": true,
			"Ip": "0.0.0.0-255.255.255.255",
			"Name": "流量控制",
			"SharedDownload": "0MBytes",
			"SharedUpload": "0MBytes",
			"PerIpDownload": "0MBytes",
			"PerIpUpload": "0MBytes"
		}
	
	nodeEdit = [];
	nodeEdit.push(oRule);
	opr = "add";
	jsonTraversal(oRule, jsTravSet);
	fixUnit(oRule);
	$('#Name').prop('disabled', false);
	$("#modal_edit").modal("show");
}

function OnDelete(that) {
	getSelected(that);
	if (nodeEdit.length < 1) {
		createModalTips("请选择要删除策略！");
		return;
	}
	createModalTips("删除后不可恢复。</br>确定要删除？", "DoDelete");
}

function OnSubmit() {
	if (!verification(".main")) return;

	var s = {};
	var upload = $("#GlobalSharedUpload").val();
	var download = $("#GlobalSharedDownload").val();

	s.GlobalSharedUpload = upload + 'Mbps';
	s.GlobalSharedDownload = download + 'Mbps';
	cgicall("SetGlobal", s, function(d) {
		if (d.status == '0') {
			createModalTips('保存成功!');
		} else {
			createModalTips('保存失败!');
		}
	});
}

function combUnit(ooo){
	var obj = ObjClone(ooo);
	for (var k in obj) {
		if (typeof(obj[k]) == "object") continue;
		var unit = $('#' + k + '_Unit');
		if(!unit.length) continue;

		obj[k] = $('#' + k).val() + unit.val();
	}
	return obj;
}

function fixUnit(ooo){
	for (var k in ooo) {
		if (typeof(ooo[k]) == "object" || k == "Name" || k == "Enabled" || k == "Ip") continue;
		var unit = $('#' + k + '_Unit');
		var val = ooo[k];
		var idx = val.indexOf('M');
		if (idx < 0) idx = val.indexOf('K');
		if (idx < 0) continue;

		$('#' + k).val(val.substr(0, idx));
		if (val != "" && unit.length > 0) unit.val(val.substr(idx));
	};
}

function OnSelectAll() {
	dtSelectAll(this, oTabFlow);
}

function getSelected(that) {
	nodeEdit = [];
	if (that) {
		var node = $(that).closest("tr");
		var data = oTabFlow.api().row(node).data();
		nodeEdit.push(data);
	} else {
		nodeEdit = dtGetSelected(oTabFlow);
	}
}
