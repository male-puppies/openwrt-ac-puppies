
// JavaScript Document
var oTbChannel,
	opera_flag = "new",
	oConf,
	oRule = {
	 "Enabled": true,
	 "Ip": "192.168.0.10-192.168.0.200",
	 "Name": "用户限制",
	 "PerIpDownload": "",
	 "PerIpUpload": "",
	 "SharedDownload": "",
	 "SharedUpload": ""
};

$(document).ready(function(){
	oTbChannel = createoTableChannelsConfig();
	initCreateDialog()
	initData();
	initEvents();
	verifyEventsInit();
});

function initCreateDialog(){
	$('#panl_TcRule').dialog({
		"title": '流量控制配置',
		"autoOpen": false,
		"modal": true,
		"resizable": true,
		"width": 620,
		"height": 500,
		"buttons": [
			{
				"text": "确定",
				"click": function() {
					saveTcRule();
				}
			},
			{
				"text": "取消",
				"click": function() {
					$(this).dialog("close");
				}
			}
		]
	});
}

function createoTableChannelsConfig(){
	return $('#flow_ctrl').dataTable({
		"bAutoWidth": false,
		"sPaginationType": "full_numbers",
		"language": {
			"url": '/luci-static/resources/js/black/dataTables.chinese.json'
		},
		"aaSorting": [[1, 'asc']],
		"aoColumns": [
			{
				"mData": "Name",
				"mRender": function(d, t, f) {
					return "<a href='javascript:;' class='edit' onclick='set_edit(\"" + d + "\")'>"+ d +"</a>";
				}
			},
			{
				"mData": "Ip"
			},
			{
				"mData": "SharedDownload"
			},
			{
				"mData": "SharedUpload"
			},
			{
				"mData": "PerIpDownload"	
			},
			{
				"mData": "PerIpUpload"
			},
			{
				"mData": "Enabled",
				"mRender":function(d, t, f) {
					if (d.toString() == "true") {
						return '<a href="javascript:;" class="edit icon-ok" onclick="set_enable(\'' + f.Name + '\', \'' + d + '\')">已启用</a>';
					} else {
						return '<a href="javascript:;" class="edit icon-no" onclick="set_enable(\'' + f.Name + '\', \'' + d + '\')">已禁用</a>';
					}
				}	
			},
			{
				"mData": "Name",
				"bSortable": false,
				"mRender": function(d, t, f) {
					return "<a href='javascript:;' class='del' onclick='set_del(\"" + d + "\")'>删除</a>";
				}
			}
		]
	});
}

function initData() {
	$.post(
		"get_flow",
		function(d) {
			oConf = d;
			jsonTraversal(oConf, jsTravSet);
			fixUnit(oConf);
			if (typeof(oConf.Rules) != "undefined" && oConf.Rules.length != 0) {
				dtReloadData(oTbChannel, dtObjToArray(oConf.Rules));
			} else {
				oTbChannel.fnClearTable();
			}
		},
		'json'
	)
}

function saveTcRule() {	
	if (!verification(".verify-two")) return;

	var obj = jsonTraversal(oRule, jsTravGet);
	var o = combUnit(obj);

	if (opera_flag == "add_new") {
		var rules = oConf.Rules;
		for (var i = rules.length - 1; i >= 0; i--) {
			if (rules[i].Name == o.Name) {
				alert("名称冲突！");
				return;
			}
		};
		$.post(
			"insRules",
			o,
			function(d) {
				if (d.state == '0') {
					initData();
				} else {
					alert('添加失败！')
				}
			},
			"json"
		)
	} else {
		$.post(
			"updateRules",
			o,
			function(d) {
				if (d.state == '0') {
					initData();
				} else {
					alert('修改失败！')
				}
			},
			"json"
		)
	}
	$('#panl_TcRule').dialog('close');

}

function combUnit(ooo){
	var s = {};
	for (var k in ooo) {
		if (typeof(ooo[k]) == "object") continue;
		s[k] = ooo[k];
		var unit = $('#' + k + '_Unit');
		if(!unit.length) continue;

		s[k] = $('#' + k).val() + unit.val();
	}
	return s;
}

function fixUnit(ooo){
	for (var k in ooo) {
		if (typeof(ooo[k]) == "object") continue;
		var unit = $('#' + k + '_Unit');
		var val = ooo[k]; 
		var ctl = $('#' + k);
		var idx = val.indexOf('M');
		if (idx < 0) 
			idx = val.indexOf('K');

		ctl.val(val.substr(0, idx));
		if (val != "" && unit.length > 0) unit.val(val.substr(idx));
	};
}

function onAdd_new(){
	opera_flag = "add_new";
	jsonTraversal(oRule, jsTravSet);
	fixUnit(oRule);
	oRule["Enabled"] = true;
	$('#Name').prop('disabled', false);
	$("#panl_TcRule").dialog('open');
}

function set_edit(name){
	getChannelByName(name);
	jsonTraversal(oRule, jsTravSet);
	fixUnit(oRule);
	opera_flag = "edit";
	$('#Name').prop('disabled', true);
	$("#panl_TcRule").dialog('open');	
}

function getChannelByName(name){
	var rules = oConf.Rules;
	for (var i = rules.length - 1; i >= 0; i--) {
		if (rules[i].Name == name) {
			for (var k in oRule) {
				oRule[k] = rules[i][k];
			}
		}
	}
}

function set_del(name) {
	$.post(
		"deletRules",
		{
			"Name": name
		},
		function(d) {
			if (d.state == "0") {
				initData();
			} else {
				alert('删除失败！');
			}
		},
		"json"
	)
}

function set_enable(name, en){
	$.post(
		"updateRules",
		{
			"Name": name,
			"Enabled": en == 'true' ? false : true
		},
		function(d) {
			if (d.state == "0") {
				initData();
			} else {
				alert('修改失败！');
			}
		},
		"json"
	)
}

function on_save_conf() {
	if (!verification(".verify-one")) return;

	var s = {};
	var upload = $("#GlobalSharedUpload").val();
	var download = $("#GlobalSharedDownload").val();

	s.GlobalSharedUpload = upload + 'Mbps';
	s.GlobalSharedDownload = download + 'Mbps';
	$.post(
		"set_globalshare",
		s,
		function(d) {
			if (d.state == '0') {
				alert('保存成功!');
			} else {
				alert('保存失败!');
			}
		},
		"json"
	)
}

function initEvents(){
	$('.add_new').on('click', onAdd_new);
	$('.btn_save_conf').on('click', on_save_conf);
	$("#cbi-flowctrl,#panl_TcRule").tooltip();
}
