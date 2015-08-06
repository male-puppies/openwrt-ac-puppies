
// JavaScript Document
var oTbChannel,
	oDiagTc,
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
	oDiagTc = createDialogTcRule();
	oTbChannel = createoTableChannelsConfig();
	initData();
	initEvents();
	$(".panel-body").css("width","auto")
});

function createDialogTcRule(){
	return $('#panl_TcRule').dialog({
		closed: true,
		modal: true,
		resizable: true,
		title: '流量控制配置',
    	width: 540,
		height: 420,
		buttons: [
			{
				text: '确定',
				handler: function(){
					saveTcRule();
				}
			},
			{
				text: '取消',
				handler: function() {
					$('#panl_TcRule').dialog('close');	
				}
			}
		]	
	});	
}


function createoTableChannelsConfig(){
	return $('#flow_ctrl').dataTable({
	  	    "bProcessing": false,
			"bSort": true,
			"aoColumnDefs": [{"bSortable": false, "aTargets": [ 7 ]}],
			"bAutoWidth": false,
	  	    "aaData": null,
	  	    "sAjaxDataProp": "",
			"sPaginationType": "full_numbers",
	  	    "aoColumns": [
	  	    	{ 
					"mData": "Name",
					"mRender":function(d, t, f){
						return  renderOperations(d,[{type: "edit"}]); 
					}
	  	    	},
	  	    	{
					"mData": "Ip"
				},
	  	    	{ 
	  	    		"mData": "SharedDownload",
	  	    	},
				{ 
					"mData": "SharedUpload"
				},
				{
					"mData":"PerIpDownload"	
				},
				{
					"mData": "PerIpUpload"
				},
				{
					"mData":"Name",
					"mRender":function(d, t, f){
						return renderOperations(d, [{type: "enable", val: f.Enabled}])	
					}	
				},
				{
					"mData": "Name",
					
					"mRender": function(d, t, f) {
						return renderOperations(d, [{type: "del"}]);
					}
				}
			],
			"aaSorting": [[ 1, 'asc' ]]
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
				dtReloadData(oTbChannel, oConf.Rules);
			} else {
				oTbChannel.fnClearTable();
			}
		},
		'json'
	)
}

function saveTcRule() {	
	if(verification() == false){ 
		alert("Please pay attention to the error messages!");
		return;
	};
	jsonTraversal(oRule, jsTravGet);
	var o = combUnit(oRule);
	//submits
    if(o.Name ==  ""){
		alert('名称不能为空！');
		return;	
	}
	if(stringLenChina(o.Name) > 30){
		alert('名称太长！');
		return;
	}
	var rulesIp,rulesIpFront,rulesIpBack,NoSpacesRulesIpFront,NoSpacesRulesIpBack,rulesIpTest
	rulesIp = o.Ip;
	if(rulesIp == ""){
		alert('地址范围不能为空！');
		return;
	}
	rulesIpTest = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
	
	if (rulesIp.indexOf("-") != -1) {
		rulesIpFront = rulesIp.substring(0,rulesIp.indexOf("-"));
		rulesIpBack = rulesIp.substring(rulesIp.indexOf("-") + 1, rulesIp.length);
		NoSpacesRulesIpFront = $.trim(rulesIpFront);
		NoSpacesRulesIpBack = $.trim(rulesIpBack);
		if (!rulesIpTest.test(NoSpacesRulesIpFront) || !rulesIpTest.test(NoSpacesRulesIpBack)) {
			alert("地址范围格式不对！");
			return;	
		}
	} else {
		if (!rulesIpTest.test(rulesIp)) {
			alert("地址范围格式不对！");
			return;
		}
	}
	
	if ($('#SharedDownload').val() == "" || $('#SharedUpload').val() == "" || $('#PerIpDownload').val() == "" || $('#PerIpUpload').val() == "") {
		alert('流量数值不能为空！');
		return;
	}
	
	if (isNaN($('#SharedDownload').val()) || isNaN($('#SharedUpload').val()) || isNaN($('#PerIpDownload').val()) || isNaN($('#PerIpUpload').val())) {
		alert('流量数值格式不对！');
		return;
	}

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
				if (d == '0') {
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
				if (d == '0') {
					initData();
				} else {
					alert('修改失败！')
				}
			}
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
		if (!unit.length) continue;
		var val = ooo[k]; 
		var ctl = $('#' + k);
		var idx = val.indexOf('M');
		if (idx < 0) 
			idx = val.indexOf('K');

		ctl.val(val.substr(0, idx));
		unit.val(val.substr(idx));
	};
}

function onAdd_new(){
	opera_flag = "add_new";
	jsonTraversal(oRule, jsTravSet);
	fixUnit(oRule);
	oRule["Enabled"] = true;
	$('#Name').attr('disabled', false);
	oDiagTc.dialog('open');
}

function set_edit(name){
	getChannelByName(name);
	jsonTraversal(oRule, jsTravSet);
	fixUnit(oRule);
	opera_flag = "edit";
	$('#Name').attr('disabled', true);
	oDiagTc.dialog('open');	
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
			if (d == "0") {
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
			if (d == "0") {
				initData();
			} else {
				alert('修改失败！');
			}
		},
		"json"
	)
}

function on_save_conf() {
	var s = {};
	var upload = $("#GlobalSharedUpload").val();
	var download = $("#GlobalSharedDownload").val();
	
	if (upload < 0 || upload > 16000 || download < 0 || download > 16000 || download == "" || upload == "") {
		alert("请输入0-16000的数值！");
		return;
	}
	s.GlobalSharedUpload = upload + 'Mbps';
	s.GlobalSharedDownload = download + 'Mbps';
	$.post(
		"set_globalshare",
		s,
		function(d) {
			if (d == '0') {
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
}

function stringLenChina(s) { //字符串的字符长度，中文为3
	var l = 0;
	var a = s.split("");
	for (var i = 0; i < a.length; i++) {
		if (a[i].charCodeAt(0) < 299) {
			l++;
		} else {
			l += 3;
		}
	}
	return l;
}